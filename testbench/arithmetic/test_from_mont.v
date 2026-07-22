// Test for From Montgomery Conversion
`timescale 1ns/1ps

module from_mont_tb;
    reg [11:0] C;
    wire [11:0] Result;

    integer expected;
    integer m;
    integer inter;
    integer i;

    from_mont DUT(
        .C(C),
        .result(Result)
    );

    task check_result;
    begin

        m = (C * 3327) % 4096;
        inter = (C + m * 3329) / 4096;

        if(inter >= 3329)
            expected = inter - 3329;
        else
            expected = inter;

        #1;

        if(Result !== expected[11:0]) begin

            $display("FAIL");
            $display("C        = %d",C);
            $display("Expected = %d",expected);
            $display("Got      = %d",Result);
            $display("---------------------------");

        end
        else begin

            $display("PASS: C=%d  Result=%d",
                     C,Result);

        end

    end
    endtask

    initial begin

        $display("Beginning From Montgomery Tests");
        $display("-------------------------------");

        C=0;      check_result();
        C=1;      check_result();
        C=2;      check_result();
        C=767;    check_result();
        C=1353;   check_result();
        C=2048;   check_result();
        C=3328;   check_result();

        for(i=0;i<1000;i=i+1) begin

            C = $random % 3329;
            if(C < 0)
                C = -C;

            check_result();

        end

        $display("-------------------------------");
        $display("Simulation Finished");

        $finish;
    end
endmodule