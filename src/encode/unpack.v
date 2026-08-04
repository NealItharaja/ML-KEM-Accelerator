// Unpack bytes into coefficients
module unpack(
    input clk,
    input start,
    input [7:0] byte_in,
    input byte_valid,
    output ready,
    output reg [11:0] coeff_a,
    output reg [11:0] coeff_b,
    output reg coeff_valid,
    output reg done
    );

    localparam [1:0] WAIT = 2'd0;
    localparam [1:0] E0 = 2'd1;
    localparam [1:0] E1 = 2'd2;
    localparam [1:0] E2 = 2'd3;

    reg active;
    reg [1:0] state;
    reg [7:0] y0, y1, y2;
    reg [7:0] pairs_done;

    assign ready = active && (state != E2);

    always @(posedge clk) begin
        if (start) begin
            active <= 1'b1;
            state <= WAIT;
            pairs_done <= 8'd0;
            coeff_valid <= 1'b0;
            coeff_a <= 12'd0;
            coeff_b <= 12'd0;
            done <= 1'b0;
            y0 <= 8'd0;
            y1 <= 8'd0;
            y2 <= 8'd0;
        end
        else if (active) begin
            done <= 1'b0;

            case (state)
                WAIT: begin
                    coeff_valid <= 1'b0;

                    if (byte_valid) begin
                        y0 <= byte_in;
                        state <= E0;
                    end
                end

                E0: begin
                    if (byte_valid) begin
                        y1 <= byte_in;
                        state <= E1;
                    end
                end

                E1: begin
                    if (byte_valid) begin
                        y2 <= byte_in;
                        pairs_done <= pairs_done + 8'd1;
                        state <= E2;
                    end
                end

                E2: begin
                    coeff_a <= {y1[3:0], y0};
                    coeff_b <= {y2, y1[7:4]};
                    coeff_valid <= 1'b1;

                    if (pairs_done == 8'd128) begin
                        done <= 1'b1;
                        active <= 1'b0;
                    end

                    state <= WAIT;
                end
                default: state <= WAIT;
            endcase
        end
        else begin
            coeff_valid <= 1'b0;
        end
    end
endmodule
