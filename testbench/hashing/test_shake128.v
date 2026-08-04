`timescale 1ns/1ps

// SHAKE128 reference vectors (32-byte digests from hashlib.shake_128)
module test_shake128;

    reg        clk;
    reg        reset;
    reg        start;
    reg [7:0]  din;
    reg        din_valid;
    reg        din_last;
    wire       ready;
    reg        squeeze;
    wire [7:0] dout;
    wire       dout_valid;
    wire       absorb_done;

    integer i, errors, checks;
    reg [7:0] got [0:31];
    reg [7:0] exp [0:31];
    reg [7:0] msg [0:255];
    reg [8*64-1:0] name;

    shake128 DUT (
        .clk(clk),
        .reset(reset),
        .start(start),
        .din(din),
        .din_valid(din_valid),
        .din_last(din_last),
        .ready(ready),
        .squeeze(squeeze),
        .dout(dout),
        .dout_valid(dout_valid),
        .absorb_done(absorb_done)
    );

    always #5 clk = ~clk;

    task absorb_n;
        input integer n;
        integer k;
        begin
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            wait (ready);
            if (n == 0) begin
                @(negedge clk);
                din_valid = 1'b0;
                din_last  = 1'b1;
                @(negedge clk);
                din_last  = 1'b0;
            end
            else begin
                for (k = 0; k < n; k = k + 1) begin
                    wait (ready);
                    @(negedge clk);
                    din       = msg[k];
                    din_valid = 1'b1;
                    din_last  = (k == n - 1);
                    @(negedge clk);
                    din_valid = 1'b0;
                    din_last  = 1'b0;
                end
            end
            wait (absorb_done);
            #1;
        end
    endtask

    task squeeze_n;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1) begin
                @(negedge clk);
                squeeze = 1'b1;
                @(negedge clk);
                squeeze = 1'b0;
                #1;
                if (!dout_valid) begin
                    errors = errors + 1;
                    $display("FAIL %0s: dout_valid low at byte %0d", name, k);
                end
                got[k] = dout;
            end
        end
    endtask

    task check_digest;
        integer k;
        begin
            for (k = 0; k < 32; k = k + 1) begin
                checks = checks + 1;
                if (got[k] !== exp[k]) begin
                    errors = errors + 1;
                    $display("FAIL %0s byte[%0d]: got=%02h exp=%02h",
                             name, k, got[k], exp[k]);
                end
            end
            if (errors == 0)
                $display("PASS %0s", name);
        end
    endtask

    task load_hex;
        input [255:0] hex;
        integer k;
        begin
            for (k = 0; k < 32; k = k + 1)
                exp[k] = hex[8*(31 - k) +: 8];
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        din = 0;
        din_valid = 0;
        din_last = 0;
        squeeze = 0;
        errors = 0;
        checks = 0;
        #20;
        reset = 0;

        // "" -> 7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26
        $display("================================");
        $display("Test 1: empty message");
        $display("================================");
        name = "empty";
        load_hex(256'h7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26);
        absorb_n(0);
        squeeze_n(32);
        check_digest;

        // "abc" -> 5881092dd818bf5cf8a3ddb793fbcba74097d5c526a6d35f97b83351940f2cc8
        $display("================================");
        $display("Test 2: \"abc\"");
        $display("================================");
        name = "abc";
        load_hex(256'h5881092dd818bf5cf8a3ddb793fbcba74097d5c526a6d35f97b83351940f2cc8);
        msg[0] = 8'h61;
        msg[1] = 8'h62;
        msg[2] = 8'h63;
        absorb_n(3);
        squeeze_n(32);
        check_digest;

        // \x00\x01\x02 -> 203d4b7543731ad58bce7697b39a48eafc4fee548891d1cf94bffd231022a896
        $display("================================");
        $display("Test 3: 00 01 02");
        $display("================================");
        name = "00_01_02";
        load_hex(256'h203d4b7543731ad58bce7697b39a48eafc4fee548891d1cf94bffd231022a896);
        msg[0] = 8'h00;
        msg[1] = 8'h01;
        msg[2] = 8'h02;
        absorb_n(3);
        squeeze_n(32);
        check_digest;

        $display("--------------------------------");
        $display("Checked %0d, mismatches %0d", checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $display("--------------------------------");
        $finish;
    end

endmodule
