`timescale 1ns/1ps

module ads7953_16ch_reader #(
    parameter integer CLK_HZ  = 50_000_000,
    parameter integer SCLK_HZ = 10_000_000,
    parameter integer MAX_FRAME_COUNT = 32
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         trig,

    output reg          adc_cs_n,
    output reg          adc_sclk,
    output reg          adc_sdi,
    input  wire         adc_sdo,

    output reg          ready,
    output reg          busy,
    output reg          sample_valid,
    output reg  [3:0]   sample_channel,
    output reg  [11:0]  sample_code,
    output reg  [15:0]  sample_mv,
    output reg          scan_done,
    output reg  [191:0] adc_codes,

    output wire [2:0]   debug_state,
    output wire [15:0]  debug_tx_word,
    output wire [15:0]  debug_rx_shift,
    output wire [3:0]   debug_expected_channel
);

    // CLK_HZ must be an integer multiple of SCLK_HZ. Odd period divisors
    // use asymmetric high/low phases; at 50 MHz / 10 MHz this is 2/3 clocks
    // (40 ns high, 60 ns low), both above the ADS7953 20-ns minimum.
    localparam integer SCLK_PERIOD_CLKS = CLK_HZ / SCLK_HZ;
    localparam integer SCLK_HIGH_CLKS   = SCLK_PERIOD_CLKS / 2;
    localparam integer SCLK_LOW_CLKS    = SCLK_PERIOD_CLKS - SCLK_HIGH_CLKS;
    localparam integer CS_HIGH_CLKS = (CLK_HZ + 9_999_999) / 10_000_000;
    localparam integer POWERUP_CLKS = (CLK_HZ + 499_999) / 500_000;

    localparam [2:0] ST_POWERUP = 3'd0;
    localparam [2:0] ST_IDLE    = 3'd1;
    localparam [2:0] ST_START   = 3'd2;
    localparam [2:0] ST_SHIFT   = 3'd3;
    localparam [2:0] ST_GAP     = 3'd4;

    // Auto-2 program register: last channel = 15.
    localparam [15:0] CMD_AUTO2_PROGRAM = 16'h93C0;
    // Auto-2 mode, update enabled, restart from CH0, range = 0..2*VREF.
    localparam [15:0] CMD_AUTO2_ENTER   = 16'h3C40;
    // DI15..12 = 0000 keeps the previously selected mode and settings.
    localparam [15:0] CMD_CONTINUE      = 16'h0000;

    reg [2:0]  state;
    reg [15:0] tx_word;
    reg [15:0] rx_shift;
    reg [4:0]  bit_index;
    reg [31:0] divider_count;
    reg [31:0] gap_count;
    reg [31:0] powerup_count;
    reg [1:0]  discard_count;
    reg [15:0] frame_count;
    reg [3:0]  expected_channel;
    reg        collecting;
    reg        stop_after_gap;

    reg trig_meta;
    reg trig_sync;
    reg trig_sync_d;
    wire trig_rise = trig_sync & ~trig_sync_d;

    function [15:0] code_to_mv;
        input [11:0] code;
        reg [24:0] scaled;
        begin
            // Rounded conversion for VREF = 2.500 V and Range 2.
            scaled = code * 16'd5000 + 25'd2048;
            code_to_mv = scaled[24:12];
        end
    endfunction

    assign debug_state            = state;
    assign debug_tx_word          = tx_word;
    assign debug_rx_shift         = rx_shift;
    assign debug_expected_channel = expected_channel;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trig_meta       <= 1'b0;
            trig_sync       <= 1'b0;
            trig_sync_d     <= 1'b0;
        end else begin
            trig_meta       <= trig;
            trig_sync       <= trig_meta;
            trig_sync_d     <= trig_sync;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= ST_POWERUP;
            adc_cs_n         <= 1'b1;
            adc_sclk         <= 1'b0;
            adc_sdi          <= 1'b0;
            ready            <= 1'b0;
            busy             <= 1'b0;
            sample_valid     <= 1'b0;
            sample_channel   <= 4'd0;
            sample_code      <= 12'd0;
            sample_mv        <= 16'd0;
            scan_done        <= 1'b0;
            adc_codes        <= 192'd0;
            tx_word          <= 16'd0;
            rx_shift         <= 16'd0;
            bit_index        <= 5'd0;
            divider_count    <= 32'd0;
            gap_count        <= 32'd0;
            powerup_count    <= 32'd0;
            discard_count    <= 2'd0;
            frame_count      <= 16'd0;
            expected_channel <= 4'd0;
            collecting       <= 1'b0;
            stop_after_gap   <= 1'b0;
        end else begin
            sample_valid <= 1'b0;
            scan_done    <= 1'b0;

            case (state)
                ST_POWERUP: begin
                    if (powerup_count == POWERUP_CLKS-1) begin
                        state <= ST_IDLE;
                        ready <= 1'b1;
                    end else begin
                        powerup_count <= powerup_count + 1'b1;
                    end
                end

                ST_IDLE: begin
                    if (trig_rise) begin
                        ready            <= 1'b0;
                        busy             <= 1'b1;
                        adc_codes        <= 192'd0;
                        discard_count    <= 2'd0;
                        frame_count      <= 16'd0;
                        expected_channel <= 4'd0;
                        collecting       <= 1'b0;
                        stop_after_gap   <= 1'b0;
                        tx_word          <= CMD_AUTO2_PROGRAM;
                        state            <= ST_START;
                    end
                end

                ST_START: begin
                    adc_cs_n      <= 1'b0;
                    adc_sclk      <= 1'b0;
                    adc_sdi       <= tx_word[15];
                    rx_shift      <= 16'd0;
                    bit_index     <= 5'd15;
                    divider_count <= SCLK_LOW_CLKS-1;
                    state         <= ST_SHIFT;
                end

                ST_SHIFT: begin
                    if (divider_count != 0) begin
                        divider_count <= divider_count - 1'b1;
                    end else begin
                        if (!adc_sclk) begin
                            // ADS7953 updates SDO on falling edges; sample on rising edges.
                            divider_count <= SCLK_HIGH_CLKS-1;
                            adc_sclk <= 1'b1;
                            rx_shift <= {rx_shift[14:0], adc_sdo};
                        end else begin
                            divider_count <= SCLK_LOW_CLKS-1;
                            adc_sclk <= 1'b0;
                            if (bit_index == 0) begin
                                adc_cs_n <= 1'b1;
                                adc_sdi  <= 1'b0;
                                gap_count <= CS_HIGH_CLKS-1;
                                state <= ST_GAP;

                                if (discard_count == 0) begin
                                    tx_word       <= CMD_AUTO2_ENTER;
                                    discard_count <= 1;
                                end else if (discard_count < 3) begin
                                    tx_word       <= CMD_CONTINUE;
                                    discard_count <= discard_count + 1'b1;
                                end else begin
                                    tx_word <= CMD_CONTINUE;
                                    if (!collecting) begin
                                        if (rx_shift[15:12] == 4'd0) begin
                                            adc_codes[11:0] <= rx_shift[11:0];
                                            sample_channel <= 4'd0;
                                            sample_code    <= rx_shift[11:0];
                                            sample_mv      <= code_to_mv(rx_shift[11:0]);
                                            sample_valid   <= 1'b1;
                                            expected_channel <= 4'd1;
                                            collecting <= 1'b1;
                                        end
                                    end else if (rx_shift[15:12] == expected_channel) begin
                                        adc_codes[expected_channel*12 +: 12] <= rx_shift[11:0];
                                        sample_channel <= expected_channel;
                                        sample_code    <= rx_shift[11:0];
                                        sample_mv      <= code_to_mv(rx_shift[11:0]);
                                        sample_valid   <= 1'b1;
                                        if (expected_channel == 4'd15) begin
                                            stop_after_gap <= 1'b1;
                                        end else begin
                                            expected_channel <= expected_channel + 1'b1;
                                        end
                                    end else if (rx_shift[15:12] == 4'd0) begin
                                        // Re-synchronize only at the beginning of a fresh sweep.
                                        adc_codes <= 192'd0;
                                        adc_codes[11:0] <= rx_shift[11:0];
                                        sample_channel <= 4'd0;
                                        sample_code    <= rx_shift[11:0];
                                        sample_mv      <= code_to_mv(rx_shift[11:0]);
                                        sample_valid   <= 1'b1;
                                        expected_channel <= 4'd1;
                                    end
                                end

                                // A missing ADC leaves SDO floating and may never
                                // produce CH0..CH15. Bound every scan so one trigger
                                // cannot keep SCLK running forever. Normal Auto-2
                                // scans finish well before the default 32 frames.
                                if (frame_count == MAX_FRAME_COUNT-1) begin
                                    stop_after_gap <= 1'b1;
                                    if (!(collecting &&
                                          (rx_shift[15:12] == expected_channel) &&
                                          (expected_channel == 4'd15)))
                                        adc_codes <= 192'd0;
                                end else begin
                                    frame_count <= frame_count + 1'b1;
                                end
                            end else begin
                                bit_index <= bit_index - 1'b1;
                                adc_sdi   <= tx_word[bit_index-1'b1];
                            end
                        end
                    end
                end

                ST_GAP: begin
                    if (gap_count == 0) begin
                        if (stop_after_gap) begin
                            stop_after_gap <= 1'b0;
                            busy      <= 1'b0;
                            ready     <= 1'b1;
                            scan_done <= 1'b1;
                            state     <= ST_IDLE;
                        end else begin
                            state <= ST_START;
                        end
                    end else begin
                        gap_count <= gap_count - 1'b1;
                    end
                end

                default: state <= ST_POWERUP;
            endcase
        end
    end

endmodule
