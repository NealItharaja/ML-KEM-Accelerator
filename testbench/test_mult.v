// Test for Modular Multiplication
`timescale 1ns/1ps

module mod_mult_tb;
    //------------------------------------------
    // Inputs
    //------------------------------------------
    reg [11:0] A;
    reg [11:0] B;

    //------------------------------------------
    // Output
    //------------------------------------------
    wire [11:0] Product;

    //------------------------------------------
    // Test Variables
    //------------------------------------------
    integer expected;
    integer product;
    integer m;
    integer inter;
    integer i;

    //------------------------------------------
    // DUT
    //------------------------------------------

    mod_mult DUT(
        .A(A),
        .B(B),
        .result(Product)
    );

    //------------------------------------------
    // Check Result
    //------------------------------------------

    task check_result;
    begin

        //--------------------------------------
        // Software Montgomery Reduction
        //--------------------------------------

        product = A * B;

        m = (product * 3327) & 12'hFFF;;
        inter = (product + m * 3329) / 4096;

        if(inter >= 3329)
            expected = inter - 3329;
        else
            expected = inter;

        #1;

        if(Product !== expected[11:0]) begin

            $display("");
            $display("======================================");
            $display("FAIL");
            $display("======================================");
            $display("A                = %d", A);
            $display("B                = %d", B);
            $display("Raw Product      = %d", product);
            $display("m                = %d", m);
            $display("Intermediate      = %d", inter);
            $display("");
            $display("Expected Product = %d", expected);
            $display("Actual Product   = %d", Product);
            $display("======================================");
            $display("");

        end
        else begin

            $display("PASS: A=%4d  B=%4d  Product=%4d",
                     A,B,Product);

        end

    end
    endtask

    //------------------------------------------
    // Test Sequence
    //------------------------------------------

    initial begin

        $display("");
        $display("======================================");
        $display(" Montgomery Modular Multiplier Test");
        $display("======================================");

        //----------------------------------
        // Small values
        //----------------------------------

        A=0;      B=0;      check_result();
        A=1;      B=1;      check_result();
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
        // Known Montgomery values
        //----------------------------------

        A=1464;   B=2997;   check_result();
        A=1573;   B=3280;   check_result();
        A=883;    B=1139;   check_result();
        A=1515;   B=2137;   check_result();
        A=929;    B=774;    check_result();
        A=2675;   B=2606;   check_result();
        A=2469;   B=2638;   check_result();

        //----------------------------------
        // Random testing
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
        $display("Simulation Finished");
        $display("======================================");

        $finish;
    end
endmodule