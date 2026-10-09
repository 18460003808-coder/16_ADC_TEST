create_clock -name clk_50m -period 20.000 [get_ports {clk}]
derive_clock_uncertainty

# UART input is asynchronous and is synchronized inside uart_rx_8n1.
set_false_path -from [get_ports {uart_rxd}]

# ADS7953 SDO is sampled by logic generated from the system clock. The
# conservative 1 MHz validation SCLK leaves ample margin; keep the external
# interface visible in TimeQuest instead of inventing a virtual-clock model.
