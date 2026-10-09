`timescale 1ns/1ps

module ads7953_Nboard_NET_hw_top (
    input  wire        clk,
    input  wire        rst_n,
    output wire [19:0] adc_cs_n,
    output wire        adc_sclk,
    output wire        adc_sdi,
    input  wire        adc_sdo,
    input  wire        e_rxc,
    input  wire [7:0]  e_rxd,
    input  wire        e_rxdv,
    input  wire        e_rxer,
    output wire        e_gtxc,
    output wire [7:0]  e_txd,
    output wire        e_txen,
    output wire        e_txer,
    output wire        e_reset_n,
    output wire        e_mdc,
    inout  wire        e_mdio
);
    ads7953_Nboard_NET_top u_core (
        .clk(clk),
        .rst_n(rst_n),
        .adc_cs_n(adc_cs_n),
        .adc_sclk(adc_sclk),
        .adc_sdi(adc_sdi),
        .adc_sdo(adc_sdo),
        .e_rxc(e_rxc),
        .e_rxd(e_rxd),
        .e_rxdv(e_rxdv),
        .e_rxer(e_rxer),
        .e_gtxc(e_gtxc),
        .e_txd(e_txd),
        .e_txen(e_txen),
        .e_txer(e_txer),
        .e_reset_n(e_reset_n),
        .e_mdc(e_mdc),
        .e_mdio(e_mdio),
        .ready(),
        .busy(),
        .packet_busy()
    );
endmodule
