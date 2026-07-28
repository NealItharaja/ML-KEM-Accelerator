`timescale 1ns/1ps

module coeff_ram_tb;
    reg clk;
    reg we;
    reg [7:0] addr;
    reg [11:0] din;
    wire [11:0] dout;

    coeff_ram DUT (
        .clk(clk),
        .we(we),
        .addr(addr),
        .din(din),
        .dout(dout)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        we = 0;
        addr = 0;
        din = 0;

        $display("==============================");
        $display("Coefficient RAM Test");
        $display("==============================");

        //-----------------------
        // Write address 0
        //-----------------------
        @(posedge clk);
        we = 1;
        addr = 0;
        din = 12'd1234;

        @(posedge clk);
        we = 0;

        @(posedge clk);
        addr = 0;

        @(posedge clk);

        if(dout == 1234)
            $display("PASS Address 0");
        else
            $display("FAIL Address 0");

        //-----------------------
        // Write address 37
        //-----------------------

        @(posedge clk);
        we = 1;
        addr = 37;
        din = 12'd2222;

        @(posedge clk);
        we = 0;

        @(posedge clk);
        addr = 37;

        @(posedge clk);

        if(dout == 2222)
            $display("PASS Address 37");
        else
            $display("FAIL Address 37");

        //-----------------------
        // Overwrite
        //-----------------------

        @(posedge clk);
        we = 1;
        addr = 37;
        din = 12'd3333;

        @(posedge clk);
        we = 0;

        @(posedge clk);
        addr = 37;

        @(posedge clk);

        if(dout == 3333)
            $display("PASS Overwrite");
        else
            $display("FAIL Overwrite");

        //-----------------------
        // Highest address
        //-----------------------

        @(posedge clk);
        we = 1;
        addr = 8'd255;
        din = 12'd4095;

        @(posedge clk);
        we = 0;

        @(posedge clk);
        addr = 255;

        @(posedge clk);

        if(dout == 4095)
            $display("PASS Address 255");
        else
            $display("FAIL Address 255");

        $display("==============================");
        $finish;
    end

endmodule