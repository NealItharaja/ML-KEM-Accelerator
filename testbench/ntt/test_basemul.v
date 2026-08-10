`timescale 1ns/1ps

// Testbench for Kyber basemul (degree-1 NTT-domain multiply).

module test_basemul;
    reg clk;
    reg [11:0] a0, a1, b0, b1, twiddle;
    reg [11:0] e0, e1;

    wire [11:0] r0, r1;

    integer errors, checks;

    localparam [11:0] Q = 12'd3329;

    basemul DUT(
        .clk(clk),
        .a0(a0),
        .a1(a1),
        .b0(b0),
        .b1(b1),
        .twiddle(twiddle),
        .r0(r0),
        .r1(r1)
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

    function [11:0] fqmul;
        input [11:0] x;
        input [11:0] y;
        begin
            fqmul = mont(x * y);
        end
    endfunction

    function [11:0] addmod;
        input [11:0] x;
        input [11:0] y;
        reg [12:0] s;
        begin
            s = x + y;
            if (s >= Q)
                addmod = s - Q;
            else
                addmod = s[11:0];
        end
    endfunction

    task golden;
        input [11:0] xa0, xa1, xb0, xb1, xz;
        output [11:0] yr0, yr1;
        begin
            yr0 = addmod(fqmul(xa0, xb0), fqmul(fqmul(xa1, xb1), xz));
            yr1 = addmod(fqmul(xa0, xb1), fqmul(xa1, xb0));
        end
    endtask

    task check_pair;
        input [11:0] xa0, xa1, xb0, xb1, xz;
        input [255:0] name;
        begin
            a0 = xa0; a1 = xa1; b0 = xb0; b1 = xb1; twiddle = xz;
            golden(xa0, xa1, xb0, xb1, xz, e0, e1);
            @(posedge clk);
            #1;
            checks = checks + 2;
            if (r0 !== e0) begin
                errors = errors + 1;
                $display("FAIL %0s r0: got=%0d exp=%0d", name, r0, e0);
            end
            else
                $display("PASS %0s r0=%0d", name, r0);
            if (r1 !== e1) begin
                errors = errors + 1;
                $display("FAIL %0s r1: got=%0d exp=%0d", name, r1, e1);
            end
            else
                $display("PASS %0s r1=%0d", name, r1);
        end
    endtask

    integer i;

    initial begin
        clk = 0;
        a0 = 0; a1 = 0; b0 = 0; b1 = 0; twiddle = 0;
        errors = 0;
        checks = 0;

        @(posedge clk);

        $display("================================");
        $display("Test 1: trivial / edges");
        $display("================================");
        check_pair(12'd0, 12'd0, 12'd0, 12'd0, 12'd1, "zeros");
        check_pair(12'd1, 12'd0, 12'd1, 12'd0, 12'd1, "a0*b0 only");
        check_pair(12'd0, 12'd1, 12'd0, 12'd1, 12'd1, "zeta*a1*b1");
        check_pair(12'd1, 12'd1, 12'd1, 12'd1, 12'd1, "all ones zeta=1");

        $display("================================");
        $display("Test 2: Kyber-like values");
        $display("================================");
        check_pair(12'd17, 12'd42, 12'd99, 12'd123, 12'd2285, "sample A");
        check_pair(12'd3328, 12'd1, 12'd2, 12'd3327, 12'd2571, "sample B");
        check_pair(12'd1000, 12'd2000, 12'd3000, 12'd400, 12'd2970, "sample C");

        $display("================================");
        $display("Test 3: random sweep");
        $display("================================");
        for (i = 0; i < 64; i = i + 1) begin
            check_pair((i * 17 + 3) % 3329, (i * 41 + 5) % 3329, (i * 13 + 7) % 3329, (i * 29 + 11) % 3329, (i * 53 + 2285) % 3329, "rand");
        end

        $display("--------------------------------");
        $display("Checked %0d, mismatches %0d", checks, errors);
        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");
        $display("--------------------------------");
        $finish;
    end
endmodule
