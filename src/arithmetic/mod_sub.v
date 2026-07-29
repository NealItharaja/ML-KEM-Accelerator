// Modular Subtraction
// Assumptions: Inputs are already modulo reduced, e.g.  0 ≤ A < q &  0 ≤ B < q, thus making  0 ≤ result < q

module mod_sub(
    input [11:0] A,
    input [11:0] B,
    output reg [11:0] result
    );

    parameter [11:0] q = 12'd3329;
    
    always @(*) begin
        if (A >= B) begin
            result = A - B;
        end else begin
            result = A + q - B;
        end
    end
endmodule