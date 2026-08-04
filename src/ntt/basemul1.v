// NTT-domain pointwise multiplication on degree-1 pairs
module basemul1(
    input [11:0] a0,
    input [11:0] a1,
    input [11:0] b0,
    input [11:0] b1,
    input [11:0] twiddle,
    output [11:0] r0,
    output [11:0] r1
);

    wire [11:0] a_intermediate;
    wire [11:0] intermediate;
    wire [11:0] b_intermediate;

    mod_mult first (
        .A(a1),
        .B(b1),
        .result(a_intermediate)
    );

    mod_mult second (
        .A(a_intermediate),
        .B(twiddle),
        .result(r0)
    )

    mod_mult third (
        .A(a0),
        .B(b0),
        .result(intermediate)
    );

    assign r0 = r0 + intermediate;

    mod_mult fourth (
        .A(a0),
        .B(b1),
        .result(r1)
    );

    mod_mult fifth (
        .A(a1),
        .B(b0),
        .result(b_intermediate)
    );

    assign r1 = r1 + b_intermediate;
endmodule