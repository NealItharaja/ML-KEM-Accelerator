// Modular Multiplication
module mod_mult(
    input [11:0] A,
    input [11:0] B,
    output [11:0] result
);
    
    wire [23:0] product;
    
    assign product = A * B;

    montgomery Result (
        .T(product),
        .t(result)
    );
endmodule