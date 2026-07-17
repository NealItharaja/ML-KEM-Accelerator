// Modular Multiplication
module mod_mult(
    input [11:0] A,
    input [11:0] B,
    output [11:0] result
);

    parameter [11:0] N = 3329;
    parameter [11:0] N_Prime = 3327;
    
    wire [23:0] product;

    assign product = A * B;

    montgomery A_Prime (
        .T(product),
        .t(result)
    )
endmodule