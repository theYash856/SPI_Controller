`timescale 1ns / 1ps

module SPI_Slave_tb;
    parameter DATA_WIDTH = 8;
    parameter CPOL = 1'b1;   // change these two to test any of the 4 modes
    parameter CPHA = 1'b1;

    reg clk_tb, rst_tb;
    reg [DATA_WIDTH-1:0] tx_data_tb;
    reg mosi_tb;
    reg cs_tb;
    reg posedge_tick_tb, negedge_tick_tb;

    wire [DATA_WIDTH-1:0] rx_data_tb;
    wire miso_tb;
    wire busy_tb;
    wire done_tb;

    SPI_Slave #(.DATA_WIDTH(DATA_WIDTH), .CPOL(CPOL), .CPHA(CPHA)) 
            uut (.clk(clk_tb), .rst(rst_tb),.tx_data(tx_data_tb), .miso(miso_tb),
           .posedge_tick(posedge_tick_tb), .negedge_tick(negedge_tick_tb),
           .rx_data(rx_data_tb), .mosi(mosi_tb), .cs(cs_tb), .busy(busy_tb), .done(done_tb));

    // Clock generator
    always #5 clk_tb = ~clk_tb;
    
    // Watchdog - guarantees the sim ends even if a wait() never resolves because of a DUT bug.
    initial begin
        #50000;
        $display("[TIMEOUT] Watchdog expired - a wait() condition never resolved");
    end
    
    // Verification variables
    integer pass_count, fail_count, total_tests, i;
    reg [DATA_WIDTH-1:0] expected_data;
    reg [DATA_WIDTH-1:0] expected_rx;
    
    // Waveform dump
    initial begin
        $dumpfile("SPI_Slave_tb.vcd");
        $dumpvars(0, SPI_Slave_tb);
    end

    // Monitor
    initial begin
        $monitor("Time=%0t | State=%0d | CS=%b | Busy=%b | Done=%b | Bit=%0d | MOSI=%b | MISO=%b | RX=%b",
                 $time, uut.current_state, cs_tb, busy_tb, done_tb, uut.bit_counter, mosi_tb, miso_tb, rx_data_tb);
    end
    
    // -----------------------------------------------------------------
    // Driver tasks
    // -----------------------------------------------------------------
    
    // 1. Reset DUT
    task reset_dut;
            begin
                rst_tb = 1;
                cs_tb  = 1; // After each task is completed CS is released.
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
                cs_tb = 0;
                @(posedge clk_tb);
                wait(busy_tb == 1);
            end
        endtask
        
    // 3. SPI Leading Edge 
    task spi_leading_edge;
       begin
           if (CPOL == 0) begin
               posedge_tick_tb = 1;
               #1;
               @(posedge clk_tb);
               #1;
               posedge_tick_tb = 0;
           end
           else begin
               negedge_tick_tb = 1;
               #1;
               @(posedge clk_tb);
               #1;
               negedge_tick_tb = 0;
           end
       end
       endtask
       
       // 4. SPI Trailing Edge
       task spi_trailing_edge;
       begin
           if (CPOL == 0) begin
               negedge_tick_tb = 1;
               #1;
               @(posedge clk_tb);
               #1;
               negedge_tick_tb = 0;
           end
           else begin
               posedge_tick_tb = 1;
               #1;
               @(posedge clk_tb);
               #1;
               posedge_tick_tb = 0;
           end
       end
       endtask
       
       // 5. SPI Clock Cycle
       task spi_clock_cycle;
       begin
           spi_leading_edge();
           spi_trailing_edge();
       end
       endtask
       
       // 6. Generic Test Checker
       task check_result(input condition, input [8*40:1] test_name);
            begin
                total_tests = total_tests + 1;
                if (condition) begin
                    $display("[PASS] Test %0d : %0s", total_tests, test_name);
                    pass_count = pass_count + 1;
                end else begin
                    $display("[FAIL] Test %0d : %0s", total_tests, test_name);
                    fail_count = fail_count + 1;
                    end
               end
           endtask
           
    // -----------------------------------------------------------------
    // Test sequence
    // -----------------------------------------------------------------
    initial begin
        clk_tb = 0;
        rst_tb = 0;
        cs_tb = 1;
        tx_data_tb  = 0;
        mosi_tb     = 0;
        posedge_tick_tb = 0;
        negedge_tick_tb = 0;
        pass_count  = 0;
        fail_count  = 0;
        total_tests = 0;
        i = 0;
        expected_data = 0;
        expected_rx = 0;
        
        // Test 1 : Reset Verification
        reset_dut();
        check_result(busy_tb == 0 && done_tb == 0 && cs_tb == 1 && rx_data_tb == 0, "Reset Verification");
        
        
        // Test 2: Start Transfer
        expected_data = 8'b1010_0101;
        start_transfer(expected_data);
        check_result(busy_tb == 1 && cs_tb == 0, "Start Transfer");
        
        
        // Test 3 : Transaction Complete
        repeat (DATA_WIDTH) 
        spi_clock_cycle();
        cs_tb = 1;  // Master releases CS
        wait(done_tb == 1);
      
        #1;   
        check_result(busy_tb == 0 && done_tb == 1, "Transaction Complete");


        // Test 4 : Busy Flag Verification
        reset_dut();
        expected_data = 8'b1010_0101;
        start_transfer(expected_data);
        repeat (DATA_WIDTH - 1) 
        spi_clock_cycle();
        check_result(busy_tb == 1, "Busy Flag Verification");
        spi_clock_cycle();
        @(posedge clk_tb);
        
        
        // Test 5 : Busy Status Verification
        reset_dut();
        expected_data = 8'b1010_0101;
        start_transfer(expected_data);
        repeat (DATA_WIDTH - 1) 
        spi_clock_cycle();
        check_result(busy_tb == 1, "Busy Held During Transfer");
        spi_clock_cycle();
        
        wait(done_tb == 1);
        cs_tb = 1; // Master releases CS
        #1;   
        check_result(busy_tb == 0, "Busy Cleared After CS Release");
        
        
        // Test 6: MOSI Shift Verification (Same as MOSI Shift Verification in Master now swapped with MISO)
        reset_dut();
        expected_data = 8'b1010_0101;
        start_transfer(expected_data);
        
        if (CPHA == 0) begin
        
            // First bit is already preloaded
            check_result(miso_tb == expected_data[DATA_WIDTH-1], "MISO Shift Verification");
        
            // Remaining bits
            for (i = DATA_WIDTH-2; i >= 0; i = i - 1) begin
                spi_clock_cycle();
                #1;
                check_result(miso_tb == expected_data[i], "MISO Shift Verification");
            end
        
            // Final sample edge to complete the transfer
            spi_leading_edge();
        end
        
        else begin
            // First bit appears on first shift edge
            for (i = DATA_WIDTH-1; i >= 0; i = i - 1) begin
                spi_leading_edge();
                #1;
                check_result(miso_tb == expected_data[i], "MISO Shift Verification");
                spi_trailing_edge();
            end  
        end
        
        wait(done_tb == 1);
        cs_tb = 1;   
        @(posedge clk_tb);
        
        // Test 7:  MOSI Receive Verification (Same as MISO Receive Verification in Master but swapped with MOSI)
        reset_dut();
        expected_rx   = 8'b11001010;
        expected_data = 8'b10100101;
        
        start_transfer(expected_data);
        
        for(i=DATA_WIDTH-1;i>=0;i=i-1) begin
            mosi_tb = expected_rx[i];
            #1;
            spi_clock_cycle();
        end
        
        wait(done_tb);
        cs_tb = 1;   
        @(posedge clk_tb);
        #1;   
        check_result(rx_data_tb==expected_rx, "MOSI Receive Verification");


        // Test 8 : Back-to-Back Transfers
        reset_dut();
        
        // 1st Transfer
        expected_data = 8'b1010_0101;
        start_transfer(expected_data);
        repeat (DATA_WIDTH) 
        spi_clock_cycle();
        cs_tb = 1;
        
        wait(done_tb == 1);
        #1;   
        check_result(done_tb == 1 && busy_tb == 0, "First Transfer Complete");
        
        // 2nd Transfer
        expected_data = 8'b0101_1010;
        start_transfer(expected_data);
        repeat (DATA_WIDTH) spi_clock_cycle();
        
        wait(done_tb == 1);
        cs_tb = 1;   
        #1;   
        check_result(done_tb == 1 && busy_tb == 0, "Second Transfer Complete");
        
        @(posedge clk_tb);
        
        
        // Verification Summary
        $display("\n========================================");
        $display("      SPI SLAVE VERIFICATION SUMMARY");
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
