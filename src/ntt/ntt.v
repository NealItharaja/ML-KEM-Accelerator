// 256-point NTT
module ntt256(
    input clk,
    input reset,
    input start,
    input load,
    input [7:0]  load_addr_a,
    input [7:0]  load_addr_b,
    input [11:0] load_data_a,
    input [11:0] load_data_b,
    input [7:0]  read_addr,
    output [11:0] read_data,
    output done
);

    reg ram_rd_en;
    reg ram_wr_en;
    reg running;
    reg [7:0] ram_rd_addr_a;
    reg [7:0] ram_rd_addr_b;
    reg [7:0] ram_wr_addr_a;
    reg [7:0] ram_wr_addr_b;
    reg [11:0] ram_wr_data_a;
    reg [11:0] ram_wr_data_b;

    wire rd_en;
    wire wr_en;
    wire [7:0] rd_addr_a;
    wire [7:0] rd_addr_b;
    wire [7:0] wr_addr_a;
    wire [7:0] wr_addr_b;
    wire [6:0] twiddle_addr;
    wire [11:0] coeff_a;
    wire [11:0] coeff_b;
    wire [11:0] butterfly_a;
    wire [11:0] butterfly_b;
    wire [11:0] twiddle;

    always @(posedge clk or posedge reset) begin
        if (reset)
            running <= 1'b0;
        else if (start) 
            running <= 1'b1;
        else if (done)  
            running <= 1'b0;
    end

    always @(*) begin
        if (running) begin
            ram_rd_en = rd_en;
            ram_wr_en = wr_en;
            ram_rd_addr_a = rd_addr_a;
            ram_rd_addr_b = rd_addr_b;
            ram_wr_addr_a = wr_addr_a;
            ram_wr_addr_b = wr_addr_b;
            ram_wr_data_a = butterfly_a;
            ram_wr_data_b = butterfly_b;
        end
        else begin
            ram_rd_en = ~load;
            ram_wr_en = load;
            ram_rd_addr_a = read_addr;
            ram_rd_addr_b = read_addr ^ 8'd1;
            ram_wr_addr_a = load_addr_a;
            ram_wr_addr_b = load_addr_b;
            ram_wr_data_a = load_data_a;
            ram_wr_data_b = load_data_b;
        end
    end

    assign read_data = coeff_a;

    address_gen #(.PIPE_LATENCY(2)) addresses(
        .clk(clk),
        .reset(reset),
        .start(start),
        .inverse(1'b0),
        .rd_en(rd_en),
        .rd_addr_a(rd_addr_a),
        .rd_addr_b(rd_addr_b),
        .twiddle_addr(twiddle_addr),
        .wr_en(wr_en),
        .wr_addr_a(wr_addr_a),
        .wr_addr_b(wr_addr_b),
        .done(done)
    );

    coeff_ram memory(
        .clk(clk),
        .rd_en(ram_rd_en),
        .wr_en(ram_wr_en),
        .rd_addr_a(ram_rd_addr_a),
        .wr_addr_a(ram_wr_addr_a),
        .rd_addr_b(ram_rd_addr_b),
        .wr_addr_b(ram_wr_addr_b),
        .wr_data_a(ram_wr_data_a),
        .wr_data_b(ram_wr_data_b),
        .rd_data_a(coeff_a),
        .rd_data_b(coeff_b)
    );

    twiddle_rom twiddles(
        .clk(clk),
        .addr(twiddle_addr),
        .data(twiddle)
    );

    butterfly butterfly_unit(
        .clk(clk),
        .a(coeff_a),
        .b(coeff_b),
        .twiddle(twiddle),
        .a_out(butterfly_a),
        .b_out(butterfly_b)
    );
endmodule
