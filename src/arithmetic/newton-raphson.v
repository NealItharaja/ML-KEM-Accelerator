// Newton-Raphson Method for finding inverse modulus
module nr(
    input N,
    output N'
);

    paramter [11:0] N = 3329;
    parameter R = 4096;

    reg [11:0] Y = 12'd3;
    reg [1:0] loop_count = 2'd0;
endmodule