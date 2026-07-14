// Modular addition

module
    input [11:0] A,
    input [11:0] B,
    output [11:0] result
    
    wire [12:0] sum;
    paramter [11:0] q = 12'd3329;

    assign sum = A + B;
    assign result = sum & (q - 1);
endmodule