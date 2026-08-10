`timescale 1ns/1ps

module test_intt;
    reg clk;
    reg reset;
    reg start;
    reg load;
    reg [7:0] load_addr_a, load_addr_b;
    reg [11:0] load_data_a, load_data_b;
    reg [7:0] read_addr;
    reg [11:0] init_vec [0:255];
    reg [11:0] ntt_vec [0:255];
    reg [11:0] gmem [0:255];
    reg [11:0] hw_out [0:255];
    reg [11:0] tw [0:127];
    reg [11:0] got;
    reg [11:0] Tt, na, nb, t0;

    wire [11:0] read_data;
    wire done;

    integer k, st, g, jj;
    integer d, gps, ai, bi, twi;
    integer errors, checks;

    localparam [11:0] Q = 12'd3329;
    localparam [11:0] F = 12'd512;   // R/128 for montgomery.v

    intt DUT(
        .clk(clk),
        .reset(reset),
        .start(start),
        .load(load),
        .load_addr_a(load_addr_a),
        .load_addr_b(load_addr_b),
        .load_data_a(load_data_a),
        .load_data_b(load_data_b),
        .read_addr(read_addr),
        .read_data(read_data),
        .done(done)
    );

    always #5 clk = ~clk;

    function [11:0] mont;
        input [31:0] T;
        reg [15:0] m;
        reg [35:0] temp;
        reg [24:0] reduced;
        begin
            m = (T * 16'd3327) & 16'hFFFF;
            temp = T + (m * 16'd3329);
            reduced = temp >> 16;
            if (reduced >= 3329)
                mont = reduced - 3329;
            else
                mont = reduced[11:0];
        end
    endfunction

    function [11:0] addmod;
        input [11:0] a;
        input [11:0] b;
        reg [12:0] s;
        begin
            s = a + b;
            if (s >= Q)
                addmod = s - Q;
            else
                addmod = s[11:0];
        end
    endfunction

    function [11:0] submod;
        input [11:0] a;
        input [11:0] b;
        begin
            if (a >= b)
                submod = a - b;
            else
                submod = a + Q - b;
        end
    endfunction

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        load = 0;
        load_addr_a = 0;
        load_addr_b = 0;
        load_data_a = 0;
        load_data_b = 0;
        read_addr = 0;
        errors = 0;
        checks = 0;

        $readmemh("src/memory/twiddle.mem", tw);

        for (k = 0; k < 256; k = k + 1)
            init_vec[k] = (k * 7 + 13) % 3329;

        for (k = 0; k < 256; k = k + 1)
            ntt_vec[k] = init_vec[k];

        twi = 1;
        for (st = 0; st < 7; st = st + 1) begin
            d = 128 >> st;
            gps = 1 << st;

            for (g = 0; g < gps; g = g + 1) begin
                for (jj = 0; jj < d; jj = jj + 1) begin
                    ai = (g << (8 - st)) + jj;
                    bi = ai + d;
                    Tt = mont(ntt_vec[bi] * tw[twi]);
                    na = addmod(ntt_vec[ai], Tt);
                    nb = submod(ntt_vec[ai], Tt);
                    ntt_vec[ai] = na;
                    ntt_vec[bi] = nb;
                end
                twi = twi + 1;
            end
        end

        for (k = 0; k < 256; k = k + 1)
            gmem[k] = ntt_vec[k];

        twi = 127;
        for (st = 0; st < 7; st = st + 1) begin
            d = 2 << st;
            gps = 1 << (6 - st);
            for (g = 0; g < gps; g = g + 1) begin
                for (jj = 0; jj < d; jj = jj + 1) begin
                    ai = (g << (st + 2)) + jj;
                    bi = ai + d;
                    t0 = gmem[ai];
                    na = addmod(t0, gmem[bi]);
                    nb = mont(tw[twi] * submod(gmem[bi], t0));
                    gmem[ai] = na;
                    gmem[bi] = nb;
                end
                twi = twi - 1;
            end
        end

        for (k = 0; k < 256; k = k + 1)
            gmem[k] = mont(gmem[k] * F);

        $display("================================");
        $display("INTT INPUT = NTT(x) (index : value)");
        $display("================================");
        for (k = 0; k < 256; k = k + 1)
            $display("in[%0d] = %0d", k, ntt_vec[k]);
        $display("");

        #20;
        reset = 0;

        $display("Loading 256 NTT-domain coefficients...");
        load = 1;
        for (k = 0; k < 128; k = k + 1) begin
            @(negedge clk);
            load_addr_a = 2*k;
            load_addr_b = 2*k + 1;
            load_data_a = ntt_vec[2*k];
            load_data_b = ntt_vec[2*k + 1];
        end
        @(negedge clk);
        load = 0;

        $display("Running hardware INTT...");
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        wait (done);
        repeat (5) @(posedge clk);

        $display("Reading back and checking against golden invntt...");
        for (k = 0; k < 256; k = k + 1) begin
            @(negedge clk);
            read_addr = k;
            @(posedge clk);
            #1;
            got = read_data;
            hw_out[k] = got;
            checks = checks + 1;
            if (got !== gmem[k]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("MISMATCH MEM[%0d]: hw=%0d golden=%0d", k, got, gmem[k]);
            end
            if (got !== init_vec[k]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("ROUNDTRIP FAIL MEM[%0d]: hw=%0d orig=%0d", k, got, init_vec[k]);
            end
        end

        $display("================================");
        $display("INTT OUTPUT (index : value)");
        $display("================================");
        for (k = 0; k < 256; k = k + 1)
            $display("out[%0d] = %0d", k, hw_out[k]);
        $display("");

        $display("--------------------------------");
        $display("Checked %0d coefficients, %0d mismatches", checks, errors);
        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");
        $display("--------------------------------");
        $finish;
    end
endmodule
