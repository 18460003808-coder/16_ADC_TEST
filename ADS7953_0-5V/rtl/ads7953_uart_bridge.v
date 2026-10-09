`timescale 1ns/1ps

module ads7953_uart_bridge #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD   = 115_200
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         uart_rxd,
    output wire         uart_txd,
    input  wire         adc_ready,
    input  wire         scan_done,
    input  wire [191:0] adc_codes,
    output wire         trig_pulse,
    output wire         packet_busy
);
    wire       rx_valid;
    wire [7:0] rx_data;
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx_busy;

    reg         packet_active;
    reg  [5:0]  byte_index;
    reg  [7:0]  checksum;
    reg  [191:0] codes_snapshot;

    assign trig_pulse = rx_valid && (rx_data == 8'h54) &&
                        adc_ready && !packet_active && !tx_busy && !tx_start;
    assign packet_busy = packet_active | tx_busy | tx_start;

    uart_rx_8n1 #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_uart_rx (
        .clk(clk), .rst_n(rst_n), .rx(uart_rxd),
        .data_valid(rx_valid), .data(rx_data)
    );

    uart_tx_8n1 #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_uart_tx (
        .clk(clk), .rst_n(rst_n), .start(tx_start), .data(tx_data),
        .tx(uart_txd), .busy(tx_busy)
    );

    function [7:0] packet_byte;
        input [5:0] index;
        input [191:0] codes;
        input [7:0] checksum_value;
        reg [5:0] payload_index;
        begin
            payload_index = 6'd0;
            if (index == 0)
                packet_byte = 8'hA5;
            else if (index == 1)
                packet_byte = 8'h5A;
            else if (index == 2)
                packet_byte = 8'd32;
            else if (index <= 34) begin
                payload_index = index - 6'd3;
                if (!payload_index[0])
                    packet_byte = codes[(payload_index >> 1)*12 +: 8];
                else
                    packet_byte = {4'b0000,
                        codes[(payload_index >> 1)*12+8 +: 4]};
            end else
                packet_byte = checksum_value;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_start       <= 1'b0;
            tx_data        <= 8'd0;
            packet_active  <= 1'b0;
            byte_index     <= 6'd0;
            checksum       <= 8'd0;
            codes_snapshot <= 192'd0;
        end else begin
            tx_start <= 1'b0;

            if (scan_done) begin
                codes_snapshot <= adc_codes;
                packet_active  <= 1'b1;
                byte_index     <= 6'd0;
                checksum       <= 8'd0;
            end else if (packet_active && !tx_busy && !tx_start) begin
                tx_data  <= packet_byte(byte_index, codes_snapshot, checksum);
                tx_start <= 1'b1;

                if ((byte_index >= 2) && (byte_index <= 34))
                    checksum <= checksum ^
                        packet_byte(byte_index, codes_snapshot, checksum);

                if (byte_index == 35)
                    packet_active <= 1'b0;
                else
                    byte_index <= byte_index + 1'b1;
            end
        end
    end
endmodule
