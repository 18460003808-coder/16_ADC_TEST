`timescale 1ns/1ps

module slide #(
    parameter integer SYS_CLK  = 50_000_000,
    parameter integer PWM_FREQ = 2_000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        trig,
    input  wire        move_dir,
    input  wire [15:0] pulse_num,
    output reg         pwm_out,
    output reg         dir,
    output reg         busy,
    output reg         done
);
    localparam integer PWM_PERIOD_CNT = SYS_CLK / PWM_FREQ;
    localparam integer PWM_HALF_CNT   = PWM_PERIOD_CNT / 2;
    localparam integer CYCLE_WIDTH    = $clog2(PWM_PERIOD_CNT);

    reg [15:0] pulse_target;
    reg [15:0] pulse_count;
    reg [CYCLE_WIDTH-1:0] cycle_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pulse_target <= 16'd0;
            pulse_count  <= 16'd0;
            cycle_count  <= {CYCLE_WIDTH{1'b0}};
            pwm_out      <= 1'b0;
            dir          <= 1'b0;
            busy         <= 1'b0;
            done         <= 1'b0;
        end else begin
            done <= 1'b0;

            if (trig && !busy) begin
                pulse_target <= pulse_num;
                pulse_count  <= 16'd0;
                cycle_count  <= {CYCLE_WIDTH{1'b0}};
                pwm_out      <= 1'b0;
                dir          <= move_dir;
                busy         <= 1'b1;
            end else if (busy) begin
                if (pulse_count < pulse_target) begin
                    pwm_out <= (cycle_count < PWM_HALF_CNT);
                    if (cycle_count == PWM_PERIOD_CNT - 1) begin
                        cycle_count <= {CYCLE_WIDTH{1'b0}};
                        pulse_count <= pulse_count + 1'b1;
                    end else begin
                        cycle_count <= cycle_count + 1'b1;
                    end
                end else begin
                    pwm_out <= 1'b0;
                    busy    <= 1'b0;
                    done    <= 1'b1;
                end
            end else begin
                pwm_out <= 1'b0;
            end
        end
    end
endmodule
