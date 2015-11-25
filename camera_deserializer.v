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

module camera_deserializer
(
  fmc_la00p_i,
  fmc_la00n_i,
  fmc_la02p_i,
  fmc_la02n_i,
  fmc_la03p_i,
  fmc_la03n_i,
  fmc_la04p_i,
  fmc_la04n_i,
  fmc_la05p_i,
  fmc_la05n_i,
  fmc_la14p_i,
  fmc_la14n_i,
  fmc_la15p_i,
  fmc_la15n_i,
  fmc_la18p_i,
  fmc_la18n_i,
  fmc_la19p_i,
  fmc_la19n_i,
  fmc_la20p_i,
  fmc_la20n_i,
  fmc_la21p_i,
  fmc_la21n_i,
  
  init_camera,
  reset_camera,
  take_photo,
  stop_photo,
  
  cl_locked,
  cl_clk_debug,
  cl_rd_addr,
  cl_data,
  
  uart_cfg_busy,
  uart_tx_start_debug,
  capture_state_debug,
  cmd_gen_state_debug,
  counter_debug,
  rx_data_debug,
  
  sys_clk_250,
  sys_clk_50,
  rst
);

input fmc_la00p_i;
input fmc_la00n_i;
input fmc_la02p_i;
input fmc_la02n_i;
input fmc_la03p_i;
input fmc_la03n_i;
input fmc_la04p_i;
input fmc_la04n_i;
input fmc_la05p_i;
input fmc_la05n_i;
input fmc_la14p_i;
input fmc_la14n_i;
output fmc_la15p_i;
output fmc_la15n_i;
output fmc_la18p_i;
output fmc_la18n_i;
output fmc_la19p_i;
output fmc_la19n_i;
output fmc_la20p_i;
output fmc_la20n_i;
output fmc_la21p_i;
output fmc_la21n_i;

input init_camera;
input reset_camera;
input take_photo;
input stop_photo;

output cl_locked;
output [6:0] cl_clk_debug;
input [9:0] cl_rd_addr;
output [15:0] cl_data;

output uart_cfg_busy;
output uart_tx_start_debug;
output [2:0] capture_state_debug;
output [4:0] cmd_gen_state_debug;
output [3:0] counter_debug;
output [7:0] rx_data_debug;

input sys_clk_250;
input sys_clk_50;
input rst;

parameter integer     S = 7 ;			// Set the serdes factor to 8
parameter integer     D = 4 ;			// Set the number of inputs and outputs
parameter integer     DS = (D*S)-1 ;		// Used for bus widths = serdes factor * number of inputs - 1

wire xclk;
wire [3:0] x_net;
wire ser_tfg;
wire ser_tc;

wire	[DS:0] 	rxd ;				// Data from serdeses
reg	[DS:0] 	rxr ;				// Registered Data from serdeses
wire bitslip;
reg	[3:0]	count ;
wire	[6:0]	clk_iserdes_data ;

wire rx_bufpll_lckd;
wire not_bufpll_lckd;

wire rx_serdesstrobe;
wire rx_bufpll_clk_xn;
wire rx_bufg_x1;

wire [7:0] uart_rx_data;
wire [7:0] uart_tx_data;

wire uart_tx_start;
wire uart_tx_busy;
wire uart_rx_valid;
wire uart_rx_idle;

assign uart_tx_start_debug = uart_tx_start;

assign not_bufpll_lckd = ~rx_bufpll_lckd;
assign cl_clk_debug = clk_iserdes_data;
assign cl_locked = rx_bufpll_lckd;

always @ (posedge rx_bufg_x1)				// process received data
begin
	rxr <= rxd ;
end

camera_link_fmc_bridge camera_link_inst
(
  .fmc_la00p_i(fmc_la00p_i),
  .fmc_la00n_i(fmc_la00n_i),
  .fmc_la02p_i(fmc_la02p_i),
  .fmc_la02n_i(fmc_la02n_i),
  .fmc_la03p_i(fmc_la03p_i),
  .fmc_la03n_i(fmc_la03n_i),
  .fmc_la04p_i(fmc_la04p_i),
  .fmc_la04n_i(fmc_la04n_i),
  .fmc_la05p_i(fmc_la05p_i),
  .fmc_la05n_i(fmc_la05n_i),
  .fmc_la14p_i(fmc_la14p_i),
  .fmc_la14n_i(fmc_la14n_i),
  .fmc_la15p_i(fmc_la15p_i),
  .fmc_la15n_i(fmc_la15n_i),
  .fmc_la18p_i(fmc_la18p_i),
  .fmc_la18n_i(fmc_la18n_i),
  .fmc_la19p_i(fmc_la19p_i),
  .fmc_la19n_i(fmc_la19n_i),
  .fmc_la20p_i(fmc_la20p_i),
  .fmc_la20n_i(fmc_la20n_i),
  .fmc_la21p_i(fmc_la21p_i),
  .fmc_la21n_i(fmc_la21n_i),
  
  .xclk(xclk),
  .x(x_net),
  .cc(4'd0),
  .ser_tfg(ser_tfg),
  .ser_tc(ser_tc)
);

serdes_1_to_n_clk_pll_s8_diff #(
  .S			(S),
  .CLKIN_PERIOD		(11.000),
	.PLLD 			(1),
  .PLLX			(S),
	.BS 			("TRUE"))    		// Parameter to enable bitslip TRUE or FALSE (has to be true for video applications)
inst_clkin (
	.x_clk(xclk),
	.rxioclk    		(rx_bufpll_clk_xn),
	.pattern1		(7'b1100001),		// default values for 7:1 video applications
	.pattern2		(7'b1100011),
	.rx_serdesstrobe	(rx_serdesstrobe),
	.rx_bufg_pll_x1		(rx_bufg_x1),
	.bitslip   		(bitslip),
	.reset     		(rst),
	.datain  		(clk_iserdes_data),
	.rx_pll_lckd  		(),			// PLL locked - only used if a 2nd BUFPLL is required
	.rx_pllout_xs 		(),			// Multiplied PLL clock - only used if a 2nd BUFPLL is required
	.rx_bufpll_lckd		(rx_bufpll_lckd)) ;

serdes_1_to_n_data_s8_diff #(
  .S			(S),			
  .D			(D))
inst_datain (
	.use_phase_detector 	(1'b1),			// '1' enables the phase detector logic
	.input_data(x_net),
	.rxioclk    		(rx_bufpll_clk_xn),
	.rxserdesstrobe 	(rx_serdesstrobe),
	.gclk    		(rx_bufg_x1),
	.bitslip   		(bitslip),
	.reset   		(not_bufpll_lckd),
	.data_out  		(rxd),
	.debug_in  		(2'b00),
	.debug    		());

cameralink_parser cameralink_parser_inst
(
  .take_photo(take_photo),
  .reset_state(reset_camera),
  .xdata(rxr),
  .cl_clk(rx_bufg_x1),
  .sys_clk(sys_clk_50),
  .rst(rst),
  .pixel_rd_addr(cl_rd_addr),
  .pixel_rd_data(cl_data),
  .capture_state_debug(capture_state_debug)
);

uart cl_uart
(
  .clk(sys_clk_50),
  .txd(uart_tx_data),
  .tx_start(uart_tx_start),
  .tx_busy(uart_tx_busy),
  .tx_out(ser_tc),
  .rxd(uart_rx_data),
  .rx_valid(uart_rx_valid),
  .rx_in(ser_tfg),
  .rx_idle(uart_rx_idle)
);

camera_serial_command_generator camera_serial_command_generator_inst
(
  .init_camera(init_camera),
  .take_photo(take_photo),
  .stop_photo(stop_photo),
  .tx_data(uart_tx_data),
  .tx_en(uart_tx_start),
  .tx_busy(uart_tx_busy),
  .rx_data(uart_rx_data),
  .rx_done(uart_rx_valid),
  .sys_clk_50(sys_clk_50),
  .rst(reset_camera),
  .busy(uart_cfg_busy),
  .cmd_gen_state_debug(cmd_gen_state_debug),
  .counter_debug(counter_debug),
  .rx_data_debug(rx_data_debug)
);

endmodule