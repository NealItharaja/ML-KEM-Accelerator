`timescale 1ns/1ps

// Testbench for Kyber ByteEncode_12 pack.
// Checks: single-pair encoding, a few hand pairs, and a full 256-coeff poly
// against the poly_tobytes bit layout.

module test_pack;
    reg clk;
    reg start;
    reg [11:0] coeff_a, coeff_b;
    reg coeff_valid;

    wire ready;
    wire [7:0] byte_out;
    wire byte_valid;
    wire done;

    integer i, errors, checks;
    reg [11:0] poly [0:255];
    reg [7:0]  got_bytes [0:383];
    reg [7:0]  exp_bytes [0:383];
    reg [7:0]  b0, b1, b2;

    pack DUT(
        .clk(clk),
        .start(start),
        .coeff_a(coeff_a),
        .coeff_b(coeff_b),
        .coeff_valid(coeff_valid),
        .ready(ready),
        .byte_out(byte_out),
        .byte_valid(byte_valid),
        .done(done)
    );

    always #5 clk = ~clk;

    // Kyber poly_tobytes for one pair
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

    // Push one pair, collect the 3 emitted bytes
    task push_pair_get_bytes;
        input  [11:0] a;
        input  [11:0] b;
        output [7:0]  y0;
        output [7:0]  y1;
        output [7:0]  y2;
        begin
            @(negedge clk);
            while (!ready) @(negedge clk);
            coeff_a = a;
            coeff_b = b;
            coeff_valid = 1'b1;
            @(negedge clk);
            coeff_valid = 1'b0;

            while (!byte_valid) @(posedge clk);
            y0 = byte_out;
            @(posedge clk);
            while (!byte_valid) @(posedge clk);
            y1 = byte_out;
            @(posedge clk);
            while (!byte_valid) @(posedge clk);
            y2 = byte_out;
        end
    endtask

    task check_byte;
        input [7:0] got;
        input [7:0] exp;
        input [255:0] name;
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL %0s: got=%02h exp=%02h", name, got, exp);
            end
            else begin
                $display("PASS %0s: %02h", name, got);
            end
        end
    endtask

    initial begin
        clk = 0;
        start = 0;
        coeff_a = 0;
        coeff_b = 0;
        coeff_valid = 0;
        errors = 0;
        checks = 0;

        // ---------------------------------------------------------------
        // Test 1: single pair, known values
        // a=0x123 -> bytes use low 12 bits 0x123
        // b=0xABC
        // byte0=0x23, byte1={0xC,0x1}=0xC1, byte2=0xAB
        // ---------------------------------------------------------------
        $display("================================");
        $display("Test 1: single pair (0x123, 0xABC)");
        $display("================================");

        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        push_pair_get_bytes(12'h123, 12'hABC, b0, b1, b2);
        encode_pair(12'h123, 12'hABC, exp_bytes[0], exp_bytes[1], exp_bytes[2]);
        check_byte(b0, exp_bytes[0], "pair0 byte0");
        check_byte(b1, exp_bytes[1], "pair0 byte1");
        check_byte(b2, exp_bytes[2], "pair0 byte2");

        // ---------------------------------------------------------------
        // Test 2: edge pairs
        // ---------------------------------------------------------------
        $display("================================");
        $display("Test 2: edge pairs");
        $display("================================");

        // Restart a fresh poly for a clean pair counter — feed 128 pairs
        // below in test 3. For now just check encoding math on a few pairs
        // by restarting each time (done will fire after 128; for unit checks
        // of the bit layout we only need the 3 bytes).
        @(negedge clk); start = 1; @(negedge clk); start = 0;
        push_pair_get_bytes(12'h000, 12'h000, b0, b1, b2);
        check_byte(b0, 8'h00, "zero byte0");
        check_byte(b1, 8'h00, "zero byte1");
        check_byte(b2, 8'h00, "zero byte2");

        @(negedge clk); start = 1; @(negedge clk); start = 0;
        push_pair_get_bytes(12'hFFF, 12'hFFF, b0, b1, b2);
        check_byte(b0, 8'hFF, "ones byte0");
        check_byte(b1, 8'hFF, "ones byte1");
        check_byte(b2, 8'hFF, "ones byte2");

        @(negedge clk); start = 1; @(negedge clk); start = 0;
        push_pair_get_bytes(12'h001, 12'h010, b0, b1, b2);
        encode_pair(12'h001, 12'h010, exp_bytes[0], exp_bytes[1], exp_bytes[2]);
        check_byte(b0, exp_bytes[0], "small byte0");
        check_byte(b1, exp_bytes[1], "small byte1");
        check_byte(b2, exp_bytes[2], "small byte2");

        // ---------------------------------------------------------------
        // Test 3: full 256-coefficient polynomial
        // ---------------------------------------------------------------
        $display("================================");
        $display("Test 3: full poly (256 coeffs)");
        $display("================================");

        for (i = 0; i < 256; i = i + 1)
            poly[i] = (i * 7 + 13) % 3329;

        for (i = 0; i < 128; i = i + 1)
            encode_pair(poly[2*i], poly[2*i+1],
                        exp_bytes[3*i], exp_bytes[3*i+1], exp_bytes[3*i+2]);

        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        i = 0;
        fork
            begin : feed
                integer p;
                for (p = 0; p < 128; p = p + 1) begin
                    @(negedge clk);
                    while (!ready) @(negedge clk);
                    coeff_a = poly[2*p];
                    coeff_b = poly[2*p+1];
                    coeff_valid = 1'b1;
                    @(negedge clk);
                    coeff_valid = 1'b0;
                end
            end
            begin : collect
                integer n;
                n = 0;
                while (n < 384) begin
                    @(posedge clk);
                    if (byte_valid) begin
                        got_bytes[n] = byte_out;
                        n = n + 1;
                    end
                end
            end
        join

        wait (done);
        @(posedge clk);

        for (i = 0; i < 384; i = i + 1) begin
            checks = checks + 1;
            if (got_bytes[i] !== exp_bytes[i]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL poly byte[%0d]: got=%02h exp=%02h",
                             i, got_bytes[i], exp_bytes[i]);
            end
        end

        if (errors == 0)
            $display("PASS full poly: all 384 bytes match Kyber poly_tobytes");

        $display("--------------------------------");
        $display("Checked %0d, mismatches %0d", checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $display("--------------------------------");

        $finish;
    end

endmodule
