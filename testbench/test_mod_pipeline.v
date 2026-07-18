`timescale 1ns/1ps

module mod_pipeline_tb;

    //------------------------------------------
    // Inputs
    //------------------------------------------

    reg [11:0] A;
    reg [11:0] B;


    //------------------------------------------
    // Internal wires
    //------------------------------------------

    wire [11:0] A_Prime;
    wire [11:0] B_Prime;

    wire [11:0] Product_Prime;

    wire [11:0] Result;


    //------------------------------------------
    // Expected values
    //------------------------------------------

    integer expected;
    integer raw_product;

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
    // Check
    //------------------------------------------

    task check_result;
    begin

        raw_product = A * B;

        expected = raw_product % 3329;


        #1;


        if(Result !== expected[11:0]) begin

            $display("");
            $display("======================================");
            $display("FAIL");
            $display("======================================");

            $display("A              = %d", A);
            $display("B              = %d", B);

            $display("Raw Product    = %d", raw_product);
            $display("Expected       = %d", expected);

            $display("Got            = %d", Result);

            $display("");
            $display("A_Prime        = %d", A_Prime);
            $display("B_Prime        = %d", B_Prime);

            $display("Product_Prime  = %d", Product_Prime);

            $display("======================================");
            $display("");

        end
        else begin

            $display(
                "PASS: A=%4d B=%4d Result=%4d",
                A,B,Result
            );

        end

    end
    endtask



    //------------------------------------------
    // Test sequence
    //------------------------------------------

    initial begin


        $display("");
        $display("======================================");
        $display(" ML-KEM Montgomery Pipeline Test");
        $display("======================================");


        //----------------------------------
        // Basic tests
        //----------------------------------

        A=0;      B=0;      check_result();
        A=1;      B=1;      check_result();
        A=2;      B=3;      check_result();
        A=10;     B=20;     check_result();


        //----------------------------------
        // Boundary tests
        //----------------------------------

        A=3328; B=1;      check_result();
        A=1;    B=3328;   check_result();

        A=3328; B=3328;   check_result();
        A=3327; B=3327;   check_result();


        //----------------------------------
        // ML-KEM style values
        //----------------------------------

        A=2051; B=881;    check_result();
        A=3210; B=1541;   check_result();
        A=1388; B=2437;   check_result();

        A=902;  B=2631;   check_result();
        A=1111; B=2017;   check_result();


        //----------------------------------
        // Random tests
        //----------------------------------

        $display("");
        $display("Beginning Random Tests...");
        $display("");


        for(i=0;i<1000;i=i+1) begin

            A = $random;
            A = A % 3329;

            if(A < 0)
                A = -A;


            B = $random;
            B = B % 3329;

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