// Modular Subtraction
// Assumptions: Inputs are already modulo reduced, e.g.  0 ≤ A < q &  0 ≤ B < q, thus making  0 ≤ result < q

module mod_sub(
    input [11:0] A,
    input [11:0] B,
    output reg [11:0] result
    );
    
    wire [12:0] diff;
    parameter [11:0] q = 12'd3329;

    assign diff = A - B;
    
    always @(*) begin
        if (diff >= q) begin
            result = diff - q;
        end else begin
            result = diff;
        end
    end
endmodule