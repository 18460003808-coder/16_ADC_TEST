`timescale 1ns/1ps

module ads7953_model #(
    parameter [11:0] FIRST_BASE = 12'h100
)(
    input  wire cs_n,
    input  wire sclk,
    input  wire sdi,
    output reg  sdo
);
    integer bit_ptr = 15;
    reg [15:0] mosi_shift = 16'd0;
    reg [15:0] response = 16'd0;
    reg        auto_mode = 1'b0;
    reg        warmup = 1'b0;
    reg [3:0]  seq_channel = 4'd0;
    reg [11:0] model_base = FIRST_BASE - 12'h100;

    function [15:0] channel_word;
        input [3:0] channel;
        begin
            channel_word = {channel, model_base + channel};
        end
    endfunction

    always @(negedge cs_n) begin
        bit_ptr = 15;
        mosi_shift = 16'd0;
        sdo = response[15];
    end

    always @(posedge sclk) begin
        if (!cs_n)
            mosi_shift = {mosi_shift[14:0], sdi};
    end

    always @(negedge sclk) begin
        if (!cs_n && bit_ptr > 0) begin
            bit_ptr = bit_ptr - 1;
            sdo = response[bit_ptr];
        end
    end

    always @(posedge cs_n) begin
        if (mosi_shift[15:12] == 4'b1001) begin
            model_base = model_base + 12'h100;
        end else if (mosi_shift[15:12] == 4'b0011) begin
            if (mosi_shift !== 16'h3C40)
                $display("ERROR: expected Auto-2 Range-2 command 3C40, got %04h",
                         mosi_shift);
            auto_mode = 1'b1;
            warmup = 1'b1;
            response = 16'h9AAA;
        end else if (auto_mode && warmup) begin
            warmup = 1'b0;
            seq_channel = 4'd1;
            response = channel_word(4'd0);
        end else if (auto_mode) begin
            response = channel_word(seq_channel);
            seq_channel = seq_channel + 1'b1;
        end else begin
            response = channel_word(4'd0);
        end
    end
endmodule

module tb_ads7953_2board;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg uart_rxd = 1'b1;
    wire uart_txd;
    wire [1:0] adc_cs_n;
    wire adc_sclk;
    wire adc_sdi;
    wire adc_sdo;
    wire ready;
    wire busy;
    wire packet_busy;
    wire sample_valid;
    wire sample_board;
    wire [3:0] sample_channel;
    wire [11:0] sample_code;
    wire sdo0;
    wire sdo1;

    integer errors = 0;
    integer sample_count_board0 = 0;
    integer sample_count_board1 = 0;
    integer low_cs_count;

    localparam integer UART_BIT_NS = 200; // 5 Mbaud for simulation.

    always #10 clk = ~clk; // 50 MHz

    assign adc_sdo = !adc_cs_n[0] ? sdo0 :
                     !adc_cs_n[1] ? sdo1 : 1'b0;

    ads7953_2board_top #(
        .CLK_HZ(50_000_000),
        .UART_BAUD(5_000_000),
        .ADC_SCLK_HZ(5_000_000)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .adc_cs_n(adc_cs_n),
        .adc_sclk(adc_sclk),
        .adc_sdi(adc_sdi),
        .adc_sdo(adc_sdo),
        .ready(ready),
        .busy(busy),
        .packet_busy(packet_busy),
        .sample_valid(sample_valid),
        .sample_board(sample_board),
        .sample_channel(sample_channel),
        .sample_code(sample_code)
    );

    ads7953_model #(.FIRST_BASE(12'h100)) model0 (
        .cs_n(adc_cs_n[0]), .sclk(adc_sclk), .sdi(adc_sdi), .sdo(sdo0)
    );

    ads7953_model #(.FIRST_BASE(12'h500)) model1 (
        .cs_n(adc_cs_n[1]), .sclk(adc_sclk), .sdi(adc_sdi), .sdo(sdo1)
    );

    task uart_send_byte;
        input [7:0] value;
        integer i;
        begin
            uart_rxd = 1'b0;
            #(UART_BIT_NS);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rxd = value[i];
                #(UART_BIT_NS);
            end
            uart_rxd = 1'b1;
            #(UART_BIT_NS);
        end
    endtask

    task uart_receive_byte;
        output [7:0] value;
        integer i;
        begin
            wait (!uart_txd);
            #(UART_BIT_NS + UART_BIT_NS/2);
            for (i = 0; i < 8; i = i + 1) begin
                value[i] = uart_txd;
                #(UART_BIT_NS);
            end
            if (!uart_txd) begin
                $display("ERROR: UART stop bit low");
                errors = errors + 1;
            end
            #(UART_BIT_NS/2);
        end
    endtask

    task receive_board_packet;
        input [7:0] expected_board;
        input [15:0] expected_sequence;
        input [11:0] expected_base;
        reg [7:0] value;
        reg [7:0] checksum;
        reg [7:0] low_byte;
        reg [7:0] high_byte;
        reg [11:0] code;
        integer ch;
        begin
            uart_receive_byte(value);
            if (value !== 8'hA5) begin
                $display("ERROR B%0d: header0=%02h", expected_board, value);
                errors = errors + 1;
            end
            uart_receive_byte(value);
            if (value !== 8'h5A) begin
                $display("ERROR B%0d: header1=%02h", expected_board, value);
                errors = errors + 1;
            end

            checksum = 8'd0;
            uart_receive_byte(value); // Version
            checksum = checksum ^ value;
            if (value !== 8'h01) errors = errors + 1;
            uart_receive_byte(value); // Board ID
            checksum = checksum ^ value;
            if (value !== expected_board) errors = errors + 1;
            uart_receive_byte(value); // Payload length
            checksum = checksum ^ value;
            if (value !== 8'd32) errors = errors + 1;
            uart_receive_byte(value); // Sequence low
            checksum = checksum ^ value;
            if (value !== expected_sequence[7:0]) errors = errors + 1;
            uart_receive_byte(value); // Sequence high
            checksum = checksum ^ value;
            if (value !== expected_sequence[15:8]) errors = errors + 1;

            for (ch = 0; ch < 16; ch = ch + 1) begin
                uart_receive_byte(low_byte);
                uart_receive_byte(high_byte);
                checksum = checksum ^ low_byte ^ high_byte;
                code = {high_byte[3:0], low_byte};
                if (code !== expected_base + ch) begin
                    $display("ERROR B%0d CH%0d expected=%03h got=%03h",
                             expected_board, ch, expected_base + ch, code);
                    errors = errors + 1;
                end
            end

            uart_receive_byte(value);
            if (value !== checksum) begin
                $display("ERROR B%0d checksum expected=%02h got=%02h",
                         expected_board, checksum, value);
                errors = errors + 1;
            end
        end
    endtask

    task trigger_and_check;
        input [15:0] expected_sequence;
        input [11:0] board0_base;
        input [11:0] board1_base;
        begin
            wait (ready && !packet_busy);
            sample_count_board0 = 0;
            sample_count_board1 = 0;
            uart_send_byte(8'h54);
            wait (busy);
            receive_board_packet(8'd0, expected_sequence, board0_base);
            receive_board_packet(8'd1, expected_sequence, board1_base);
            if (sample_count_board0 != 16 || sample_count_board1 != 16) begin
                $display("ERROR sample counts B0=%0d B1=%0d",
                         sample_count_board0, sample_count_board1);
                errors = errors + 1;
            end
        end
    endtask

    always @(posedge clk) begin
        if (rst_n) begin
            low_cs_count = (!adc_cs_n[0]) + (!adc_cs_n[1]);
            if (low_cs_count > 1) begin
                $display("ERROR: both chip selects low at %0t", $time);
                errors = errors + 1;
            end

            if (sample_valid) begin
                if (!sample_board)
                    sample_count_board0 = sample_count_board0 + 1;
                else
                    sample_count_board1 = sample_count_board1 + 1;
            end
        end
    end

    initial begin
        #100;
        rst_n = 1'b1;

        trigger_and_check(16'd0, 12'h100, 12'h500);
        trigger_and_check(16'd1, 12'h200, 12'h600);

        if (errors == 0)
            $display("PASS: two-board shared-SPI scans, CS isolation and UART packets passed.");
        else
            $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #5000000;
        $display("FAIL: timeout");
        $finish;
    end
endmodule

