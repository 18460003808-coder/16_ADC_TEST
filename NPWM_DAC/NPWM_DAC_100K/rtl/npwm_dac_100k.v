// Low-resource 100 kHz PWM driven by a 50 MHz system clock.
// Each 1% PWM slot contains exactly five system clocks.
module npwm_dac_100k (
    input  wire       sysclk,
    input  wire       rst_n,
    input  wire       trig,
    input  wire       rst_pwm_n,
    output wire       pwm_out,
    output reg  [6:0] pwm_duty
);

    reg [2:0] slot_clock;
    reg [6:0] pwm_slot;

    reg       trig_meta;
    reg       trig_sync;
    reg       trig_sync_d;
    reg [1:0] trig_valid;
    reg       trig_armed;

    wire trig_rise;
    assign trig_rise = trig_armed & trig_sync & ~trig_sync_d;

    // 5 clocks/slot * 100 slots = 500 clocks = 10 us = 100 kHz.
    always @(posedge sysclk or negedge rst_n) begin
        if (!rst_n) begin
            slot_clock <= 3'd0;
            pwm_slot   <= 7'd0;
        end else if (slot_clock == 3'd4) begin
            slot_clock <= 3'd0;
            if (pwm_slot == 7'd99)
                pwm_slot <= 7'd0;
            else
                pwm_slot <= pwm_slot + 1'b1;
        end else begin
            slot_clock <= slot_clock + 1'b1;
        end
    end

    // Synchronize trig and reject a high level left over from either reset.
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

    assign pwm_out = (pwm_slot < pwm_duty);

endmodule

