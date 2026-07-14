// Modular addition
// Assumptions: Inputs are already modulo reduced, e.g.  0 ≤ A < q &  0 ≤ B < q, thus making  0 ≤ result < q

module
    input [11:0] A,
    input [11:0] B,
    output reg [11:0] result
    
    wire [12:0] sum;
    paramter [11:0] q = 12'd3329;

    assign sum = A + B;
    
    always @(*) begin
        if (sum >= q) begin
            result = sum - q;
        end else begin
            result = sum
        end
    end
endmodule