`timescale 1ns/1ps

// SamplePolyCBD_eta vs hashlib.shake_256 + CBD golden hex vectors
module test_sample_poly_CBD;

    reg         clk;
    reg         reset;
    reg         start2;
    reg         start3;
    reg [255:0] seed;
    reg [7:0]   nonce;
    wire [11:0] coeff_out2;
    wire        coeff_valid2;
    wire        done2;
    wire [11:0] coeff_out3;
    wire        coeff_valid3;
    wire        done3;

    integer k, errors, checks, ngot, which;
    reg [11:0] got  [0:255];
    reg [11:0] exp2 [0:255];
    reg [11:0] exp3 [0:255];
    reg [8*64-1:0] name;

    sample_poly_CBD #(.ETA(2)) DUT2 (
        .clk(clk),
        .reset(reset),
        .start(start2),
        .seed(seed),
        .nonce(nonce),
        .coeff_out(coeff_out2),
        .coeff_valid(coeff_valid2),
        .done(done2)
    );

    sample_poly_CBD #(.ETA(3)) DUT3 (
        .clk(clk),
        .reset(reset),
        .start(start3),
        .seed(seed),
        .nonce(nonce),
        .coeff_out(coeff_out3),
        .coeff_valid(coeff_valid3),
        .done(done3)
    );

    always #5 clk = ~clk;

    task run_sample2;
        begin
            ngot = 0;
            @(negedge clk);
            start2 = 1'b1;
            @(negedge clk);
            start2 = 1'b0;

            while (ngot < 256) begin
                @(posedge clk);
                if (coeff_valid2) begin
                    got[ngot] = coeff_out2;
                    ngot = ngot + 1;
                end
            end
            wait (done2);
            #1;
        end
    endtask

    task run_sample3;
        begin
            ngot = 0;
            @(negedge clk);
            start3 = 1'b1;
            @(negedge clk);
            start3 = 1'b0;

            while (ngot < 256) begin
                @(posedge clk);
                if (coeff_valid3) begin
                    got[ngot] = coeff_out3;
                    ngot = ngot + 1;
                end
            end
            wait (done3);
            #1;
        end
    endtask

    task check_got;
        begin
            for (k = 0; k < 256; k = k + 1) begin
                checks = checks + 1;
                if (which == 2) begin
                    if (got[k] !== exp2[k]) begin
                        errors = errors + 1;
                        if (errors < 16)
                            $display("FAIL %0s coeff[%0d]: got=%0d exp=%0d",
                                     name, k, got[k], exp2[k]);
                    end
                end
                else begin
                    if (got[k] !== exp3[k]) begin
                        errors = errors + 1;
                        if (errors < 16)
                            $display("FAIL %0s coeff[%0d]: got=%0d exp=%0d",
                                     name, k, got[k], exp3[k]);
                    end
                end
            end
            if (errors == 0)
                $display("PASS %0s (256 coeffs)", name);
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        start2 = 0;
        start3 = 0;
        seed = 256'd0;
        nonce = 8'd0;
        errors = 0;
        checks = 0;
        which = 2;
        $readmemh("testbench/generation/vectors/sample_cbd2_seed0_n0.hex", exp2);
        $readmemh("testbench/generation/vectors/sample_cbd3_seed0_n0.hex", exp3);
        #20;
        reset = 0;

        $display("================================");
        $display("Test 1: CBD eta=2, seed=0, nonce=0");
        $display("================================");
        name = "cbd2_seed0_n0";
        which = 2;
        run_sample2;
        check_got;

        $display("================================");
        $display("Test 2: CBD eta=3, seed=0, nonce=0");
        $display("================================");
        name = "cbd3_seed0_n0";
        which = 3;
        run_sample3;
        check_got;

        $display("--------------------------------");
        $display("Checked %0d, mismatches %0d", checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $display("--------------------------------");
        $finish;
    end

endmodule
