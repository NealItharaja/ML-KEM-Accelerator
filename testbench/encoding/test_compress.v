`timescale 1ns/1ps

// Testbench for Compress_d (default D=10).
// Checks golden formula, edges, full x sweep, and Compress(Decompress(y))==y.

module test_compress;

    reg  [11:0] x;
    wire [9:0]  y10;
    wire [3:0]  y4;
    wire [0:0]  y1;

    reg  [9:0]  y10_in;
    reg  [3:0]  y4_in;
    reg         y1_in;
    wire [11:0] x10, x4, x1;

    integer i, errors, checks, exp;

    compress #(.D(10)) dut10(.x(x), .compressed_x(y10));
    compress #(.D(4))  dut4 (.x(x), .compressed_x(y4));
    compress #(.D(1))  dut1 (.x(x), .compressed_x(y1));

    decompress #(.D(10)) dec10(.y(y10_in), .decompressed_y(x10));
    decompress #(.D(4))  dec4 (.y(y4_in),  .decompressed_y(x4));
    decompress #(.D(1))  dec1 (.y(y1_in),  .decompressed_y(x1));

    function integer cref;
        input integer xi;
        input integer d;
        begin
            cref = (((xi << d) + 1664) / 3329) & ((1 << d) - 1);
        end
    endfunction

    task check;
        input integer got;
        input integer expected;
        input [255:0] name;
        begin
            checks = checks + 1;
            if (got !== expected) begin
                errors = errors + 1;
                $display("FAIL %0s: got=%0d exp=%0d", name, got, expected);
            end
            else
                $display("PASS %0s: %0d", name, got);
        end
    endtask

    initial begin
        errors = 0;
        checks = 0;
        x = 0;
        y10_in = 0;
        y4_in = 0;
        y1_in = 0;

        // ---------------------------------------------------------------
        $display("================================");
        $display("Test 1: D=10 spot checks");
        $display("================================");
        x = 12'd0;    #1; check(y10, cref(0, 10),    "D10 x=0");
        x = 12'd1;    #1; check(y10, cref(1, 10),    "D10 x=1");
        x = 12'd1664; #1; check(y10, cref(1664, 10), "D10 x=1664");
        x = 12'd1665; #1; check(y10, cref(1665, 10), "D10 x=1665");
        x = 12'd3328; #1; check(y10, cref(3328, 10), "D10 x=3328");

        // ---------------------------------------------------------------
        $display("================================");
        $display("Test 2: D=4 and D=1 spot checks");
        $display("================================");
        x = 12'd0;    #1; check(y4, cref(0, 4),    "D4 x=0");
        x = 12'd3328; #1; check(y4, cref(3328, 4), "D4 x=3328");
        x = 12'd0;    #1; check(y1, cref(0, 1),    "D1 x=0");
        x = 12'd1665; #1; check(y1, cref(1665, 1), "D1 x=1665");
        x = 12'd3328; #1; check(y1, cref(3328, 1), "D1 x=3328");

        // ---------------------------------------------------------------
        $display("================================");
        $display("Test 3: full sweep x=0..3328 (D=10)");
        $display("================================");
        for (i = 0; i < 3329; i = i + 1) begin
            x = i;
            #1;
            exp = cref(i, 10);
            checks = checks + 1;
            if (y10 !== exp) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL sweep x=%0d got=%0d exp=%0d", i, y10, exp);
            end
        end
        if (errors == 0)
            $display("PASS full D=10 sweep (3329 values)");

        // ---------------------------------------------------------------
        $display("================================");
        $display("Test 4: Compress(Decompress(y)) == y");
        $display("================================");
        for (i = 0; i < 1024; i = i + 1) begin
            y10_in = i;
            #1;
            x = x10;
            #1;
            checks = checks + 1;
            if (y10 !== i[9:0]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL RT D10 y=%0d got=%0d", i, y10);
            end
        end
        for (i = 0; i < 16; i = i + 1) begin
            y4_in = i;
            #1;
            x = x4;
            #1;
            checks = checks + 1;
            if (y4 !== i[3:0]) begin
                errors = errors + 1;
                $display("FAIL RT D4 y=%0d got=%0d", i, y4);
            end
        end
        for (i = 0; i < 2; i = i + 1) begin
            y1_in = i;
            #1;
            x = x1;
            #1;
            checks = checks + 1;
            if (y1 !== i[0]) begin
                errors = errors + 1;
                $display("FAIL RT D1 y=%0d got=%0d", i, y1);
            end
        end
        if (errors == 0)
            $display("PASS Compress(Decompress(y)) for D=10,4,1");

        $display("--------------------------------");
        $display("Checked %0d, mismatches %0d", checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $display("--------------------------------");
        $finish;
    end

endmodule
