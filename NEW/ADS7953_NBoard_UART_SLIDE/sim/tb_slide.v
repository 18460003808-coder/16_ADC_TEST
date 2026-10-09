`timescale 1ns/1ps

module tb_slide;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg trig = 1'b0;
    reg move_dir = 1'b0;
    reg [15:0] pulse_num = 16'd0;
    wire pwm_out;
    wire dir;
    wire busy;
    wire done;

    integer rising_edges = 0;
    integer errors = 0;

    always #5 clk = ~clk;
    always @(posedge pwm_out)
        rising_edges = rising_edges + 1;

    slide #(
        .SYS_CLK(100),
        .PWM_FREQ(10)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .trig(trig),
        .move_dir(move_dir),
        .pulse_num(pulse_num),
        .pwm_out(pwm_out),
        .dir(dir),
        .busy(busy),
        .done(done)
    );

    task trigger_move;
        input direction;
        input [15:0] pulses;
        begin
            @(negedge clk);
            move_dir = direction;
            pulse_num = pulses;
            trig = 1'b1;
            @(negedge clk);
            trig = 1'b0;
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        trigger_move(1'b1, 16'd3);
        repeat (4) @(negedge clk);
        move_dir = 1'b0;
        pulse_num = 16'd9;
        trig = 1'b1;
        @(negedge clk);
        trig = 1'b0;

        wait (done);
        if (rising_edges != 3) begin
            $display("ERROR: expected 3 PWM pulses, got %0d", rising_edges);
            errors = errors + 1;
        end
        if (dir !== 1'b1) begin
            $display("ERROR: direction changed during a busy move");
            errors = errors + 1;
        end
        if (busy !== 1'b0 || pwm_out !== 1'b0) begin
            $display("ERROR: outputs did not return idle after completion");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: slide direction, pulse count and busy interlock");
        else
            $display("FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
