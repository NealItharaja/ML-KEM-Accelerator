`timescale 1ns/1ps

module twiddle_rom_tb;
    reg clk;
    reg [6:0] addr;
    reg [11:0] expected [0:127];

    wire [11:0] data;

    integer i;
    integer pass_count;
    integer fail_count;

    twiddle_rom DUT(
        .clk(clk),
        .addr(addr),
        .data(data)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        pass_count = 0;
        fail_count = 0;
        $readmemh("src/memory/twiddle.mem", expected);

        for (i = 0; i < 128; i = i + 1) begin
            @(negedge clk);
            addr = i;

            @(posedge clk);
            #1;

            if (data === expected[i]) begin
                $display("PASS: ROM[%0d] = %03h", i, data);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: ROM[%0d] Expected = %03h, Got = %03h", i, expected[i], data);
                fail_count = fail_count + 1;
            end
        end
        $finish;
    end
endmodule