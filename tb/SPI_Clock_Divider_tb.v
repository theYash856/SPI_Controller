`timescale 1ns / 1ps

module SPI_Clock_Divider_tb;
    parameter CPOL = 1'b0;
    reg clk_tb, rst_tb, enable_tb;
    wire sclk_tb;
    wire posedge_tick_tb, negedge_tick_tb;

    // Instantiate DUT
    SPI_Clock_Divider #(
        .CLK_FREQ(100_000_000),
        .SPI_FREQ(1_000_000),
        .CPOL(CPOL)
    ) uut (.clk(clk_tb), .rst(rst_tb), .enable(enable_tb), .sclk(sclk_tb), .posedge_tick(posedge_tick_tb),
           .negedge_tick(negedge_tick_tb));

    // Clock Generator
    always #5 clk_tb = ~clk_tb;

    // Verification Variables
    integer pass_count;
    integer fail_count;
    integer total_tests;

    reg old_sclk;

    initial begin
        clk_tb = 0;
        rst_tb = 0;
        enable_tb = 0;

        pass_count  = 0;
        fail_count  = 0;
        total_tests = 0;
    end

    // Waveform Dump
    initial begin
        $dumpfile("SPI_Clock_Divider_tb.vcd");
        $dumpvars(0, SPI_Clock_Divider_tb);
    end

    //---------------------------------------------------------
    // TASKS
    //---------------------------------------------------------

    // 1. Reset DUT
    task reset_dut;
    begin
        rst_tb = 1;
        repeat(2) @(posedge clk_tb);
        rst_tb = 0;
        @(posedge clk_tb);
    end
    endtask

    // 2. Disable DUT
    task disable_dut;
    begin
        enable_tb = 0;
        @(posedge clk_tb);
    end
    endtask

    // 3. Enable DUT
    task enable_dut;
    begin
        enable_tb = 1;
        @(posedge clk_tb);
    end
    endtask

    // 4. Check Reset
    task check_reset;
    begin
        total_tests = total_tests + 1;

        if ((sclk_tb == CPOL) && (posedge_tick_tb == 0) && (negedge_tick_tb == 0))
        begin
            $display("[PASS] Test %0d : Reset Verification", total_tests);
            pass_count = pass_count + 1;
        end
        else begin
            $display("[FAIL] Test %0d : Reset Verification", total_tests);
            fail_count = fail_count + 1;
        end
    end
    endtask

    // 5. Check Idle
    task check_idle;
    begin
        total_tests = total_tests + 1;

        if ((sclk_tb == CPOL) && (posedge_tick_tb == 0) && (negedge_tick_tb == 0))
        begin
            $display("[PASS] Test %0d : Idle Verification", total_tests);
            pass_count = pass_count + 1;
        end
        else begin
            $display("[FAIL] Test %0d : Idle Verification", total_tests);
            fail_count = fail_count + 1;
        end
    end
    endtask

    // 6. Check Clock Generation
    task check_clock_gen;
    begin
        total_tests = total_tests + 1;

        old_sclk = sclk_tb;

        wait(sclk_tb != old_sclk);

        if(old_sclk != sclk_tb) begin
            $display("[PASS] Test %0d : Clock Generation", total_tests);
            pass_count = pass_count + 1;
        end
        else begin
            $display("[FAIL] Test %0d : Clock Generation", total_tests);
            fail_count = fail_count + 1;
        end
    end
    endtask

    // 7. Check Positive Edge Tick
    task check_posedge_tick;
    begin
        total_tests = total_tests + 1;

        wait(posedge_tick_tb);

        if(posedge_tick_tb && !negedge_tick_tb) begin
            $display("[PASS] Test %0d : Positive Edge Tick", total_tests);
            pass_count = pass_count + 1;
        end
        else begin
            $display("[FAIL] Test %0d : Positive Edge Tick", total_tests);
            fail_count = fail_count + 1;
        end
    end
    endtask

    // 8. Check Negative Edge Tick
    task check_negedge_tick;
    begin
        total_tests = total_tests + 1;

        wait(negedge_tick_tb);

        if(negedge_tick_tb && !posedge_tick_tb) begin
            $display("[PASS] Test %0d : Negative Edge Tick", total_tests);
            pass_count = pass_count + 1;
        end
        else begin
            $display("[FAIL] Test %0d : Negative Edge Tick", total_tests);
            fail_count = fail_count + 1;
        end
    end
    endtask

    //---------------------------------------------------------
    // TESTS
    //---------------------------------------------------------

    initial begin

        // Test 1 : Reset
        reset_dut();
        check_reset();

        // Test 2 : Idle
        disable_dut();
        check_idle();

        // Test 3 : Clock Generation
        enable_dut();
        check_clock_gen();

        // Test 4 : Positive Edge Tick
        check_posedge_tick();

        // Test 5 : Negative Edge Tick
        check_negedge_tick();

        // Test Summary
        $display("\n===============================");
        $display("Total Tests : %0d", total_tests);
        $display("Passed      : %0d", pass_count);
        $display("Failed      : %0d", fail_count);
        $display("===============================\n");
        $finish;
        
    end
endmodule