// SRAM version
module coeff_ram_sram(
    `ifdef USE_POWER_PINS
        inout vccd1,
        inout vssd1,
    `endif
    
    input clk,
    input rd_en,
    input wr_en,
    input [7:0] rd_addr_a,
    input [7:0] wr_addr_a,
    input [7:0] rd_addr_b,
    input [7:0] wr_addr_b,
    input [11:0] wr_data_a,
    input [11:0] wr_data_b,
    output reg [11:0] rd_data_a,
    output reg [11:0] rd_data_b
    );

    reg read_a_in_bank0_d;

    wire read_a_in_bank0 = (^rd_addr_a) == 1'b0;
    wire write_a_in_bank0 = (^wr_addr_a) == 1'b0;
    wire [6:0] b0_raddr = read_a_in_bank0 ? rd_addr_a[7:1] : rd_addr_b[7:1];
    wire [6:0] b1_raddr = read_a_in_bank0 ? rd_addr_b[7:1] : rd_addr_a[7:1];
    wire [6:0] b0_waddr = write_a_in_bank0 ? wr_addr_a[7:1] : wr_addr_b[7:1];
    wire [11:0] b0_wdata = write_a_in_bank0 ? wr_data_a : wr_data_b;
    wire [6:0] b1_waddr = write_a_in_bank0 ? wr_addr_b[7:1] : wr_addr_a[7:1];
    wire [11:0] b1_wdata = write_a_in_bank0 ? wr_data_b : wr_data_a;
    wire [31:0] b0_dout1, b1_dout1;

    always @(posedge clk) begin
        read_a_in_bank0_d <= read_a_in_bank0;
    end

    sky130_sram_1kbyte_1rw1r_32x256_8 bank0 (
        `ifdef USE_POWER_PINS
            .vccd1 (vccd1),
            .vssd1 (vssd1),
        `endif

        .clk0(clk),
        .csb0(~wr_en),
        .web0(1'b0),
        .wmask0(4'b0011),
        .addr0({1'b0, b0_waddr}),
        .din0({20'd0, b0_wdata}),
        .dout0(),
        .clk1(clk),
        .csb1(~rd_en),
        .addr1({1'b0, b0_raddr}),
        .dout1(b0_dout1)
    );

    sky130_sram_1kbyte_1rw1r_32x256_8 bank1 (
        `ifdef USE_POWER_PINS
            .vccd1 (vccd1),
            .vssd1 (vssd1),
        `endif

        .clk0(clk),
        .csb0(~wr_en),
        .web0(1'b0),
        .wmask0(4'b0011),
        .addr0({1'b0, b1_waddr}),
        .din0({20'd0, b1_wdata}),
        .dout0(),
        .clk1(clk),
        .csb1(~rd_en),
        .addr1({1'b0, b1_raddr}),
        .dout1(b1_dout1)
    );

    always @(*) begin
        rd_data_a = read_a_in_bank0_d ? b0_dout1[11:0] : b1_dout1[11:0];
        rd_data_b = read_a_in_bank0_d ? b1_dout1[11:0] : b0_dout1[11:0];
    end
endmodule
