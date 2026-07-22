// Test for Montgomery Reduction algorithm
`timescale 1ns/1ps

module montgomery_tb;

    reg  [23:0] T;
    wire [11:0] t;

    integer expected;
    integer m;
    integer inter;
    integer i;

    // DUT
    montgomery DUT (
        .T(T),
        .t(t)
    );

    // Compute the expected Montgomery reduction
    task check_result;
    begin
        m = (T * 3327) % 4096;
        inter = (T + m * 3329) / 4096;

        if (inter >= 3329)
            expected = inter - 3329;
        else
            expected = inter;

        #1;

        if (t !== expected[11:0]) begin
            $display("FAIL");
            $display("T        = %d", T);
            $display("Expected = %d", expected);
            $display("Got      = %d", t);
            $display("---------------------------");
        end
        else begin
            $display("PASS: T=%d  Result=%d", T, t);
        end
    end
    endtask

    initial begin

        $display("Beginning Montgomery Reduction Tests");
        $display("------------------------------------");

        //-------------------------------------------------
        // Basic edge cases
        //-------------------------------------------------

        T = 0;          check_result();
        T = 1;          check_result();
        T = 2;          check_result();
        T = 3328;       check_result();
        T = 3329;       check_result();
        T = 4095;       check_result();
        T = 4096;       check_result();

        //-------------------------------------------------
        // Products you'd commonly see from multipliers
        //-------------------------------------------------

        T = 1000 * 1000;    check_result();
        T = 2000 * 2000;    check_result();
        T = 3000 * 3000;    check_result();
        T = 3328 * 3328;    check_result();

        //-------------------------------------------------
        // Random tests
        //-------------------------------------------------

        for (i = 0; i < 1000; i = i + 1) begin
            T = $random;

            // Limit to legal range
            T = T % (3329 * 4096);

            check_result();
        end

        $display("------------------------------------");
        $display("Simulation Finished");

        $finish;

    end

endmodule