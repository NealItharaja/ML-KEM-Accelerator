module from_mont(
    input [11:0] C,
    output [11:0] result
);
    montgomery Result (
        .T(C),
        .t(result)
    );
endmodule