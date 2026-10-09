// 50 MHz input clock, 50 kHz PWM output.
// pwm_duty is an integer percentage from 0 through 100.
module npwm_dac_50k (
    input  wire       sysclk,
    input  wire       rst_n,
    input  wire       trig,
    input  wire       rst_pwm_n,
    output wire       pwm_out,
    output reg  [6:0] pwm_duty
);

    // 50 MHz / 50 kHz = 1000 clock cycles per PWM period.
    reg [9:0] pwm_counter;

    reg       trig_meta;
    reg       trig_sync;
    reg       trig_sync_d;
    reg [1:0] trig_valid;
    reg       trig_armed;

    wire        trig_rise;
    wire [10:0] pwm_high_clocks;

    assign trig_rise = trig_armed & trig_sync & ~trig_sync_d;
    assign pwm_high_clocks = pwm_duty * 11'd10;

    // Synchronize trig and ignore any high level left over from reset.
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

            // A low level must be seen after reset before a new edge is valid.
            if (!trig_valid[1])
                trig_armed <= 1'b0;
            else if (!trig_sync)
                trig_armed <= 1'b1;
        end
    end

    always @(posedge sysclk or negedge rst_n) begin
        if (!rst_n)
            pwm_counter <= 10'd0;
        else if (pwm_counter == 10'd999)
            pwm_counter <= 10'd0;
        else
            pwm_counter <= pwm_counter + 1'b1;
    end

    always @(posedge sysclk or negedge rst_n or negedge rst_pwm_n) begin
        if (!rst_n || !rst_pwm_n)
            pwm_duty <= 7'd0;
        else if (trig_rise && pwm_duty < 7'd100)
            pwm_duty <= pwm_duty + 1'b1;
    end

    assign pwm_out = ({1'b0, pwm_counter} < pwm_high_clocks);

endmodule

