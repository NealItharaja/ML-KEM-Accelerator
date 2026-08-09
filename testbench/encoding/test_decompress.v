`timescale 1ns/1ps

module test_decompress;
    reg [9:0] y10;
    reg [3:0] y4;
    reg y1;

    wire [11:0] x10, x4, x1;

    integer i, errors, checks, exp;

    decompress #(.D(10)) dut10(
        .y(y10), 
        .decompressed_y(x10)
    );

    decompress #(.D(4)) dut4(
        .y(y4),  
        .decompressed_y(x4)
    );

    decompress #(.D(1)) dut1(
        .y(y1),  
        .decompressed_y(x1)
    );

    function integer dref;
        input integer yi;
        input integer d;

        begin
            dref = (yi * 3329 + (1 << (d - 1))) >> d;
        end
    endfunction

    task check;
        input integer got;
        input integer expected;
        input [255:0] name;

        begin
            checks = checks + 1;
            if (got !== expected) begin
                errors = errors + 1;
                $display("FAIL %0s: got=%0d exp=%0d", name, got, expected);
            end
            else
                $display("PASS %0s: %0d", name, got);
        end
    endtask

    initial begin
        errors = 0;
        checks = 0;
        y10 = 0;
        y4 = 0;
        y1 = 0;

        $display("================================");
        $display("Test 1: D=10 spot checks");
        $display("================================");

        y10 = 10'd0;    
        #1; 
        check(x10, dref(0, 10), "D10 y=0");

        y10 = 10'd1;    
        #1; 
        check(x10, dref(1, 10), "D10 y=1");

        y10 = 10'd512;  
        #1; 
        check(x10, dref(512, 10), "D10 y=512");

        y10 = 10'd1023; #
        1; 
        check(x10, dref(1023, 10), "D10 y=1023");

        $display("================================");
        $display("Test 2: D=4 and D=1 spot checks");
        $display("================================");

        y4 = 4'd0;  
        #1; 
        check(x4, dref(0, 4), "D4 y=0");
        
        y4 = 4'd8;  
        #1; 
        check(x4, dref(8, 4), "D4 y=8");

        y4 = 4'd15; 
        #1; 
        check(x4, dref(15, 4), "D4 y=15");

        y1 = 1'd0;  
        #1; 
        check(x1, dref(0, 1), "D1 y=0");
        
        y1 = 1'd1;  
        #1; 
        check(x1, dref(1, 1), "D1 y=1");

        $display("================================");
        $display("Test 3: full sweep y=0..1023 (D=10)");
        $display("================================");

        for (i = 0; i < 1024; i = i + 1) begin
            y10 = i;
            #1;
            exp = dref(i, 10);
            checks = checks + 1;
            if (x10 !== exp) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL sweep y=%0d got=%0d exp=%0d", i, x10, exp);
            end
            if (x10 >= 3329) begin
                errors = errors + 1;
                $display("FAIL range y=%0d out=%0d (>=q)", i, x10);
            end
        end
        if (errors == 0)
            $display("PASS full D=10 sweep (1024 values, all < q)");

        $display("================================");
        $display("Test 4: full sweep D=4 and D=1");
        $display("================================");

        for (i = 0; i < 16; i = i + 1) begin
            y4 = i;
            #1;
            checks = checks + 1;
            if (x4 !== dref(i, 4)) begin
                errors = errors + 1;
                $display("FAIL D4 y=%0d got=%0d exp=%0d", i, x4, dref(i, 4));
            end
        end

        for (i = 0; i < 2; i = i + 1) begin
            y1 = i;
            #1;
            checks = checks + 1;
            if (x1 !== dref(i, 1)) begin
                errors = errors + 1;
                $display("FAIL D1 y=%0d got=%0d exp=%0d", i, x1, dref(i, 1));
            end
        end
        if (errors == 0)
            $display("PASS D=4 and D=1 sweeps");

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
