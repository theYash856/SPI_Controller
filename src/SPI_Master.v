`timescale 1ns / 1ps

// Standard way to write configurable Verilog module.

module SPI_Master #(  
    parameter DATA_WIDTH = 8, // To keep the design configurable 
    parameter CPOL = 1'b0, // Clock Polarity 
    parameter CPHA = 1'b0  // Clock Phase 
    )(
    input clk,
    input rst,
    input tx_start, // Start transmission
    input [DATA_WIDTH - 1:0] tx_data, // Data to transmit
    input miso, // Master In Slave Out
    
    input posedge_tick,
    input negedge_tick,
    
    output reg [DATA_WIDTH - 1:0] rx_data, // Received data
    output reg mosi, // Master Out Slave In
    output reg cs, // Active-low Chip Select (0 = selected, 1 = deselected)
    output reg busy,
    output reg done
    );
    
    // Internal Registers
    reg [$clog2(DATA_WIDTH + 1) - 1 : 0] bit_counter;
    reg [DATA_WIDTH - 1 : 0] master_shift;
    reg [DATA_WIDTH - 1 : 0] slave_shift;
    reg transfer_done;
    
    // FSM States
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam TRANSFER = 2'b10;
    localparam DONE = 2'b11;
    
    reg [1:0] current_state, next_state;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_data <= 0;
            bit_counter <= 0;
            cs <= 1; 
            busy <= 0;
            done <= 0;
            mosi <= 0;
            master_shift <= 0;
            slave_shift <= 0;
            transfer_done <= 0;
            current_state <= IDLE;
        end
        
        else begin
            current_state <= next_state;
            
            case(current_state)
                IDLE: begin
                        busy <= 0;
                        cs <= 1;
                        done <= 0;
                      end
                
                LOAD: begin
                          cs <= 0;
                          transfer_done <= 0;
                          master_shift <= tx_data;
                          slave_shift  <= 0;
                          bit_counter  <= 0;
                          busy         <= 1;
                          done         <= 0;
                          
                          if (CPHA == 0)
                              mosi <= tx_data[DATA_WIDTH-1];   // preload first bit
                          else
                              mosi <= 0;                       // first bit sent on first shift edge
                          
                      
                      end
                
                TRANSFER: begin
                          busy <= 1;
                        
                          case ({CPOL, CPHA})
                          
                              // SPI Mode 0 (CPOL=0, CPHA=0)
                              2'b00: begin
                                  
                                  // Rising edge: Sample MISO
                                  if (posedge_tick) begin
                                  
                                      slave_shift <= {slave_shift[DATA_WIDTH-2:0], miso};
                                  
                                      if (bit_counter == DATA_WIDTH-1) begin
                                          rx_data <= {slave_shift[DATA_WIDTH-2:0], miso};
                                          transfer_done <= 1;
                                      end
                                      else begin
                                          bit_counter <= bit_counter + 1;
                                      end
                                  end
                                  
                                  // Falling edge: Shift MOSI
                                  else if (negedge_tick) begin
                                      master_shift <= master_shift << 1;
                                      mosi <= master_shift[DATA_WIDTH-2];
                                  end
                              end
                          
                          
                              // SPI Mode 1 (CPOL=0, CPHA=1)
                              2'b01: begin
                                  // Rising edge: Shift MOSI
                                  if (posedge_tick) begin
                              
                                      mosi <= master_shift[DATA_WIDTH-1];
                                      master_shift <= master_shift << 1;
                              
                                  end
                              
                                  // Falling edge: Sample MISO
                                  else if (negedge_tick) begin
                                      slave_shift <= {slave_shift[DATA_WIDTH-2:0], miso};
                              
                                      if (bit_counter == DATA_WIDTH-1) begin
                                          rx_data <= {slave_shift[DATA_WIDTH-2:0], miso};
                                          transfer_done <= 1;
                                      end
                                      else begin
                                          bit_counter <= bit_counter + 1;
                                      end
                                  end
                              end
                          
                          
                              // SPI Mode 2 (CPOL=1, CPHA=0)
                              2'b10: begin
                                  // Falling edge: Sample MISO (leading edge)
                                  if (negedge_tick) begin
                                  
                                      slave_shift <= {slave_shift[DATA_WIDTH-2:0], miso};
                                  
                                      if (bit_counter == DATA_WIDTH-1) begin
                                          rx_data <= {slave_shift[DATA_WIDTH-2:0], miso};
                                          transfer_done <= 1;
                                      end
                                      else begin
                                          bit_counter <= bit_counter + 1;
                                      end
                                  end
                          
                                  // Rising edge: Shift MOSI
                                  else if (posedge_tick) begin
                                      master_shift <= master_shift << 1;
                                      mosi <= master_shift[DATA_WIDTH-2];
                                  end
                              end
                          
                          
                              // SPI Mode 3 (CPOL=1, CPHA=1)
                              2'b11: begin
                              
                                  // Falling edge: Shift MOSI
                                  if (negedge_tick) begin
                                  
                                      mosi         <= master_shift[DATA_WIDTH-1];
                                      master_shift <= master_shift << 1;
                                  
                                  end
                              
                              
                                  // Rising edge: Sample MISO
                                  else if (posedge_tick) begin
                                      
                                      slave_shift <= {slave_shift[DATA_WIDTH-2:0], miso};
                              
                                      if (bit_counter == DATA_WIDTH-1) begin
                                          rx_data <= {slave_shift[DATA_WIDTH-2:0], miso};
                                          transfer_done <= 1'b1;
                                      end
                                      
                                      else begin
                                          bit_counter <= bit_counter + 1;
                                      end
                              
                                  end
                              
                              end
                          
                          endcase
                          end
                      
                DONE: begin
                        
                        cs <= 1;
                        busy <= 0;
                        done <= 1;
                        transfer_done <= 0;
                      end
            endcase          
        end
    end
    
    // Next-state logic block
    always @(*) begin
        next_state = current_state;
        case(current_state)
            IDLE: if (tx_start) begin
                    next_state = LOAD;
                  end
                  
            LOAD: next_state = TRANSFER;
            
            TRANSFER: begin
                if (transfer_done)
                    next_state = DONE;
                else
                    next_state = TRANSFER;
            end
            
            DONE: next_state = IDLE;

        endcase
    end
    
endmodule
