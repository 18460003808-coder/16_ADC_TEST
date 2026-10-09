`timescale 1ns/1ps

module ads7953_Nboard_hw_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        uart_rxd,
    output wire        uart_txd,
    output wire [19:0] adc_cs_n,
    output wire        adc_sclk,
    output wire        adc_sdi,
    input  wire        adc_sdo,
    output wire        pwm_out,
    output wire        dir
);
    wire        unused_ready;
    wire        unused_busy;
    wire        unused_packet_busy;
    wire        unused_sample_valid;
    wire [4:0]  unused_sample_board;
    wire [3:0]  unused_sample_channel;
    wire [11:0] unused_sample_code;

    ads7953_Nboard_top u_core (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .adc_cs_n(adc_cs_n),
        .adc_sclk(adc_sclk),
        .adc_sdi(adc_sdi),
        .adc_sdo(adc_sdo),
        .pwm_out(pwm_out),
        .dir(dir),
        .ready(unused_ready),
        .busy(unused_busy),
        .packet_busy(unused_packet_busy),
        .sample_valid(unused_sample_valid),
        .sample_board(unused_sample_board),
        .sample_channel(unused_sample_channel),
        .sample_code(unused_sample_code)
    );
endmodule
