// SamplePolyCBD_eta: Creates the error and secret polynomials
module sample_poly_CBD #(
    parameter ETA = 2
)(
    input clk,
    input reset,
    input start,
    input [255:0] seed,
    input [7:0] nonce,
    output reg [11:0] coeff_out,
    output reg coeff_valid,
    output reg done
    );

    localparam [11:0] q = 12'd3329;
    localparam integer NEED_BITS = 2 * ETA;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] ABSORB_SEED = 3'd1;
    localparam [2:0] WAIT_XO = 3'd2;
    localparam [2:0] REQ_BYTE = 3'd3;
    localparam [2:0] GOT_BYTE = 3'd4;
    localparam [2:0] EMIT = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state;
    reg [5:0] seed_idx;
    reg [8:0] ncoeffs;
    reg [15:0] bit_buf;
    reg [4:0] bit_count;
    reg shake_start;
    reg [7:0] shake_din;
    reg shake_din_valid;
    reg shake_din_last;
    reg shake_squeeze;
    reg [3:0] x_sum;
    reg [3:0] y_sum;
    reg [11:0] diff;

    wire shake_ready;
    wire [7:0] shake_dout;
    wire shake_dout_valid;
    wire shake_absorb_done;

    integer k;

    shake256 prf (
        .clk(clk),
        .reset(reset),
        .start(shake_start),
        .din(shake_din),
        .din_valid(shake_din_valid),
        .din_last(shake_din_last),
        .ready(shake_ready),
        .squeeze(shake_squeeze),
        .dout(shake_dout),
        .dout_valid(shake_dout_valid),
        .absorb_done(shake_absorb_done)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            seed_idx <= 6'd0;
            ncoeffs <= 9'd0;
            bit_buf <= 16'd0;
            bit_count <= 5'd0;
            coeff_out <= 12'd0;
            coeff_valid <= 1'b0;
            done <= 1'b0;
            shake_start <= 1'b0;
            shake_din <= 8'd0;
            shake_din_valid <= 1'b0;
            shake_din_last <= 1'b0;
            shake_squeeze <= 1'b0;
            x_sum <= 4'd0;
            y_sum <= 4'd0;
            diff <= 12'd0;
        end
        else begin
            shake_start <= 1'b0;
            shake_din_valid <= 1'b0;
            shake_din_last <= 1'b0;
            shake_squeeze <= 1'b0;
            coeff_valid <= 1'b0;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        seed_idx <= 6'd0;
                        ncoeffs <= 9'd0;
                        bit_buf <= 16'd0;
                        bit_count <= 5'd0;
                        shake_start <= 1'b1;
                        state <= ABSORB_SEED;
                    end
                end

                ABSORB_SEED: begin
                    if (shake_ready) begin
                        shake_din_valid <= 1'b1;

                        if (seed_idx < 6'd32) begin
                            shake_din <= seed[8*seed_idx +: 8];
                            shake_din_last <= 1'b0;
                            seed_idx <= seed_idx + 6'd1;
                        end
                        else begin
                            shake_din <= nonce;
                            shake_din_last <= 1'b1;
                            state <= WAIT_XOF;
                        end
                    end
                end

                WAIT_XOF: begin
                    if (shake_absorb_done)
                        state <= REQ_BYTE;
                end

                REQ_BYTE: begin
                    if (bit_count >= NEED_BITS[4:0])
                        state <= EMIT;
                    else if (shake_absorb_done) begin
                        shake_squeeze <= 1'b1;
                        state <= GOT_BYTE;
                    end
                end

                GOT_BYTE: begin
                    if (shake_dout_valid) begin
                        bit_buf <= bit_buf | ({8'd0, shake_dout} << bit_count);
                        bit_count <= bit_count + 5'd8;
                        state <= REQ_BYTE;
                    end
                end

                EMIT: begin
                    x_sum = 4'd0;
                    y_sum = 4'd0;

                    for (k = 0; k < ETA; k = k + 1) begin
                        x_sum = x_sum + bit_buf[k];
                        y_sum = y_sum + bit_buf[ETA + k];
                    end

                    if (x_sum >= y_sum)
                        diff = {8'd0, x_sum} - {8'd0, y_sum};
                    else
                        diff = q - ({8'd0, y_sum} - {8'd0, x_sum});

                    coeff_out <= diff;
                    coeff_valid <= 1'b1;
                    bit_buf <= bit_buf >> NEED_BITS;
                    bit_count <= bit_count - NEED_BITS[4:0];
                    ncoeffs <= ncoeffs + 9'd1;

                    if (ncoeffs == 9'd255)
                        state <= FINISH;
                    else
                        state <= REQ_BYTE;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
