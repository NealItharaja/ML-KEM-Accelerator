// Unpack bytes into coefficients
module unpack(
    input clk,
    input start,
    input [7:0] byte_in,
    input byte_valid,
    output ready,
    output reg [11:0] coeff_a,
    output reg [11:0] coeff_b,
    output reg coeff_valid,
    output reg done
    );

    localparam [1:0] WAIT = 2'd0;
    localparam [1:0] E0 = 2'd1;
    localparam [1:0] E1 = 2'd2;
    localparam [1:0] E2 = 2'd3;

    reg active;
    reg [1:0] state;
    reg [7:0] b0, b1, b2;
    reg [7:0] pairs_done;

    assign ready = active && (state == WAIT);

    always @(posedge clk) begin
        if (start) begin
        end
    end
endmodule
