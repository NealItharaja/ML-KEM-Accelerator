// Packs coefficients
module pack #(
    parameter D = 12
)(
    input clk,
    input start,
    input [11:0] coeff_in,
    input coeff_valid,
    output ready,
    output reg [7:0] byte_out,
    output reg byte_valid,
    output reg done
    );

    localparam [1:0] WAIT = 2'd0;
    localparam [1:0] EMIT = 2'd1;
    localparam integer BUF_W = D + 8;

    reg active;
    reg [1:0] state;
    reg [BUF_W-1:0] bit_buf;
    reg [4:0] bits;
    reg [8:0] coeffs_done;

    wire [BUF_W-1:0] coeff_ext = {{(BUF_W-D){1'b0}}, coeff_in[D-1:0]};
    wire [4:0] bits_after_in  = bits + D[4:0];
    wire [4:0] bits_after_out = bits - 5'd8;

    assign ready = active && (state == WAIT);

    always @(posedge clk) begin
        if (start) begin
            active <= 1'b1;
            state <= WAIT;
            bit_buf <= {BUF_W{1'b0}};
            bits <= 5'd0;
            coeffs_done <= 9'd0;
            byte_valid <= 1'b0;
            byte_out <= 8'd0;
            done <= 1'b0;
        end
        else if (active) begin
            done <= 1'b0;

            case (state)
                WAIT: begin
                    byte_valid <= 1'b0;
                    if (coeff_valid) begin
                        bit_buf <= bit_buf | (coeff_ext << bits);
                        bits <= bits_after_in;
                        coeffs_done <= coeffs_done + 9'd1;

                        if (bits_after_in >= 5'd8)
                            state <= EMIT;
                    end
                end

                EMIT: begin
                    byte_out <= bit_buf[7:0];
                    byte_valid <= 1'b1;
                    bit_buf <= bit_buf >> 8;
                    bits <= bits_after_out;

                    if (bits_after_out >= 5'd8) begin
                        state <= EMIT;
                    end
                    else if ((coeffs_done == 9'd256) && (bits_after_out == 5'd0)) begin
                        done <= 1'b1;
                        active <= 1'b0;
                        state <= WAIT;
                    end
                    else begin
                        state <= WAIT;
                    end
                end

                default: state <= WAIT;
            endcase
        end
        else begin
            byte_valid <= 1'b0;
        end
    end
endmodule
