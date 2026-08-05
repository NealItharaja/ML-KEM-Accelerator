`timescale 1ns/1ps

// Full CCA roundtrip for ML-KEM-512/768/1024 vs mlkem_ref.py expected SS
module test_kem;

    reg clk, reset, start;
    reg [1:0] mode;
    reg [255:0] d_seed, z_seed, m_msg;
    integer level_sel; // 512, 768, or 1024

    wire [255:0] ss512, ss768, ss1024;
    wire done512, done768, done1024;
    wire ok512, ok768, ok1024;
    wire [15:0] st512, st768, st1024;

    integer t, errors, checks;
    reg [255:0] got_be;

    // Fixed coins matching testbench/verify_kem.py / mlkem_ref.py (SS big-endian):
    // d=bytes(range(32)), z=bytes(255-i), m=bytes((i*3)&0xFF)
    localparam [255:0] EXP_SS_512 =
        256'h6164b413348f21a5d49b561f18add239a373388ffd8ccd4650b3a11fafbfe553;
    localparam [255:0] EXP_SS_768 =
        256'h490a3f33ab31400f33db15480b3aef60f46d7f205ad4ef74c473deaf0c12443c;
    localparam [255:0] EXP_SS_1024 =
        256'hf18d073ab55f138070a775fbae4f699f7390398e8124be83f15d79321df26c7f;

    kem #(.LEVEL(512)) dut512 (
        .clk(clk), .reset(reset), .start(start && (level_sel == 512)), .mode(mode),
        .d_seed(d_seed), .z_seed(z_seed), .m_msg(m_msg),
        .din(8'd0), .din_valid(1'b0), .din_last(1'b0), .din_sel(2'd0),
        .ss_out(ss512), .done(done512), .decaps_ok(ok512), .status(st512)
    );
    kem #(.LEVEL(768)) dut768 (
        .clk(clk), .reset(reset), .start(start && (level_sel == 768)), .mode(mode),
        .d_seed(d_seed), .z_seed(z_seed), .m_msg(m_msg),
        .din(8'd0), .din_valid(1'b0), .din_last(1'b0), .din_sel(2'd0),
        .ss_out(ss768), .done(done768), .decaps_ok(ok768), .status(st768)
    );
    kem #(.LEVEL(1024)) dut1024 (
        .clk(clk), .reset(reset), .start(start && (level_sel == 1024)), .mode(mode),
        .d_seed(d_seed), .z_seed(z_seed), .m_msg(m_msg),
        .din(8'd0), .din_valid(1'b0), .din_last(1'b0), .din_sel(2'd0),
        .ss_out(ss1024), .done(done1024), .decaps_ok(ok1024), .status(st1024)
    );

    always #5 clk = ~clk;

    task set_coins;
        begin
            for (t = 0; t < 32; t = t + 1) begin
                d_seed[8*t +: 8] = t[7:0];
                z_seed[8*t +: 8] = 8'd255 - t[7:0];
                m_msg[8*t +: 8]  = (t * 3) & 8'hFF;
            end
        end
    endtask

    task to_be;
        input [255:0] le;
        output [255:0] be;
        integer b;
        begin
            for (b = 0; b < 32; b = b + 1)
                be[8*(31 - b) +: 8] = le[8*b +: 8];
        end
    endtask

    task run_op;
        input [1:0] md;
        input integer lvl;
        time t_start;
        begin
            level_sel = lvl;
            mode = md;
            t_start = $time;
            @(negedge clk);
            start = 1;
            @(negedge clk);
            start = 0;
            if (lvl == 512) wait (done512);
            else if (lvl == 768) wait (done768);
            else wait (done1024);
            #1;
            $display("    [HW-TIME] Mode=%0d Level=%0d took %0d ns (status=%h)",
                md, lvl, $time - t_start,
                (lvl == 512) ? st512 : (lvl == 768) ? st768 : st1024);
        end
    endtask

    task check_ss;
        input [255:0] got;
        input [255:0] exp;
        input [8*32-1:0] tag;
        input expect_ok;
        input got_ok;
        begin
            to_be(got, got_be);
            checks = checks + 1;
            $display("  [%0s] GOT_SS=%064h", tag, got_be);
            $display("  [%0s] EXP_SS=%064h", tag, exp);
            if (got_be !== exp) begin
                errors = errors + 1;
                $display("  [FAIL] %0s SS mismatch!", tag);
            end
            else begin
                $display("  [PASS] %0s SS matches golden reference.", tag);
            end
            if (expect_ok && !got_ok) begin
                errors = errors + 1;
                $display("  [FAIL] %0s decaps_ok expected 1 but got 0!", tag);
            end
        end
    endtask

    task roundtrip;
        input integer lvl;
        input [255:0] exp;
        begin
            $display("======================================================");
            $display(" ML-KEM-%0d: KeyGen -> Encapsulation -> Decapsulation", lvl);
            $display("======================================================");
            $display("  [Step 1] Running KeyGen (mode=0)...");
            run_op(2'd0, lvl);
            $display("  [Step 2] Running Encapsulation (mode=1)...");
            run_op(2'd1, lvl);
            if (lvl == 512)
                check_ss(ss512, exp, "512 ENCAPS", 0, 0);
            else if (lvl == 768)
                check_ss(ss768, exp, "768 ENCAPS", 0, 0);
            else
                check_ss(ss1024, exp, "1024 ENCAPS", 0, 0);

            $display("  [Step 3] Running Decapsulation (mode=2)...");
            run_op(2'd2, lvl);
            if (lvl == 512)
                check_ss(ss512, exp, "512 DECAPS", 1, ok512);
            else if (lvl == 768)
                check_ss(ss768, exp, "768 DECAPS", 1, ok768);
            else
                check_ss(ss1024, exp, "1024 DECAPS", 1, ok1024);
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        mode = 2'd0;
        level_sel = 512;
        errors = 0;
        checks = 0;
        set_coins;
        #50;
        reset = 0;
        #20;

        roundtrip(512, EXP_SS_512);
        roundtrip(768, EXP_SS_768);
        roundtrip(1024, EXP_SS_1024);

        $display("=================================================");
        if (errors == 0)
            $display(" ALL TESTS PASSED SUCCESSFULLY! (%0d checks)", checks);
        else
            $display(" TEST FAILED: %0d errors / %0d checks", errors, checks);
        $display("=================================================");
        $finish;
    end

    initial begin
        #5_000_000_000;
        $display("TIMEOUT");
        $finish;
    end
endmodule