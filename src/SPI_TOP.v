`timescale 1ns / 1ps

module SPI_TOP #(
    parameter DATA_WIDTH = 8,         // To keep the design configurable 
    parameter CPOL = 1'b0,            // Clock Polarity 
    parameter CPHA = 1'b0,            // Clock Phase 
    parameter CLK_FREQ = 100_000_000, // 100 MHz
    parameter SPI_FREQ = 1_000_000    // 1 MHz
    )(
    input clk,
    input rst,
    input tx_start,
    input [DATA_WIDTH-1:0] tx_data,

    output [DATA_WIDTH-1:0] rx_data,
    output mosi,
    output sclk,
    output cs,
    output busy,
    output done,
    
    // not real SPI pins, exists only because slave is co-located here
    output [DATA_WIDTH-1:0] slave_rx_data,
    output slave_busy,
    output slave_done
    );
    
    // Internal SPI clock signals
    wire posedge_tick;
    wire negedge_tick;
    
    // Enable signal for clock divider
    wire spi_enable;
    
    // Internal MISO
    wire miso;
    
    assign spi_enable = busy && slave_busy;
    
    // Instantiation
    
    // 1. Clock Divider
    SPI_Clock_Divider #(
        .CLK_FREQ(CLK_FREQ),
        .SPI_FREQ(SPI_FREQ),
        .CPOL(CPOL)
    ) clk_div (.clk(clk), .rst(rst), .enable(spi_enable), .sclk(sclk), .posedge_tick(posedge_tick), .negedge_tick(negedge_tick));
    
    // 2. SPI Master
    SPI_Master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CPOL(CPOL),
        .CPHA(CPHA)
    ) master(.clk(clk), .rst(rst), .tx_start(tx_start), .tx_data(tx_data), .miso(miso), .posedge_tick(posedge_tick),
             .negedge_tick(negedge_tick), .rx_data(rx_data), .mosi(mosi), .cs(cs), .busy(busy), .done(done));
             
    // 3. SPI SLAVE
    SPI_Slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .CPOL(CPOL),
        .CPHA(CPHA)
    ) slave (.clk(clk), .rst(rst), .tx_data(tx_data), .mosi(mosi), .cs(cs), .posedge_tick(posedge_tick),
             .negedge_tick(negedge_tick), .rx_data(slave_rx_data), .miso(miso), .busy(slave_busy), .done(slave_done)
    );
    
endmodule
