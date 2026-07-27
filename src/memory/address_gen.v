// Address generator for Kyber
module address_gen(
    input clk,
    input reset,
    input start,
    input butterfly_done,
    output reg [7:0] addr_a,
    output reg [7:0] addr_b,
    output reg [7:0] twiddle_addr,
    output reg done,
    output reg valid
    );
endmodule