///////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2009 Xilinx, Inc.
// This design is confidential and proprietary of Xilinx, All Rights Reserved.
///////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /   Vendor: Xilinx
// \   \   \/    Version: 1.0
//  \   \        Filename: top_nto1_pll_diff_rx.v
//  /   /        Date Last Modified:  November 5 2009
// /___/   /\    Date Created: June 1 2009
// \   \  /  \
//  \___\/\___\
// 
//Device: 	Spartan 6
//Purpose:  	Example differential input receiver for clock and data using PLL
//		Serdes factor and number of data lines are set by constants in the code
//Reference:
//    
//Revision History:
//    Rev 1.0 - First created (nicks)
//
///////////////////////////////////////////////////////////////////////////////
//
//  Disclaimer: 
//
//		This disclaimer is not a license and does not grant any rights to the materials 
//              distributed herewith. Except as otherwise provided in a valid license issued to you 
//              by Xilinx, and to the maximum extent permitted by applicable law: 
//              (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, 
//              AND XILINX HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, 
//              INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR 
//              FITNESS FOR ANY PARTICULAR PURPOSE; and (2) Xilinx shall not be liable (whether in contract 
//              or tort, including negligence, or under any other theory of liability) for any loss or damage 
//              of any kind or nature related to, arising under or in connection with these materials, 
//              including for any direct, or any indirect, special, incidental, or consequential loss 
//              or damage (including loss of data, profits, goodwill, or any type of loss or damage suffered 
//              as a result of any action brought by a third party) even if such damage or loss was 
//              reasonably foreseeable or Xilinx had been advised of the possibility of the same.
//
//  Critical Applications:
//
//		Xilinx products are not designed or intended to be fail-safe, or for use in any application 
//		requiring fail-safe performance, such as life-support or safety devices or systems, 
//		Class III medical devices, nuclear facilities, applications related to the deployment of airbags,
//		or any other applications that could lead to death, personal injury, or severe property or 
//		environmental damage (individually and collectively, "Critical Applications"). Customer assumes 
//		the sole risk and liability of any use of Xilinx products in Critical Applications, subject only 
//		to applicable laws and regulations governing limitations on product liability.
//
//  THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES.
//
//////////////////////////////////////////////////////////////////////////////

`timescale 1ps/1ps

module top_nto1_pll_diff_rx (
input		reset,				// reset (active high)
//input	[3:0]	rx_data_in_fix,		// lvds data inputs
input	[1:0] rx_data_in_fix,		// lvds data inputs
input		x_clk,		// lvds clock input
//output	[27:0]	data_out) ;			// dummy outputs
output	[13:0]	data_out) ;			// dummy outputs

// Parameters for serdes factor and number of IO pins

parameter integer     S = 7 ;			// Set the serdes factor to 8
parameter integer     D = 4 ;			// Set the number of inputs and outputs
parameter integer     DS = (D*S)-1 ;		// Used for bus widths = serdes factor * number of inputs - 1

wire       	rst ;
wire	[DS:0] 	rxd ;				// Data from serdeses
reg	[DS:0] 	rxr ;				// Registered Data from serdeses
reg		state ;
reg 		bslip ;
reg	[3:0]	count ;
wire	[6:0]	clk_iserdes_data ;

assign rst = reset ; 				// active high reset pin
assign data_out = rxr ;

// Clock Input. Generate ioclocks via BUFIO2

serdes_1_to_n_clk_pll_s8_diff #(
      	.S			(S), 		
      	.CLKIN_PERIOD		(50.000),
	.PLLD 			(1),
      	.PLLX			(S),
	.BS 			("TRUE"))    		// Parameter to enable bitslip TRUE or FALSE (has to be true for video applications)
inst_clkin (
	.x_clk(x_clk),
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
	
// Data Inputs

assign not_bufpll_lckd = ~rx_bufpll_lckd ;

serdes_1_to_n_data_s8_diff #(
      	.S			(S),			
      	.D			(D))
inst_datain (
	.use_phase_detector 	(1'b1),			// '1' enables the phase detector logic
	.rx_data_in_fix(rx_data_in_fix),
	.rxioclk    		(rx_bufpll_clk_xn),
	.rxserdesstrobe 	(rx_serdesstrobe),
	.gclk    		(rx_bufg_x1),
	.bitslip   		(bitslip),
	.reset   		(not_bufpll_lckd),
	.data_out  		(rxd),
	.debug_in  		(2'b00),
	.debug    		());

always @ (posedge rx_bufg_x1)				// process received data
begin
	rxr <= rxd ;
end

endmodule
