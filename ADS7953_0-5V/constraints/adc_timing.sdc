# Assumption: PIN_G1 supplies a 50-MHz system clock.
create_clock -name clk -period 20.000 [get_ports {clk}]

# UART RX is asynchronous and is synchronized by rx_meta/rx_sync.
set_false_path -from [get_ports {uart_rxd}] -to [get_registers {*rx_meta*}]
