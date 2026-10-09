// Low-resource adjustable-frequency PWM.
// Frequency = 50 MHz / period_count, with period_count limited to 100..5000.
module npwm_dac_adjustable (
    input  wire        sysclk,
    input  wire        rst_n,
    input  wire        trig,
    input  wire        rst_pwm_n,
    input  wire [12:0] period_count,
    output wire        pwm_out,
    output reg  [6:0]  pwm_duty
);

    // The PWM period is divided into 100 fractional slots. This avoids a
    // runtime multiplier/divider while retaining integer-percent duty control.
    reg [12:0] active_period;
    reg [12:0] phase_accum;
    reg [6:0]  pwm_slot;
    reg        period_initialized;

    reg        trig_meta;
    reg        trig_sync;
    reg        trig_sync_d;
    reg [1:0]  trig_valid;
    reg        trig_armed;

    wire [12:0] limited_period;
    wire [13:0] phase_sum;
    wire        trig_rise;

    assign limited_period = (period_count < 13'd100)  ? 13'd100  :
                            (period_count > 13'd5000) ? 13'd5000 :
                                                       period_count;
    assign phase_sum = {1'b0, phase_accum} + 14'd100;
    assign trig_rise = trig_armed & trig_sync & ~trig_sync_d;
    assign pwm_out = (pwm_slot < pwm_duty);

    // Latch a new period only at a complete PWM period boundary. Adding 100
    // each clock advances exactly 100 slots in active_period clock cycles.
    always @(posedge sysclk or negedge rst_n) begin
        if (!rst_n) begin
            active_period     <= 13'd100;
            phase_accum       <= 13'd0;
            pwm_slot          <= 7'd0;
            period_initialized <= 1'b0;
        end else if (!period_initialized) begin
            active_period     <= limited_period;
            phase_accum       <= 13'd0;
            pwm_slot          <= 7'd0;
            period_initialized <= 1'b1;
        end else if (phase_sum >= {1'b0, active_period}) begin
            phase_accum <= phase_sum[12:0] - active_period;
            if (pwm_slot == 7'd99) begin
                pwm_slot      <= 7'd0;
                active_period <= limited_period;
            end else begin
                pwm_slot <= pwm_slot + 1'b1;
            end
        end else begin
            phase_accum <= phase_sum[12:0];
        end
    end

    // Synchronize trig. After either reset, trig must first be observed low;
    // a high level held through reset release cannot increment the duty.
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

            if (!trig_valid[1])
                trig_armed <= 1'b0;
            else if (!trig_sync)
                trig_armed <= 1'b1;
        end
    end

    always @(posedge sysclk or negedge rst_n or negedge rst_pwm_n) begin
        if (!rst_n || !rst_pwm_n)
            pwm_duty <= 7'd0;
        else if (trig_rise && pwm_duty < 7'd100)
            pwm_duty <= pwm_duty + 1'b1;
    end

endmodule
