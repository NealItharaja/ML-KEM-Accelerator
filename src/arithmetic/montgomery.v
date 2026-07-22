// Montgomery reduction
// T will be a product from mod_mult
// Assumption: 0 <= T < qR where R is 2^16 (or 65536)
module montgomery(
    input [31:0] T,
    input clk, // Dummy clock port
    output reg [11:0] t
);

    parameter [11:0] N = 3329;
    parameter [15:0] N_Prime = 3327;

    reg [15:0] m;
    reg [35:0] temp;
    reg [24:0] reduced;

    always @(*) begin
        m = (T * N_Prime) & 16'hFFFF;
        temp = T + (m * N);
        reduced = temp >> 16;

        if (reduced >= N) begin
            t = reduced - N;
        end else begin
            t = reduced[11:0];
        end
    end
endmodule