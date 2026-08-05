`timescale 1ns/1ps

// ALU: streamed poly/vector mod_add and mod_sub
module test_alu;

    reg         clk;
    reg         reset;
    reg         start;
    reg         op;
    reg  [2:0]  n_polys;
    reg  [11:0] a_in;
    reg  [11:0] b_in;
    reg         in_valid;
    wire        ready;
    wire [11:0] c_out;
    wire        out_valid;
    wire        done;

    integer i, errors, checks, ngot, ntotal;
    reg [11:0] a_mem [0:1023];
    reg [11:0] b_mem [0:1023];
    reg [11:0] exp  [0:1023];
    reg [11:0] got  [0:1023];
    reg [8*64-1:0] name;

    localparam [11:0] Q = 12'd3329;

    alu DUT (
        .clk(clk),
        .reset(reset),
        .start(start),
        .op(op),
        .n_polys(n_polys),
        .a_in(a_in),
        .b_in(b_in),
        .in_valid(in_valid),
        .ready(ready),
        .c_out(c_out),
        .out_valid(out_valid),
        .done(done)
    );

    always #5 clk = ~clk;

    function [11:0] mod_add_ref;
        input [11:0] a;
        input [11:0] b;
        reg [12:0] s;
        begin
            s = a + b;
            if (s >= Q)
                mod_add_ref = s - Q;
            else
                mod_add_ref = s[11:0];
        end
    endfunction

    function [11:0] mod_sub_ref;
        input [11:0] a;
        input [11:0] b;
        begin
            if (a >= b)
                mod_sub_ref = a - b;
            else
                mod_sub_ref = a + Q - b;
        end
    endfunction

    task fill_vecs;
        input integer n;
        input integer mode; // 0 patterned, 1 near-q
        integer t;
        begin
            for (t = 0; t < n; t = t + 1) begin
                if (mode == 0) begin
                    a_mem[t] = t % Q;
                    b_mem[t] = (3 * t + 7) % Q;
                end
                else begin
                    a_mem[t] = (Q - 1) - (t % 16);
                    b_mem[t] = (t % 16) + 1;
                end
            end
        end
    endtask

    task build_exp;
        input integer n;
        input do_sub;
        integer t;
        begin
            for (t = 0; t < n; t = t + 1) begin
                if (do_sub)
                    exp[t] = mod_sub_ref(a_mem[t], b_mem[t]);
                else
                    exp[t] = mod_add_ref(a_mem[t], b_mem[t]);
            end
        end
    endtask

    task run_op;
        input integer n;
        input do_sub;
        input [2:0] k;
        integer t;
        begin
            ntotal = n;
            ngot = 0;
            op = do_sub;
            n_polys = k;

            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            t = 0;
            while (ngot < n) begin
                @(negedge clk);
                if (ready && (t < n)) begin
                    a_in = a_mem[t];
                    b_in = b_mem[t];
                    in_valid = 1'b1;
                    t = t + 1;
                end
                else begin
                    in_valid = 1'b0;
                end

                @(posedge clk);
                #1;
                if (out_valid) begin
                    got[ngot] = c_out;
                    ngot = ngot + 1;
                end
            end
            in_valid = 1'b0;
            wait (done);
            #1;
        end
    endtask

    task check;
        integer t;
        begin
            for (t = 0; t < ntotal; t = t + 1) begin
                checks = checks + 1;
                if (got[t] !== exp[t]) begin
                    errors = errors + 1;
                    if (errors < 16)
                        $display("FAIL %0s [%0d]: got=%0d exp=%0d",
                                 name, t, got[t], exp[t]);
                end
            end
            if (errors == 0)
                $display("PASS %0s (%0d coeffs)", name, ntotal);
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        op = 0;
        n_polys = 3'd1;
        a_in = 0;
        b_in = 0;
        in_valid = 0;
        errors = 0;
        checks = 0;
        #20;
        reset = 0;

        // ---- poly add (k=1) ----
        $display("================================");
        $display("Test 1: poly add, k=1");
        $display("================================");
        name = "poly_add_k1";
        fill_vecs(256, 0);
        build_exp(256, 0);
        run_op(256, 0, 3'd1);
        check;

        // ---- poly sub (k=1), near wrap ----
        $display("================================");
        $display("Test 2: poly sub, k=1");
        $display("================================");
        name = "poly_sub_k1";
        fill_vecs(256, 1);
        build_exp(256, 1);
        run_op(256, 1, 3'd1);
        check;

        // ---- vector add k=2 ----
        $display("================================");
        $display("Test 3: vector add, k=2");
        $display("================================");
        name = "vec_add_k2";
        fill_vecs(512, 0);
        build_exp(512, 0);
        run_op(512, 0, 3'd2);
        check;

        // ---- vector sub k=3 ----
        $display("================================");
        $display("Test 4: vector sub, k=3");
        $display("================================");
        name = "vec_sub_k3";
        fill_vecs(768, 1);
        build_exp(768, 1);
        run_op(768, 1, 3'd3);
        check;

        // ---- vector add k=4 ----
        $display("================================");
        $display("Test 5: vector add, k=4");
        $display("================================");
        name = "vec_add_k4";
        fill_vecs(1024, 0);
        build_exp(1024, 0);
        run_op(1024, 0, 3'd4);
        check;

        $display("--------------------------------");
        $display("Checked %0d, mismatches %0d", checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $display("--------------------------------");
        $finish;
    end

endmodule
