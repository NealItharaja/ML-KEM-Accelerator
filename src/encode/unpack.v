// Unpacs data
module unpack #(
    parameter D = 12
)(
    input clk,
    input start,
    input [7:0] byte_in,
    input byte_valid,
    output ready,
    output reg [11:0] coeff_out,
    output reg coeff_valid,
    output reg done
    );

    localparam [1:0] WAIT = 2'd0;
    localparam [1:0] OUT = 2'd1;
    localparam integer BUF_W = D + 8;
    localparam integer N_BYTES = 32 * D;

    reg active;
    reg [1:0] state;
    reg [BUF_W-1:0] bit_buf;
    reg [4:0] bits;
    reg [8:0] coeffs_done;
    reg [9:0] bytes_done;

    wire [4:0] bits_after_in  = bits + 5'd8;
    wire [4:0] bits_after_out = bits - D[4:0];

    assign ready = active && (state == WAIT);

    always @(posedge clk) begin
        if (start) begin
            active <= 1'b1;
            state <= WAIT;
            bit_buf <= {BUF_W{1'b0}};
            bits <= 5'd0;
            coeffs_done <= 9'd0;
            bytes_done <= 10'd0;
            coeff_valid <= 1'b0;
            coeff_out <= 12'd0;
            done <= 1'b0;
        end
        else if (active) begin
            done <= 1'b0;

            case (state)
                WAIT: begin
                    coeff_valid <= 1'b0;
                    if (byte_valid) begin
                        bit_buf <= bit_buf | ({{(BUF_W-8){1'b0}}, byte_in} << bits);
                        bits <= bits_after_in;
                        bytes_done <= bytes_done + 10'd1;

                        if (bits_after_in >= D[4:0])
                            state <= OUT;
                    end
                end

                OUT: begin
                    coeff_out <= 12'd0 | bit_buf[D-1:0];
                    coeff_valid <= 1'b1;
                    bit_buf <= bit_buf >> D;
                    bits <= bits_after_out;
                    coeffs_done <= coeffs_done + 9'd1;

                    if ((coeffs_done + 9'd1) == 9'd256) begin
                        done <= 1'b1;
                        active <= 1'b0;
                        state <= WAIT;
                    end
                    else if (bits_after_out >= D[4:0]) begin
                        state <= OUT;
                    end
                    else begin
                        state <= WAIT;
                    end
                end

                default: state <= WAIT;
            endcase
        end
        else begin
            coeff_valid <= 1'b0;
        end
    end
endmodule
