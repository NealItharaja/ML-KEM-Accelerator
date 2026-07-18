// Modular Multiplication test

`timescale 1ns/1ps

module mod_pipeline_tb;
    //------------------------------------------
    // Inputs
    //------------------------------------------
    reg [11:0] A;
    reg [11:0] B;

    //------------------------------------------
    // Internal Wires
    //------------------------------------------
    wire [11:0] A_Prime;
    wire [11:0] B_Prime;
    wire [11:0] Product_Prime;
    wire [11:0] Result;

    //------------------------------------------
    // Expected Value
    //------------------------------------------
    integer expected;
    integer i;

    //------------------------------------------
    // DUT
    //------------------------------------------

    to_mont ToMontA(
        .A(A),
        .A_Prime(A_Prime)
    );

    to_mont ToMontB(
        .A(B),
        .A_Prime(B_Prime)
    );

    mod_mult Multiplier(
        .A(A_Prime),
        .B(B_Prime),
        .result(Product_Prime)
    );

    from_mont FromMont(
        .C(Product_Prime),
        .result(Result)
    );

    //------------------------------------------
    // Compute Expected Result
    //------------------------------------------

    task check_result;
    begin

        expected = (A * B) % 3329;

        #1;

        if(Result !== expected[11:0]) begin

            $display("FAIL");
            $display("A          = %d", A);
            $display("B          = %d", B);
            $display("Expected   = %d", expected);
            $display("Got        = %d", Result);
            $display("A'         = %d", A_Prime);
            $display("B'         = %d", B_Prime);
            $display("Product'   = %d", Product_Prime);
            $display("-------------------------------------");

        end
        else begin

            $display("PASS: A=%4d  B=%4d  Result=%4d", A, B, Result);

        end

    end
    endtask

    //------------------------------------------
    // Test Sequence
    //------------------------------------------

    initial begin

        $display("");
        $display("=======================================");
        $display(" Integrated Montgomery Multiplier Test ");
        $display("=======================================");

        //----------------------------------
        // Edge Cases
        //----------------------------------

        A = 0;      B = 0;      check_result();
        A = 0;      B = 1;      check_result();
        A = 1;      B = 0;      check_result();
        A = 1;      B = 1;      check_result();
        A = 1;      B = 2;      check_result();
        A = 2;      B = 3;      check_result();

        //----------------------------------
        // Boundary Values
        //----------------------------------

        A = 3328;   B = 1;      check_result();
        A = 1;      B = 3328;   check_result();
        A = 3328;   B = 3328;   check_result();
        A = 3328;   B = 3327;   check_result();
        A = 3327;   B = 3327;   check_result();

        //----------------------------------
        // Typical ML-KEM Values
        //----------------------------------

        A = 100;    B = 200;    check_result();
        A = 500;    B = 600;    check_result();
        A = 1000;   B = 2000;   check_result();
        A = 2048;   B = 2048;   check_result();
        A = 2500;   B = 3000;   check_result();
        A = 3072;   B = 1024;   check_result();

        //----------------------------------
        // Random Testing
        //----------------------------------

        $display("");
        $display("Beginning Random Tests...");
        $display("");

        for(i = 0; i < 1000; i = i + 1) begin

            A = $random % 3329;
            if(A < 0)
                A = -A;

            B = $random % 3329;
            if(B < 0)
                B = -B;

            check_result();

        end

        $display("");
        $display("=======================================");
        $display(" Simulation Finished");
        $display("=======================================");

        $finish;
    end
endmodule