`timescale 1ns/1ps

module ads7953_20board_controller #(
    parameter integer CLK_HZ       = 50_000_000,
    parameter integer SCLK_HZ      = 1_000_000,
    parameter integer BOARD_GAP_NS = 100
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          start,
    input  wire [4:0]    board_count,

    output wire [19:0]   adc_cs_n,
    output wire          adc_sclk,
    output wire          adc_sdi,
    input  wire          adc_sdo,

    output wire          ready,
    output reg           busy,
    output reg           all_done,
    output reg  [3839:0] board_codes,

    output wire          sample_valid,
    output wire [4:0]    sample_board,
    output wire [3:0]    sample_channel,
    output wire [11:0]   sample_code
);
    localparam integer NS_PER_GAP_TICK = 1_000_000_000 / BOARD_GAP_NS;
    localparam integer BOARD_GAP_CLKS_RAW =
        (CLK_HZ + NS_PER_GAP_TICK - 1) / NS_PER_GAP_TICK;
    localparam integer BOARD_GAP_CLKS =
        (BOARD_GAP_CLKS_RAW < 1) ? 1 : BOARD_GAP_CLKS_RAW;

    localparam [2:0] ST_WAIT_POWERUP = 3'd0;
    localparam [2:0] ST_IDLE         = 3'd1;
    localparam [2:0] ST_WAIT_BOARD   = 3'd2;
    localparam [2:0] ST_BOARD_GAP    = 3'd3;
    localparam [2:0] ST_FINISH       = 3'd4;

    reg [2:0]  state;
    reg [4:0]  selected_board;
    reg [4:0]  last_board;
    reg        reader_trig;
    reg [31:0] gap_count;

    wire         reader_cs_n;
    wire         reader_sclk;
    wire         reader_sdi;
    wire         reader_ready;
    wire         reader_scan_done;
    wire [191:0] reader_codes;

    assign adc_sclk = reader_sclk;
    assign adc_sdi  = reader_sdi;

    // One-hot-or-zero active-low decode. When reader_cs_n is high, all
    // boards are deselected. Otherwise exactly selected_board is low.
    assign adc_cs_n = reader_cs_n ? 20'hFFFFF :
                      ~(20'h00001 << selected_board);

    assign ready        = (state == ST_IDLE) && reader_ready && !busy;
    assign sample_board = selected_board;

    ads7953_16ch_reader #(
        .CLK_HZ(CLK_HZ),
        .SCLK_HZ(SCLK_HZ)
    ) u_reader (
        .clk(clk),
        .rst_n(rst_n),
        .trig(reader_trig),
        .adc_cs_n(reader_cs_n),
        .adc_sclk(reader_sclk),
        .adc_sdi(reader_sdi),
        .adc_sdo(adc_sdo),
        .ready(reader_ready),
        .busy(),
        .sample_valid(sample_valid),
        .sample_channel(sample_channel),
        .sample_code(sample_code),
        .sample_mv(),
        .scan_done(reader_scan_done),
        .adc_codes(reader_codes),
        .debug_state(),
        .debug_tx_word(),
        .debug_rx_shift(),
        .debug_expected_channel()
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_WAIT_POWERUP;
            selected_board <= 5'd0;
            last_board     <= 5'd19;
            reader_trig    <= 1'b0;
            gap_count      <= 32'd0;
            busy           <= 1'b0;
            all_done       <= 1'b0;
            board_codes    <= 3840'd0;
        end else begin
            reader_trig <= 1'b0;
            all_done    <= 1'b0;

            case (state)
                ST_WAIT_POWERUP: begin
                    if (reader_ready)
                        state <= ST_IDLE;
                end

                ST_IDLE: begin
                    if (start) begin
                        board_codes    <= 3840'd0;
                        selected_board <= 5'd0;
                        last_board     <= ((board_count >= 1) && (board_count <= 20)) ?
                                          board_count - 1'b1 : 5'd19;
                        reader_trig    <= 1'b1;
                        busy           <= 1'b1;
                        state          <= ST_WAIT_BOARD;
                    end
                end

                ST_WAIT_BOARD: begin
                    if (reader_scan_done) begin
                        board_codes[selected_board*192 +: 192] <= reader_codes;
                        if (selected_board == last_board) begin
                            state <= ST_FINISH;
                        end else begin
                            selected_board <= selected_board + 1'b1;
                            gap_count      <= BOARD_GAP_CLKS - 1;
                            state          <= ST_BOARD_GAP;
                        end
                    end
                end

                ST_BOARD_GAP: begin
                    if (gap_count == 0) begin
                        reader_trig <= 1'b1;
                        state       <= ST_WAIT_BOARD;
                    end else begin
                        gap_count <= gap_count - 1'b1;
                    end
                end

                ST_FINISH: begin
                    // The final board slice was registered on the prior clock.
                    all_done <= 1'b1;
                    busy     <= 1'b0;
                    state    <= ST_IDLE;
                end

                default: state <= ST_WAIT_POWERUP;
            endcase
        end
    end
endmodule
