// Test for modular subtraction
`timescale 1ns/1ps

module mod_sub_tb;
    reg  [11:0] A;
    reg  [11:0] B;

    wire [11:0] Result;

    mod_sub DUT (
        .A(A),
        .B(B),
        .result(Result)
    );

    initial begin
        $display(" Time     A      B    Result");
        $display("--------------------------------");

        A = 12'd20;
        B = 12'd10;
        #10;
        $display("%4t    %4d   %4d   %4d", $time, A, B, Result);

        A = 12'd3000;
        B = 12'd200;
        #10;
        $display("%4t    %4d   %4d   %4d", $time, A, B, Result);

        A = 12'd3328;
        B = 12'd0;
        #10;
        $display("%4t    %4d   %4d   %4d", $time, A, B, Result);

        A = 12'd3328;
        B = 12'd1;
        #10;
        $display("%4t    %4d   %4d   %4d", $time, A, B, Result);

        A = 12'd2000;
        B = 12'd2000;
        #10;
        $display("%4t    %4d   %4d   %4d", $time, A, B, Result);
        $finish;
    end
endmodule