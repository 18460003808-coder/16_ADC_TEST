`timescale 1ns/1ps

module tb_1board_reader;
    reg clk = 0;
    reg rst_n = 0;
    reg trig = 0;
    reg model_sdo = 0;
    reg model_connected = 1;
    wire sdo = model_connected ? model_sdo : 1'b0;
    wire cs_n, sclk, sdi, ready, sample_valid, scan_done;
    wire [3:0] sample_channel;
    wire [11:0] sample_code;
    wire [191:0] adc_codes;
    integer samples = 0;
    integer errors = 0;
    integer bit_ptr = 15;
    integer last_rise = 0;
    integer last_fall = 0;
    reg [15:0] command = 0;
    reg [15:0] response = 0;
    reg auto_mode = 0;
    reg warmup = 0;
    reg [3:0] channel = 0;

    always #10 clk = ~clk;

    ads7953_16ch_reader #(.CLK_HZ(50_000_000), .SCLK_HZ(10_000_000)) dut (
        .clk(clk), .rst_n(rst_n), .trig(trig),
        .adc_cs_n(cs_n), .adc_sclk(sclk), .adc_sdi(sdi), .adc_sdo(sdo),
        .ready(ready), .busy(), .sample_valid(sample_valid),
        .sample_channel(sample_channel), .sample_code(sample_code),
        .sample_mv(), .scan_done(scan_done), .adc_codes(adc_codes),
        .debug_state(), .debug_tx_word(), .debug_rx_shift(),
        .debug_expected_channel()
    );

    always @(negedge cs_n) begin
        bit_ptr = 15;
        command = 0;
        model_sdo = response[15];
    end
    always @(posedge sclk) if (!cs_n) begin
        command = {command[14:0], sdi};
        if (last_fall && ($time-last_fall != 60)) errors = errors + 1;
        last_rise = $time;
    end
    always @(negedge sclk) if (!cs_n) begin
        if (last_rise && ($time-last_rise != 40)) errors = errors + 1;
        last_fall = $time;
        if (bit_ptr > 0) begin
            bit_ptr = bit_ptr-1;
            model_sdo = response[bit_ptr];
        end
    end
    always @(posedge cs_n) begin
        last_rise = 0;
        last_fall = 0;
        if (command[15:12] == 4'h9) response = 16'h0000;
        else if (command[15:12] == 4'h3) begin
            auto_mode = 1; warmup = 1; response = 16'h9AAA;
        end else if (auto_mode && warmup) begin
            warmup = 0; channel = 1; response = {4'd0,12'h100};
        end else if (auto_mode) begin
            response = {channel, 12'h100 + channel};
            channel = channel + 1'b1;
        end
    end
    always @(posedge clk) if (sample_valid) samples = samples + 1;

    initial begin
        #100 rst_n = 1;
        wait (ready); @(posedge clk); trig = 1; @(posedge clk); trig = 0;
        wait (scan_done); #1;
        if (samples != 16) errors = errors + 1;
        if (adc_codes[11:0] != 12'h100 || adc_codes[191:180] != 12'h10F)
            errors = errors + 1;

        // Disconnect the ADC model. One trigger must still terminate after
        // MAX_FRAME_COUNT frames, return to idle and clear the invalid data.
        model_connected = 0;
        samples = 0;
        @(posedge clk); trig = 1; @(posedge clk); trig = 0;
        wait (scan_done); #100;
        if (!ready || !cs_n || sclk || adc_codes != 192'd0)
            errors = errors + 1;

        if (errors == 0)
            $display("PASS: valid scan and missing-board bounded stop passed.");
        else $display("FAIL: %0d errors", errors);
        $finish;
    end
    initial begin #200000; $display("FAIL: timeout"); $finish; end
endmodule
