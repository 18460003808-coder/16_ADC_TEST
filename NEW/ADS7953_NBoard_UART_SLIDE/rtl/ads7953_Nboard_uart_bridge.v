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
    input  wire [19:0]   board_valid,
    input  wire          slide_busy,
    input  wire          slide_done,
    output wire          start_scans,
    output reg           slide_start,
    output reg           slide_dir,
    output reg  [15:0]   slide_pulse_num,
    output wire          packet_busy
);
    localparam [7:0] PROTOCOL_VERSION = 8'h01;
    localparam [7:0] PAYLOAD_LENGTH   = 8'd32;
    localparam [5:0] DATA_LAST_INDEX  = 6'd39;
    localparam [5:0] END_LAST_INDEX   = 6'd7;
    localparam [4:0] LAST_BOARD       = BOARD_COUNT - 1'b1;
    localparam [2:0] RX_IDLE          = 3'd0;
    localparam [2:0] RX_HEADER_2      = 3'd1;
    localparam [2:0] RX_OPCODE        = 3'd2;
    localparam [2:0] RX_DIR           = 3'd3;
    localparam [2:0] RX_PULSE_LO      = 3'd4;
    localparam [2:0] RX_PULSE_HI      = 3'd5;
    localparam [2:0] RX_CHECKSUM      = 3'd6;

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
    reg  [19:0]   valid_snapshot;
    reg          sending_end;
    reg  [2:0]   rx_state;
    reg  [7:0]   rx_checksum;
    reg          rx_slide_dir;
    reg  [15:0]  rx_slide_pulse_num;
    reg          slide_status_pending;
    reg  [3:0]   slide_status_index;

    assign start_scans = rx_valid && (rx_data == 8'h54) &&
                         (rx_state == RX_IDLE) &&
                         adc_ready && !slide_busy && !slide_status_pending &&
                         !packet_active && !tx_busy && !tx_start;
    assign packet_busy = packet_active | slide_status_pending | tx_busy | tx_start;

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
        input [19:0]   valid_bits;
        integer code_base;
        begin
            code_base = board_id * 192 + (payload_index >> 1) * 12;
            if (!payload_index[0])
                code_byte = codes[code_base +: 8];
            else if ((payload_index == 5'd1) && !valid_bits[board_id])
                // CH0 high byte bit7 marks a bounded SPI scan failure.
                // Existing hosts mask the upper nibble and remain compatible.
                code_byte = {1'b1, 3'b000, codes[code_base + 8 +: 4]};
            else
                code_byte = {4'b0000, codes[code_base + 8 +: 4]};
        end
    endfunction

    function [7:0] packet_byte;
        input [5:0]    index;
        input [4:0]    board_id;
        input [15:0]   seq_value;
        input [3839:0] codes;
        input [19:0]   valid_bits;
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
                        board_id, index - 6'd7, codes, valid_bits);
                endcase
            end
        end
    endfunction

    function [7:0] slide_status_byte;
        input [3:0] index;
        begin
            case (index)
                4'd0: slide_status_byte = 8'hA5;
                4'd1: slide_status_byte = 8'h5A;
                4'd2: slide_status_byte = PROTOCOL_VERSION;
                4'd3: slide_status_byte = 8'hFE;
                4'd4: slide_status_byte = 8'h01;
                4'd5: slide_status_byte = {7'd0, slide_dir};
                4'd6: slide_status_byte = slide_pulse_num[7:0];
                4'd7: slide_status_byte = slide_pulse_num[15:8];
                default: slide_status_byte = PROTOCOL_VERSION ^ 8'hFE ^ 8'h01 ^
                                             {7'd0, slide_dir} ^
                                             slide_pulse_num[7:0] ^
                                             slide_pulse_num[15:8];
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state        <= RX_IDLE;
            rx_checksum     <= 8'd0;
            rx_slide_dir    <= 1'b0;
            rx_slide_pulse_num <= 16'd0;
            slide_start     <= 1'b0;
            slide_dir       <= 1'b0;
            slide_pulse_num <= 16'd0;
        end else begin
            slide_start <= 1'b0;
            if (rx_valid) begin
                case (rx_state)
                    RX_IDLE: begin
                        if (rx_data == 8'h55)
                            rx_state <= RX_HEADER_2;
                    end
                    RX_HEADER_2: begin
                        if (rx_data == 8'hAA)
                            rx_state <= RX_OPCODE;
                        else if (rx_data != 8'h55)
                            rx_state <= RX_IDLE;
                    end
                    RX_OPCODE: begin
                        if (rx_data == 8'h4D) begin
                            rx_checksum <= 8'h4D;
                            rx_state    <= RX_DIR;
                        end else begin
                            rx_state <= RX_IDLE;
                        end
                    end
                    RX_DIR: begin
                        if (rx_data <= 8'h01) begin
                            rx_slide_dir <= rx_data[0];
                            rx_checksum <= rx_checksum ^ rx_data;
                            rx_state    <= RX_PULSE_LO;
                        end else begin
                            rx_state <= RX_IDLE;
                        end
                    end
                    RX_PULSE_LO: begin
                        rx_slide_pulse_num[7:0] <= rx_data;
                        rx_checksum <= rx_checksum ^ rx_data;
                        rx_state    <= RX_PULSE_HI;
                    end
                    RX_PULSE_HI: begin
                        rx_slide_pulse_num[15:8] <= rx_data;
                        rx_checksum <= rx_checksum ^ rx_data;
                        rx_state    <= RX_CHECKSUM;
                    end
                    RX_CHECKSUM: begin
                        if ((rx_data == rx_checksum) && adc_ready && !slide_busy &&
                                !packet_active && !slide_status_pending) begin
                            slide_dir       <= rx_slide_dir;
                            slide_pulse_num <= rx_slide_pulse_num;
                            slide_start <= 1'b1;
                        end
                        rx_state <= RX_IDLE;
                    end
                    default: rx_state <= RX_IDLE;
                endcase
            end
        end
    end

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
            valid_snapshot   <= 20'd0;
            sending_end      <= 1'b0;
            slide_status_pending <= 1'b0;
            slide_status_index   <= 4'd0;
        end else begin
            tx_start <= 1'b0;

            if (slide_done) begin
                slide_status_pending <= 1'b1;
                slide_status_index   <= 4'd0;
            end

            if (scans_done) begin
                codes_snapshot   <= board_codes;
                valid_snapshot   <= board_valid;
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
                                        valid_snapshot, checksum, sending_end);
                tx_start <= 1'b1;

                if ((byte_index >= 6'd2) &&
                        ((!sending_end && (byte_index <= 6'd38)) ||
                         (sending_end && (byte_index <= 6'd6))))
                    checksum <= checksum ^ packet_byte(
                        byte_index, packet_board, packet_sequence,
                        codes_snapshot, valid_snapshot, checksum, sending_end);

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
            end else if (slide_status_pending && !tx_busy && !tx_start) begin
                tx_data  <= slide_status_byte(slide_status_index);
                tx_start <= 1'b1;
                if (slide_status_index == 4'd8) begin
                    slide_status_pending <= 1'b0;
                    slide_status_index   <= 4'd0;
                end else begin
                    slide_status_index <= slide_status_index + 1'b1;
                end
            end
        end
    end
endmodule
