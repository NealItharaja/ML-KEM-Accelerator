// Storage for Kyber coefficients
module coeff_ram(
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

    reg [11:0] bank0 [0:127];
    reg [11:0] bank1 [0:127];
    reg [11:0] b0_q, b1_q;
    reg read_a_in_bank0_d;
    
    wire read_a_in_bank0 = (^rd_addr_a) == 1'b0;
    wire write_a_in_bank0 = (^wr_addr_a) == 1'b0;
    wire [6:0] b0_raddr = read_a_in_bank0 ? rd_addr_a[7:1] : rd_addr_b[7:1];
    wire [6:0] b1_raddr = read_a_in_bank0 ? rd_addr_b[7:1] : rd_addr_a[7:1];
    wire [6:0] b0_waddr = write_a_in_bank0 ? wr_addr_a[7:1] : wr_addr_b[7:1];
    wire [11:0] b0_wdata = write_a_in_bank0 ? wr_data_a : wr_data_b;
    wire [6:0] b1_waddr = write_a_in_bank0 ? wr_addr_b[7:1] : wr_addr_a[7:1];
    wire [11:0] b1_wdata = write_a_in_bank0 ? wr_data_b : wr_data_a;

    always @(posedge clk) begin
        if (wr_en) begin
            bank0[b0_waddr] <= b0_wdata;
            bank1[b1_waddr] <= b1_wdata;
        end
        if (rd_en) begin
            b0_q <= bank0[b0_raddr];
            b1_q <= bank1[b1_raddr];
        end

        read_a_in_bank0_d <= read_a_in_bank0;
    end

    always @(*) begin
        rd_data_a = read_a_in_bank0_d ? b0_q : b1_q;
        rd_data_b = read_a_in_bank0_d ? b1_q : b0_q;
    end
endmodule
