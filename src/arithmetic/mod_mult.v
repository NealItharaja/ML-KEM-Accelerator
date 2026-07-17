// Modular Multiplication
module mod_mult(
    input [11:0] A,
    input [11:0] B,
    output [11:0] result
);

    montgomery Result (
        .T(A * B),
        .t(result)
    );
endmodule