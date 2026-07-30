`timescale 1ns/1ps

module test_ntt256;

    reg clk;
    reg reset;
    reg start;
    reg load;
    reg [7:0]  load_addr_a, load_addr_b;
    reg [11:0] load_data_a, load_data_b;
    reg [7:0]  read_addr;

    wire [11:0] read_data;
    wire done;

    integer k, st, g, jj;
    integer d, gps, tw_shift, ai, bi, twi;
    integer errors, checks;

    reg [11:0] init_vec [0:255];   // values loaded into hardware
    reg [11:0] hw_out   [0:255];   // NTT results read back from hardware
    reg [11:0] gmem     [0:255];   // golden memory (transformed in place)
    reg [11:0] tw       [0:127];   // golden copy of the twiddle ROM
    reg [11:0] got;

    localparam [11:0] Q = 12'd3329;

    ntt256 DUT(
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

    // ----- golden arithmetic (mirrors montgomery.v / mod_add.v / mod_sub.v) --
    function [11:0] mont;                 // Montgomery reduction, R = 2^16
        input [31:0] T;
        reg [15:0] m;
        reg [35:0] temp;
        reg [24:0] reduced;
        begin
            m       = (T * 16'd3327) & 16'hFFFF;
            temp    = T + (m * 16'd3329);
            reduced = temp >> 16;
            if (reduced >= 3329) mont = reduced - 3329;
            else                 mont = reduced[11:0];
        end
    endfunction

    function [11:0] addmod;
        input [11:0] a;
        input [11:0] b;
        reg [12:0] s;
        begin
            s = a + b;
            if (s >= Q) addmod = s - Q;
            else        addmod = s[11:0];
        end
    endfunction

    function [11:0] submod;
        input [11:0] a;
        input [11:0] b;
        begin
            if (a >= b) submod = a - b;
            else        submod = a + Q - b;
        end
    endfunction

    reg [11:0] Tt, na, nb;

    initial begin
        clk   = 0;
        reset = 1;
        start = 0;
        load  = 0;
        load_addr_a = 0; load_addr_b = 0;
        load_data_a = 0; load_data_b = 0;
        read_addr   = 0;
        errors = 0;
        checks = 0;

        $readmemh("src/memory/twiddle.mem", tw);

        // Known input vector (already reduced mod q)
        for (k = 0; k < 256; k = k + 1) begin
            init_vec[k] = (k * 7 + 13) % 3329;
            gmem[k]     = init_vec[k];
        end

        // Dump the input vector for external verification.
        $display("================================");
        $display("NTT INPUT (index : value)");
        $display("================================");
        for (k = 0; k < 256; k = k + 1)
            $display("in[%0d] = %0d", k, init_vec[k]);
        $display("");

        #20;
        reset = 0;

        // ---------------------------------------------------------------
        // Load 128 conflict-free pairs (2k, 2k+1)
        // ---------------------------------------------------------------
        $display("Loading 256 coefficients (128 pairs)...");
        load = 1;
        for (k = 0; k < 128; k = k + 1) begin
            @(negedge clk);
            load_addr_a = 2*k;
            load_addr_b = 2*k + 1;
            load_data_a = init_vec[2*k];
            load_data_b = init_vec[2*k + 1];
        end
        @(negedge clk);
        load = 0;

        // ---------------------------------------------------------------
        // Run the hardware NTT
        // ---------------------------------------------------------------
        $display("Running hardware NTT...");
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        wait (done);
        repeat (5) @(posedge clk);

        // ---------------------------------------------------------------
        // Golden NTT on gmem (same schedule / arithmetic as hardware)
        // ---------------------------------------------------------------
        for (st = 0; st < 8; st = st + 1) begin
            d        = 1 << st;
            gps      = 1 << (7 - st);
            tw_shift = (st <= 6) ? (6 - st) : 0;
            for (g = 0; g < gps; g = g + 1) begin
                for (jj = 0; jj < d; jj = jj + 1) begin
                    ai  = (g << (st + 1)) + jj;
                    bi  = ai + d;
                    twi = jj << tw_shift;
                    Tt  = mont(gmem[bi] * tw[twi]);
                    na  = addmod(gmem[ai], Tt);
                    nb  = submod(gmem[ai], Tt);
                    gmem[ai] = na;
                    gmem[bi] = nb;
                end
            end
        end

        // ---------------------------------------------------------------
        // Read hardware memory back and compare to golden
        // ---------------------------------------------------------------
        $display("Reading back and checking against golden model...");
        for (k = 0; k < 256; k = k + 1) begin
            @(negedge clk);
            read_addr = k;
            @(posedge clk);
            #1;
            got       = read_data;
            hw_out[k] = got;
            checks = checks + 1;
            if (got !== gmem[k]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("MISMATCH MEM[%0d]: hw=%0d golden=%0d", k, got, gmem[k]);
            end
        end

        // Dump the hardware NTT result for external verification.
        $display("================================");
        $display("NTT OUTPUT (index : value)");
        $display("================================");
        for (k = 0; k < 256; k = k + 1)
            $display("out[%0d] = %0d", k, hw_out[k]);
        $display("");

        $display("--------------------------------");
        $display("Checked %0d coefficients, %0d mismatches", checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $display("--------------------------------");

        $finish;
    end

endmodule
