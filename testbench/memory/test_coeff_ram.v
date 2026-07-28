`timescale 1ns/1ps

module coeff_ram_tb;

reg clk;
reg we;
reg [7:0] addr;
reg [11:0] din;
wire [11:0] dout;

integer pass_count;
integer fail_count;

coeff_ram DUT(
    .clk(clk),
    .we(we),
    .addr(addr),
    .din(din),
    .dout(dout)
);

always #5 clk = ~clk;

task check;
    input [11:0] expected;
    input [127:0] name;
begin
    if(dout == expected) begin
        $display("PASS: %s", name);
        pass_count = pass_count + 1;
    end
    else begin
        $display("FAIL: %s", name);
        $display("Expected = %0d", expected);
        $display("Got      = %0d", dout);
        fail_count = fail_count + 1;
    end
end
endtask

initial begin

    clk = 0;
    we = 0;
    addr = 0;
    din = 0;

    pass_count = 0;
    fail_count = 0;

    // Address 0

    @(posedge clk);
    we = 1;
    addr = 0;
    din = 1234;

    @(posedge clk);
    we = 0;

    @(posedge clk);
    addr = 0;

    @(posedge clk);
    check(1234,"Address 0");

    // Address 37

    @(posedge clk);
    we = 1;
    addr = 37;
    din = 2222;

    @(posedge clk);
    we = 0;

    @(posedge clk);
    addr = 37;

    @(posedge clk);
    check(2222,"Address 37");

    // Overwrite

    @(posedge clk);
    we = 1;
    addr = 37;
    din = 3333;

    @(posedge clk);
    we = 0;

    @(posedge clk);
    addr = 37;

    @(posedge clk);
    check(3333,"Overwrite");

    // Highest address

    @(posedge clk);
    we = 1;
    addr = 255;
    din = 4095;

    @(posedge clk);
    we = 0;

    @(posedge clk);
    addr = 255;

    @(posedge clk);
    check(4095,"Address 255");

    $display("--------------------------------");
    $display("Passed = %0d",pass_count);
    $display("Failed = %0d",fail_count);
    $display("--------------------------------");

    $finish;

end

endmodule