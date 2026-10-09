create_clock -name clk_50m -period 20.000 [get_ports {clk}]
create_clock -name gmii_rx_clk -period 8.000 [get_ports {e_rxc}]
derive_pll_clocks
derive_clock_uncertainty

# The receive command crosses through a toggle synchronizer into clk_50m.
set_clock_groups -asynchronous -group [get_clocks {gmii_rx_clk}] -group [get_clocks {clk_50m}]

# Response-ready uses a toggle synchronizer from 50 MHz to the PLL clock.
set_false_path -from [get_registers {*response_toggle_50}] \
               -to [get_registers {*response_sync_125[0]}]
