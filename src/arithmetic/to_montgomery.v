// Turns input into Montogomery domain
module to_mont(
    input [11:0] A,
    output [11:0] A_Prime,
);

    parameter [11:0] R_Sq_mod = 1353; // Uses R^2 mod q constant value

    montgomery APrime (
        .T(A * R_Sq_mod),
        .t(A_Prime)
    );
endmodule