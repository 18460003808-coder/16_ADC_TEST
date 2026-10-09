`timescale 1ns/1ps

module ads7953_Nboard_uart_bridge #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD   = 115_200,
    parameter [4:0] BOARD_COUNT = 5'd2
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          uart_rxd,
    output wire          uart_txd,
    input  wire          adc_ready,
    input  wire          scans_done,
    input  wire [3839:0] board_codes,
    output wire          start_scans,
    output wire          packet_busy
);
    localparam [7:0] PROTOCOL_VERSION = 8'h01;
    localparam [7:0] PAYLOAD_LENGTH   = 8'd32;
    localparam [5:0] DATA_LAST_INDEX  = 6'd39;
    localparam [5:0] END_LAST_INDEX   = 6'd7;
    localparam [4:0] LAST_BOARD       = BOARD_COUNT - 1'b1;

    wire       rx_valid;
    wire [7:0] rx_data;
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx_busy;

    reg          packet_active;
    reg  [4:0]   packet_board;
    reg  [5:0]   byte_index;
    reg  [7:0]   checksum;
    reg  [15:0]  sequence_counter;
    reg  [15:0]  packet_sequence;
    reg  [3839:0] codes_snapshot;
    reg          sending_end;

    assign start_scans = rx_valid && (rx_data == 8'h54) &&
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

    function [7:0] code_byte;
        input [4:0]    board_id;
        input [4:0]    payload_index;
        input [3839:0] codes;
        integer code_base;
        begin
            code_base = board_id * 192 + (payload_index >> 1) * 12;
            if (!payload_index[0])
                code_byte = codes[code_base +: 8];
            else
                code_byte = {4'b0000, codes[code_base + 8 +: 4]};
        end
    endfunction

    function [7:0] packet_byte;
        input [5:0]    index;
        input [4:0]    board_id;
        input [15:0]   seq_value;
        input [3839:0] codes;
        input [7:0]    checksum_value;
        input          is_end;
        begin
            if (is_end) begin
                case (index)
                    6'd0: packet_byte = 8'hA5;
                    6'd1: packet_byte = 8'h5A;
                    6'd2: packet_byte = PROTOCOL_VERSION;
                    6'd3: packet_byte = 8'hFF;
                    6'd4: packet_byte = {3'b000, BOARD_COUNT};
                    6'd5: packet_byte = seq_value[7:0];
                    6'd6: packet_byte = seq_value[15:8];
                    default: packet_byte = checksum_value;
                endcase
            end else begin
                case (index)
                    6'd0:  packet_byte = 8'hA5;
                    6'd1:  packet_byte = 8'h5A;
                    6'd2:  packet_byte = PROTOCOL_VERSION;
                    6'd3:  packet_byte = {3'b000, board_id};
                    6'd4:  packet_byte = PAYLOAD_LENGTH;
                    6'd5:  packet_byte = seq_value[7:0];
                    6'd6:  packet_byte = seq_value[15:8];
                    6'd39: packet_byte = checksum_value;
                    default: packet_byte = code_byte(
                        board_id, index - 6'd7, codes);
                endcase
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_start         <= 1'b0;
            tx_data          <= 8'd0;
            packet_active    <= 1'b0;
            packet_board     <= 5'd0;
            byte_index       <= 6'd0;
            checksum         <= 8'd0;
            sequence_counter <= 16'd0;
            packet_sequence  <= 16'd0;
            codes_snapshot   <= 3840'd0;
            sending_end      <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            if (scans_done) begin
                codes_snapshot   <= board_codes;
                packet_sequence  <= sequence_counter;
                sequence_counter <= sequence_counter + 1'b1;
                packet_active    <= 1'b1;
                packet_board     <= 5'd0;
                byte_index       <= 6'd0;
                checksum         <= 8'd0;
                sending_end      <= 1'b0;
            end else if (packet_active && !tx_busy && !tx_start) begin
                tx_data  <= packet_byte(byte_index, packet_board,
                                        packet_sequence, codes_snapshot,
                                        checksum, sending_end);
                tx_start <= 1'b1;

                if ((byte_index >= 6'd2) &&
                        ((!sending_end && (byte_index <= 6'd38)) ||
                         (sending_end && (byte_index <= 6'd6))))
                    checksum <= checksum ^ packet_byte(
                        byte_index, packet_board, packet_sequence,
                        codes_snapshot, checksum, sending_end);

                if ((!sending_end && (byte_index == DATA_LAST_INDEX)) ||
                        (sending_end && (byte_index == END_LAST_INDEX))) begin
                    if (!sending_end && (packet_board < LAST_BOARD)) begin
                        packet_board <= packet_board + 1'b1;
                        byte_index   <= 6'd0;
                        checksum     <= 8'd0;
                    end else if (!sending_end) begin
                        sending_end <= 1'b1;
                        byte_index  <= 6'd0;
                        checksum    <= 8'd0;
                    end else begin
                        packet_active <= 1'b0;
                        sending_end   <= 1'b0;
                    end
                end else begin
                    byte_index <= byte_index + 1'b1;
                end
            end
        end
    end
endmodule
