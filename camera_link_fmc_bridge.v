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

module camera_link_fmc_bridge
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
  
  xclk,
  x,
  cc,
  ser_tfg,
  ser_tc
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

output xclk;
output [3:0] x;
input [3:0] cc;
output ser_tfg;
input ser_tc;

IBUFDS xclk_lvds (
  .O(xclk),
  .I(fmc_la00p_i),
  .IB(fmc_la00n_i)
);

IBUFDS x0_lvds (
  .O(x[0]),
  .I(fmc_la02p_i),
  .IB(fmc_la02n_i)
);

IBUFDS x1_lvds (
  .O(x[1]),
  .I(fmc_la03p_i),
  .IB(fmc_la03n_i)
);

IBUFDS x2_lvds (
  .O(x[2]),
  .I(fmc_la04p_i),
  .IB(fmc_la04n_i)
);


IBUFDS x3_lvds (
  .O(x[3]),
  .I(fmc_la05p_i),
  .IB(fmc_la05n_i)
);

IBUFDS ser_tfg_lvds (
  .O(ser_tfg),
  .I(fmc_la14p_i),
  .IB(fmc_la14n_i)
);

OBUFDS cc0_lvds (
  .O(fmc_la18p_i),
  .OB(fmc_la18n_i),
  .I(cc[0])
);

OBUFDS cc1_lvds (
  .O(fmc_la19p_i),
  .OB(fmc_la19n_i),
  .I(cc[1])
);

OBUFDS cc2_lvds (
  .O(fmc_la20p_i),
  .OB(fmc_la20n_i),
  .I(cc[2])
);

OBUFDS cc3_lvds (
  .O(fmc_la21p_i),
  .OB(fmc_la21n_i),
  .I(cc[3])
);

OBUFDS ser_tc_lvds (
  .O(fmc_la15p_i),
  .OB(fmc_la15n_i),
  .I(ser_tc)
);

endmodule