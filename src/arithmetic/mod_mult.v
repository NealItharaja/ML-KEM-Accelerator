// Modular Multiplication
module mod_mult(
    input [11:0] A,
    input [11:0] B,
    output [11:0] result
);

    parameter [11:0] R_Sq_mod = 1353; // Uses R^2 mod q constant value
    
    wire [23:0] product;
    wire [11:0] A_Prime;
    wire [11:0] B_Prime;
    wire [11:0] C;

    assign product = A * B;

    montgomery A_Prime (
        .T(A * R_Sq_mod),
        .t(A_Prime)
    )

    montgomery B_Prime (
        .T(B * R_Sq_mod),
        .t(B_Prime)
    )

    montgomery C (
        .T(A_Prime * B_Prime),
        .t(C)
    )

    montgomery result (
        .T(C),
        .t(result)
    )
endmodule