`timescale 1ns / 1ps

module SPI_Clock_Divider(

    input clk,
    input rst,
    input enable,
    
    output reg sclk,
    output reg posedge_tick,
    output reg negedge_tick
);

    // Divide by 2 because one SPI clock period requires two toggles.
    parameter CLK_FREQ = 100_000_000; // 100 MHz
    parameter SPI_FREQ = 1_000_000;   // 1 MHz
    parameter CPOL = 0;
    localparam CLK_DIV = CLK_FREQ/(2*SPI_FREQ);
   
    // Internal Register 
    reg [$clog2(CLK_DIV) - 1: 0] counter;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            sclk <= CPOL;
            posedge_tick <= 0;
            negedge_tick <= 0;
        end
        
        else if (!enable) begin
            sclk <= CPOL;
            counter <= 0;
            posedge_tick <= 0;
            negedge_tick <= 0;
        end
        
        else if (enable) begin
            negedge_tick <= 0;
            posedge_tick <= 0;
            
            if (counter == CLK_DIV - 1) begin
                counter <= 0;
                sclk <= ~sclk; // Toggling
                
                if (sclk == 0) begin  // sclk will be toggling to 1
                    posedge_tick <= 1;
                    negedge_tick <= 0;
                end
                
                else if (sclk == 1) begin // sclk will be toggling to 0
                    negedge_tick <= 1;
                    posedge_tick <= 0;
                end
            end
            
            else begin
                counter <= counter + 1;
            end   
        end
    end
endmodule
