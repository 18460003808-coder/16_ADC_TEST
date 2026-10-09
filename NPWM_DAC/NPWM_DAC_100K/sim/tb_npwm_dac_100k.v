`timescale 1ns/1ps

module tb_npwm_dac_100k;

    localparam integer PWM_PERIODS_PER_DUTY = 10;

    reg        sysclk;
    reg        rst_n;
    reg        trig;
    reg        rst_pwm_n;
    wire       pwm_out;
    wire [6:0] pwm_duty;

    integer duty_level;
    integer extra_trigger;

    npwm_dac_100k dut (
        .sysclk    (sysclk),
        .rst_n     (rst_n),
        .trig      (trig),
        .rst_pwm_n (rst_pwm_n),
        .pwm_out   (pwm_out),
        .pwm_duty  (pwm_duty)
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

    task expect_duty;
        input [6:0] expected;
        begin
            if (pwm_duty !== expected) begin
                $display("ERROR: expected duty %0d, got %0d at %0t",
                         expected, pwm_duty, $time);
                $stop;
            end
        end
    endtask

    task check_pwm_periods;
        input integer expected_percent;
        integer period_index;
        integer clock_index;
        integer high_count;
        begin
            while ((dut.pwm_slot != 7'd0) || (dut.slot_clock != 3'd0))
                @(negedge sysclk);

            for (period_index = 0;
                 period_index < PWM_PERIODS_PER_DUTY;
                 period_index = period_index + 1) begin
                high_count = 0;
                for (clock_index = 0; clock_index < 500;
                     clock_index = clock_index + 1) begin
                    #1;
                    if (pwm_out)
                        high_count = high_count + 1;
                    @(negedge sysclk);
                end

                if (high_count != expected_percent * 5) begin
                    $display("ERROR: duty %0d%% period %0d: expected %0d high clocks, got %0d",
                             expected_percent, period_index + 1,
                             expected_percent * 5, high_count);
                    $stop;
                end
            end
        end
    endtask

    initial begin
        sysclk    = 1'b0;
        rst_n     = 1'b0;
        trig      = 1'b0;
        rst_pwm_n = 1'b1;

        repeat (3) @(posedge sysclk);
        @(negedge sysclk);
        rst_n = 1'b1;
        repeat (3) @(posedge sysclk);
        expect_duty(7'd0);

        // A trig level held high through reset release must not increment duty.
        @(negedge sysclk);
        trig = 1'b1;
        repeat (3) @(posedge sysclk);
        rst_pwm_n = 1'b0;
        #1;
        expect_duty(7'd0);
        repeat (3) @(posedge sysclk);
        @(negedge sysclk);
        rst_pwm_n = 1'b1;
        repeat (6) @(posedge sysclk);
        expect_duty(7'd0);

        @(negedge sysclk);
        trig = 1'b0;
        repeat (4) @(posedge sysclk);
        send_trig;
        expect_duty(7'd1);

        // Return to zero before scanning every integer duty setting.
        @(negedge sysclk);
        rst_pwm_n = 1'b0;
        #1;
        expect_duty(7'd0);
        @(negedge sysclk);
        rst_pwm_n = 1'b1;
        repeat (4) @(posedge sysclk);
        check_pwm_periods(0);

        for (duty_level = 1; duty_level <= 100;
             duty_level = duty_level + 1) begin
            send_trig;
            expect_duty(duty_level[6:0]);
            check_pwm_periods(duty_level);
        end

        for (extra_trigger = 0; extra_trigger < 5;
             extra_trigger = extra_trigger + 1)
            send_trig;
        expect_duty(7'd100);

        rst_pwm_n = 1'b0;
        #1;
        expect_duty(7'd0);

        $display("PASS: 100 kHz PWM, duty 0%% through 100%%, %0d periods per level",
                 PWM_PERIODS_PER_DUTY);
        $finish;
    end

endmodule

