// Gentleman-Sande butterfly for inverse NTT
// a_out = a + b, b_out = twiddle * (b - a)
// Subtract happens first, then the multiply - the mirror of the CT butterfly.
// Latency from stable inputs to outputs is 2 cycles, matching butterfly.v so the same PIPE_LATENCY write-back timing work
module butterfly_gs(
    input clk,
    input [11:0] a,
    input [11:0] b,
    input [11:0] twiddle,
    output [11:0] a_out,
    output [11:0] b_out
    );

    wire [11:0] sum;
    wire [11:0] diff;

    reg [11:0] sum_reg;
    reg [11:0] diff_reg;
    reg [11:0] tw_reg;

    mod_add add (
        .A(a),
        .B(b),
        .result(sum)
    );

    mod_sub sub (
        .A(b),
        .B(a),
        .result(diff)
    );

    always @(posedge clk) begin
        sum_reg <= sum;
        diff_reg <= diff;
        tw_reg <= twiddle;
    end

    assign a_out = sum_reg;

    mod_mult product (
        .A(diff_reg),
        .B(tw_reg),
        .result(b_out)
    );
endmodule
