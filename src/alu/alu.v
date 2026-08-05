// Poly / Vector ALU: streams coefficient-wise addition or subtraction over n_polys * 256
module alu(
    input clk,
    input reset,
    input start,
    input op,
    input [2:0] n_polys,
    input [11:0] a_in,
    input [11:0] b_in,
    input in_valid,
    output ready,
    output reg [11:0] c_out,
    output reg out_valid,
    output reg done
    );

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] RUN = 2'd1;
    localparam [1:0] FIN = 2'd2;

    reg [1:0] state;
    reg op_r;
    reg [10:0] total;
    reg [10:0] count;
    reg [11:0] result;

    wire [11:0] add_r;
    wire [11:0] sub_r;

    assign ready = (state == RUN);

    mod_add u_add (
        .A(a_in),
        .B(b_in),
        .result(add_r)
    );

    mod_sub u_sub (
        .A(a_in),
        .B(b_in),
        .result(sub_r)
    );

    always @(*) begin
        if (op_r == 1'b0)
            result = add_r;
        else
            result = sub_r;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            op_r <= 1'b0;
            total <= 11'd0;
            count <= 11'd0;
            c_out <= 12'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
        end
        else begin
            out_valid <= 1'b0;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        op_r <= op;
                        count <= 11'd0;

                        if (n_polys == 3'd0)
                            total <= 11'd256;
                        else if (n_polys > 3'd4)
                            total <= 11'd1024;
                        else
                            total <= {n_polys, 8'd0};
                        state <= RUN;
                    end
                end

                RUN: begin
                    if (in_valid) begin
                        c_out <= result;
                        out_valid <= 1'b1;
                        count <= count + 11'd1;

                        if (count == (total - 11'd1))
                            state <= FIN;
                    end
                end

                FIN: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
