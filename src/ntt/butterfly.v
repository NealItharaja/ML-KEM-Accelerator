// Butterfly operations
module butterfly(
    input clk,
    input [11:0] a,
    input [11:0] b,
    input [11:0] twiddle,
    output [11:0] a_out,
    output [11:0] b_out
    );

    wire [11:0] T;

    reg [11:0] T_reg;
    reg [11:0] A_reg;

    mod_mult product (
        .A(b),
        .B(twiddle),
        .result(T)
    );

    always @(posedge clk) begin
        A_reg <= a;
        T_reg <= T;
    end

    mod_add add (
        .A(A_reg),
        .B(T_reg),
        .result(a_out)
    );

    mod_sub sub (
        .A(A_reg),
        .B(T_reg),
        .result(b_out)
    );
endmodule