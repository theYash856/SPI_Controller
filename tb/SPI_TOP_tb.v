`timescale 1ns / 1ps

module SPI_TOP_tb;
    parameter DATA_WIDTH = 8;
    parameter CPOL = 1'b1;    
    parameter CPHA = 1'b1;
    parameter CLK_FREQ = 100_000_000; 
    parameter SPI_FREQ = 1_000_000;

    reg clk_tb, rst_tb;
    reg tx_start_tb;
    reg [DATA_WIDTH-1:0] tx_data_tb;

    wire [DATA_WIDTH-1:0] rx_data_tb;
    wire mosi_tb;
    wire sclk_tb;
    wire cs_tb;
    wire busy_tb;
    wire done_tb;

    // Exposed by SPI_TOP purely because master and slave are co-located in this design, not real SPI pins.
    wire [DATA_WIDTH-1:0] slave_rx_data_tb;
    wire slave_busy_tb;
    wire slave_done_tb;

    SPI_TOP #(
        .DATA_WIDTH(DATA_WIDTH),
        .CPOL(CPOL),
        .CPHA(CPHA),
        .CLK_FREQ(CLK_FREQ),
        .SPI_FREQ(SPI_FREQ)
    ) uut (
        .clk(clk_tb), .rst(rst_tb), .tx_start(tx_start_tb), .tx_data(tx_data_tb),
        .rx_data(rx_data_tb), .mosi(mosi_tb), .sclk(sclk_tb), .cs(cs_tb),
        .busy(busy_tb), .done(done_tb),
        .slave_rx_data(slave_rx_data_tb), .slave_busy(slave_busy_tb), .slave_done(slave_done_tb)
    );

    // Clock generator - 10ns period = 100MHz, matches CLK_FREQ default
    always #5 clk_tb = ~clk_tb;

    // Watchdog - guarantees the sim ends even if a wait() never resolves because of a DUT bug.
    initial begin
        #200000;
        $display("[TIMEOUT] Watchdog expired - a wait() condition never resolved");
        $finish;
    end

    // Verification variables
    integer pass_count, fail_count, total_tests;
    reg [DATA_WIDTH-1:0] expected_data;

    // Waveform dump
    initial begin
        $dumpfile("SPI_TOP_tb.vcd");
        $dumpvars(0, SPI_TOP_tb);
    end

    // Monitor
    initial begin
        $monitor("Time=%0t | M_State=%0d S_State=%0d | CS=%b | Busy=%b SBusy=%b | Done=%b SDone=%b | MOSI=%b SCLK=%b | RX=%b SRX=%b",
                 $time, uut.master.current_state, uut.slave.current_state,
                 cs_tb, busy_tb, slave_busy_tb, done_tb, slave_done_tb,
                 mosi_tb, sclk_tb, rx_data_tb, slave_rx_data_tb);
    end

    
    // Driver tasks
    // 1. Reset DUT
     task reset_dut;
        begin
            rst_tb = 1;
            repeat (2) @(posedge clk_tb);
            rst_tb = 0;
            @(posedge clk_tb);
            #1; 
        end
        endtask
    
    // 2. Start Transfer
    task start_transfer(input [DATA_WIDTH-1:0] data);
        begin
            tx_data_tb  = data;
            tx_start_tb = 1;
            @(posedge clk_tb);
            tx_start_tb = 0;
            wait(busy_tb == 1 && slave_busy_tb == 1);
            @(posedge clk_tb);
        end
    endtask
    
    
    // 3. Wait for Done
    task wait_for_done;
        begin
            wait(done_tb == 1 && slave_done_tb == 1);
            // @(posedge clk_tb);
            #1;
        end
    endtask
    
    // 4. Check Result
    task check_result(input condition, input [8*40:1] test_name);
        begin
            total_tests = total_tests + 1;
            if (condition) begin
                $display("[PASS] Test %0d : %0s", total_tests, test_name);
                pass_count = pass_count + 1;
            end 
            else begin
                $display("[FAIL] Test %0d : %0s", total_tests, test_name);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // Tests
    // -----------------------------------------------------------------
    // Test sequence
    // -----------------------------------------------------------------
    initial begin
        clk_tb = 0;
        rst_tb = 0;
        tx_start_tb = 0;
        tx_data_tb  = 0;
        pass_count  = 0;
        fail_count  = 0;
        total_tests = 0;   
    
    // Test 1: Reset DUT
    reset_dut();
    check_result(busy_tb == 0 && done_tb == 0 && cs_tb == 1 && mosi_tb == 0 && rx_data_tb == 0 
                 && slave_busy_tb == 0 && slave_done_tb == 0 && slave_rx_data_tb == 0, "Reset Verification");
    
    // Test 2: Start Transfer
    reset_dut();            
    expected_data = 8'b1010_0101;
    start_transfer(expected_data);
    check_result(busy_tb == 1 && cs_tb == 0, "Start Transfer");
    
    // Test 3: End-to-End Loopback
    wait_for_done();
    check_result(rx_data_tb == expected_data && slave_rx_data_tb == expected_data, "End-to-End Loopback");
    
    // Test 4: Check Both FSMs
    check_result(done_tb == 1 && slave_done_tb == 1 && busy_tb == 0 && slave_busy_tb == 0, "Both FSMs Complete Together");
    
    // Test 5: Back to Back Transfer
    expected_data = 8'b1010_0101;
    start_transfer(expected_data);
    wait_for_done();
    check_result(rx_data_tb == expected_data && slave_rx_data_tb == expected_data,
                 "First Back-to-Back Transfer");
    
    expected_data = 8'b0101_1010;
    start_transfer(expected_data);
    wait_for_done();
    check_result(rx_data_tb == expected_data && slave_rx_data_tb == expected_data,
                 "Second Back-to-Back Transfer");
                 
    // Verification Summary
    $display("\n========================================");
    $display("      SPI TOP VERIFICATION SUMMARY");
    $display("      Mode: CPOL=%0d CPHA=%0d", CPOL, CPHA);
    $display("========================================");
    $display("Total Checks : %0d", total_tests);
    $display("Passed       : %0d", pass_count);
    $display("Failed       : %0d", fail_count);
        if (fail_count == 0)
            $display("RESULT      : ALL TESTS PASSED");
        else
            $display("RESULT      : SOME TESTS FAILED");
    $display("========================================\n");     
        @(posedge clk_tb);
        $finish;
    end
endmodule