`timescale 1ns/1ps

// Cyclone IV E PLL: 50 MHz board clock -> 125 MHz GMII transmit clock.
module gmii_pll_125m (
    input  wire inclk0,
    input  wire areset,
    output wire c0,
    output wire locked
);
    wire [4:0] pll_clocks;

    assign c0 = pll_clocks[0];

    altpll #(
        .bandwidth_type("AUTO"),
        .clk0_divide_by(2),
        .clk0_duty_cycle(50),
        .clk0_multiply_by(5),
        .clk0_phase_shift("0"),
        .compensate_clock("CLK0"),
        .inclk0_input_frequency(20000),
        .intended_device_family("Cyclone IV E"),
        .operation_mode("NORMAL"),
        .pll_type("AUTO"),
        .port_activeclock("PORT_UNUSED"),
        .port_areset("PORT_USED"),
        .port_clkbad0("PORT_UNUSED"),
        .port_clkbad1("PORT_UNUSED"),
        .port_clkloss("PORT_UNUSED"),
        .port_clkswitch("PORT_UNUSED"),
        .port_configupdate("PORT_UNUSED"),
        .port_fbin("PORT_UNUSED"),
        .port_inclk0("PORT_USED"),
        .port_inclk1("PORT_UNUSED"),
        .port_locked("PORT_USED"),
        .port_pfdena("PORT_UNUSED"),
        .port_phasecounterselect("PORT_UNUSED"),
        .port_phasedone("PORT_UNUSED"),
        .port_phasestep("PORT_UNUSED"),
        .port_phaseupdown("PORT_UNUSED"),
        .port_pllena("PORT_UNUSED"),
        .port_scanaclr("PORT_UNUSED"),
        .port_scanclk("PORT_UNUSED"),
        .port_scanclkena("PORT_UNUSED"),
        .port_scandata("PORT_UNUSED"),
        .port_scandataout("PORT_UNUSED"),
        .port_scandone("PORT_UNUSED"),
        .port_scanread("PORT_UNUSED"),
        .port_scanwrite("PORT_UNUSED"),
        .port_clk0("PORT_USED"),
        .port_clk1("PORT_UNUSED"),
        .port_clk2("PORT_UNUSED"),
        .port_clk3("PORT_UNUSED"),
        .port_clk4("PORT_UNUSED"),
        .port_clk5("PORT_UNUSED"),
        .port_clkena0("PORT_UNUSED"),
        .port_clkena1("PORT_UNUSED"),
        .port_clkena2("PORT_UNUSED"),
        .port_clkena3("PORT_UNUSED"),
        .port_clkena4("PORT_UNUSED"),
        .port_clkena5("PORT_UNUSED"),
        .port_extclk0("PORT_UNUSED"),
        .port_extclk1("PORT_UNUSED"),
        .port_extclk2("PORT_UNUSED"),
        .port_extclk3("PORT_UNUSED"),
        .width_clock(5)
    ) u_altpll (
        .areset(areset),
        .inclk({1'b0, inclk0}),
        .clk(pll_clocks),
        .locked(locked)
    );
endmodule
