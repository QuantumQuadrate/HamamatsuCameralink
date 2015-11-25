module uart
(
  clk,
  txd,
  tx_start,
  tx_busy,
  tx_out,
  rxd,
  rx_valid,
  rx_in,
  rx_idle
);

input clk;
input [7:0] txd;
input tx_start;
input rx_in;

output [7:0] rxd;
output rx_valid;
output rx_idle;
output tx_busy;
output tx_out;

async_transmitter
#(
  .ClkFrequency(50000000),
  .Baud(38400)
)
uart_tx
(
  .clk(clk),
  .TxD_start(tx_start),
  .TxD_data(txd),
  .TxD(tx_out),
  .TxD_busy(tx_busy)
);

async_receiver
#(
  .ClkFrequency(50000000),
  .Baud(38400)
)
uart_rx
(
  .clk(clk),
  .RxD(rx_in),
  .RxD_data_ready(rx_valid),
  .RxD_data(rxd),
  .RxD_idle(rx_idle),
  .RxD_endofpacket()
);

endmodule