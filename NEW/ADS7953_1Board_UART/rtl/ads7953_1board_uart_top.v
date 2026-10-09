`timescale 1ns/1ps

module ads7953_1board_uart_top (
    input  wire clk,
    input  wire rst_n,
    input  wire uart_rxd,
    output wire uart_txd,
    output wire adc_cs_n,
    output wire adc_sclk,
    output wire adc_sdi,
    input  wire adc_sdo
);
    wire start_scan;
    wire reader_ready;
    wire scan_done;
    wire [191:0] adc_codes;
    wire [3839:0] board_codes;

    assign board_codes = {3648'd0, adc_codes};

    ads7953_Nboard_uart_bridge #(
        .CLK_HZ(50_000_000), .BAUD(115_200), .BOARD_COUNT(5'd1)
    ) u_transport (
        .clk(clk), .rst_n(rst_n), .uart_rxd(uart_rxd), .uart_txd(uart_txd),
        .adc_ready(reader_ready), .scans_done(scan_done),
        .board_codes(board_codes), .start_scans(start_scan), .packet_busy()
    );

    ads7953_16ch_reader #(
        .CLK_HZ(50_000_000), .SCLK_HZ(1_000_000)
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
