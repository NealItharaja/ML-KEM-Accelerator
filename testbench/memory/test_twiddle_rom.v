`timescale 1ns/1ps

module twiddle_rom_tb;
    reg clk;
    reg [7:0] addr;
    wire [11:0] data;

    twiddle_rom DUT(
        .clk(clk),
        .addr(addr),
        .data(data)
    );

    always #5 clk = ~clk;

    initial begin

        clk = 0;

        $display("==============================");
        $display("Twiddle ROM Test");
        $display("==============================");

        addr = 0;
        @(posedge clk);
        $display("ROM[0] = %d",data);

        addr = 1;
        @(posedge clk);
        $display("ROM[1] = %d",data);

        addr = 2;
        @(posedge clk);
        $display("ROM[2] = %d",data);

        addr = 3;
        @(posedge clk);
        $display("ROM[3] = %d",data);

        addr = 127;
        @(posedge clk);
        $display("ROM[127] = %d",data);

        addr = 255;
        @(posedge clk);
        $display("ROM[255] = %d",data);

        $display("==============================");

        $finish;

    end

endmodule