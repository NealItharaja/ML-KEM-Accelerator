// Data compression
// 'Packing' data: converts coefficients into byte streams
module compress(
    input clk,
    input start,
    input [11:0] coeff_in,
    input coeff_valid,
    output reg [9:0] byte_out,
    output reg byte_valid,
    output reg done
    );
endmodule