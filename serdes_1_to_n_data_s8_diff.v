//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2009 Xilinx, Inc.
// This design is confidential and proprietary of Xilinx, All Rights Reserved.
//////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /   Vendor: Xilinx
// \   \   \/    Version: 1.0
//  \   \        Filename: serdes_1_to_n_data_s8_diff.vhd
//  /   /        Date Last Modified:  November 5 2009
// /___/   /\    Date Created: August 1 2008
// \   \  /  \
//  \___\/\___\
// 
//Device: 	Spartan 6
//Purpose:  	D-bit generic 1:n data receiver module with differential inputs
// 		Takes in 1 bit of differential data and deserialises this to n bits
// 		data is received LSB first
//		Serial input words
//		Line0     : 0,   ...... DS-(S+1)
// 		Line1 	  : 1,   ...... DS-(S+2)
// 		Line(D-1) : .           .
// 		Line0(D)  : D-1, ...... DS
// 		Parallel output word
//		DS, DS-1 ..... 1, 0
//
//		Includes state machine to control CAL and the phase detector
//		Data inversion can be accomplished via the RX_RX_SWAP_MASK 
//		parameter if required
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

module serdes_1_to_n_data_s8_diff (use_phase_detector, input_data, rxioclk, rxserdesstrobe, reset, gclk, bitslip, debug_in, data_out, debug) ;

parameter integer S = 8 ;   			// Parameter to set the serdes factor 1..8
parameter integer D = 16 ;			// Set the number of inputs and outputs
parameter         DIFF_TERM = "FALSE" ;   	// Parameter to enable internal differential termination

input 			use_phase_detector ;	// '1' enables the phase detector logic
input 	[D-1:0]		input_data ;	//
input 			rxioclk ;		// IO Clock network
input 			rxserdesstrobe ;	// Parallel data capture strobe
input 			reset ;			// Reset line
input 			gclk ;			// Global clock
input 			bitslip ;		// Bitslip control line
input 	[1:0]		debug_in ;		// Debug Inputs
output 	[(D*S)-1:0]	data_out ;		// Output data
output 	[2*D+6:0] 	debug ;			// Debug bus, 2D+6 = 2 lines per input (from mux and ce) + 7, leave nc if debug not required

wire 	[D-1:0]		ddly_m;     		// Master output from IODELAY1
wire 	[D-1:0]		ddly_s;     		// Slave output from IODELAY1
wire	[D-1:0]		busys ;			//
wire 	[D-1:0]		rx_data_in ;		//
wire 	[D-1:0]		cascade ;		//
wire 	[D-1:0]		pd_edge ;		//
reg	[8:0]		counter ;
reg	[3:0]		state ;
reg			cal_data_sint ;
wire 	[D-1:0]		busy_data ;
reg 			busy_data_d ;
wire			cal_data_slave ;
reg			enable ;
reg			cal_data_master ;
reg			rst_data ;
reg 			inc_data_int ;
wire 			inc_data ;
reg 	[D-1:0]		ce_data ;
reg 			valid_data_d ;
reg 			incdec_data_d ;
wire	[(8*D)-1:0] 	mdataout ;		//
reg	[4:0] 		pdcounter ;
wire 	[D-1:0]		valid_data ;
wire 	[D-1:0]		incdec_data ;
reg 			flag ;
reg 	[D-1:0]		mux ;
reg			ce_data_inta ;
wire	[D:0]		incdec_data_or ;
wire	[D-1:0]		incdec_data_im ;
wire	[D:0]		valid_data_or ;
wire	[D-1:0]		valid_data_im ;
wire	[D:0]		busy_data_or ;
wire	[D-1:0]		all_ce ;

parameter	  SIM_TAP_DELAY = 49 ;		//
parameter [D-1:0] RX_SWAP_MASK = 16'h0000 ;	// pinswap mask for input bits (0 = no swap (default), 1 = swap). Allows inputs to be connected the wrong way round to ease PCB routing.

assign busy_data = busys ;
assign debug = {mux, cal_data_master, rst_data, cal_data_slave, busy_data_d, inc_data, ce_data, valid_data_d, incdec_data_d};

genvar i ;					// Limit the output data bus to the most significant 'S' number of bits
genvar j ;

assign cal_data_slave = cal_data_sint ;

always @ (posedge gclk or posedge reset)
begin
if (reset == 1'b1) begin
	state <= 0 ;
	cal_data_master <= 1'b0 ;
	cal_data_sint <= 1'b0 ;
	counter <= 9'h000 ;
	enable <= 1'b0 ;
	mux <= 16'h0001 ;
end
else begin
   	counter <= counter + 9'h001 ;
   	if (counter[8] == 1'b1) begin
		counter <= 9'h000 ;
   	end
   	if (counter[5] == 1'b1) begin
		enable <= 1'b1 ;
   	end
  	if (state == 0 && enable == 1'b1) begin				// Wait for IODELAY to be available
		cal_data_master <= 1'b0 ;
		cal_data_sint <= 1'b0 ;
		rst_data <= 1'b0 ;
   		if (busy_data_d == 1'b0) begin
			state <= 1 ;
		end
   	end
   	else if (state == 1) begin					// Issue calibrate command to both master and slave, needed for simulation, not for the silicon
   		cal_data_master <= 1'b1 ;
   		cal_data_sint <= 1'b1 ;
   		if (busy_data_d == 1'b1) begin				// and wait for command to be accepted
   			state <= 2 ;
   		end
   	end
   	else if (state == 2) begin					// Now RST master and slave IODELAYs needed for simulation, not for the silicon
   		cal_data_master <= 1'b0 ;
   		cal_data_sint <= 1'b0 ;
   		if (busy_data_d == 1'b0) begin
   			rst_data <= 1'b1 ;
   			state <= 3 ;
   		end
   	end
   	else if (state == 3) begin					// Wait for IODELAY to be available
   		rst_data <= 1'b0 ;
   		if (busy_data_d == 1'b0) begin
   			state <= 4 ;
   		end
   	end
   	else if (state == 4) begin					// Wait for occasional enable
   		if (counter[8] == 1'b1) begin
  		 	state <= 5 ;
   		end
    	end
    	else if (state == 5) begin					// Calibrate slave only
   		if (busy_data_d == 1'b0) begin
   			cal_data_sint <= 1'b1 ;
   			state <= 6 ;
   			if (D != 1) begin
   				mux <= {mux[D-2:0], mux[D-1]} ;
   			end
   		end
   	end
    	else if (state == 6) begin					// Wait for command to be accepted
   		cal_data_sint <= 1'b0 ;
   		if (busy_data_d == 1'b1) begin
   			state <= 7 ;
   		end
   	end
   	else if (state == 7) begin					// Wait for all IODELAYs to be available, ie CAL command finished
    		cal_data_sint <= 1'b0 ;
  		if (busy_data_d == 1'b0) begin
   			state <= 4 ;
   		end
   	end
end
end

always @ (posedge gclk or posedge reset)				// Per-bit phase detection state machine
begin
if (reset == 1'b1) begin
	pdcounter <= 5'b1000 ;
	ce_data_inta <= 1'b0 ;
	flag <= 1'b0 ;							// flag is there to only allow one inc or dec per cal (test)
end
else begin
	busy_data_d <= busy_data_or[D] ;
   	if (use_phase_detector == 1'b1) begin				// decide whther pd is used
		incdec_data_d <= incdec_data_or[D] ;
		valid_data_d <= valid_data_or[D] ;
		if (ce_data_inta == 1'b1) begin
			ce_data = mux ;
		end
		else begin
			ce_data = 64'h0000000000000000 ;
		end
   		if (state == 7) begin
 			flag <= 1'b0 ;
		end
   		else if (state != 4 || busy_data_d == 1'b1) begin	// Reset filter if state machine issues a cal command or unit is busy
			pdcounter <= 5'b10000 ;
   			ce_data_inta <= 1'b0 ;
   		end
   		else if (pdcounter == 5'b11111 && flag == 1'b0) begin	// Filter has reached positive max - increment the tap count
   			ce_data_inta <= 1'b1 ;
   			inc_data_int <= 1'b1 ;
 			pdcounter <= 5'b10000 ;
 			flag <= 1'b1 ;
 		end
    		else if (pdcounter == 5'b00000 && flag == 1'b0) begin	// Filter has reached negative max - decrement the tap count
   			ce_data_inta <= 1'b1 ;
   			inc_data_int <= 1'b0 ;
 			pdcounter <= 5'b10000 ;
 			flag <= 1'b1 ;
   		end
		else if (valid_data_d == 1'b1) begin			// increment filter
   			ce_data_inta <= 1'b0 ;
			if (incdec_data_d == 1'b1 && pdcounter != 5'b11111) begin
				pdcounter <= pdcounter + 5'b00001 ;
			end
			else if (incdec_data_d == 1'b0 && pdcounter != 5'b00000) begin	// decrement filter
				pdcounter <= pdcounter + 5'b11111 ;
			end
   		end
   		else begin
   			ce_data_inta <= 1'b0 ;
   		end
   	end
   	else begin
		ce_data = all_ce ;
		inc_data_int <= debug_in[1] ;
   	end
end
end

assign inc_data = inc_data_int ;

assign incdec_data_or[0] = 1'b0 ;							// Input Mux - Initialise generate loop OR gates
assign valid_data_or[0] = 1'b0 ;
assign busy_data_or[0] = 1'b0 ;

generate
for (i = 0 ; i <= (D-1) ; i = i+1)
begin : loop0

assign incdec_data_im[i] = incdec_data[i] & mux[i] ;					// Input muxes
assign incdec_data_or[i+1] = incdec_data_im[i] | incdec_data_or[i] ;			// AND gates to allow just one signal through at a tome
assign valid_data_im[i] = valid_data[i] & mux[i] ;					// followed by an OR
assign valid_data_or[i+1] = valid_data_im[i] | valid_data_or[i] ;			// for the three inputs from each PD
assign busy_data_or[i+1] = busy_data[i] | busy_data_or[i] ;				// The busy signals just need an OR gate

assign all_ce[i] = debug_in[0] ;

IODELAY2 #(
	.DATA_RATE      	("SDR"), 		// <SDR>, DDR
	.IDELAY_VALUE  		(0), 			// {0 ... 255}
	.IDELAY2_VALUE 		(0), 			// {0 ... 255}
	.IDELAY_MODE  		("NORMAL" ), 		// NORMAL, PCI
	.ODELAY_VALUE  		(0), 			// {0 ... 255}
	.IDELAY_TYPE   		("DIFF_PHASE_DETECTOR"),// "DEFAULT", "DIFF_PHASE_DETECTOR", "FIXED", "VARIABLE_FROM_HALF_MAX", "VARIABLE_FROM_ZERO"
	.COUNTER_WRAPAROUND 	("WRAPAROUND" ), 	// <STAY_AT_LIMIT>, WRAPAROUND
	.DELAY_SRC     		("IDATAIN" ), 		// "IO", "IDATAIN", "ODATAIN"
	.SERDES_MODE   		("MASTER"), 		// <NONE>, MASTER, SLAVE
	.SIM_TAPDELAY_VALUE   	(SIM_TAP_DELAY)) 	//
iodelay_m (
	.IDATAIN  		(input_data[i]), 	// data from primary IOB
	.TOUT     		(), 			// tri-state signal to IOB
	.DOUT     		(), 			// output data to IOB
	.T        		(1'b1), 		// tri-state control from OLOGIC/OSERDES2
	.ODATAIN  		(1'b0), 		// data from OLOGIC/OSERDES2
	.DATAOUT  		(ddly_m[i]), 		// Output data 1 to ILOGIC/ISERDES2
	.DATAOUT2 		(),	 		// Output data 2 to ILOGIC/ISERDES2
	.IOCLK0   		(rxioclk), 		// High speed clock for calibration
	.IOCLK1   		(1'b0), 		// High speed clock for calibration
	.CLK      		(gclk), 		// Fabric clock (GCLK) for control signals
	.CAL      		(cal_data_master),	// Calibrate control signal
	.INC      		(inc_data), 		// Increment counter
	.CE       		(ce_data[i]), 		// Clock Enable
	.RST      		(rst_data),		// Reset delay line
	.BUSY      		()) ; 			// output signal indicating sync circuit has finished / calibration has finished

IODELAY2 #(
	.DATA_RATE      	("SDR"), 		// <SDR>, DDR
	.IDELAY_VALUE  		(0), 			// {0 ... 255}
	.IDELAY2_VALUE 		(0), 			// {0 ... 255}
	.IDELAY_MODE  		("NORMAL" ), 		// NORMAL, PCI
	.ODELAY_VALUE  		(0), 			// {0 ... 255}
	.IDELAY_TYPE   		("DIFF_PHASE_DETECTOR"),// "DEFAULT", "DIFF_PHASE_DETECTOR", "FIXED", "VARIABLE_FROM_HALF_MAX", "VARIABLE_FROM_ZERO"
	.COUNTER_WRAPAROUND 	("WRAPAROUND" ), 	// <STAY_AT_LIMIT>, WRAPAROUND
	.DELAY_SRC     		("IDATAIN" ), 		// "IO", "IDATAIN", "ODATAIN"
	.SERDES_MODE   		("SLAVE"), 		// <NONE>, MASTER, SLAVE
	.SIM_TAPDELAY_VALUE   	(SIM_TAP_DELAY)) 	//
iodelay_s (
	.IDATAIN 		(input_data[i]), 	// data from primary IOB
	.TOUT     		(), 			// tri-state signal to IOB
	.DOUT     		(), 			// output data to IOB
	.T        		(1'b1), 		// tri-state control from OLOGIC/OSERDES2
	.ODATAIN  		(1'b0), 		// data from OLOGIC/OSERDES2
	.DATAOUT  		(ddly_s[i]), 		// Output data 1 to ILOGIC/ISERDES2
	.DATAOUT2 		(),	 		// Output data 2 to ILOGIC/ISERDES2
	.IOCLK0   		(rxioclk), 		// High speed clock for calibration
	.IOCLK1   		(1'b0), 		// High speed clock for calibration
	.CLK      		(gclk), 		// Fabric clock (GCLK) for control signals
	.CAL      		(cal_data_slave),	// Calibrate control signal
	.INC      		(inc_data), 		// Increment counter
	.CE       		(ce_data[i]), 		// Clock Enable
	.RST      		(rst_data),		// Reset delay line
	.BUSY      		(busys[i])) ;		// output signal indicating sync circuit has finished / calibration has finished

ISERDES2 #(
	.DATA_WIDTH     	(S), 			// SERDES word width.  This should match the setting is BUFPLL
	.DATA_RATE      	("SDR"), 		// <SDR>, DDR
	.BITSLIP_ENABLE 	("TRUE"), 		// <FALSE>, TRUE
	.SERDES_MODE    	("MASTER"), 		// <DEFAULT>, MASTER, SLAVE
	.INTERFACE_TYPE 	("RETIMED")) 		// NETWORKING, NETWORKING_PIPELINED, <RETIMED>
iserdes_m (
	.D       		(ddly_m[i]),
	.CE0     		(1'b1),
	.CLK0    		(rxioclk),
	.CLK1    		(1'b0),
	.IOCE    		(rxserdesstrobe),
	.RST     		(reset),
	.CLKDIV  		(gclk),
	.SHIFTIN 		(pd_edge[i]),
	.BITSLIP 		(bitslip),
	.FABRICOUT 		(),
	.Q4  			(mdataout[(8*i)+7]),
	.Q3  			(mdataout[(8*i)+6]),
	.Q2  			(mdataout[(8*i)+5]),
	.Q1  			(mdataout[(8*i)+4]),
	.DFB  			(),
	.CFB0 			(),
	.CFB1 			(),
	.VALID    		(valid_data[i]),
	.INCDEC   		(incdec_data[i]),
	.SHIFTOUT 		(cascade[i]));

ISERDES2 #(
	.DATA_WIDTH     	(S), 			// SERDES word width.  This should match the setting is BUFPLL
	.DATA_RATE      	("SDR"), 		// <SDR>, DDR
	.BITSLIP_ENABLE 	("TRUE"), 		// <FALSE>, TRUE
	.SERDES_MODE    	("SLAVE"), 		// <DEFAULT>, MASTER, SLAVE
	.INTERFACE_TYPE 	("RETIMED")) 		// NETWORKING, NETWORKING_PIPELINED, <RETIMED>
iserdes_s (
	.D       		(ddly_s[i]),
	.CE0     		(1'b1),
	.CLK0    		(rxioclk),
	.CLK1    		(1'b0),
	.IOCE    		(rxserdesstrobe),
	.RST     		(reset),
	.CLKDIV  		(gclk),
	.SHIFTIN 		(cascade[i]),
	.BITSLIP 		(bitslip),
	.FABRICOUT 		(),
	.Q4  			(mdataout[(8*i)+3]),
	.Q3  			(mdataout[(8*i)+2]),
	.Q2  			(mdataout[(8*i)+1]),
	.Q1  			(mdataout[(8*i)+0]),
	.DFB  			(),
	.CFB0 			(),
	.CFB1 			(),
	.VALID 			(),
	.INCDEC 		(),
	.SHIFTOUT 		(pd_edge[i]));

for (j = 0; j < S; j = j + 1) begin : loop2
  assign data_out[j + (i * 7)] = mdataout[(S - j) + (i * 8)];
end
end

endgenerate
// Assign received data bits to correct place in data word, and invert as necessary using information from the data mask

endmodule
