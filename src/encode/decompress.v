// Data decompression
module decompress #(
    parameter D = 10
) (
    input [D-1:0] y,
    output [11:0] decompressed_y
);

    localparam [11:0] q = 12'd3329;

    wire [11+D:0] product = y * q;
    wire [11+D:0] sum = product + (1 << (D-1));

    assign decompressed_y = sum[11+D:D];
endmodule
