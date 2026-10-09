create_clock -name clk_50m -period 20.000 [get_ports {clk}]
derive_clock_uncertainty

# UART RX is asynchronous and passes through a two-register synchronizer.
set_false_path -from [get_ports {uart_rxd}]
