module from_montgomery(
    input [11:0] C,
    input clk, //Dummy clock
    output [11:0] result
);
    wire [31:0] extended_C;

    assign extended_C = {20'd0, C};

    montgomery Result (
        .clk(clk),
        .T(extended_C),
        .t(result)
    );
endmodule