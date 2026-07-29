// Butterfly operations
module butterfly(
    input clk,
    input [11:0] a,
    input [11:0] b,
    input [11:0] twiddle,
    output [11:0] a_out,
    output [11:0] b_out,
    );

    wire [11:0] T;

    mod_mult product (
        .A(b),
        .B(twiddle),
        .result(T)
    );

    mod_add add (
        .A(a),
        .B(T),
        .result(a_out)
    );

    mod_sub sub (
        .A(a),
        .B(T),
        .result(b_out)
    );
endmodule