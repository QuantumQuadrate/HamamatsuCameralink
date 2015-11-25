//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2009 Xilinx, Inc.
// This design is confidential and proprietary of Xilinx, All Rights Reserved.
//////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /   Vendor: Xilinx
// \   \   \/    Version: 1.0
//  \   \        Filename: serdes_1_to_n_clk_pll_s8_diff.v
//  /   /        Date Last Modified:  November 5 2009
// /___/   /\    Date Created: August 1 2008
// \   \  /  \
//  \___\/\___\
// 
//Device: 	Spartan 6
//Purpose:  	1-bit generic 1:n clock receiver modulefor serdes factors 
//		from 2 to 8
// 		Instantiates necessary clock buffers and PLL
//		Contains state machine to calibrate clock input delay line, 
//		and perform bitslip if required.
//		Takes in 1 bit of differential data and deserialises this to 
//		n bits for where this data is required
// 		data is received LSB first
// 		0, 1, 2 ......
//
//Reference:
//    
//Revision History:
//    Rev 1.0 - First created (nicks)
//////////////////////////////////////////////////////////////////////////////
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

module serdes_1_to_n_clk_pll_s8_diff (x_clk, rxioclk, pattern1, pattern2, rx_serdesstrobe, reset, rx_bufg_pll_x1, rx_pll_lckd, rx_pllout_xs, bitslip, rx_bufpll_lckd, datain) ;

parameter integer S = 8 ;   			// Parameter to set the serdes factor 2..8
parameter         BS = "FALSE" ;   		// Parameter to enable bitslip TRUE or FALSE
parameter         PLLX = 7 ;   			// Parameter to set multiplier for PLL (7 for video links, 2 for DDR etc)
parameter         PLLD = 1 ;   			// Parameter to set divider for PLL
//parameter real 	  CLKIN_PERIOD = 50.000 ;	// clock period (ns) of input clock on clkin_p
parameter real 	  CLKIN_PERIOD = 11.000 ;	// clock period (ns) of input clock on clkin_p
parameter         DIFF_TERM = "FALSE" ; 	// Parameter to enable internal differential termination
                                        	
input		x_clk ;		//
input 		reset ;				// Reset line
input 	[S-1:0]	pattern1 ;	 		// Data to define pattern that bitslip should search for
input 	[S-1:0]	pattern2 ;	 		// Data to define alternate pattern that bitslip should search for
output 		rxioclk ;			// IO Clock network
output 		rx_serdesstrobe ;		// Parallel data capture strobe
output 		rx_bufg_pll_x1 ;		// Global clock output
output 		rx_pll_lckd ; 			// PLL locked - only used if a 2nd BUFPLL is required
output 		rx_pllout_xs ;			// Multiplied PLL clock - only used if a 2nd BUFPLL is required
output 		bitslip ;			// Bitslip control line
output 		rx_bufpll_lckd ; 		// BUFPLL locked
output 	[S-1:0]	datain ;	 		// Data

wire 		P_clk ;       		// P clock out to BUFIO2
wire 		buf_pll_fb_clk ;	// PLL feedback clock into BUFIOFB
wire 		ddly_m ;     		// Master output from IODELAY1
wire 		ddly_s ;     		// Slave output from IODELAY1
wire	[7:0]	mdataout ;		//
wire		busys ;			//
wire		busym ;			//
wire		buf_P_clk ;		//
reg	[3:0]	state ;
reg 		bslip ;
reg	[2:0]	count ;
reg 		busyd ;
reg	[11:0]	counter ;
wire 	[S-1:0] clk_iserdes_data ;
reg 		cal_clk ;
reg 		rst_clk ;
wire		rx_bufplllckd ;
wire		not_rx_bufpll_lckd ;
reg 		enable ;
reg 		flag1 ;
reg 		flag2 ;

parameter  	RX_SWAP_CLK  = 1'b0 ;	// pinswap mask for input clock (0 = no swap (default), 1 = swap). Allows input to be connected the wrong way round to ease PCB routing.

assign busy_clk = busym ;
assign datain = mdataout[7:1] ;
assign 	bitslip = bslip ;

// Bitslip and CAL state machine

always @ (posedge rx_bufg_pll_x1 or posedge not_rx_bufpll_lckd)
begin
if (not_rx_bufpll_lckd == 1'b1) begin
	state <= 0 ;
	enable <= 1'b0 ;
	cal_clk <= 1'b0 ;
	rst_clk <= 1'b0 ;
	bslip <= 1'b0 ;
   	busyd <= 1'b1 ;
	counter <= 12'b000000000000 ;
end
else begin
   	busyd <= busy_clk ;
   	if (counter[5] == 1'b1) begin
		enable <= 1'b1 ;
   	end
   	if (counter[11] == 1'b1) begin					// re calibrate every 2^11 clocks
		state <= 0 ;
		cal_clk <= 1'b0 ;
		rst_clk <= 1'b0 ;
		bslip <= 1'b0 ;
   		busyd <= 1'b1 ;
		counter <= 12'b000000000000 ;
   	end 
   	else begin
   		counter <= counter + 12'b000000000001 ;
   		if (clk_iserdes_data != pattern1) begin flag1 <= 1'b1 ; end else begin flag1 <= 1'b0 ; end
   		if (clk_iserdes_data != pattern2) begin flag2 <= 1'b1 ; end else begin flag2 <= 1'b0 ; end
   		if (state == 0 && enable == 1'b1 && busyd == 1'b0) begin
   			state <= 1 ;
   		end
   		else if (state == 1) begin				// cal high
   			cal_clk <= 1'b1 ; state <= 2 ;
   		end
   		else if (state == 2) begin
   			cal_clk <= 1'b0 ;				// cal low
   			if (busyd == 1'b1) begin			// wait for busy high
   				state <= 3 ;
   			end	
   		end
   		else if (state == 3 && busyd == 1'b0) begin		// wait for busy low
   			rst_clk <= 1'b1 ; state <= 4 ;			// rst high
   		end
   		else if (state == 4) begin				// rst low
   			rst_clk <= 1'b0 ; state <= 5 ;
   		end
   		else if (state == 5 && busyd == 1'b0) begin		// wait for busy low
   			state <= 6 ;
   			count <= 3'b000 ;
   		end
   		else if (state == 6) begin				// hang around
   			count <= count + 3'b001 ;
   			if (count == 3'b111) begin
        			state <= 7 ;
        end
      end
     	else if (state == 7) begin
   			if (BS == "TRUE" && flag1 == 1'b1 && flag2 == 1'b1) begin
          bslip <= 1'b1 ;				// bitslip needed
          state <= 8 ;
          count <= 3'b000 ;
        end
        else begin
          state <= 9 ;
        end
      end
   		else if (state == 8) begin
     		   	bslip <= 1'b0 ;					// bitslip low
     		   	count <= count + 3'b001 ;
   			if (count == 3'b111) begin
     		   		state <= 7 ;
     		   	end
     		end
   		else if (state == 9) begin				
     		   	state <= 9 ;
   		end
   	end
  end
end

genvar i ;						// Limit the output data bus to the most significant 'S' number of bits
generate
for (i = 0 ; i <= (S - 1) ; i = i + 1)
begin : loop0
assign clk_iserdes_data[i] = mdataout[8+i-S] ;
end
endgenerate

IODELAY2 #(
	.DATA_RATE      	("SDR"), 			// <SDR>, DDR
	.SIM_TAPDELAY_VALUE	(49),  				// nominal tap delay (sim parameter only)
	.IDELAY_VALUE  		(0), 				// {0 ... 255}
	.IDELAY2_VALUE 		(0), 				// {0 ... 255}
	.ODELAY_VALUE  		(0), 				// {0 ... 255}
	.IDELAY_MODE   		("NORMAL"), 			// "NORMAL", "PCI"
	.SERDES_MODE   		("MASTER"), 			// <NONE>, MASTER, SLAVE
	.IDELAY_TYPE   		("VARIABLE_FROM_HALF_MAX"), 	// "DEFAULT", "DIFF_PHASE_DETECTOR", "FIXED", "VARIABLE_FROM_HALF_MAX", "VARIABLE_FROM_ZERO"
	.COUNTER_WRAPAROUND 	("STAY_AT_LIMIT"), 		// <STAY_AT_LIMIT>, WRAPAROUND
	.DELAY_SRC     		("IDATAIN")) 			// "IO", "IDATAIN", "ODATAIN"
iodelay_m (
	.IDATAIN  		(x_clk), 			// data from master IOB
	.TOUT     		(), 				// tri-state signal to IOB
	.DOUT     		(), 				// output data to IOB
	.T        		(1'b1), 			// tri-state control from OLOGIC/OSERDES2
	.ODATAIN  		(1'b0), 			// data from OLOGIC/OSERDES2
	.DATAOUT  		(ddly_m), 			// Output data 1 to ILOGIC/ISERDES2
	.DATAOUT2 		(),	 			// Output data 2 to ILOGIC/ISERDES2
	.IOCLK0   		(rxioclk), 			// High speed clock for calibration
	.IOCLK1   		(1'b0), 			// High speed clock for calibration
	.CLK      		(rx_bufg_pll_x1), 		// Fabric clock (GCLK) for control signals
	.CAL      		(cal_clk), 			// Calibrate enable signal
	.INC      		(1'b0), 			// Increment counter
	.CE       		(1'b0), 			// Clock Enable
	.RST      		(rst_clk), 			// Reset delay line to 1/2 max in this case
	.BUSY      		(busym)) ;  			// output signal indicating sync circuit has finished / calibration has finished

IODELAY2 #(
	.DATA_RATE      	("SDR"), 			// <SDR>, DDR
	.SIM_TAPDELAY_VALUE	(49),  				// nominal tap delay (sim parameter only)
	.IDELAY_VALUE  		(0), 				// {0 ... 255}
	.IDELAY2_VALUE 		(0), 				// {0 ... 255}
	.ODELAY_VALUE  		(0), 				// {0 ... 255}
	.IDELAY_MODE   		("NORMAL"), 			// "NORMAL", "PCI"
	.SERDES_MODE   		("SLAVE"), 			// <NONE>, MASTER, SLAVE
	.IDELAY_TYPE   		("FIXED"), 			// "DEFAULT", "DIFF_PHASE_DETECTOR", "FIXED", "VARIABLE_FROM_HALF_MAX", "VARIABLE_FROM_ZERO"
	.COUNTER_WRAPAROUND 	("STAY_AT_LIMIT"), 		// <STAY_AT_LIMIT>, WRAPAROUND
	.DELAY_SRC     		("IDATAIN")) 			// "IO", "IDATAIN", "ODATAIN"
iodelay_s (
	.IDATAIN 		(x_clk), 			// data from slave IOB
	.TOUT     		(), 				// tri-state signal to IOB
	.DOUT     		(), 				// output data to IOB
	.T        		(1'b1), 			// tri-state control from OLOGIC/OSERDES2
	.ODATAIN  		(1'b0), 			// data from OLOGIC/OSERDES2
	.DATAOUT 		(ddly_s), 			// Output data 1 to ILOGIC/ISERDES2
	.DATAOUT2 		(),	 			// Output data 2 to ILOGIC/ISERDES2
	.IOCLK0    		(1'b0), 			// High speed clock for calibration
	.IOCLK1   		(1'b0), 			// High speed clock for calibration
	.CLK      		(1'b0), 			// Fabric clock (GCLK) for control signals
	.CAL      		(1'b0), 			// Calibrate control signal, never needed as the slave supplies the clock input to the PLL
	.INC      		(1'b0), 			// Increment counter
	.CE       		(1'b0), 			// Clock Enable
	.RST      		(1'b0), 			// Reset delay line
	.BUSY      		()) ;				// output signal indicating sync circuit has finished / calibration has finished

BUFIO2 #(
      .DIVIDE			(1),               		// The DIVCLK divider divide-by value; default 1
      .DIVIDE_BYPASS		("TRUE"))    			// DIVCLK output sourced from Divider (FALSE) or from I input, by-passing Divider (TRUE); default TRUE
P_clk_bufio2_inst (
      .I			(P_clk),               		// P_clk input from IDELAY via DFB pin
      .IOCLK			(),        			// Output Clock
      .DIVCLK			(buf_P_clk),    		// Output Divided Clock
      .SERDESSTROBE		()) ;           		// Output SERDES strobe (Clock Enable)

BUFIO2FB #(
      .DIVIDE_BYPASS		("TRUE"))    			// DIVCLK output sourced from Divider (FALSE) or from I input, by-passing Divider (TRUE); default TRUE
P_clk_bufio2fb_inst (
      .I			(feedback),             	// PLL generated Clock to be fed back from IOI
      .O			(buf_pll_fb_clk)) ;   		// PLL Output Feedback Clock

ISERDES2 #(
	.DATA_WIDTH     	(S), 				// SERDES word width.  This should match the setting in BUFPLL
	.DATA_RATE      	("SDR"), 			// <SDR>, DDR
	.BITSLIP_ENABLE 	("TRUE"), 			// <FALSE>, TRUE
	.SERDES_MODE    	("MASTER"), 			// <DEFAULT>, MASTER, SLAVE
	.INTERFACE_TYPE 	("RETIMED")) 			// NETWORKING, NETWORKING_PIPELINED, <RETIMED>
iserdes_m (
	.D       		(ddly_m),
	.CE0     		(1'b1),
	.CLK0    		(rxioclk),
	.CLK1    		(1'b0),
	.IOCE    		(rx_serdesstrobe),
	.RST     		(not_rx_bufpll_lckd),
	.CLKDIV  		(rx_bufg_pll_x1),
	.SHIFTIN 		(pd_edge),
	.BITSLIP 		(bslip),
	.FABRICOUT 		(),
	.DFB 			(),
	.CFB0 			(),
	.CFB1 			(),
	.Q4 			(mdataout[7]),
	.Q3 			(mdataout[6]),
	.Q2 			(mdataout[5]),
	.Q1 			(mdataout[4]),
	.VALID    		(),
	.INCDEC   		(),
	.SHIFTOUT 		(cascade));

ISERDES2 #(
	.DATA_WIDTH     	(S), 				// SERDES word width.  This should match the setting is BUFPLL
	.DATA_RATE      	("SDR"), 			// <SDR>, DDR
	.BITSLIP_ENABLE 	("TRUE"), 			// <FALSE>, TRUE
	.SERDES_MODE    	("SLAVE"), 			// <DEFAULT>, MASTER, SLAVE
	.INTERFACE_TYPE 	("RETIMED")) 			// NETWORKING, NETWORKING_PIPELINED, <RETIMED>
iserdes_s (
	.D       		(ddly_s),
	.CE0     		(1'b1),
	.CLK0    		(rxioclk),
	.CLK1    		(1'b0),
	.IOCE    		(rx_serdesstrobe),
	.RST     		(not_rx_bufpll_lckd),
	.CLKDIV  		(rx_bufg_pll_x1),
	.SHIFTIN 		(cascade),
	.BITSLIP 		(bslip),
	.FABRICOUT 		(),
	.DFB 			(P_clk),
	.CFB0 			(feedback),
	.CFB1 			(),
	.Q4  			(mdataout[3]),
	.Q3  			(mdataout[2]),
	.Q2  			(mdataout[1]),
	.Q1  			(mdataout[0]),
	.VALID 			(),
	.INCDEC 		(),
	.SHIFTOUT 		(pd_edge));

PLL_ADV #(
      .BANDWIDTH		("OPTIMIZED"),  		// "high", "low" or "optimized"
      // This was PLLX, needed to change this to 21 because output clock needs
      // to be between 400 and 1080 MHz.
      .CLKFBOUT_MULT		(7),       			// multiplication factor for all output clocks
      .CLKFBOUT_PHASE		(0.0),     			// phase shift (degrees) of all output clocks
      .CLKIN1_PERIOD		(CLKIN_PERIOD),  		// clock period (ns) of input clock on clkin1
      .CLKIN2_PERIOD		(CLKIN_PERIOD),  		// clock period (ns) of input clock on clkin2
      .CLKOUT0_DIVIDE		(1),       			// division factor for clkout0 (1 to 128)
      .CLKOUT0_DUTY_CYCLE	(0.5), 				// duty cycle for clkout0 (0.01 to 0.99)
      .CLKOUT0_PHASE		(315.0), 				// phase shift (degrees) for clkout0 (0.0 to 360.0)
      .CLKOUT1_DIVIDE		(1),   				// division factor for clkout1 (1 to 128)
      .CLKOUT1_DUTY_CYCLE	(0.5), 				// duty cycle for clkout1 (0.01 to 0.99)
      .CLKOUT1_PHASE		(0.0), 				// phase shift (degrees) for clkout1 (0.0 to 360.0)
      .CLKOUT2_DIVIDE		(7),   				// division factor for clkout2 (1 to 128)
      .CLKOUT2_DUTY_CYCLE	(0.5), 				// duty cycle for clkout2 (0.01 to 0.99)
      .CLKOUT2_PHASE		(315.0), 				// phase shift (degrees) for clkout2 (0.0 to 360.0)
      .CLKOUT3_DIVIDE		(7),   				// division factor for clkout3 (1 to 128)
      .CLKOUT3_DUTY_CYCLE	(0.5), 				// duty cycle for clkout3 (0.01 to 0.99)
      .CLKOUT3_PHASE		(0.0), 				// phase shift (degrees) for clkout3 (0.0 to 360.0)
      .CLKOUT4_DIVIDE		(7),   				// division factor for clkout4 (1 to 128)
      .CLKOUT4_DUTY_CYCLE	(0.5), 				// duty cycle for clkout4 (0.01 to 0.99)
      .CLKOUT4_PHASE		(0.0),      			// phase shift (degrees) for clkout4 (0.0 to 360.0)
      .CLKOUT5_DIVIDE		(7),       			// division factor for clkout5 (1 to 128)
      .CLKOUT5_DUTY_CYCLE	(0.5), 				// duty cycle for clkout5 (0.01 to 0.99)
      .CLKOUT5_PHASE		(0.0),      			// phase shift (degrees) for clkout5 (0.0 to 360.0)
      .COMPENSATION		("SOURCE_SYNCHRONOUS"),		// "SYSTEM_SYNCHRONOUS", "SOURCE_SYNCHRONOUS", "INTERNAL", "EXTERNAL", "DCM2PLL", "PLL2DCM"
      .DIVCLK_DIVIDE		(PLLD),        			// division factor for all clocks (1 to 52)
      .CLK_FEEDBACK		("CLKOUT0"),       		//
      .REF_JITTER		(0.100))        		// input reference jitter (0.000 to 0.999 ui%)
rx_pll_adv_inst (
      .CLKFBDCM			(),              		// output feedback signal used when pll feeds a dcm
      .CLKFBOUT			(),              		// general output feedback signal
      .CLKOUT0			(rx_pllout_xs),      		// xS clock for receiver
      .CLKOUT1			(),      			//
      .CLKOUT2			(rx_pllout_x1), 		// x1 clock for BUFG
      .CLKOUT3			(),              		// one of six general clock output signals
      .CLKOUT4			(),              		// one of six general clock output signals
      .CLKOUT5			(),              		// one of six general clock output signals
      .CLKOUTDCM0		(),            			// one of six clock outputs to connect to the dcm
      .CLKOUTDCM1		(),            			// one of six clock outputs to connect to the dcm
      .CLKOUTDCM2		(),            			// one of six clock outputs to connect to the dcm
      .CLKOUTDCM3		(),            			// one of six clock outputs to connect to the dcm
      .CLKOUTDCM4		(),            			// one of six clock outputs to connect to the dcm
      .CLKOUTDCM5		(),            			// one of six clock outputs to connect to the dcm
      .DO			(),                    		// dynamic reconfig data output (16-bits)
      .DRDY			(),                  		// dynamic reconfig ready output
      .LOCKED			(rx_pll_lckd),        		// active high pll lock signal
      .CLKFBIN			(buf_pll_fb_clk),		// clock feedback input
      .CLKIN1			(buf_P_clk),     		// primary clock input
      .CLKIN2			(1'b0),		     		// secondary clock input
      .CLKINSEL			(1'b1),             		// selects '1' = clkin1, '0' = clkin2
      .DADDR			(5'b00000),            		// dynamic reconfig address input (5-bits)
      .DCLK			(1'b0),               		// dynamic reconfig clock input
      .DEN			(1'b0),                		// dynamic reconfig enable input
      .DI			(16'h0000),        		// dynamic reconfig data input (16-bits)
      .DWE			(1'b0),                		// dynamic reconfig write enable input
      .RST			(reset),               		// asynchronous pll reset
      .REL			(1'b0)) ;    			// used to force the state of the PFD outputs (test only)

BUFG	bufg_pll_x1 (.I(rx_pllout_x1), .O(rx_bufg_pll_x1) ) ;

BUFPLL #(
      .DIVIDE			(S))              		// PLLIN0 divide-by value to produce SERDESSTROBE (1 to 8); default 1
rx_bufpll_inst (
      .PLLIN			(rx_pllout_xs),        		// PLL Clock input
      .GCLK			(rx_bufg_pll_x1), 		// Global Clock input
      .LOCKED			(rx_pll_lckd),             	// Clock0 locked input
      .IOCLK			(rxioclk), 			// Output PLL Clock
      .LOCK			(rx_bufplllckd),          	// BUFPLL Clock and strobe locked
      .SERDESSTROBE		(rx_serdesstrobe)) ; 		// Output SERDES strobe

assign rx_bufpll_lckd = rx_pll_lckd & rx_bufplllckd ;
assign not_rx_bufpll_lckd = ~rx_bufpll_lckd ;

endmodule
