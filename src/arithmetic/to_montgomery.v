// Turns input into Montogomery domain
module to_montgomery(
    input [11:0] A,
    input clk, //Dummy clock
    output [11:0] A_Prime
);

    parameter [11:0] R_Sq_mod = 1353; // Uses R^2 mod q constant value
    
    wire [31:0] product;
    
    assign product = A * R_Sq_mod;

    montgomery APrime (
        .clk(clk), //Instantiating dummy clock
        .T(product),
        .t(A_Prime)
    );
endmodule