`timescale 1ns/1ps

module twiddle_rom_tb;

reg clk;
reg [6:0] addr;
wire [11:0] data;

integer i;
integer pass_count;
integer fail_count;

reg [11:0] expected [0:127];

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

    // Load the exact same file used by the ROM
    $readmemh("src/memory/twiddle.mem", expected);

    @(posedge clk);

    for(i = 0; i < 128; i = i + 1) begin

        addr = i;

        @(posedge clk);

        if(data === expected[i]) begin
            $display("PASS: ROM[%0d] = %03h", i, data);
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL: ROM[%0d]", i);
            $display("Expected = %03h", expected[i]);
            $display("Got      = %03h", data);
            fail_count = fail_count + 1;
        end
    end

    $display("--------------------------------");
    $display("Passed = %0d", pass_count);
    $display("Failed = %0d", fail_count);
    $display("--------------------------------");

    $finish;

end

endmodule