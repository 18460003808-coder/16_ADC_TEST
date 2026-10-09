`timescale 1ns/1ps

// Minimal fixed-IPv4 UDP endpoint for the RTL8211EG in 1000BASE-T GMII mode.
// RX command payload: ASCII 'T'. TX payload: N data frames + one end frame,
// identical to the serial N-board application protocol.
module ads7953_udp_gmii #(
    parameter [4:0]  BOARD_COUNT = 5'd2,
    parameter [47:0] LOCAL_MAC   = 48'h02_00_00_00_79_53,
    parameter [31:0] LOCAL_IP    = 32'hC0_A8_01_32,
    parameter [15:0] LOCAL_PORT  = 16'd5000,
    parameter integer PHY_RESET_CYCLES = 1_000_000
)(
    input  wire          clk_50m,
    input  wire          clk_125m,
    input  wire          rst_n,
    input  wire          pll_locked,

    input  wire          adc_ready,
    input  wire          scans_done,
    input  wire [3839:0] board_codes,
    output wire          start_scans,
    output wire          packet_busy,

    input  wire          gmii_rx_clk,
    input  wire [7:0]    gmii_rxd,
    input  wire          gmii_rx_dv,
    input  wire          gmii_rx_er,
    output wire          gmii_gtx_clk,
    output reg  [7:0]    gmii_txd,
    output reg           gmii_tx_en,
    output wire          gmii_tx_er,
    output reg           phy_reset_n,
    output wire          mdc,
    inout  wire          mdio
);
    localparam integer APP_LENGTH      = BOARD_COUNT * 40 + 8;
    localparam integer UDP_LENGTH      = 8 + APP_LENGTH;
    localparam integer IP_TOTAL_LENGTH = 20 + UDP_LENGTH;
    localparam integer FRAME_LENGTH    = 14 + IP_TOTAL_LENGTH;
    localparam [4:0] LAST_BOARD        = BOARD_COUNT - 1'b1;

    assign gmii_gtx_clk = clk_125m;
    assign gmii_tx_er   = 1'b0;
    assign mdc          = 1'b0;
    assign mdio         = 1'bz;

    // Hold the PHY in reset for 20 ms after the transmit PLL locks.
    reg [19:0] phy_reset_count;
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            phy_reset_count <= 20'd0;
            phy_reset_n     <= 1'b0;
        end else if (!pll_locked) begin
            phy_reset_count <= 20'd0;
            phy_reset_n     <= 1'b0;
        end else if (!phy_reset_n) begin
            if (phy_reset_count == PHY_RESET_CYCLES - 1)
                phy_reset_n <= 1'b1;
            else
                phy_reset_count <= phy_reset_count + 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // GMII receive domain: recognize a UDP packet whose first payload byte
    // is 'T', and retain the sender address for the reply.
    // Byte offsets include the 7-byte preamble and one-byte SFD.
    // ------------------------------------------------------------------
    reg [10:0] rx_index;
    reg        rx_in_frame;
    reg        rx_error_seen;
    reg        rx_command_seen;
    reg [15:0] rx_ethertype;
    reg [7:0]  rx_ip_version_ihl;
    reg [7:0]  rx_ip_protocol;
    reg [15:0] rx_destination_port;
    reg [47:0] source_mac_work;
    reg [31:0] source_ip_work;
    reg [15:0] source_port_work;
    reg [47:0] remote_mac_rx;
    reg [31:0] remote_ip_rx;
    reg [15:0] remote_port_rx;
    reg        trigger_toggle_rx;

    always @(posedge gmii_rx_clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_index            <= 11'd0;
            rx_in_frame         <= 1'b0;
            rx_error_seen       <= 1'b0;
            rx_command_seen     <= 1'b0;
            rx_ethertype        <= 16'd0;
            rx_ip_version_ihl   <= 8'd0;
            rx_ip_protocol      <= 8'd0;
            rx_destination_port <= 16'd0;
            source_mac_work     <= 48'd0;
            source_ip_work      <= 32'd0;
            source_port_work    <= 16'd0;
            remote_mac_rx       <= 48'd0;
            remote_ip_rx        <= 32'd0;
            remote_port_rx      <= 16'd0;
            trigger_toggle_rx   <= 1'b0;
        end else if (gmii_rx_dv) begin
            rx_in_frame   <= 1'b1;
            rx_error_seen <= rx_error_seen | gmii_rx_er;
            rx_index      <= rx_index + 1'b1;
            case (rx_index)
                11'd14: source_mac_work[47:40] <= gmii_rxd;
                11'd15: source_mac_work[39:32] <= gmii_rxd;
                11'd16: source_mac_work[31:24] <= gmii_rxd;
                11'd17: source_mac_work[23:16] <= gmii_rxd;
                11'd18: source_mac_work[15:8]  <= gmii_rxd;
                11'd19: source_mac_work[7:0]   <= gmii_rxd;
                11'd20: rx_ethertype[15:8]     <= gmii_rxd;
                11'd21: rx_ethertype[7:0]      <= gmii_rxd;
                11'd22: rx_ip_version_ihl      <= gmii_rxd;
                11'd31: rx_ip_protocol         <= gmii_rxd;
                11'd34: source_ip_work[31:24]  <= gmii_rxd;
                11'd35: source_ip_work[23:16]  <= gmii_rxd;
                11'd36: source_ip_work[15:8]   <= gmii_rxd;
                11'd37: source_ip_work[7:0]    <= gmii_rxd;
                11'd42: source_port_work[15:8] <= gmii_rxd;
                11'd43: source_port_work[7:0]  <= gmii_rxd;
                11'd44: rx_destination_port[15:8] <= gmii_rxd;
                11'd45: rx_destination_port[7:0]  <= gmii_rxd;
                11'd50: begin
                    if ((gmii_rxd == 8'h54) &&
                        (rx_ethertype == 16'h0800) &&
                        (rx_ip_version_ihl == 8'h45) &&
                        (rx_ip_protocol == 8'h11) &&
                        (rx_destination_port == LOCAL_PORT))
                        rx_command_seen <= 1'b1;
                end
                default: begin end
            endcase
        end else begin
            if (rx_in_frame && rx_command_seen && !rx_error_seen) begin
                remote_mac_rx     <= source_mac_work;
                remote_ip_rx      <= source_ip_work;
                remote_port_rx    <= source_port_work;
                trigger_toggle_rx <= ~trigger_toggle_rx;
            end
            rx_index        <= 11'd0;
            rx_in_frame     <= 1'b0;
            rx_error_seen   <= 1'b0;
            rx_command_seen <= 1'b0;
        end
    end

    // Request CDC into the 50 MHz ADC domain. Address fields are stable from
    // the end of the command packet until the next accepted command.
    reg [2:0] trigger_sync_50;
    reg [47:0] request_remote_mac_50;
    reg [31:0] request_remote_ip_50;
    reg [15:0] request_remote_port_50;
    wire trigger_pulse_50 = trigger_sync_50[2] ^ trigger_sync_50[1];

    reg [15:0] sequence_counter_50;
    reg response_toggle_50;
    reg build_active;
    reg [3839:0] build_codes;
    reg [15:0] build_sequence;
    reg [47:0] build_remote_mac;
    reg [31:0] build_remote_ip;
    reg [15:0] build_remote_port;
    reg [15:0] build_ip_checksum;
    reg [4:0] build_board;
    reg [5:0] build_offset;
    reg build_sending_end;
    reg [7:0] build_checksum;
    reg [9:0] build_address;
    reg [7:0] frame_mem [0:FRAME_LENGTH-1];
    assign start_scans = trigger_pulse_50 && adc_ready && !build_active;

    function [7:0] build_code_byte;
        input [4:0] board_id;
        input [4:0] payload_index;
        input [3839:0] codes;
        integer code_base;
        begin
            code_base = board_id * 192 + (payload_index >> 1) * 12;
            if (!payload_index[0])
                build_code_byte = codes[code_base +: 8];
            else
                build_code_byte = {4'b0000, codes[code_base + 8 +: 4]};
        end
    endfunction

    function [7:0] build_packet_byte;
        input [4:0] board_id;
        input [5:0] offset;
        input is_end;
        input [15:0] sequence_value;
        input [3839:0] codes;
        input [7:0] checksum_value;
        begin
            if (is_end) begin
                case (offset)
                    6'd0: build_packet_byte = 8'hA5;
                    6'd1: build_packet_byte = 8'h5A;
                    6'd2: build_packet_byte = 8'h01;
                    6'd3: build_packet_byte = 8'hFF;
                    6'd4: build_packet_byte = {3'b000, BOARD_COUNT};
                    6'd5: build_packet_byte = sequence_value[7:0];
                    6'd6: build_packet_byte = sequence_value[15:8];
                    default: build_packet_byte = checksum_value;
                endcase
            end else begin
                case (offset)
                    6'd0: build_packet_byte = 8'hA5;
                    6'd1: build_packet_byte = 8'h5A;
                    6'd2: build_packet_byte = 8'h01;
                    6'd3: build_packet_byte = {3'b000, board_id};
                    6'd4: build_packet_byte = 8'd32;
                    6'd5: build_packet_byte = sequence_value[7:0];
                    6'd6: build_packet_byte = sequence_value[15:8];
                    6'd39: build_packet_byte = checksum_value;
                    default: build_packet_byte = build_code_byte(
                        board_id, offset - 6'd7, codes);
                endcase
            end
        end
    endfunction

    function [15:0] build_ipv4_checksum;
        input [31:0] destination_ip;
        input [15:0] identification;
        reg [31:0] sum;
        begin
            sum = 32'h0000_4500 + IP_TOTAL_LENGTH + identification +
                  16'h4000 + 16'h4011 + LOCAL_IP[31:16] + LOCAL_IP[15:0] +
                  destination_ip[31:16] + destination_ip[15:0];
            sum = sum[15:0] + sum[31:16];
            sum = sum[15:0] + sum[31:16];
            build_ipv4_checksum = ~sum[15:0];
        end
    endfunction

    function [7:0] build_header_byte;
        input [5:0] index;
        input [47:0] remote_mac_value;
        input [31:0] remote_ip_value;
        input [15:0] remote_port_value;
        input [15:0] sequence_value;
        input [15:0] ip_checksum_value;
        begin
            case (index)
                6'd0:  build_header_byte = remote_mac_value[47:40];
                6'd1:  build_header_byte = remote_mac_value[39:32];
                6'd2:  build_header_byte = remote_mac_value[31:24];
                6'd3:  build_header_byte = remote_mac_value[23:16];
                6'd4:  build_header_byte = remote_mac_value[15:8];
                6'd5:  build_header_byte = remote_mac_value[7:0];
                6'd6:  build_header_byte = LOCAL_MAC[47:40];
                6'd7:  build_header_byte = LOCAL_MAC[39:32];
                6'd8:  build_header_byte = LOCAL_MAC[31:24];
                6'd9:  build_header_byte = LOCAL_MAC[23:16];
                6'd10: build_header_byte = LOCAL_MAC[15:8];
                6'd11: build_header_byte = LOCAL_MAC[7:0];
                6'd12: build_header_byte = 8'h08;
                6'd13: build_header_byte = 8'h00;
                6'd14: build_header_byte = 8'h45;
                6'd15: build_header_byte = 8'h00;
                6'd16: build_header_byte = IP_TOTAL_LENGTH[15:8];
                6'd17: build_header_byte = IP_TOTAL_LENGTH[7:0];
                6'd18: build_header_byte = sequence_value[15:8];
                6'd19: build_header_byte = sequence_value[7:0];
                6'd20: build_header_byte = 8'h40;
                6'd21: build_header_byte = 8'h00;
                6'd22: build_header_byte = 8'h40;
                6'd23: build_header_byte = 8'h11;
                6'd24: build_header_byte = ip_checksum_value[15:8];
                6'd25: build_header_byte = ip_checksum_value[7:0];
                6'd26: build_header_byte = LOCAL_IP[31:24];
                6'd27: build_header_byte = LOCAL_IP[23:16];
                6'd28: build_header_byte = LOCAL_IP[15:8];
                6'd29: build_header_byte = LOCAL_IP[7:0];
                6'd30: build_header_byte = remote_ip_value[31:24];
                6'd31: build_header_byte = remote_ip_value[23:16];
                6'd32: build_header_byte = remote_ip_value[15:8];
                6'd33: build_header_byte = remote_ip_value[7:0];
                6'd34: build_header_byte = LOCAL_PORT[15:8];
                6'd35: build_header_byte = LOCAL_PORT[7:0];
                6'd36: build_header_byte = remote_port_value[15:8];
                6'd37: build_header_byte = remote_port_value[7:0];
                6'd38: build_header_byte = UDP_LENGTH[15:8];
                6'd39: build_header_byte = UDP_LENGTH[7:0];
                default: build_header_byte = 8'h00;
            endcase
        end
    endfunction

    wire [7:0] current_build_byte = (build_address < 10'd42) ?
        build_header_byte(build_address[5:0], build_remote_mac,
                          build_remote_ip, build_remote_port, build_sequence,
                          build_ip_checksum) :
        build_packet_byte(build_board, build_offset, build_sending_end,
                          build_sequence, build_codes, build_checksum);

    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            trigger_sync_50        <= 3'd0;
            request_remote_mac_50  <= 48'd0;
            request_remote_ip_50   <= 32'd0;
            request_remote_port_50 <= 16'd0;
            sequence_counter_50    <= 16'd0;
            response_toggle_50     <= 1'b0;
            build_active           <= 1'b0;
            build_codes            <= 3840'd0;
            build_sequence         <= 16'd0;
            build_remote_mac       <= 48'd0;
            build_remote_ip        <= 32'd0;
            build_remote_port      <= 16'd0;
            build_ip_checksum      <= 16'd0;
            build_board            <= 5'd0;
            build_offset           <= 6'd0;
            build_sending_end      <= 1'b0;
            build_checksum         <= 8'd0;
            build_address          <= 10'd0;
        end else begin
            trigger_sync_50 <= {trigger_sync_50[1:0], trigger_toggle_rx};
            if (trigger_pulse_50 && adc_ready && !build_active) begin
                request_remote_mac_50  <= remote_mac_rx;
                request_remote_ip_50   <= remote_ip_rx;
                request_remote_port_50 <= remote_port_rx;
            end
            if (scans_done && !build_active) begin
                sequence_counter_50     <= sequence_counter_50 + 1'b1;
                build_active            <= 1'b1;
                build_codes             <= board_codes;
                build_sequence          <= sequence_counter_50;
                build_remote_mac        <= request_remote_mac_50;
                build_remote_ip         <= request_remote_ip_50;
                build_remote_port       <= request_remote_port_50;
                build_ip_checksum       <= build_ipv4_checksum(
                    request_remote_ip_50, sequence_counter_50);
                build_board             <= 5'd0;
                build_offset            <= 6'd0;
                build_sending_end       <= 1'b0;
                build_checksum          <= 8'd0;
                build_address           <= 10'd0;
            end else if (build_active) begin
                frame_mem[build_address] <= current_build_byte;
                if ((build_address >= 10'd42) && (build_offset >= 6'd2) &&
                    ((!build_sending_end && (build_offset <= 6'd38)) ||
                     (build_sending_end && (build_offset <= 6'd6))))
                    build_checksum <= build_checksum ^ current_build_byte;

                if ((build_address >= 10'd42) &&
                    ((!build_sending_end && (build_offset == 6'd39)) ||
                     (build_sending_end && (build_offset == 6'd7)))) begin
                    build_checksum <= 8'd0;
                    build_offset   <= 6'd0;
                    if (!build_sending_end && (build_board < LAST_BOARD)) begin
                        build_board <= build_board + 1'b1;
                    end else if (!build_sending_end) begin
                        build_sending_end <= 1'b1;
                    end
                end else if (build_address >= 10'd42) begin
                    build_offset <= build_offset + 1'b1;
                end
                if (build_address == FRAME_LENGTH - 1) begin
                    build_active       <= 1'b0;
                    response_toggle_50 <= ~response_toggle_50;
                end else begin
                    build_address <= build_address + 1'b1;
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // 125 MHz transmit domain: Ethernet II + IPv4 + UDP + application data.
    // ------------------------------------------------------------------
    localparam [2:0] TX_IDLE     = 3'd0;
    localparam [2:0] TX_PREAMBLE = 3'd1;
    localparam [2:0] TX_FRAME    = 3'd2;
    localparam [2:0] TX_FCS      = 3'd3;
    localparam [2:0] TX_IFG      = 3'd4;

    reg [2:0] tx_state;
    reg [3:0] preamble_index;
    reg [10:0] frame_index;
    reg [1:0] fcs_index;
    reg [3:0] ifg_count;
    reg [31:0] crc;
    reg [31:0] fcs_value;
    reg [2:0] response_sync_125;
    reg response_seen_125;
    reg [9:0] frame_read_address;
    reg [7:0] frame_read_data;

    assign packet_busy = build_active || (tx_state != TX_IDLE);

    always @(posedge clk_125m)
        frame_read_data <= frame_mem[frame_read_address];

    function [31:0] crc32_next;
        input [31:0] current_crc;
        input [7:0] data;
        begin
            crc32_next[0]  = ^(current_crc & 32'h00000104) ^ ^(data & 8'h04);
            crc32_next[1]  = ^(current_crc & 32'h00000209) ^ ^(data & 8'h09);
            crc32_next[2]  = ^(current_crc & 32'h00000413) ^ ^(data & 8'h13);
            crc32_next[3]  = ^(current_crc & 32'h00000826) ^ ^(data & 8'h26);
            crc32_next[4]  = ^(current_crc & 32'h0000104D) ^ ^(data & 8'h4D);
            crc32_next[5]  = ^(current_crc & 32'h0000209A) ^ ^(data & 8'h9A);
            crc32_next[6]  = ^(current_crc & 32'h00004030) ^ ^(data & 8'h30);
            crc32_next[7]  = ^(current_crc & 32'h00008061) ^ ^(data & 8'h61);
            crc32_next[8]  = ^(current_crc & 32'h000100C2) ^ ^(data & 8'hC2);
            crc32_next[9]  = ^(current_crc & 32'h00020080) ^ ^(data & 8'h80);
            crc32_next[10] = ^(current_crc & 32'h00040004) ^ ^(data & 8'h04);
            crc32_next[11] = ^(current_crc & 32'h00080008) ^ ^(data & 8'h08);
            crc32_next[12] = ^(current_crc & 32'h00100011) ^ ^(data & 8'h11);
            crc32_next[13] = ^(current_crc & 32'h00200023) ^ ^(data & 8'h23);
            crc32_next[14] = ^(current_crc & 32'h00400046) ^ ^(data & 8'h46);
            crc32_next[15] = ^(current_crc & 32'h0080008C) ^ ^(data & 8'h8C);
            crc32_next[16] = ^(current_crc & 32'h0100001D) ^ ^(data & 8'h1D);
            crc32_next[17] = ^(current_crc & 32'h0200003B) ^ ^(data & 8'h3B);
            crc32_next[18] = ^(current_crc & 32'h04000077) ^ ^(data & 8'h77);
            crc32_next[19] = ^(current_crc & 32'h080000EE) ^ ^(data & 8'hEE);
            crc32_next[20] = ^(current_crc & 32'h100000D8) ^ ^(data & 8'hD8);
            crc32_next[21] = ^(current_crc & 32'h200000B4) ^ ^(data & 8'hB4);
            crc32_next[22] = ^(current_crc & 32'h4000006C) ^ ^(data & 8'h6C);
            crc32_next[23] = ^(current_crc & 32'h800000D8) ^ ^(data & 8'hD8);
            crc32_next[24] = ^(current_crc & 32'h000000B5) ^ ^(data & 8'hB5);
            crc32_next[25] = ^(current_crc & 32'h0000006F) ^ ^(data & 8'h6F);
            crc32_next[26] = ^(current_crc & 32'h000000DF) ^ ^(data & 8'hDF);
            crc32_next[27] = ^(current_crc & 32'h000000BA) ^ ^(data & 8'hBA);
            crc32_next[28] = ^(current_crc & 32'h00000071) ^ ^(data & 8'h71);
            crc32_next[29] = ^(current_crc & 32'h000000E3) ^ ^(data & 8'hE3);
            crc32_next[30] = ^(current_crc & 32'h000000C3) ^ ^(data & 8'hC3);
            crc32_next[31] = ^(current_crc & 32'h00000082) ^ ^(data & 8'h82);
        end
    endfunction

    wire [7:0] current_frame_byte = frame_read_data;
    wire [31:0] crc_after_current = crc32_next(crc, current_frame_byte);

    always @(posedge clk_125m or negedge rst_n) begin
        if (!rst_n) begin
            tx_state          <= TX_IDLE;
            gmii_txd          <= 8'd0;
            gmii_tx_en        <= 1'b0;
            preamble_index    <= 4'd0;
            frame_index       <= 11'd0;
            fcs_index         <= 2'd0;
            ifg_count         <= 4'd0;
            crc               <= 32'hFFFF_FFFF;
            fcs_value         <= 32'd0;
            response_sync_125 <= 3'd0;
            response_seen_125 <= 1'b0;
            frame_read_address <= 10'd0;
        end else begin
            response_sync_125 <= {response_sync_125[1:0], response_toggle_50};
            case (tx_state)
                TX_IDLE: begin
                    gmii_tx_en <= 1'b0;
                    if (pll_locked &&
                            (response_sync_125[2] != response_seen_125)) begin
                        response_seen_125 <= response_sync_125[2];
                        preamble_index    <= 4'd0;
                        crc               <= 32'hFFFF_FFFF;
                        frame_read_address <= 10'd0;
                        tx_state          <= TX_PREAMBLE;
                    end
                end

                TX_PREAMBLE: begin
                    gmii_tx_en <= 1'b1;
                    gmii_txd   <= (preamble_index == 4'd7) ? 8'hD5 : 8'h55;
                    if (preamble_index == 4'd7) begin
                        frame_index <= 11'd0;
                        frame_read_address <= 10'd1;
                        tx_state    <= TX_FRAME;
                    end else begin
                        preamble_index <= preamble_index + 1'b1;
                    end
                end

                TX_FRAME: begin
                    gmii_tx_en <= 1'b1;
                    gmii_txd   <= current_frame_byte;
                    crc        <= crc_after_current;
                    if (frame_index < FRAME_LENGTH - 1)
                        frame_read_address <= frame_read_address + 1'b1;
                    if (frame_index == FRAME_LENGTH - 1) begin
                        fcs_value   <= ~crc_after_current;
                        fcs_index   <= 2'd0;
                        tx_state    <= TX_FCS;
                    end else begin
                        frame_index <= frame_index + 1'b1;
                    end
                end

                TX_FCS: begin
                    gmii_tx_en <= 1'b1;
                    case (fcs_index)
                        2'd0: gmii_txd <= fcs_value[7:0];
                        2'd1: gmii_txd <= fcs_value[15:8];
                        2'd2: gmii_txd <= fcs_value[23:16];
                        default: gmii_txd <= fcs_value[31:24];
                    endcase
                    if (fcs_index == 2'd3) begin
                        ifg_count <= 4'd0;
                        tx_state  <= TX_IFG;
                    end else begin
                        fcs_index <= fcs_index + 1'b1;
                    end
                end

                TX_IFG: begin
                    gmii_tx_en <= 1'b0;
                    gmii_txd   <= 8'd0;
                    if (ifg_count == 4'd11)
                        tx_state <= TX_IDLE;
                    else
                        ifg_count <= ifg_count + 1'b1;
                end

                default: tx_state <= TX_IDLE;
            endcase
        end
    end
endmodule
