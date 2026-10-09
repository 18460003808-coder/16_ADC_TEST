`timescale 1ns/1ps
`include "rtl/ads7953_board_count.vh"

module ads7953_Nboard_top #(
    parameter integer CLK_HZ      = 50_000_000,
    parameter integer UART_BAUD   = 115_200,
    parameter integer ADC_SCLK_HZ = 1_000_000,
    parameter [4:0] BOARD_COUNT = `ADS7953_BOARD_COUNT
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          uart_rxd,
    output wire          uart_txd,
    output wire [19:0]   adc_cs_n,
    output wire          adc_sclk,
    output wire          adc_sdi,
    input  wire          adc_sdo,
    output wire          pwm_out,
    output wire          dir,
    output wire          ready,
    output wire          busy,
    output wire          packet_busy,
    output wire          sample_valid,
    output wire [4:0]    sample_board,
    output wire [3:0]    sample_channel,
    output wire [11:0]   sample_code
);
    wire          start_scans;
    wire          scans_done;
    wire [3839:0] board_codes;
    wire [19:0]   board_valid;
    wire          slide_start;
    wire          slide_move_dir;
    wire [15:0]   slide_pulse_num;
    wire          slide_busy;
    wire          slide_done;

    ads7953_Nboard_uart_bridge #(
        .CLK_HZ(CLK_HZ),
        .BAUD(UART_BAUD),
        .BOARD_COUNT(BOARD_COUNT)
    ) u_uart_bridge (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .adc_ready(ready),
        .scans_done(scans_done),
        .board_codes(board_codes),
        .board_valid(board_valid),
        .slide_busy(slide_busy),
        .slide_done(slide_done),
        .start_scans(start_scans),
        .slide_start(slide_start),
        .slide_dir(slide_move_dir),
        .slide_pulse_num(slide_pulse_num),
        .packet_busy(packet_busy)
    );

    slide #(
        .SYS_CLK(CLK_HZ),
        .PWM_FREQ(2_000)
    ) u_slide (
        .clk(clk),
        .rst_n(rst_n),
        .trig(slide_start),
        .move_dir(slide_move_dir),
        .pulse_num(slide_pulse_num),
        .pwm_out(pwm_out),
        .dir(dir),
        .busy(slide_busy),
        .done(slide_done)
    );

    ads7953_Nboard_controller #(
        .CLK_HZ(CLK_HZ),
        .SCLK_HZ(ADC_SCLK_HZ),
        .BOARD_GAP_NS(100),
        .BOARD_COUNT(BOARD_COUNT)
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
        .board_valid(board_valid),
        .sample_valid(sample_valid),
        .sample_board(sample_board),
        .sample_channel(sample_channel),
        .sample_code(sample_code)
    );
endmodule
