// Storage for coefficients
module coeff_ram(
    input clk,
    input we,
    input [7:0] addr,
    input [11:0] din,
    output reg [11:0] dout
    );
    
    reg [11:0] mem [0:255];

    always @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        dout <= mem[addr];
    end 
endmodule