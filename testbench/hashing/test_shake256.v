`timescale 1ns/1ps

// SHAKE256 reference vectors (32-byte digests from hashlib.shake_256)
module test_shake256;

    reg clk;
    reg reset;
    reg start;
    reg [7:0] din;
    reg din_valid;
    reg din_last;
    wire ready;
    reg squeeze;
    wire [7:0] dout;
    wire dout_valid;
    wire absorb_done;

    integer errors, checks;
    reg [7:0] got [0:31];
    reg [7:0] exp [0:31];
    reg [7:0] msg [0:255];
    reg [8*64-1:0] name;

    shake256 DUT (
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
                din_last = 1'b1;
                @(negedge clk);
                din_last = 1'b0;
            end
            else begin
                for (k = 0; k < n; k = k + 1) begin
                    wait (ready);
                    @(negedge clk);
                    din = msg[k];
                    din_valid = 1'b1;
                    din_last = (k == n - 1);
                    @(negedge clk);
                    din_valid = 1'b0;
                    din_last = 1'b0;
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

        $display("================================");
        $display("Test 1: empty message");
        $display("================================");
        name = "empty";
        load_hex(256'h46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f);
        absorb_n(0);
        squeeze_n(32);
        check_digest;

        $display("================================");
        $display("Test 2: \"abc\"");
        $display("================================");
        name = "abc";
        load_hex(256'h483366601360a8771c6863080cc4114d8db44530f8f1e1ee4f94ea37e78b5739);
        msg[0] = 8'h61;
        msg[1] = 8'h62;
        msg[2] = 8'h63;
        absorb_n(3);
        squeeze_n(32);
        check_digest;

        $display("================================");
        $display("Test 3: 00 01 02");
        $display("================================");
        name = "00_01_02";
        load_hex(256'h714501167ead924ea87e422993eea1e67df0ead7b93140c1109470fb66d50aaa);
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
