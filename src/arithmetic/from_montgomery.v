module from_mont(
    input [11:0] C,
    output [11:0] result
);
    wire [31:0] extended_C;

    assign extended_C = {20'd0, C};

    montgomery Result (
        .T(extended_C),
        .t(result)
    );
endmodule