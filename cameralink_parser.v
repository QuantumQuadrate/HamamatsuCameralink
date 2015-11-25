/*
 * Copyright (c) 2015, Ziliang Guo
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * * Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * * Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 * * Neither the name of Wisconsin Robotics nor the
 *   names of its contributors may be used to endorse or promote products
 *   derived from this software without specific prior written permission.
 *   
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL WISCONSIN ROBOTICS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

`define IDLE_STATE 3'b000
`define PREPAD_STATE 3'b001
`define PRELINE_STATE 3'b010
`define POSTLINE_STATE 3'b011
`define PIXEL_CAPTURE_STATE 3'b100
`define POSTPAD_STATE 3'b101

module cameralink_parser
(
  take_photo,
  reset_state,
  xdata,
  cl_clk,
  sys_clk,
  rst,
  pixel_rd_addr,
  pixel_rd_data,
  capture_state_debug
);

input take_photo;
input reset_state;
input [27:0] xdata;
input cl_clk;
input sys_clk;
input rst;

input [9:0] pixel_rd_addr;
output [15:0] pixel_rd_data;
output [2:0] capture_state_debug;

wire [15:0] pixel_wr_data;
reg [9:0] pixel_wr_addr;
reg [9:0] pixel_wr_addr_next;

wire frame_valid;
wire line_valid;
wire data_valid;
wire pixel_valid;

reg take_photo_reg;
reg [2:0] capture_state;
reg [2:0] capture_state_next;
reg [15:0] counter;
reg [15:0] counter_next;
reg data_wr_en;

wire [3:0] data_bank_wr;

reg [6:0] line_counter;
reg [6:0] line_counter_next;

assign pixel_wr_data[4:0] = xdata[4:0];
assign pixel_wr_data[5] = xdata[6];
assign pixel_wr_data[6] = xdata[27];
assign pixel_wr_data[7] = xdata[5];
assign pixel_wr_data[10:8] = xdata[9:7];
assign pixel_wr_data[13:11] = xdata[14:12];
assign pixel_wr_data[15:14] = xdata[11:10];

assign line_valid = xdata[24];
assign frame_valid = xdata[25];
assign data_valid = xdata[26];

assign pixel_valid = line_valid & frame_valid & data_valid;

assign capture_state_debug = capture_state;

always@(posedge cl_clk) begin
  if(reset_state) begin
    take_photo_reg <= 1'b0;
    counter <= 16'd0;
    capture_state <= `IDLE_STATE;
    line_counter <= 7'd0;
    pixel_wr_addr <= 10'd0;
  end
  else begin
    take_photo_reg <= take_photo;
    counter <= counter_next;
    capture_state <= capture_state_next;
    line_counter <= line_counter_next;
    pixel_wr_addr <= pixel_wr_addr_next;
  end
end

always@(*) begin
  capture_state_next <= capture_state;
  counter_next <= counter;
  data_wr_en <= 1'b0;
  pixel_wr_addr_next <= pixel_wr_addr;
  line_counter_next <= line_counter;
  case(capture_state)
    `IDLE_STATE: begin
      counter_next <= 16'd0;
      pixel_wr_addr_next <= 12'd0;
      line_counter_next <= 7'd0;
      if(~take_photo_reg & take_photo) begin
        capture_state_next <= `PREPAD_STATE;
      end
    end
      
    `PREPAD_STATE: begin
      if(pixel_valid) begin
        counter_next <= counter + 16'd1;
        if(counter == 114687) begin
          capture_state_next <= `PRELINE_STATE;
          counter_next <= 16'd0;
        end
      end
    end
    
    `PRELINE_STATE: begin
      if(pixel_valid) begin
        counter_next <= counter + 16'd1;
        if(counter == 223) begin
          capture_state_next <= `PIXEL_CAPTURE_STATE;
          counter_next <= 15'd0;
        end
      end
    end
    
    `PIXEL_CAPTURE_STATE: begin
      if(pixel_valid) begin
        pixel_wr_addr_next <= pixel_wr_addr + 10'd1;
        counter_next <= counter + 16'd1;
        data_wr_en <= 1'b1;
        if(counter == 63) begin
          capture_state_next <= `POSTLINE_STATE;
          counter_next <= 15'd0;
          line_counter_next <= line_counter + 7'd1;
        end
      end
    end
    
    `POSTLINE_STATE: begin
      if(pixel_valid) begin
        counter_next <= counter + 16'd1;
        if(counter == 16'd223) begin
          if(line_counter == 7'd64) begin
            capture_state_next <= `POSTPAD_STATE;
          end
          else begin
            capture_state_next <= `PRELINE_STATE;
          end
          counter_next <= 15'd0;
        end
      end
    end
    
    `POSTPAD_STATE: begin
      if(pixel_valid) begin
        counter_next <= counter + 16'd1;
        if(counter == 114687) begin
          capture_state_next <= `IDLE_STATE;
          counter_next <= 16'd0;
        end
      end
    end
    
  endcase
end

blk_mem blk_mem_inst (
  .clka(cl_clk), // input clka
  .wea(data_wr_en), // input [0 : 0] wea
  .addra(pixel_wr_addr), // input [9 : 0] addra
  .dina(pixel_wr_data), // input [15 : 0] dina
  .clkb(sys_clk), // input clkb
  .addrb(pixel_rd_addr), // input [11 : 0] addrb
  .doutb(pixel_rd_data) // output [15 : 0] doutb
);

endmodule