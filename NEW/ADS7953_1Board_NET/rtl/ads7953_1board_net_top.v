`timescale 1ns/1ps

module ads7953_1board_net_top (
    input  wire clk,
    input  wire rst_n,
    output wire adc_cs_n,
    output wire adc_sclk,
    output wire adc_sdi,
    input  wire adc_sdo,
    input  wire e_rxc,
    input  wire [7:0] e_rxd,
    input  wire e_rxdv,
    input  wire e_rxer,
    output wire e_gtxc,
    output wire [7:0] e_txd,
    output wire e_txen,
    output wire e_txer,
    output wire e_reset_n,
    output wire e_mdc,
    inout  wire e_mdio
);
    wire clk_125m;
    wire pll_locked;
    wire start_scan;
    wire reader_ready;
    wire scan_done;
    wire [191:0] adc_codes;
    wire [3839:0] board_codes;

    assign board_codes = {3648'd0, adc_codes};

    gmii_pll_125m u_pll (
        .inclk0(clk), .areset(~rst_n), .c0(clk_125m), .locked(pll_locked)
    );

    ads7953_udp_gmii #(.BOARD_COUNT(5'd1)) u_transport (
        .clk_50m(clk), .clk_125m(clk_125m), .rst_n(rst_n),
        .pll_locked(pll_locked), .adc_ready(reader_ready),
        .scans_done(scan_done), .board_codes(board_codes),
        .start_scans(start_scan), .packet_busy(),
        .gmii_rx_clk(e_rxc), .gmii_rxd(e_rxd), .gmii_rx_dv(e_rxdv),
        .gmii_rx_er(e_rxer), .gmii_gtx_clk(e_gtxc), .gmii_txd(e_txd),
        .gmii_tx_en(e_txen), .gmii_tx_er(e_txer),
        .phy_reset_n(e_reset_n), .mdc(e_mdc), .mdio(e_mdio)
    );

    ads7953_16ch_reader #(
        .CLK_HZ(50_000_000), .SCLK_HZ(10_000_000)
    ) u_reader (
        .clk(clk), .rst_n(rst_n), .trig(start_scan),
        .adc_cs_n(adc_cs_n), .adc_sclk(adc_sclk),
        .adc_sdi(adc_sdi), .adc_sdo(adc_sdo),
        .ready(reader_ready), .busy(), .sample_valid(),
        .sample_channel(), .sample_code(), .sample_mv(),
        .scan_done(scan_done), .adc_codes(adc_codes),
        .debug_state(), .debug_tx_word(), .debug_rx_shift(),
        .debug_expected_channel()
    );
endmodule
