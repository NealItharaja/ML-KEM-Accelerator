// Data compression
module compress #(
    parameter D = 10
) (
    input [11:0] x,
    output [D-1:0] compressed_x
);

    localparam [11:0] q = 12'd3329;
    localparam [11:0] q_HALF = 12'd1664;

    wire [11+D:0] shifted = {x, {D{1'b0}}};
    wire [11+D:0] V = shifted + q_HALF;
    wire [11+D:0] quotient = V / q;

    assign compressed_x = quotient[D-1:0];
endmodule
