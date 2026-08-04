// NTT-domain pointwise multiplication on degree-1 pairs (Kyber basemul)
module basemul(
    input clk,
    input [11:0] a0,
    input [11:0] a1,
    input [11:0] b0,
    input [11:0] b1,
    input [11:0] twiddle,
    output reg [11:0] r0,
    output reg [11:0] r1
);

    wire [11:0] a1_b1;
    wire [11:0] a1_b1_zeta;
    wire [11:0] a0_b0;
    wire [11:0] a0_b1;
    wire [11:0] a1_b0;
    wire [11:0] r0_c;
    wire [11:0] r1_c;

    mod_mult mult_a1_b1 (
        .A(a1),
        .B(b1),
        .result(a1_b1)
    );

    mod_mult mult_a1_b1_z (
        .A(a1_b1),
        .B(twiddle),
        .result(a1_b1_zeta)
    );

    mod_mult mult_a0_b0 (
        .A(a0),
        .B(b0),
        .result(a0_b0)
    );

    mod_add add_r0 (
        .A(a0_b0),
        .B(a1_b1_zeta),
        .result(r0_c)
    );

    mod_mult mult_a0_b1 (
        .A(a0),
        .B(b1),
        .result(a0_b1)
    );

    mod_mult mult_a1_b0 (
        .A(a1),
        .B(b0),
        .result(a1_b0)
    );

    mod_add add_r1 (
        .A(a0_b1),
        .B(a1_b0),
        .result(r1_c)
    );

    always @(posedge clk) begin
        r0 <= r0_c;
        r1 <= r1_c;
    end
endmodule
