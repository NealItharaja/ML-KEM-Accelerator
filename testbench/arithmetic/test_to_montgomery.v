// Test for To Montgomery Conversion
`timescale 1ns/1ps

module to_mont_tb;
    reg  [11:0] A;
    wire [11:0] A_Prime;

    integer product;
    integer expected;
    integer m;
    integer inter;
    integer i;

    to_montgomery DUT (
        .A(A),
        .A_Prime(A_Prime)
    );

    task check_result;
    begin
        product = A * 1353;
        m = (product * 3327) % 4096;
        inter = (product + m * 3329) / 4096;

        if(inter >= 3329)
            expected = inter - 3329;
        else
            expected = inter;

        if(expected < 0)
            expected = expected + 3329;

        #1;

        if(A_Prime !== expected[11:0]) begin
            $display("FAIL");
            $display("A = %d", A);
            $display("Product = %d", product);
            $display("m = %d", m);
            $display("inter = %d", inter);
            $display("Expected = %d", expected);
            $display("Got = %d", A_Prime);
            $display("---------------------------");

        end
        else begin
            $display("PASS: A=%d  A'=%d", A, A_Prime);
        end
    end
    endtask


    initial begin
        $display("Beginning To Montgomery Tests");
        $display("-----------------------------");

        A=0;      
        check_result();

        A=1;      
        check_result();

        A=2;      
        check_result();

        A=100;    
        check_result();

        A=1000;   
        check_result();

        A=2048;   
        check_result();

        A=3328;   
        check_result();

        for(i=0;i<1000;i=i+1) begin
            A = $random % 3329;

            if(A < 0)
                A = -A;
            check_result();
        end

        $display("-----------------------------");
        $display("Simulation Finished");
        $finish;
    end
endmodule