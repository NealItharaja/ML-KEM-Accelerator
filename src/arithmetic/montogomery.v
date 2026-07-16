// Montgomery reduction
// T will be a product from mod_mult
module montgomery(
    input [23:0] T,
    output reg [11:0] t
);

    parameter [11:0] N = 3329;
    parameter [11:0] N_Prime = 3327;

    wire [11:0] m;
    wire [24:0] inter;
    wire [12:0] t_inter;

    assign m = (T * N_Prime);
    assign inter = T + (m*N);
    assign t_inter = inter >> 12;

    always @(*) begin
        if (t_inter >= N) begin
            t = t_inter - N;
        end else begin
            t = t_inter;
        end
    end
endmodule