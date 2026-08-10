// Integrated Memory Pipeline Testbench for Kyber NTT
`timescale 1ns / 1ps

module ntt_memory_pipeline_tb;
    // Must match the AG PIPE_LATENCY below
    localparam integer L = 4;

    reg clk;
    reg reset;
    reg start;
    reg finished;
    reg [7:0] idx;
    reg [11:0] got;
    reg [11:0] expected_twiddle [0:127];
    reg [11:0] exp [0:255];
    reg [11:0] a_dly [0:L-2];
    reg [11:0] b_dly [0:L-2];
    reg rd_en_d;
    reg [7:0] rd_a_d, rd_b_d;
    reg [6:0] tw_d;

    wire rd_en;
    wire [7:0] rd_addr_a, rd_addr_b;
    wire [6:0] twiddle_addr;
    wire wr_en;
    wire [7:0] wr_addr_a, wr_addr_b;
    wire done;
    wire [11:0] rd_data_a, rd_data_b;
    wire [11:0] twiddle_factor;
    wire [11:0] wr_data_a = a_dly[L-2];
    wire [11:0] wr_data_b = b_dly[L-2];

    integer pass_count = 0;
    integer fail_count = 0;
    integer rd_count = 0;
    integer wr_count = 0;
    integer cyc = 0;
    integer i;
    integer t;
    integer d;

    address_gen #(.PIPE_LATENCY(L)) AG (
        .clk(clk),
        .reset(reset),
        .start(start),
        .rd_en(rd_en),
        .rd_addr_a(rd_addr_a),
        .rd_addr_b(rd_addr_b),
        .twiddle_addr(twiddle_addr),
        .wr_en(wr_en),
        .wr_addr_a(wr_addr_a),
        .wr_addr_b(wr_addr_b),
        .done(done)
    );

    always @(posedge clk) begin
        a_dly[0] <= rd_data_a;
        b_dly[0] <= rd_data_b;

        for (d = 1; d <= L-2; d = d + 1) begin
            a_dly[d] <= a_dly[d-1];
            b_dly[d] <= b_dly[d-1];
        end
    end

    coeff_ram RAM (
        .clk(clk),
        .rd_en(rd_en),
        .rd_addr_a(rd_addr_a),
        .rd_addr_b(rd_addr_b),
        .rd_data_a(rd_data_a),
        .rd_data_b(rd_data_b),
        .wr_en(wr_en),
        .wr_addr_a(wr_addr_a),
        .wr_addr_b(wr_addr_b),
        .wr_data_a(wr_data_a),
        .wr_data_b(wr_data_b)
    );

    twiddle_rom TW_ROM (
        .clk(clk),
        .addr(twiddle_addr),
        .data(twiddle_factor)
    );

    always @(posedge clk) begin
        rd_en_d <= rd_en;
        rd_a_d <= rd_addr_a;
        rd_b_d <= rd_addr_b;
        tw_d <= twiddle_addr;
    end

    // 100 MHz
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        start = 0;

        $readmemh("src/memory/twiddle.mem", expected_twiddle);

        $display("=================================================");
        $display("Step 1: Preloading 256 coefficients into coeff_ram");
        $display("=================================================");

        for (i = 0; i < 256; i = i + 1) begin
            idx    = i[7:0];
            exp[i] = idx * 12'h005 + 12'h001;
            if (^idx)
                RAM.bank1[i >> 1] = exp[i];   // odd parity goes to bank1
            else
                RAM.bank0[i >> 1] = exp[i];   // even parity goes to bank0
        end

        $display("=================================================");
        $display("Step 2: Starting address generator & memory pipeline");
        $display("=================================================");

        @(posedge clk);
        #1;
        reset = 0;

        @(posedge clk);
        #1;
        start = 1;

        @(posedge clk);
        #1;
        start = 0;

        finished = 0;

        while (!finished && cyc < 6000) begin
            if (rd_en) begin
                rd_count = rd_count + 1;
                if ((^rd_addr_a) !== (^rd_addr_b)) begin
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL: read pair (%0d,%0d) share a bank", rd_addr_a, rd_addr_b);
                    fail_count = fail_count + 1;
                end
            end

            if (wr_en)
                wr_count = wr_count + 1;

            if (rd_en_d) begin
                if (rd_data_a === exp[rd_a_d])
                    pass_count = pass_count + 1;
                else begin
                    $display("FAIL [coeff_ram A]: addr=%0d Expected=%03h Got=%03h", rd_a_d, exp[rd_a_d], rd_data_a);
                    fail_count = fail_count + 1;
                end

                if (rd_data_b === exp[rd_b_d])
                    pass_count = pass_count + 1;
                else begin
                    $display("FAIL [coeff_ram B]: addr=%0d Expected=%03h Got=%03h", rd_b_d, exp[rd_b_d], rd_data_b);
                    fail_count = fail_count + 1;
                end

                if (twiddle_factor === expected_twiddle[tw_d])
                    pass_count = pass_count + 1;
                else begin
                    $display("FAIL [twiddle ROM]: addr=%0d Expected=%03h Got=%03h", tw_d, expected_twiddle[tw_d], twiddle_factor);
                    fail_count = fail_count + 1;
                end
            end

            if (done) finished = 1;
            else begin
                @(posedge clk); #1;
                cyc = cyc + 1;
            end
        end

        for (t = 0; t < L + 3; t = t + 1) begin
            @(posedge clk); #1;
            if (wr_en)
                wr_count = wr_count + 1;
        end

        for (i = 0; i < 256; i = i + 1) begin
            idx = i[7:0];
            got = (^idx) ? RAM.bank1[i >> 1] : RAM.bank0[i >> 1];

            if (got === exp[i]) begin
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [mem@%0d]: Expected=%03h Got=%03h", i, exp[i], got);
                fail_count = fail_count + 1;
            end
        end

        $display("=================================================");
        $display("INTEGRATED PIPELINE TEST SUMMARY");
        $display("Read pairs  = %0d (expected 1024)", rd_count);
        $display("Write pairs = %0d (expected 1024)", wr_count);
        $display("Passed checks = %0d", pass_count);
        $display("Failed checks = %0d", fail_count);
        $display("=================================================");

        if (rd_count == 1024 && wr_count == 1024 && fail_count == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");
        $finish;
    end
endmodule
