// Data decompression
// 'Packing' data: converts coefficients into byte streams
module decompress(
    input clk,
    input start,
    input [9:0] coeff_in,
    input coeff_valid,
    output reg [11:0] coeff_out,
    output reg coeff_valid,
    output reg done
    );
endmodule