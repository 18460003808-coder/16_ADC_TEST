// 50 MHz 输入时钟、500 kHz 输出频率的 PWM 模块。
// pwm_duty 的数值范围为 0~100，单位为百分比。
module npwm_dac (
    input  wire       sysclk,
    input  wire       rst_n,
    input  wire       trig,
    input  wire       rst_pwm_n,
    output wire       pwm_out,
    output reg  [6:0] pwm_duty
);

    // 50 MHz / 500 kHz = 100 个时钟周期。
    reg [6:0] pwm_counter;

    // trig 可能与 sysclk 异步：两级同步后检测上升沿。
    reg trig_meta;
    reg trig_sync;
    reg trig_sync_d;
    reg [1:0] trig_valid;
    reg trig_armed;

    wire trig_rise;
    assign trig_rise = trig_armed & trig_sync & ~trig_sync_d;

    always @(posedge sysclk or negedge rst_n or negedge rst_pwm_n) begin
        if (!rst_n || !rst_pwm_n) begin
            trig_meta   <= 1'b0;
            trig_sync   <= 1'b0;
            trig_sync_d <= 1'b0;
            trig_valid  <= 2'b00;
            trig_armed  <= 1'b0;
        end else begin
            trig_meta   <= trig;
            trig_sync   <= trig_meta;
            trig_sync_d <= trig_sync;
            trig_valid  <= {trig_valid[0], 1'b1};

            // 复位释放后，必须先确认同步后的 trig 为低，才接受新上升沿。
            if (!trig_valid[1])
                trig_armed <= 1'b0;
            else if (!trig_sync)
                trig_armed <= 1'b1;
        end
    end

    always @(posedge sysclk or negedge rst_n) begin
        if (!rst_n)
            pwm_counter <= 7'd0;
        else if (pwm_counter == 7'd99)
            pwm_counter <= 7'd0;
        else
            pwm_counter <= pwm_counter + 1'b1;
    end

    always @(posedge sysclk or negedge rst_n or negedge rst_pwm_n) begin
        if (!rst_n || !rst_pwm_n)
            pwm_duty <= 7'd0;
        else if (trig_rise && pwm_duty < 7'd100)
            pwm_duty <= pwm_duty + 1'b1;
    end

    assign pwm_out = (pwm_counter < pwm_duty);

endmodule
