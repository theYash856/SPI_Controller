`timescale 1ns / 1ps

module SPI_Slave #(  
    parameter DATA_WIDTH = 8, 
    parameter CPOL = 1'b0, 
    parameter CPHA = 1'b0  
    )(
    input clk,
    input rst,
    input [DATA_WIDTH - 1:0] tx_data, 
    input mosi,
    input cs,
    
    input posedge_tick,
    input negedge_tick,
    
    output reg [DATA_WIDTH - 1:0] rx_data, 
    output reg miso,
    output reg busy,
    output reg done
    );
    
    // Internal Registers
    reg [$clog2(DATA_WIDTH + 1) - 1 : 0] bit_counter;
    reg [DATA_WIDTH - 1 : 0] tx_shift; // Shifts data out (Transmit)
    reg [DATA_WIDTH - 1 : 0] rx_shift; // Shifts data in  (Receive)
    reg transfer_done;
    
    // FSM States
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam TRANSFER = 2'b10;
    localparam DONE = 2'b11;
    
    reg [1:0] current_state, next_state;
    
    // Sequential Block
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_data <= 0;
            miso <= 0;
            busy <= 0;
            done <= 0;
            bit_counter <= 0;
            rx_shift <= 0;
            tx_shift <= 0;
            transfer_done <= 0;
            current_state <= IDLE;
        end
        
        else begin                      
            current_state <= next_state;
            
            case(current_state)
                IDLE: begin
                        busy <= 0;
                        done <= 0;
                      end    
                
                LOAD: begin
                        if (cs) begin
                        // If released then don't engage.
                        busy <= 0;
                        done <= 0;
                        end 
                        else begin
                            transfer_done <= 0;
                            tx_shift <= tx_data;
                            bit_counter <= 0;
                            busy <= 1;
                            done <= 0;
                        
                            if (CPHA == 0)
                                miso <= tx_data[DATA_WIDTH-1];   // preload first bit
                            else
                                miso <= 0;                       // first bit sent on first shift edge
                            end
                        end
                 TRANSFER: begin                                                                 
                               busy <= 1;                                                            
                                                                                                     
                               case ({CPOL, CPHA})                                                   
                                                                                                     
                                   // SPI Mode 0 (CPOL=0, CPHA=0)                                    
                                   2'b00: begin                                                      
                                                                                                     
                                       // Rising edge: Sample MOSI                                  
                                       if (posedge_tick) begin                                       
                                                                                                     
                                           rx_shift <= {rx_shift[DATA_WIDTH-2:0], mosi};       
                                                                                                     
                                           if (bit_counter == DATA_WIDTH-1) begin                    
                                               rx_data <= {rx_shift[DATA_WIDTH-2:0], mosi};       
                                               transfer_done <= 1;                                   
                                           end                                                       
                                           else begin                                                
                                               bit_counter <= bit_counter + 1;                       
                                           end                                                       
                                       end                                                           
                                                                                                     
                                       // Falling edge: Shift MISO                                  
                                       else if (negedge_tick) begin                                  
                                           tx_shift <= tx_shift << 1;                        
                                           miso <= tx_shift[DATA_WIDTH-2];                       
                                       end                                                           
                                   end                                                               
                                                                                                     
                                                                                                     
                                   // SPI Mode 1 (CPOL=0, CPHA=1)                                    
                                   2'b01: begin                                                      
                                       // Rising edge: Shift MISO                                   
                                       if (posedge_tick) begin                                                                       
                                           miso <= tx_shift[DATA_WIDTH-1];                       
                                           tx_shift <= tx_shift << 1;                        
                                                                                                     
                                       end                                                           
                                                                                                     
                                       // Falling edge: Sample MOSI                                 
                                       else if (negedge_tick) begin                            
                                           rx_shift <= {rx_shift[DATA_WIDTH-2:0], mosi};       
                                                                                                     
                                           if (bit_counter == DATA_WIDTH-1) begin                    
                                               rx_data <= {rx_shift[DATA_WIDTH-2:0], mosi};       
                                               transfer_done <= 1;                                   
                                           end                                                       
                                           else begin                                                
                                               bit_counter <= bit_counter + 1;                       
                                           end                                                       
                                       end                                                           
                                   end            
                                   
                                   // SPI Mode 2 (CPOL=1, CPHA=0)                               
                                   2'b10: begin                                                 
                                       // Falling edge: Sample MOSI (leading edge)              
                                       if (negedge_tick) begin                                  
                                                                                                
                                           rx_shift <= {rx_shift[DATA_WIDTH-2:0], mosi};  
                                                                                                
                                           if (bit_counter == DATA_WIDTH-1) begin               
                                               rx_data <= {rx_shift[DATA_WIDTH-2:0], mosi};  
                                               transfer_done <= 1;                              
                                           end                                                  
                                           else begin                                           
                                               bit_counter <= bit_counter + 1;                  
                                           end                                                  
                                       end                                                      
                                                                                                
                                       // Rising edge: Shift MISO                              
                                       else if (posedge_tick) begin                             
                                           tx_shift <= tx_shift << 1;                   
                                           miso <= tx_shift[DATA_WIDTH-2];                  
                                       end                                                      
                                   end                                                          
                                                                                                
                                                                                                
                                   // SPI Mode 3 (CPOL=1, CPHA=1)                               
                                   2'b11: begin                                                 
                                                                                                
                                       // Falling edge: Shift MISO                             
                                       if (negedge_tick) begin                                  
                                                                                                
                                           miso     <= tx_shift[DATA_WIDTH-1];          
                                           tx_shift <= tx_shift << 1;                   
                                                                                                
                                       end                                                      
                                                                                                
                                                                                                
                                       // Rising edge: Sample MOSI                             
                                       else if (posedge_tick) begin                             
                                                                                                
                                           rx_shift <= {rx_shift[DATA_WIDTH-2:0], mosi};  
                                                                                                
                                           if (bit_counter == DATA_WIDTH-1) begin               
                                               rx_data <= {rx_shift[DATA_WIDTH-2:0], mosi};  
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
        case (current_state)
            IDLE:      if (cs == 0) next_state = LOAD;
    
            LOAD:      next_state = cs ? IDLE : TRANSFER;
    
            TRANSFER: begin
                        if (transfer_done)      // Higher priority
                            next_state = DONE;
                        else if (cs)
                            next_state = IDLE;
                        else
                            next_state = TRANSFER;
                      end
                      
            DONE:      if (cs == 0) 
                            next_state = LOAD;   // cs still low, loads next byte automatically
                       else      
                            next_state = IDLE;   // cs released
        endcase
    end
endmodule
