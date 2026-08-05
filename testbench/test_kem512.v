`timescale 1ns/1ps

// Fast bring-up: ML-KEM-512 keygen -> encaps -> decaps only
module test_kem512;

    reg clk, reset, start;
    reg [1:0] mode;
    reg [255:0] d_seed, z_seed, m_msg;

    wire [255:0] ss;
    wire done, ok;
    wire [15:0] status;

    integer t, errors, checks, b;
    reg [255:0] got_be;

    localparam [255:0] EXP_SS =
        256'h6164b413348f21a5d49b561f18add239a373388ffd8ccd4650b3a11fafbfe553;

    kem #(.LEVEL(512)) dut (
        .clk(clk), .reset(reset), .start(start), .mode(mode),
        .d_seed(d_seed), .z_seed(z_seed), .m_msg(m_msg),
        .din(8'd0), .din_valid(1'b0), .din_last(1'b0), .din_sel(2'd0),
        .ss_out(ss), .done(done), .decaps_ok(ok), .status(status)
    );

    always #5 clk = ~clk;

    initial begin
        $display("TB start");
        $fflush;
    end

    // progress heartbeat
    initial begin
        forever begin
            #1_000_000;
            $display("alive t=%0t status=%h done=%b", $time, status, done);
            $fflush;
        end
    end

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        mode = 0;
        errors = 0;
        checks = 0;
        for (t = 0; t < 32; t = t + 1) begin
            d_seed[8*t +: 8] = t[7:0];
            z_seed[8*t +: 8] = 8'd255 - t[7:0];
            m_msg[8*t +: 8]  = (t * 3) & 8'hFF;
        end
        #50;
        reset = 0;
        #20;

        $display("KEYGEN...");
        $fflush;
        mode = 2'd0;
        @(negedge clk); start = 1;
        @(negedge clk); start = 0;
        wait (done);
        $display("KEYGEN done status=%h @%0t", status, $time);
        $fflush;

        $display("ENCAPS...");
        $fflush;
        mode = 2'd1;
        @(negedge clk); start = 1;
        @(negedge clk); start = 0;
        wait (done);
        for (b = 0; b < 32; b = b + 1)
            got_be[8*(31-b) +: 8] = ss[8*b +: 8];
        checks = checks + 1;
        $display("ENCAPS SS=%064h", got_be);
        $display("EXPECT  SS=%064h", EXP_SS);
        if (got_be !== EXP_SS) begin
            errors = errors + 1;
            $display("FAIL encaps SS");
        end else $display("PASS encaps SS");
        $fflush;

        $display("DECAPS...");
        $fflush;
        mode = 2'd2;
        @(negedge clk); start = 1;
        @(negedge clk); start = 0;
        wait (done);
        for (b = 0; b < 32; b = b + 1)
            got_be[8*(31-b) +: 8] = ss[8*b +: 8];
        checks = checks + 1;
        $display("DECAPS SS=%064h ok=%b status=%h", got_be, ok, status);
        if (got_be !== EXP_SS) begin
            errors = errors + 1;
            $display("FAIL decaps SS");
        end else $display("PASS decaps SS");
        if (!ok) begin
            errors = errors + 1;
            $display("FAIL decaps_ok");
        end
        $fflush;

        if (errors == 0)
            $display("TEST PASSED (%0d checks)", checks);
        else
            $display("TEST FAILED: %0d errors", errors);
        $fflush;
        $finish;
    end

    initial begin
        #2_000_000_000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
