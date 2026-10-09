`timescale 1ns/1ps

module tb_ads7953_udp_gmii;
`ifndef TEST_BOARD_COUNT
`define TEST_BOARD_COUNT 2
`endif
    localparam integer BOARD_COUNT = `TEST_BOARD_COUNT;
    localparam integer APP_LENGTH = BOARD_COUNT * 40 + 8;
    localparam integer EXPECTED_TX_BYTES = 8 + 42 + APP_LENGTH + 4;

    reg clk_50m = 1'b0;
    reg clk_125m = 1'b0;
    reg rx_clk = 1'b0;
    reg rst_n = 1'b0;
    reg pll_locked = 1'b1;
    reg adc_ready = 1'b1;
    reg scans_done = 1'b0;
    reg [3839:0] board_codes = 3840'd0;
    reg [7:0] rxd = 8'd0;
    reg rx_dv = 1'b0;
    reg rx_er = 1'b0;
    wire start_scans;
    wire packet_busy;
    wire gtx_clk;
    wire [7:0] txd;
    wire tx_en;
    wire tx_er;
    wire phy_reset_n;
    wire mdc;
    wire mdio;

    reg [7:0] captured [0:1023];
    integer captured_count = 0;
    integer errors = 0;
    integer index;
    integer ip_checksum_sum;
    integer end_frame_offset;
    reg capture_active = 1'b0;
    reg [31:0] expected_crc;

    always #10 clk_50m = ~clk_50m;
    always #4 clk_125m = ~clk_125m;
    always #4 rx_clk = ~rx_clk;

    ads7953_udp_gmii #(
        .BOARD_COUNT(BOARD_COUNT),
        .PHY_RESET_CYCLES(4)
    ) dut (
        .clk_50m(clk_50m), .clk_125m(clk_125m), .rst_n(rst_n),
        .pll_locked(pll_locked), .adc_ready(adc_ready),
        .scans_done(scans_done), .board_codes(board_codes),
        .start_scans(start_scans), .packet_busy(packet_busy),
        .gmii_rx_clk(rx_clk), .gmii_rxd(rxd), .gmii_rx_dv(rx_dv),
        .gmii_rx_er(rx_er), .gmii_gtx_clk(gtx_clk), .gmii_txd(txd),
        .gmii_tx_en(tx_en), .gmii_tx_er(tx_er),
        .phy_reset_n(phy_reset_n), .mdc(mdc), .mdio(mdio)
    );

    function [31:0] crc32_next;
        input [31:0] current_crc;
        input [7:0] data;
        integer bit_index;
        reg [31:0] value;
        begin
            value = current_crc;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (value[0] ^ data[bit_index])
                    value = (value >> 1) ^ 32'hEDB88320;
                else
                    value = value >> 1;
            end
            crc32_next = value;
        end
    endfunction

    always @(posedge clk_125m) begin
        if (tx_en) begin
            captured[captured_count] <= txd;
            captured_count <= captured_count + 1;
            capture_active <= 1'b1;
        end else if (capture_active) begin
            capture_active <= 1'b0;
            if (captured_count != EXPECTED_TX_BYTES) begin
                $display("ERROR TX byte count %0d expected %0d", captured_count,
                         EXPECTED_TX_BYTES);
                errors = errors + 1;
            end
        end
    end

    task send_rx_byte;
        input [7:0] value;
        begin
            @(negedge rx_clk);
            rx_dv = 1'b1;
            rxd = value;
        end
    endtask

    task send_trigger_packet;
        integer byte_index;
        reg [7:0] value;
        begin
            for (byte_index = 0; byte_index <= 50; byte_index = byte_index + 1) begin
                value = 8'h00;
                if (byte_index < 7) value = 8'h55;
                else if (byte_index == 7) value = 8'hD5;
                else if ((byte_index >= 8) && (byte_index <= 13)) value = 8'hFF;
                else begin
                    case (byte_index)
                        14: value = 8'h12;
                        15: value = 8'h34;
                        16: value = 8'h56;
                        17: value = 8'h78;
                        18: value = 8'h9A;
                        19: value = 8'hBC;
                        20: value = 8'h08;
                        21: value = 8'h00;
                        22: value = 8'h45;
                        31: value = 8'h11;
                        34: value = 8'hC0;
                        35: value = 8'hA8;
                        36: value = 8'h01;
                        37: value = 8'h0A;
                        42: value = 8'h13;
                        43: value = 8'h89;
                        44: value = 8'h13;
                        45: value = 8'h88;
                        50: value = 8'h54;
                        default: value = 8'h00;
                    endcase
                end
                send_rx_byte(value);
            end
            @(negedge rx_clk);
            rx_dv = 1'b0;
            rxd = 8'd0;
        end
    endtask

    initial begin
        for (index = 0; index < 32; index = index + 1) begin
            board_codes[index * 12 +: 12] = index[11:0];
            board_codes[192 + index * 12 +: 12] = (12'h100 + index);
        end
        #100;
        rst_n = 1'b1;
        wait (phy_reset_n);
        send_trigger_packet();
        wait (start_scans);
        @(posedge clk_50m);
        repeat (5) @(posedge clk_50m);
        scans_done = 1'b1;
        @(posedge clk_50m);
        scans_done = 1'b0;
        wait (capture_active);
        wait (!capture_active);
        #20;

        if (captured[0] !== 8'h55 || captured[7] !== 8'hD5) begin
            $display("ERROR preamble %02x %02x", captured[0], captured[7]);
            errors = errors + 1;
        end
        if ({captured[8], captured[9], captured[10], captured[11], captured[12], captured[13]}
                !== 48'h12_34_56_78_9A_BC) begin
            $display("ERROR destination MAC %02x:%02x:%02x:%02x:%02x:%02x",
                     captured[8], captured[9], captured[10], captured[11],
                     captured[12], captured[13]); errors = errors + 1; end
        if ({captured[14], captured[15], captured[16], captured[17], captured[18], captured[19]}
                !== 48'h02_00_00_00_79_53) begin
            $display("ERROR source MAC"); errors = errors + 1; end
        if ({captured[20], captured[21]} !== 16'h0800) begin
            $display("ERROR ethertype"); errors = errors + 1; end
        if ({captured[42], captured[43]} !== 16'd5000) begin
            $display("ERROR source port %02x%02x", captured[42], captured[43]);
            errors = errors + 1; end
        if ({captured[44], captured[45]} !== 16'd5001) begin
            $display("ERROR destination port %02x%02x", captured[44], captured[45]);
            errors = errors + 1; end
        if (captured[50] !== 8'hA5 || captured[51] !== 8'h5A ||
            captured[53] !== 8'h00) begin
            $display("ERROR board0 header"); errors = errors + 1; end
        if ((BOARD_COUNT > 1) &&
            (captured[90] !== 8'hA5 || captured[93] !== 8'h01)) begin
            $display("ERROR board1 header"); errors = errors + 1; end
        end_frame_offset = 50 + BOARD_COUNT * 40;
        if (captured[end_frame_offset] !== 8'hA5 ||
            captured[end_frame_offset + 3] !== 8'hFF ||
            captured[end_frame_offset + 4] !== BOARD_COUNT) begin
            $display("ERROR end header"); errors = errors + 1; end

        ip_checksum_sum = 0;
        for (index = 22; index < 42; index = index + 2)
            ip_checksum_sum = ip_checksum_sum +
                              {captured[index], captured[index + 1]};
        while (ip_checksum_sum > 16'hFFFF)
            ip_checksum_sum = (ip_checksum_sum & 16'hFFFF) +
                              (ip_checksum_sum >> 16);
        if (ip_checksum_sum !== 16'hFFFF) begin
            $display("ERROR IPv4 header checksum %04x", ip_checksum_sum);
            errors = errors + 1;
        end

        expected_crc = 32'hFFFF_FFFF;
        for (index = 8; index < EXPECTED_TX_BYTES - 4; index = index + 1)
            expected_crc = crc32_next(expected_crc, captured[index]);
        expected_crc = ~expected_crc;
        if (captured[EXPECTED_TX_BYTES-4] !== expected_crc[7:0] ||
            captured[EXPECTED_TX_BYTES-3] !== expected_crc[15:8] ||
            captured[EXPECTED_TX_BYTES-2] !== expected_crc[23:16] ||
            captured[EXPECTED_TX_BYTES-1] !== expected_crc[31:24]) begin
            $display("ERROR Ethernet FCS");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: UDP trigger, N-board payload and Ethernet FCS passed.");
        else
            $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #200000;
        $display("FAIL: timeout");
        $finish;
    end
endmodule
