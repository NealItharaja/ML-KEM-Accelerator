`timescale 1ns/1ps

module butterfly_tb;

    reg clk;
    reg [11:0] a;
    reg [11:0] b;
    reg [11:0] twiddle;

    wire [11:0] a_out;
    wire [11:0] b_out;

    butterfly DUT (
        .clk(clk),
        .a(a),
        .b(b),
        .twiddle(twiddle),
        .a_out(a_out),
        .b_out(b_out)
    );

    always #5 clk = ~clk;

    // Wider signals so additions don't overflow
    reg [12:0] expected_sum;
    reg [11:0] expected_t;
    reg [11:0] expected_a;
    reg [11:0] expected_b;

    integer errors;

    task run_test;
        input [11:0] A;
        input [11:0] B;
        input [11:0] W;
        begin

            a = A;
            b = B;
            twiddle = W;

            @(posedge clk);
            @(posedge clk);
            #1;

            expected_t = DUT.T;

            // Correct modular addition
            expected_sum = {1'b0, DUT.a} + {1'b0, expected_t};

            if (expected_sum >= 13'd3329)
                expected_a = expected_sum - 13'd3329;
            else
                expected_a = expected_sum[11:0];

            // Correct modular subtraction
            if (DUT.a >= expected_t)
                expected_b = DUT.a - expected_t;
            else
                expected_b = DUT.a + 12'd3329 - expected_t;

            if ((a_out == expected_a) && (b_out == expected_b)) begin
                $display("PASS");
                $display(" A=%4d B=%4d Tw=%4d", A, B, W);
                $display(" T=%4d", expected_t);
                $display(" A'=%4d", a_out);
                $display(" B'=%4d", b_out);
                $display("------------------------------");
            end
            else begin
                errors = errors + 1;

                $display("FAIL");
                $display(" A=%4d B=%4d Tw=%4d", A, B, W);
                $display(" T=%4d", expected_t);
                $display(" Expected A=%4d Got=%4d", expected_a, a_out);
                $display(" Expected B=%4d Got=%4d", expected_b, b_out);
                $display("------------------------------");
            end

        end
    endtask

    initial begin

        clk = 0;
        errors = 0;

        $display("===============================");
        $display(" Butterfly Test");
        $display("===============================");

        run_test(12'd1,    12'd2,    12'd1);
        run_test(12'd123,  12'd456,  12'd17);
        run_test(12'd500,  12'd600,  12'd25);
        run_test(12'd1000, 12'd1200, 12'd31);
        run_test(12'd3328, 12'd1,    12'd1);
        run_test(12'd2048, 12'd3072, 12'd7);
        run_test(12'd17,   12'd2500, 12'd83);
        run_test(12'd2500, 12'd17,   12'd111);

        $display("===============================");

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        $finish;

    end

endmodule