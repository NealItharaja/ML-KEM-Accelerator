`timescale 1ns/1ps

module test_pack;
    reg clk;
    reg start;
    reg [11:0] coeff_in;
    reg coeff_valid;

    wire ready;
    wire [7:0] byte_out;
    wire byte_valid;
    wire done;

    integer i, j, b, errors, checks, nbytes;

    reg [11:0] poly [0:255];
    reg [7:0] got_bytes [0:383];
    reg [7:0] exp_bytes [0:383];
    reg bits [0:3071];

    pack #(.D(12)) DUT(
        .clk(clk),
        .start(start),
        .coeff_in(coeff_in),
        .coeff_valid(coeff_valid),
        .ready(ready),
        .byte_out(byte_out),
        .byte_valid(byte_valid),
        .done(done)
    );

    reg start10, cv10;
    reg [11:0] cin10;

    wire ready10, bv10, done10;
    wire [7:0] bout10;

    reg [7:0] got10 [0:319];
    reg [7:0] exp10 [0:319];

    pack #(.D(10)) DUT10(
        .clk(clk),
        .start(start10),
        .coeff_in(cin10),
        .coeff_valid(cv10),
        .ready(ready10),
        .byte_out(bout10),
        .byte_valid(bv10),
        .done(done10)
    );

    reg start4, cv4;
    reg [11:0] cin4;

    wire ready4, bv4, done4;
    wire [7:0] bout4;

    reg [7:0] got4 [0:127];
    reg [7:0] exp4 [0:127];

    pack #(.D(4)) DUT4(
        .clk(clk),
        .start(start4),
        .coeff_in(cin4),
        .coeff_valid(cv4),
        .ready(ready4),
        .byte_out(bout4),
        .byte_valid(bv4),
        .done(done4)
    );

    always #5 clk = ~clk;

    task golden_encode;
        input integer d;
        begin
            for (i = 0; i < 256; i = i + 1)
                for (j = 0; j < d; j = j + 1)
                    bits[i*d + j] = poly[i][j];

            nbytes = 32 * d;
            for (b = 0; b < nbytes; b = b + 1) begin
                exp_bytes[b] = 8'd0;
                for (j = 0; j < 8; j = j + 1)
                    if (bits[8*b + j])
                        exp_bytes[b] = exp_bytes[b] | (8'd1 << j);
            end
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
            else
                $display("PASS %0s: %02h", name, got);
        end
    endtask

    task push_coeff;
        input [11:0] c;
        begin
            @(negedge clk);
            while (!ready) @(negedge clk);
            coeff_in = c;
            coeff_valid = 1'b1;
            @(negedge clk);
            coeff_valid = 1'b0;
        end
    endtask

    initial begin
        clk = 0;
        start = 0;
        start10 = 0;
        start4 = 0;
        coeff_in = 0;
        cin10 = 0;
        cin4 = 0;
        coeff_valid = 0;
        cv10 = 0;
        cv4 = 0;
        errors = 0;
        checks = 0;

        for (i = 0; i < 256; i = i + 1)
            poly[i] = (i * 7 + 13) % 3329;

        $display("================================");
        $display("Test 1: D=12 known pair as two coeffs");
        $display("================================");
        
        poly[0] = 12'h123;
        poly[1] = 12'hABC;

        for (i = 2; i < 256; i = i + 1)
            poly[i] = 12'd0;

        golden_encode(12);

        @(negedge clk); start = 1; @(negedge clk); start = 0;

        fork
            begin : feed12
                integer p;
                for (p = 0; p < 256; p = p + 1)
                    push_coeff(poly[p]);
            end
            begin : collect12
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

        check_byte(got_bytes[0], 8'h23, "D12 first byte0");
        check_byte(got_bytes[1], 8'hC1, "D12 first byte1");
        check_byte(got_bytes[2], 8'hAB, "D12 first byte2");

        for (i = 0; i < 384; i = i + 1) begin
            checks = checks + 1;
            if (got_bytes[i] !== exp_bytes[i]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL D12 byte[%0d]: got=%02h exp=%02h",
                             i, got_bytes[i], exp_bytes[i]);
            end
        end
        if (errors == 0)
            $display("PASS D=12 full poly (384 bytes)");

        $display("================================");
        $display("Test 2: D=10 full poly (320 bytes)");
        $display("================================");

        for (i = 0; i < 256; i = i + 1)
            poly[i] = (i * 7 + 13) & 10'h3FF;

        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 10; j = j + 1)
                bits[i*10 + j] = poly[i][j];

        for (b = 0; b < 320; b = b + 1) begin
            exp10[b] = 8'd0;
            for (j = 0; j < 8; j = j + 1)
                if (bits[8*b + j])
                    exp10[b] = exp10[b] | (8'd1 << j);
        end

        @(negedge clk); start10 = 1; @(negedge clk); start10 = 0;
        fork
            begin : feed10
                integer p;
                for (p = 0; p < 256; p = p + 1) begin
                    @(negedge clk);
                    while (!ready10) @(negedge clk);
                    cin10 = poly[p];
                    cv10 = 1'b1;
                    @(negedge clk);
                    cv10 = 1'b0;
                end
            end
            begin : collect10
                integer n;
                n = 0;
                while (n < 320) begin
                    @(posedge clk);
                    if (bv10) begin
                        got10[n] = bout10;
                        n = n + 1;
                    end
                end
            end
        join
        wait (done10);
        @(posedge clk);

        for (i = 0; i < 320; i = i + 1) begin
            checks = checks + 1;
            if (got10[i] !== exp10[i]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL D10 byte[%0d]: got=%02h exp=%02h",
                             i, got10[i], exp10[i]);
            end
        end
        if (errors == 0)
            $display("PASS D=10 full poly (320 bytes)");

        $display("================================");
        $display("Test 3: D=4 full poly (128 bytes)");
        $display("================================");

        for (i = 0; i < 256; i = i + 1)
            poly[i] = (i * 3 + 1) & 4'hF;

        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 4; j = j + 1)
                bits[i*4 + j] = poly[i][j];

        for (b = 0; b < 128; b = b + 1) begin
            exp4[b] = 8'd0;
            for (j = 0; j < 8; j = j + 1)
                if (bits[8*b + j])
                    exp4[b] = exp4[b] | (8'd1 << j);
        end

        @(negedge clk); start4 = 1; @(negedge clk); start4 = 0;
        fork
            begin : feed4
                integer p;
                for (p = 0; p < 256; p = p + 1) begin
                    @(negedge clk);
                    while (!ready4) @(negedge clk);
                    cin4 = poly[p];
                    cv4 = 1'b1;
                    @(negedge clk);
                    cv4 = 1'b0;
                end
            end
            begin : collect4
                integer n;
                n = 0;
                while (n < 128) begin
                    @(posedge clk);
                    if (bv4) begin
                        got4[n] = bout4;
                        n = n + 1;
                    end
                end
            end
        join
        wait (done4);
        @(posedge clk);

        for (i = 0; i < 128; i = i + 1) begin
            checks = checks + 1;
            if (got4[i] !== exp4[i]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL D4 byte[%0d]: got=%02h exp=%02h",
                             i, got4[i], exp4[i]);
            end
        end
        if (errors == 0)
            $display("PASS D=4 full poly (128 bytes)");

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
