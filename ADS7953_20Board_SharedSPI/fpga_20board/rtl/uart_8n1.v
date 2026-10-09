`timescale 1ns/1ps

module uart_rx_8n1 #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD   = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg        data_valid,
    output reg [7:0]  data
);
    localparam integer CLKS_PER_BIT = (CLK_HZ + BAUD/2) / BAUD;
    localparam integer HALF_BIT_CLKS = CLKS_PER_BIT / 2;
    localparam [1:0] ST_IDLE = 2'd0, ST_START = 2'd1,
                     ST_DATA = 2'd2, ST_STOP  = 2'd3;

    reg rx_meta, rx_sync;
    reg [1:0] state;
    reg [31:0] count;
    reg [2:0] bit_index;
    reg [7:0] shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            count      <= 32'd0;
            bit_index  <= 3'd0;
            shift      <= 8'd0;
            data       <= 8'd0;
            data_valid <= 1'b0;
        end else begin
            data_valid <= 1'b0;
            case (state)
                ST_IDLE: begin
                    if (!rx_sync) begin
                        count <= HALF_BIT_CLKS-1;
                        state <= ST_START;
                    end
                end
                ST_START: begin
                    if (count != 0)
                        count <= count - 1'b1;
                    else if (!rx_sync) begin
                        count     <= CLKS_PER_BIT-1;
                        bit_index <= 3'd0;
                        state     <= ST_DATA;
                    end else begin
                        state <= ST_IDLE;
                    end
                end
                ST_DATA: begin
                    if (count != 0) begin
                        count <= count - 1'b1;
                    end else begin
                        shift[bit_index] <= rx_sync;
                        count <= CLKS_PER_BIT-1;
                        if (bit_index == 3'd7)
                            state <= ST_STOP;
                        else
                            bit_index <= bit_index + 1'b1;
                    end
                end
                ST_STOP: begin
                    if (count != 0) begin
                        count <= count - 1'b1;
                    end else begin
                        if (rx_sync) begin
                            data       <= shift;
                            data_valid <= 1'b1;
                        end
                        state <= ST_IDLE;
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule

module uart_tx_8n1 #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD   = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] data,
    output reg        tx,
    output reg        busy
);
    localparam integer CLKS_PER_BIT = (CLK_HZ + BAUD/2) / BAUD;

    reg [31:0] count;
    reg [3:0] bit_index;
    reg [9:0] shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx        <= 1'b1;
            busy      <= 1'b0;
            count     <= 32'd0;
            bit_index <= 4'd0;
            shift     <= 10'h3ff;
        end else if (!busy) begin
            tx <= 1'b1;
            if (start) begin
                shift     <= {1'b1, data, 1'b0};
                tx        <= 1'b0;
                busy      <= 1'b1;
                count     <= CLKS_PER_BIT-1;
                bit_index <= 4'd0;
            end
        end else if (count != 0) begin
            count <= count - 1'b1;
        end else if (bit_index == 4'd9) begin
            tx   <= 1'b1;
            busy <= 1'b0;
        end else begin
            shift     <= {1'b1, shift[9:1]};
            tx        <= shift[1];
            count     <= CLKS_PER_BIT-1;
            bit_index <= bit_index + 1'b1;
        end
    end
endmodule
