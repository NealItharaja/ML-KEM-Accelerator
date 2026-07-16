// Montgomery reduction
// T will be a product from mod_mult
module montgomery(
    input [11:0] T,
    output [11:0] t
);

    paramter N = 3329;
    parameter R = 4096;
endmodule