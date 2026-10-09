`timescale 1ns/1ps

module tb_ads7953_16ch_reader;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg uart_rxd = 1'b1;
    wire uart_txd;
    wire trig_internal;
    wire uart_packet_busy;
    wire cs_n;
    wire sclk;
    wire sdi;
    reg  sdo = 1'b0;
    wire ready;
    wire busy;
    wire sample_valid;
    wire [3:0] sample_channel;
    wire [11:0] sample_code;
    wire [15:0] sample_mv;
    wire scan_done;
    wire [191:0] adc_codes;

    integer errors = 0;
    integer ch;
    integer sample_events = 0;
    integer expected_mv;
    integer bit_ptr = 15;
    reg [15:0] mosi_shift = 16'd0;
    reg [15:0] response = 16'd0;
    reg auto_mode = 1'b0;
    reg warmup = 1'b0;
    reg [3:0] seq_channel = 4'd0;
    reg [11:0] model_base = 12'h000;

    localparam integer UART_BIT_NS = 200; // 5 Mbaud, shortened for simulation.

    always #10 clk = ~clk; // 50 MHz

    ads7953_top #(
        .CLK_HZ(50_000_000),
        .UART_BAUD(5_000_000)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .uart_rxd(uart_rxd), .uart_txd(uart_txd),
        .trig_internal(trig_internal), .uart_packet_busy(uart_packet_busy),
        .adc_cs_n(cs_n), .adc_sclk(sclk), .adc_sdi(sdi), .adc_sdo(sdo),
        .ready(ready), .busy(busy), .sample_valid(sample_valid),
        .sample_channel(sample_channel), .sample_code(sample_code),
        .sample_mv(sample_mv), .scan_done(scan_done),
        .debug_state(), .debug_tx_word(), .debug_rx_shift(),
        .debug_expected_channel()
    );

    assign adc_codes = dut.adc_codes;

    function [15:0] channel_word;
        input [3:0] channel;
        begin
            channel_word = {channel, (model_base + channel)};
        end
    endfunction

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
                $display("ERROR: UART stop bit is low");
                errors = errors + 1;
            end
            #(UART_BIT_NS/2);
        end
    endtask

    task receive_and_check_packet;
        input [11:0] expected_base;
        input integer scan_number;
        reg [7:0] value;
        reg [7:0] low_byte;
        reg [7:0] high_byte;
        reg [7:0] expected_checksum;
        reg [11:0] received_code;
        integer packet_ch;
        begin
            uart_receive_byte(value);
            if (value !== 8'hA5) begin
                $display("ERROR scan %0d: first header byte = %02h", scan_number, value);
                errors = errors + 1;
            end
            uart_receive_byte(value);
            if (value !== 8'h5A) begin
                $display("ERROR scan %0d: second header byte = %02h", scan_number, value);
                errors = errors + 1;
            end
            uart_receive_byte(value);
            if (value !== 8'd32) begin
                $display("ERROR scan %0d: payload length = %0d", scan_number, value);
                errors = errors + 1;
            end
            expected_checksum = value;

            for (packet_ch = 0; packet_ch < 16; packet_ch = packet_ch + 1) begin
                uart_receive_byte(low_byte);
                uart_receive_byte(high_byte);
                expected_checksum = expected_checksum ^ low_byte ^ high_byte;
                received_code = {high_byte[3:0], low_byte};
                if (received_code !== (expected_base + packet_ch)) begin
                    $display("ERROR UART scan %0d CH%0d: expected %03h, got %03h",
                             scan_number, packet_ch, expected_base + packet_ch,
                             received_code);
                    errors = errors + 1;
                end
            end

            uart_receive_byte(value);
            if (value !== expected_checksum) begin
                $display("ERROR scan %0d: checksum expected %02h, got %02h",
                         scan_number, expected_checksum, value);
                errors = errors + 1;
            end
        end
    endtask

    task trigger_and_check;
        input [11:0] expected_base;
        input integer scan_number;
        integer first_sample_event;
        integer check_ch;
        begin
            wait (ready && !uart_packet_busy);
            first_sample_event = sample_events;
            uart_send_byte(8'h54);
            wait (busy);
            wait (scan_done);
            #1;

            if ((sample_events - first_sample_event) != 16) begin
                $display("ERROR scan %0d: expected 16 valid samples, got %0d",
                         scan_number, sample_events - first_sample_event);
                errors = errors + 1;
            end

            for (check_ch = 0; check_ch < 16; check_ch = check_ch + 1) begin
                if (adc_codes[check_ch*12 +: 12] !== (expected_base + check_ch)) begin
                    $display("ERROR scan %0d CH%0d: expected %03h, got %03h",
                             scan_number, check_ch, expected_base + check_ch,
                             adc_codes[check_ch*12 +: 12]);
                    errors = errors + 1;
                end
            end

            $display("Scan %0d complete: CH0=%03h, CH15=%03h, samples=%0d",
                     scan_number, adc_codes[11:0], adc_codes[191:180],
                     sample_events - first_sample_event);

            // scan_done must be a one-clk pulse.
            @(posedge clk);
            #1;
            if (scan_done) begin
                $display("ERROR scan %0d: scan_done wider than one clk", scan_number);
                errors = errors + 1;
            end

            receive_and_check_packet(expected_base, scan_number);
        end
    endtask

    always @(posedge clk) begin
        if (!rst_n)
            sample_events = 0;
        else if (sample_valid) begin
            sample_events = sample_events + 1;
            expected_mv = (sample_code * 5000 + 2048) / 4096;
            if (sample_mv !== expected_mv) begin
                $display("ERROR CH%0d: code %03h expected %0d mV, got %0d mV",
                         sample_channel, sample_code, expected_mv, sample_mv);
                errors = errors + 1;
            end
        end
    end

    // Minimal ADS7953 serial/Auto-2 behavioral model.
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
            // Return a different data set for each trigger so stale cache data
            // cannot accidentally pass the repeated-scan test.
            model_base = model_base + 12'h100;
        end else if (mosi_shift[15:12] == 4'b0011) begin
            if (mosi_shift !== 16'h3C40) begin
                $display("ERROR: expected Range-2 Auto-2 command 3C40, got %04h",
                         mosi_shift);
                errors = errors + 1;
            end
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

    initial begin
        #100;
        rst_n = 1'b1;

        if (dut.u_ads7953_reader.code_to_mv(12'h000) !== 16'd0 ||
            dut.u_ads7953_reader.code_to_mv(12'h800) !== 16'd2500 ||
            dut.u_ads7953_reader.code_to_mv(12'hFFF) !== 16'd4999) begin
            $display("ERROR: 0-5 V conversion boundary check failed");
            errors = errors + 1;
        end

        trigger_and_check(12'h100, 1);
        trigger_and_check(12'h200, 2);
        trigger_and_check(12'h300, 3);

        if (errors == 0)
            $display("PASS: 3 UART-triggered scans and data packets passed.");
        else
            $display("FAIL: %0d repeated-scan errors.", errors);
        $finish;
    end

    initial begin
        #1000000;
        $display("FAIL: timeout");
        $finish;
    end
endmodule
