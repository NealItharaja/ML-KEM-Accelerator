`timescale 1ns/1ps

module mod_mult_tb;
    //----------------------------------------
    // DUT Inputs
    //----------------------------------------
    reg  [11:0] A;
    reg  [11:0] B;

    //----------------------------------------
    // DUT Output
    //----------------------------------------
    wire [11:0] Result;

    //----------------------------------------
    // Constants
    //----------------------------------------
    integer expected;
    integer i;

    //----------------------------------------
    // Device Under Test
    //----------------------------------------
    mod_mult DUT (
        .A(A),
        .B(B),
        .result(Result)
    );

    //----------------------------------------
    // Compute Expected Result
    //
    // Assumes A and B are already in the
    // Montgomery domain.
    //----------------------------------------
    task check_result;
        integer product;
        integer m;
        integer inter;
    begin

        product = A * B;

        // Montgomery Reduction
        m = (product * 3327) % 4096;
        inter = (product + m * 3329) / 4096;

        if(inter >= 3329)
            expected = inter - 3329;
        else
            expected = inter;

        #1;

        if(Result !== expected[11:0]) begin

            $display("--------------------------------------");
            $display("FAIL");
            $display("A        = %d", A);
            $display("B        = %d", B);
            $display("Product  = %d", product);
            $display("Expected = %d", expected);
            $display("Got      = %d", Result);
            $display("--------------------------------------");

        end
        else begin

            $display("PASS : A=%4d  B=%4d  Result=%4d",
                     A,B,Result);

        end

    end
    endtask

    //----------------------------------------
    // Test Sequence
    //----------------------------------------
    initial begin

        $display("");
        $display("======================================");
        $display(" Montgomery Multiplier Test");
        $display("======================================");

        //----------------------------------
        // Small values
        //----------------------------------

        A=0;      B=0;      check_result();
        A=1;      B=1;      check_result();
        A=1;      B=2;      check_result();
        A=2;      B=3;      check_result();
        A=10;     B=20;     check_result();

        //----------------------------------
        // Boundary values
        //----------------------------------

        A=3328;   B=1;      check_result();
        A=1;      B=3328;   check_result();
        A=3328;   B=3328;   check_result();
        A=3328;   B=3327;   check_result();
        A=3327;   B=3327;   check_result();

        //----------------------------------
        // Typical ML-KEM coefficients
        //----------------------------------

        A=1000;   B=2000;   check_result();
        A=2500;   B=3000;   check_result();
        A=3072;   B=1024;   check_result();
        A=2048;   B=2048;   check_result();

        //----------------------------------
        // Randomized Testing
        //----------------------------------

        $display("");
        $display("Beginning Random Tests...");
        $display("");

        for(i=0;i<1000;i=i+1) begin

            A = $random % 3329;
            if(A < 0)
                A = -A;

            B = $random % 3329;
            if(B < 0)
                B = -B;

            check_result();

        end

        $display("");
        $display("======================================");
        $display(" Simulation Finished");
        $display("======================================");

        $finish;
    end
endmodule