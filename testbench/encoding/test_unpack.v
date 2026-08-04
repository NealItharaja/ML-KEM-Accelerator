`timescale 1ns/1ps

// Testbench for Kyber ByteEncode_12 unpack (poly_frombytes).
//
// Inverse of pack.v:
//   Given bytes y0,y1,y2:
//     coeff_a = {y1[3:0], y0[7:0]}
//     coeff_b = {y2[7:0], y1[7:4]}
//
// This TB will FAIL until you implement unpack.v to match that layout and a
// streaming handshake symmetric to pack (3 bytes in -> 1 coeff pair out).
// Expected unpack ports (mirror of pack):
//   input  clk, start
//   input  [7:0] byte_in
//   input  byte_valid
//   output ready            // high while waiting for a byte
//   output [11:0] coeff_a, coeff_b
//   output coeff_valid
//   output done             // after 128 pairs (384 bytes)

module test_unpack;

    reg clk;
    reg start;
    reg [7:0] byte_in;
    reg byte_valid;

    wire ready;
    wire [11:0] coeff_a, coeff_b;
    wire coeff_valid;
    wire done;

    integer i, errors, checks;
    reg [11:0] poly     [0:255];
    reg [7:0]  bytes    [0:383];
    reg [11:0] got_poly [0:255];
    reg [11:0] ea, eb;

    // DUT — implement these ports in unpack.v to match pack.v's inverse.
    unpack DUT(
        .clk(clk),
        .start(start),
        .byte_in(byte_in),
        .byte_valid(byte_valid),
        .ready(ready),
        .coeff_a(coeff_a),
        .coeff_b(coeff_b),
        .coeff_valid(coeff_valid),
        .done(done)
    );

    always #5 clk = ~clk;

    task encode_pair;
        input  [11:0] a;
        input  [11:0] b;
        output [7:0]  y0;
        output [7:0]  y1;
        output [7:0]  y2;
        begin
            y0 = a[7:0];
            y1 = {b[3:0], a[11:8]};
            y2 = b[11:4];
        end
    endtask

    task decode_pair;
        input  [7:0]  y0;
        input  [7:0]  y1;
        input  [7:0]  y2;
        output [11:0] a;
        output [11:0] b;
        begin
            a = {y1[3:0], y0};
            b = {y2, y1[7:4]};
        end
    endtask

    initial begin
        clk = 0;
        start = 0;
        byte_in = 0;
        byte_valid = 0;
        errors = 0;
        checks = 0;

        // Build a poly and its Kyber byte encoding
        for (i = 0; i < 256; i = i + 1)
            poly[i] = (i * 7 + 13) % 3329;

        for (i = 0; i < 128; i = i + 1)
            encode_pair(poly[2*i], poly[2*i+1],
                        bytes[3*i], bytes[3*i+1], bytes[3*i+2]);

        // ---------------------------------------------------------------
        // Test 1: decode a few known triples (golden software check first)
        // ---------------------------------------------------------------
        $display("================================");
        $display("Test 1: golden decode sanity");
        $display("================================");

        decode_pair(8'h23, 8'hC1, 8'hAB, ea, eb);
        checks = checks + 2;
        if (ea !== 12'h123) begin errors = errors + 1; $display("FAIL golden a"); end
        else $display("PASS golden a = %03h", ea);
        if (eb !== 12'hABC) begin errors = errors + 1; $display("FAIL golden b"); end
        else $display("PASS golden b = %03h", eb);

        // ---------------------------------------------------------------
        // Test 2: hardware unpack of the full poly byte stream
        // ---------------------------------------------------------------
        $display("================================");
        $display("Test 2: full poly unpack");
        $display("================================");

        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        i = 0;
        fork
            begin : feed_bytes
                integer n;
                for (n = 0; n < 384; n = n + 1) begin
                    @(negedge clk);
                    while (!ready) @(negedge clk);
                    byte_in = bytes[n];
                    byte_valid = 1'b1;
                    @(negedge clk);
                    byte_valid = 1'b0;
                end
            end
            begin : collect_coeffs
                integer p;
                p = 0;
                while (p < 128) begin
                    @(posedge clk);
                    if (coeff_valid) begin
                        got_poly[2*p]   = coeff_a;
                        got_poly[2*p+1] = coeff_b;
                        p = p + 1;
                    end
                end
            end
        join

        wait (done);
        @(posedge clk);

        for (i = 0; i < 256; i = i + 1) begin
            checks = checks + 1;
            if (got_poly[i] !== poly[i]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL coeff[%0d]: got=%0d exp=%0d",
                             i, got_poly[i], poly[i]);
            end
        end

        if (errors == 0)
            $display("PASS full poly: unpack recovered all 256 coeffs");

        $display("--------------------------------");
        $display("Checked %0d, mismatches %0d", checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $display("--------------------------------");

        $finish;
    end

endmodule
