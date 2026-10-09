`timescale 1ns/1ps

module tb_npwm_dac_adjustable;

    reg         sysclk;
    reg         rst_n;
    reg         trig;
    reg         rst_pwm_n;
    reg  [12:0] period_count;
    wire        pwm_out;
    wire [6:0]  pwm_duty;

    integer i;
    integer high_count;
    time period_start;
    time period_end;

    npwm_dac_adjustable dut (
        .sysclk       (sysclk),
        .rst_n        (rst_n),
        .trig         (trig),
        .rst_pwm_n    (rst_pwm_n),
        .period_count (period_count),
        .pwm_out      (pwm_out),
        .pwm_duty     (pwm_duty)
    );

    always #10 sysclk = ~sysclk;  // 50 MHz

    task send_trig;
        begin
            @(negedge sysclk);
            trig = 1'b1;
            @(negedge sysclk);
            trig = 1'b0;
            repeat (3) @(posedge sysclk);
        end
    endtask

    task wait_exact_period_start;
        begin
            @(negedge sysclk);
            while ((dut.pwm_slot != 7'd0) || (dut.phase_accum != 13'd0))
                @(negedge sysclk);
        end
    endtask

    task check_period;
        input [12:0] requested_period;
        input [12:0] expected_period;
        begin
            period_count = requested_period;
            while (dut.active_period != expected_period)
                @(negedge sysclk);

            wait_exact_period_start;
            period_start = $time;
            wait_exact_period_start;
            period_end = $time;

            if ((period_end - period_start) != expected_period * 20) begin
                $display("ERROR: period_count %0d measured %0d ns, expected %0d ns",
                         expected_period, period_end - period_start,
                         expected_period * 20);
                $stop;
            end
        end
    endtask

    initial begin
        sysclk       = 1'b0;
        rst_n        = 1'b0;
        trig         = 1'b0;
        rst_pwm_n    = 1'b1;
        period_count = 13'd100;

        repeat (3) @(posedge sysclk);
        @(negedge sysclk);
        rst_n = 1'b1;
        repeat (4) @(posedge sysclk);

        // Check both limits, a middle setting, and input clamping.
        check_period(13'd100,  13'd100);   // 500 kHz
        check_period(13'd1000, 13'd1000);  // 50 kHz
        check_period(13'd5000, 13'd5000);  // 10 kHz
        check_period(13'd50,   13'd100);   // clamp to 500 kHz
        check_period(13'd6000, 13'd5000);  // clamp to 10 kHz

        // Return to 50 kHz and verify 50% duty over a complete period.
        period_count = 13'd1000;
        while (dut.active_period != 13'd1000)
            @(negedge sysclk);
        for (i = 0; i < 50; i = i + 1)
            send_trig;
        if (pwm_duty !== 7'd50) begin
            $display("ERROR: expected duty 50, got %0d", pwm_duty);
            $stop;
        end

        wait_exact_period_start;
        high_count = 0;
        for (i = 0; i < 1000; i = i + 1) begin
            #1;
            if (pwm_out)
                high_count = high_count + 1;
            @(negedge sysclk);
        end
        if (high_count != 500) begin
            $display("ERROR: expected 500 high clocks at 50%%, got %0d",
                     high_count);
            $stop;
        end

        // A high trig held through duty reset must not cause a false increment.
        trig = 1'b1;
        rst_pwm_n = 1'b0;
        #1;
        if (pwm_duty !== 7'd0) begin
            $display("ERROR: duty reset failed");
            $stop;
        end
        repeat (3) @(posedge sysclk);
        rst_pwm_n = 1'b1;
        repeat (6) @(posedge sysclk);
        if (pwm_duty !== 7'd0) begin
            $display("ERROR: held-high trig incremented duty after reset");
            $stop;
        end

        $display("PASS: adjustable PWM from 10 kHz through 500 kHz");
        $finish;
    end

endmodule

