`timescale 1ns/1ps

module test_unpack;
    reg clk;
    reg start;
    reg [7:0] byte_in;
    reg byte_valid;

    wire ready;
    wire [11:0] coeff_out;
    wire coeff_valid;
    wire done;

    integer i, j, b, errors, checks;

    reg [11:0] poly [0:255];
    reg [11:0] got_poly [0:255];
    reg [7:0] bytes [0:383];
    reg bits [0:3071];

    unpack #(.D(12)) DUT(
        .clk(clk),
        .start(start),
        .byte_in(byte_in),
        .byte_valid(byte_valid),
        .ready(ready),
        .coeff_out(coeff_out),
        .coeff_valid(coeff_valid),
        .done(done)
    );

    reg start10, bv10;
    reg [7:0] bin10;

    wire ready10, cv10, done10;
    wire [11:0] cout10;

    reg [11:0] poly10 [0:255];
    reg [11:0] got10 [0:255];
    reg [7:0] bytes10 [0:319];

    unpack #(.D(10)) DUT10(
        .clk(clk),
        .start(start10),
        .byte_in(bin10),
        .byte_valid(bv10),
        .ready(ready10),
        .coeff_out(cout10),
        .coeff_valid(cv10),
        .done(done10)
    );

    always #5 clk = ~clk;

    task golden_encode;
        input integer d;
        begin
            for (i = 0; i < 256; i = i + 1)
                for (j = 0; j < d; j = j + 1)
                    bits[i*d + j] = poly[i][j];

            for (b = 0; b < 32*d; b = b + 1) begin
                bytes[b] = 8'd0;
                for (j = 0; j < 8; j = j + 1)
                    if (bits[8*b + j])
                        bytes[b] = bytes[b] | (8'd1 << j);
            end
        end
    endtask

    initial begin
        clk = 0;
        start = 0;
        start10 = 0;
        byte_in = 0;
        bin10 = 0;
        byte_valid = 0;
        bv10 = 0;
        errors = 0;
        checks = 0;

        $display("================================");
        $display("Test 1: D=12 golden + full unpack");
        $display("================================");

        for (i = 0; i < 256; i = i + 1)
            poly[i] = (i * 7 + 13) % 3329;

        golden_encode(12);

        checks = checks + 3;

        if (bytes[0] !== ((poly[0]) & 8'hFF)) begin
            errors = errors + 1; $display("FAIL golden byte0");
        end 
        else 
            $display("PASS golden byte0 = %02h", bytes[0]);

        @(negedge clk); start = 1; @(negedge clk); start = 0;

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
                while (p < 256) begin
                    @(posedge clk);
                    if (coeff_valid) begin
                        got_poly[p] = coeff_out;
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
                    $display("FAIL D12 coeff[%0d]: got=%0d exp=%0d",
                             i, got_poly[i], poly[i]);
            end
        end
        if (errors == 0)
            $display("PASS D=12 full poly unpack");

        $display("================================");
        $display("Test 2: D=10 full unpack");
        $display("================================");

        for (i = 0; i < 256; i = i + 1)
            poly10[i] = (i * 7 + 13) & 10'h3FF;

        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 10; j = j + 1)
                bits[i*10 + j] = poly10[i][j];
        for (b = 0; b < 320; b = b + 1) begin
            bytes10[b] = 8'd0;
            for (j = 0; j < 8; j = j + 1)
                if (bits[8*b + j])
                    bytes10[b] = bytes10[b] | (8'd1 << j);
        end

        @(negedge clk); start10 = 1; @(negedge clk); start10 = 0;

        fork
            begin : feed10
                integer n;
                for (n = 0; n < 320; n = n + 1) begin
                    @(negedge clk);
                    while (!ready10) @(negedge clk);
                    bin10 = bytes10[n];
                    bv10 = 1'b1;
                    @(negedge clk);
                    bv10 = 1'b0;
                end
            end
            begin : collect10
                integer p;
                p = 0;
                while (p < 256) begin
                    @(posedge clk);
                    if (cv10) begin
                        got10[p] = cout10;
                        p = p + 1;
                    end
                end
            end
        join
        wait (done10);
        @(posedge clk);

        for (i = 0; i < 256; i = i + 1) begin
            checks = checks + 1;
            if (got10[i] !== poly10[i]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL D10 coeff[%0d]: got=%0d exp=%0d",
                             i, got10[i], poly10[i]);
            end
        end
        if (errors == 0)
            $display("PASS D=10 full poly unpack");

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
