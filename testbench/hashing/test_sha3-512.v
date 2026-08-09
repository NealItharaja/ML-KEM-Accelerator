`timescale 1ns/1ps

module test_sha3_512;
    reg clk;
    reg reset;
    reg start;
    reg [7:0] din;
    reg din_valid;
    reg din_last;
    reg squeeze;

    wire ready;
    wire [7:0] dout;
    wire dout_valid;
    wire absorb_done;

    integer errors, checks;

    reg [7:0] got [0:63];
    reg [7:0] exp [0:63];
    reg [7:0] msg [0:255];
    reg [8*64-1:0] name;

    sha3_512 DUT (
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
            for (k = 0; k < 64; k = k + 1) begin
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
        input [511:0] hex;
        integer k;
        begin
            for (k = 0; k < 64; k = k + 1)
                exp[k] = hex[8*(63 - k) +: 8];
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
        load_hex(512'ha69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26);
        absorb_n(0);
        squeeze_n(64);
        check_digest;

        $display("================================");
        $display("Test 2: \"abc\"");
        $display("================================");

        name = "abc";
        load_hex(512'hb751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0);
        msg[0] = 8'h61;
        msg[1] = 8'h62;
        msg[2] = 8'h63;
        absorb_n(3);
        squeeze_n(64);
        check_digest;

        $display("================================");
        $display("Test 3: 00 01 02");
        $display("================================");

        name = "00_01_02";
        load_hex(512'h123119ad1d6e168e0f20a3af1fb2e29c76bc3f83711cf3ee3122ae37ef6a1c2e094bd4bc53b7f9a45c9db1f900f87a3759327a659de341ef1a7b1787afbe9ebc);
        msg[0] = 8'h00;
        msg[1] = 8'h01;
        msg[2] = 8'h02;
        absorb_n(3);
        squeeze_n(64);
        check_digest;

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
