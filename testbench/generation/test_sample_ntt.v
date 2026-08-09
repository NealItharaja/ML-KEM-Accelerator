`timescale 1ns/1ps

module test_sample_ntt;
    reg clk;
    reg reset;
    reg start;
    reg [255:0] rho;
    reg [7:0] i;
    reg [7:0] j;

    wire [11:0] coeff_out;
    wire coeff_valid;
    wire done;

    integer k, errors, checks, ngot, which;

    reg [11:0] got [0:255];
    reg [11:0] exp0 [0:255];
    reg [11:0] exp1 [0:255];
    reg [8*64-1:0] name;

    sample_ntt DUT (
        .clk(clk),
        .reset(reset),
        .start(start),
        .rho(rho),
        .i(i),
        .j(j),
        .coeff_out(coeff_out),
        .coeff_valid(coeff_valid),
        .done(done)
    );

    always #5 clk = ~clk;

    task run_sample;
        begin
            ngot = 0;
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            while (ngot < 256) begin
                @(posedge clk);
                if (coeff_valid) begin
                    got[ngot] = coeff_out;
                    ngot = ngot + 1;
                end
            end
            wait (done);
            #1;
        end
    endtask

    task check_got;
        begin
            for (k = 0; k < 256; k = k + 1) begin
                checks = checks + 1;
                if (which == 0) begin
                    if (got[k] !== exp0[k]) begin
                        errors = errors + 1;
                        if (errors < 16)
                            $display("FAIL %0s coeff[%0d]: got=%0d exp=%0d",
                                     name, k, got[k], exp0[k]);
                    end
                end
                else begin
                    if (got[k] !== exp1[k]) begin
                        errors = errors + 1;
                        if (errors < 16)
                            $display("FAIL %0s coeff[%0d]: got=%0d exp=%0d",
                                     name, k, got[k], exp1[k]);
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
        start = 0;
        rho = 256'd0;
        i = 8'd0;
        j = 8'd0;
        errors = 0;
        checks = 0;
        which = 0;
        $readmemh("testbench/generation/vectors/sample_ntt_rho0_i0_j0.hex", exp0);
        $readmemh("testbench/generation/vectors/sample_ntt_rho0_i1_j2.hex", exp1);
        #20;
        reset = 0;

        $display("================================");
        $display("Test 1: rho=0, i=0, j=0");
        $display("================================");

        name = "rho0_i0_j0";
        which = 0;
        i = 8'd0;
        j = 8'd0;
        run_sample;
        check_got;

        $display("================================");
        $display("Test 2: rho=0, i=1, j=2");
        $display("================================");

        name = "rho0_i1_j2";
        which = 1;
        i = 8'd1;
        j = 8'd2;
        run_sample;
        check_got;

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
