// Inverse 256-point NTT
// Address_gen runs with inverse=1 (distance 2..128, twiddles 127..1), uses Gentleman-Sande butterfly (butterfly_gs)
// After the 7 stages, every coefficient is scaled by F = 512 (= R/128) via Montgomery multiply, which undoes the 128 from the incomplete transform for this montgomery.v (R = 2^16).
module intt(
    input clk,
    input reset,
    input start,
    input load,
    input [7:0] load_addr_a,
    input [7:0] load_addr_b,
    input [11:0] load_data_a,
    input [11:0] load_data_b,
    input [7:0] read_addr,
    output [11:0] read_data,
    output reg done
    );

    localparam [11:0] F = 12'd512;
    localparam integer PIPE_LATENCY = 2;
    localparam [1:0] SC_IDLE  = 2'd0;
    localparam [1:0] SC_RUN   = 2'd1;
    localparam [1:0] SC_DRAIN = 2'd2;

    reg ram_rd_en;
    reg ram_wr_en;
    reg busy;
    reg scaling;
    reg [7:0] ram_rd_addr_a;
    reg [7:0] ram_rd_addr_b;
    reg [7:0] ram_wr_addr_a;
    reg [7:0] ram_wr_addr_b;
    reg [11:0] ram_wr_data_a;
    reg [11:0] ram_wr_data_b;
    reg [1:0] sc_state;
    reg [7:0] sc_j;
    reg [7:0] sc_drain;
    reg sc_we_sr [0:PIPE_LATENCY-1];
    reg [7:0] sc_adda_sr [0:PIPE_LATENCY-1];
    reg [7:0] sc_addb_sr [0:PIPE_LATENCY-1];
    reg [11:0] scale_a_r;
    reg [11:0] scale_b_r;

    integer k;

    wire ag_done;
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
    wire [11:0] scale_a_w;
    wire [11:0] scale_b_w;
    wire sc_rd_en = (sc_state == SC_RUN);
    wire sc_wr_en = sc_we_sr[PIPE_LATENCY-1];
    wire [7:0] sc_rd_a = {sc_j, 1'b0};
    wire [7:0] sc_rd_b = {sc_j, 1'b1};
    wire last_sc = (sc_j == 8'd127);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            busy <= 1'b0;
            scaling <= 1'b0;
            done <= 1'b0;
            sc_state <= SC_IDLE;
            sc_j <= 8'd0;
            sc_drain <= 8'd0;
        end
        else begin
            if (start) begin
                busy <= 1'b1;
                scaling <= 1'b0;
                done <= 1'b0;
                sc_state <= SC_IDLE;
                sc_j <= 8'd0;
            end
            else if (busy && ag_done && !scaling) begin
                scaling <= 1'b1;
                sc_state <= SC_RUN;
                sc_j <= 8'd0;
            end
            else if (scaling) begin
                case (sc_state)
                    SC_RUN: begin
                        if (last_sc) begin
                            sc_drain <= PIPE_LATENCY[7:0];
                            sc_state <= SC_DRAIN;
                        end
                        else begin
                            sc_j <= sc_j + 8'd1;
                        end
                    end
                    SC_DRAIN: begin
                        if (sc_drain == 8'd0) begin
                            scaling <= 1'b0;
                            busy <= 1'b0;
                            done <= 1'b1;
                            sc_state <= SC_IDLE;
                        end
                        else begin
                            sc_drain <= sc_drain - 8'd1;
                        end
                    end
                    default: sc_state <= SC_IDLE;
                endcase
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (k = 0; k < PIPE_LATENCY; k = k + 1) begin
                sc_we_sr[k] <= 1'b0;
                sc_adda_sr[k] <= 8'd0;
                sc_addb_sr[k] <= 8'd0;
            end

            scale_a_r <= 12'd0;
            scale_b_r <= 12'd0;
        end
        else begin
            sc_we_sr[0] <= sc_rd_en;
            sc_adda_sr[0] <= sc_rd_a;
            sc_addb_sr[0] <= sc_rd_b;
            for (k = 1; k < PIPE_LATENCY; k = k + 1) begin
                sc_we_sr[k] <= sc_we_sr[k-1];
                sc_adda_sr[k] <= sc_adda_sr[k-1];
                sc_addb_sr[k] <= sc_addb_sr[k-1];
            end

            scale_a_r <= scale_a_w;
            scale_b_r <= scale_b_w;
        end
    end

    always @(*) begin
        if (scaling) begin
            ram_rd_en = sc_rd_en;
            ram_wr_en = sc_wr_en;
            ram_rd_addr_a = sc_rd_a;
            ram_rd_addr_b = sc_rd_b;
            ram_wr_addr_a = sc_adda_sr[PIPE_LATENCY-1];
            ram_wr_addr_b = sc_addb_sr[PIPE_LATENCY-1];
            ram_wr_data_a = scale_a_r;
            ram_wr_data_b = scale_b_r;
        end
        else if (busy) begin
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
        .inverse(1'b1),
        .rd_en(rd_en),
        .rd_addr_a(rd_addr_a),
        .rd_addr_b(rd_addr_b),
        .twiddle_addr(twiddle_addr),
        .wr_en(wr_en),
        .wr_addr_a(wr_addr_a),
        .wr_addr_b(wr_addr_b),
        .done(ag_done)
    );

    coeff_ram_sram memory(
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

    butterfly_gs butterfly_unit(
        .clk(clk),
        .a(coeff_a),
        .b(coeff_b),
        .twiddle(twiddle),
        .a_out(butterfly_a),
        .b_out(butterfly_b)
    );

    mod_mult scale_a (
        .A(coeff_a),
        .B(F),
        .result(scale_a_w)
    );

    mod_mult scale_b (
        .A(coeff_b),
        .B(F),
        .result(scale_b_w)
    );
endmodule
