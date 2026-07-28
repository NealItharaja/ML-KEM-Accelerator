// Module for reading official Kyber twiddle factors
module twiddle_rom(
    input clk,
    input [6:0] addr,
    output reg [11:0] data
    );

    reg [11:0] rom [0:127];

    initial begin
        $readmemh("src/memory/twiddle.mem", rom);
    end

    always @(posedge clk) begin
        data <= rom[addr];
    end
endmodule