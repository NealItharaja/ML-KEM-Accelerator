// Storage for coefficients (SRAM version)
module coeff_ram(
    `ifdef USE_POWER_PINS
        inout vccd1,
        inout vssd1,
    `endif

    input clk,
    input we,
    input [7:0] addr,
    input [11:0] din,
    output [11:0] dout
    );

    wire [31:0] sram_din;
    wire [31:0] sram_dout;
    
    assign sram_din = {20'd0, din};
    assign dout = sram_dout[11:0];

    sky130_sram_1kbyte_1rw1r_32x256_8 SRAM (
        `ifdef USE_POWER_PINS
            .vccd1(vccd1),
            .vssd1(vssd1),
        `endif

        .clk0(clk),
        .csb0(1'b0),
        .web0(~we),           
        .wmask0(4'b0011),     
        .addr0(addr),
        .din0(sram_din),
        .dout0(sram_dout),

        // Unused Read Port
        .clk1(clk),
        .csb1(1'b1),          // Disabled second port
        .addr1(8'd0),
        .dout1()
    );
endmodule