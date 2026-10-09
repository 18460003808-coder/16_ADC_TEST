`timescale 1ns/1ps

module ads7953_2board_top #(
    parameter integer CLK_HZ    = 50_000_000,
    parameter integer UART_BAUD = 115_200,
    parameter integer ADC_SCLK_HZ = 1_000_000
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       uart_rxd,
    output wire       uart_txd,

    output wire [1:0] adc_cs_n,
    output wire       adc_sclk,
    output wire       adc_sdi,
    input  wire       adc_sdo,

    output wire       ready,
    output wire       busy,
    output wire       packet_busy,
    output wire       sample_valid,
    output wire       sample_board,
    output wire [3:0] sample_channel,
    output wire [11:0] sample_code
);
    wire         start_scans;
    wire         scans_done;
    wire [383:0] board_codes;
    wire [2:0]   debug_reader_state;

    ads7953_2board_uart_bridge #(
        .CLK_HZ(CLK_HZ),
        .BAUD(UART_BAUD)
    ) u_uart_bridge (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .adc_ready(ready),
        .scans_done(scans_done),
        .board_codes(board_codes),
        .start_scans(start_scans),
        .packet_busy(packet_busy)
    );

    ads7953_2board_controller #(
        .CLK_HZ(CLK_HZ),
        .SCLK_HZ(ADC_SCLK_HZ),
        .BOARD_GAP_NS(100)
    ) u_controller (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_scans),
        .adc_cs_n(adc_cs_n),
        .adc_sclk(adc_sclk),
        .adc_sdi(adc_sdi),
        .adc_sdo(adc_sdo),
        .ready(ready),
        .busy(busy),
        .all_done(scans_done),
        .board_codes(board_codes),
        .sample_valid(sample_valid),
        .sample_board(sample_board),
        .sample_channel(sample_channel),
        .sample_code(sample_code),
        .debug_reader_state(debug_reader_state)
    );
endmodule

