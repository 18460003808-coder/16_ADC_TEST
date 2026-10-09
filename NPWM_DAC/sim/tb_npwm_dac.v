`timescale 1ns/1ps

module tb_npwm_dac;

    // 每次改变占空比后，至少保留 10 个完整 PWM 周期再发下一次 trig。
    localparam integer PWM_PERIODS_PER_DUTY = 10;

    reg        sysclk;
    reg        rst_n;
    reg        trig;
    reg        rst_pwm_n;
    wire       pwm_out;
    wire [6:0] pwm_duty;

    integer duty_level;
    integer extra_trigger;

    npwm_dac dut (
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
        input [6:0] expected_high_clocks;
        integer period_index;
        integer clock_index;
        integer high_count;
        begin
            // 先对齐到下一个完整 PWM 周期，再连续检查多个周期。
            while (dut.pwm_counter != 7'd0)
                @(negedge sysclk);

            for (period_index = 0;
                 period_index < PWM_PERIODS_PER_DUTY;
                 period_index = period_index + 1) begin
                high_count = 0;
                for (clock_index = 0; clock_index < 100;
                     clock_index = clock_index + 1) begin
                    #1;
                    if (pwm_out)
                        high_count = high_count + 1;
                    @(negedge sysclk);
                end

                if (high_count != expected_high_clocks) begin
                    $display("ERROR: duty %0d%% period %0d: expected %0d high clocks, got %0d",
                             expected_high_clocks, period_index + 1,
                             expected_high_clocks, high_count);
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
        rst_n = 1'b1;
        repeat (2) @(posedge sysclk);
        expect_duty(7'd0);

        // trig 在占空比复位期间及释放后保持为高，不得产生一次误加。
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

        // trig 必须先回到低电平；随后新的上升沿才允许递增。
        @(negedge sysclk);
        trig = 1'b0;
        repeat (4) @(posedge sysclk);
        send_trig;
        expect_duty(7'd1);

        // 恢复到 0，开始完整占空比扫描。
        @(negedge sysclk);
        rst_pwm_n = 1'b0;
        #1;
        expect_duty(7'd0);
        @(negedge sysclk);
        rst_pwm_n = 1'b1;
        repeat (4) @(posedge sysclk);
        check_pwm_periods(7'd0);

        // 依次遍历 1%~100%，每一级保持并检查 10 个完整 PWM 周期。
        for (duty_level = 1; duty_level <= 100;
             duty_level = duty_level + 1) begin
            send_trig;
            expect_duty(duty_level[6:0]);
            check_pwm_periods(duty_level[6:0]);
        end

        // 额外触发后仍应饱和在 100%。
        for (extra_trigger = 0; extra_trigger < 5;
             extra_trigger = extra_trigger + 1)
            send_trig;
        expect_duty(7'd100);

        // 独立占空比复位应回到 0。
        rst_pwm_n = 1'b0;
        #1;
        expect_duty(7'd0);
        rst_pwm_n = 1'b1;
        repeat (2) @(posedge sysclk);

        $display("PASS: duty 0%% through 100%%, %0d PWM periods per level",
                 PWM_PERIODS_PER_DUTY);
        $finish;
    end

endmodule
