// SampleNTT: creates the 256 coefficients required for the public matrix A
module sample_ntt(
    input clk,
    input reset,
    input start,
    input [255:0] rho,
    input [7:0] i,
    input [7:0] j,
    output reg [11:0] coeff_out,
    output reg coeff_valid,
    output reg done
    );

    localparam [11:0] q = 12'd3329;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] ABSORB_SEED = 3'd1;
    localparam [2:0] WAIT_XOF = 3'd2;
    localparam [2:0] REQ_BYTE = 3'd3;
    localparam [2:0] GOT_BYTE = 3'd4;
    localparam [2:0] TRY_D1 = 3'd5;
    localparam [2:0] TRY_D2 = 3'd6;
    localparam [2:0] FINISH = 3'd7;

    reg [2:0] state;
    reg [5:0] seed_idx;
    reg [1:0] byte_cnt;
    reg [7:0] b0, b1;
    reg [8:0] ncoeffs;
    reg [11:0] d1, d2;
    reg shake_start;
    reg [7:0] shake_din;
    reg shake_din_valid;
    reg shake_din_last;
    reg shake_squeeze;

    wire shake_ready;
    wire [7:0] shake_dout;
    wire shake_dout_valid;
    wire shake_absorb_done;

    shake128 xof (
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
            byte_cnt <= 2'd0;
            b0 <= 8'd0;
            b1 <= 8'd0;
            ncoeffs <= 9'd0;
            d1 <= 12'd0;
            d2 <= 12'd0;
            coeff_out <= 12'd0;
            coeff_valid <= 1'b0;
            done <= 1'b0;
            shake_start <= 1'b0;
            shake_din <= 8'd0;
            shake_din_valid <= 1'b0;
            shake_din_last <= 1'b0;
            shake_squeeze <= 1'b0;
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
                        byte_cnt <= 2'd0;
                        ncoeffs <= 9'd0;
                        shake_start <= 1'b1;
                        state <= ABSORB_SEED;
                    end
                end

                ABSORB_SEED: begin
                    if (shake_ready) begin
                        shake_din_valid <= 1'b1;

                        if (seed_idx < 6'd32) begin
                            shake_din <= rho[8*seed_idx +: 8];
                            shake_din_last <= 1'b0;
                            seed_idx <= seed_idx + 6'd1;
                        end
                        else if (seed_idx == 6'd32) begin
                            shake_din <= i;
                            shake_din_last <= 1'b0;
                            seed_idx <= seed_idx + 6'd1;
                        end
                        else begin
                            shake_din <= j;
                            shake_din_last <= 1'b1;
                            state <= WAIT_XOF;
                        end
                    end
                end

                WAIT_XOF: begin
                    if (shake_absorb_done) begin
                        byte_cnt <= 2'd0;
                        state <= REQ_BYTE;
                    end
                end

                REQ_BYTE: begin
                    if (shake_absorb_done) begin
                        shake_squeeze <= 1'b1;
                        state <= GOT_BYTE;
                    end
                end

                GOT_BYTE: begin
                    if (shake_dout_valid) begin
                        if (byte_cnt == 2'd0) begin
                            b0 <= shake_dout;
                            byte_cnt <= 2'd1;
                            state <= REQ_BYTE;
                        end
                        else if (byte_cnt == 2'd1) begin
                            b1 <= shake_dout;
                            byte_cnt <= 2'd2;
                            state <= REQ_BYTE;
                        end
                        else begin
                            d1 <= {b1[3:0], b0};
                            d2 <= {shake_dout, b1[7:4]};
                            state <= TRY_D1;
                        end
                    end
                end

                TRY_D1: begin
                    if (d1 < q) begin
                        coeff_out <= d1;
                        coeff_valid <= 1'b1;
                        ncoeffs <= ncoeffs + 9'd1;

                        if (ncoeffs == 9'd255)
                            state <= FINISH;
                        else
                            state <= TRY_D2;
                    end
                    else begin
                        state <= TRY_D2;
                    end
                end

                TRY_D2: begin
                    if (d2 < q) begin
                        coeff_out <= d2;
                        coeff_valid <= 1'b1;
                        ncoeffs <= ncoeffs + 9'd1;

                        if (ncoeffs == 9'd255)
                            state <= FINISH;
                        else begin
                            byte_cnt <= 2'd0;
                            state <= REQ_BYTE;
                        end
                    end
                    else begin
                        byte_cnt <= 2'd0;
                        state <= REQ_BYTE;
                    end
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
