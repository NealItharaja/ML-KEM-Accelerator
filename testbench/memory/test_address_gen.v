`timescale 1ns/1ps

module address_gen_tb;

reg clk;
reg reset;
reg start;
reg butterfly_done;

wire [7:0] addr_a;
wire [7:0] addr_b;
wire [7:0] twiddle_addr;
wire done;
wire valid;

integer i;
integer pass_count;
integer fail_count;

address_gen DUT(
    .clk(clk),
    .reset(reset),
    .start(start),
    .butterfly_done(butterfly_done),
    .addr_a(addr_a),
    .addr_b(addr_b),
    .twiddle_addr(twiddle_addr),
    .done(done),
    .valid(valid)
);

always #5 clk = ~clk;

initial begin

    clk = 0;
    reset = 1;
    start = 0;
    butterfly_done = 0;

    pass_count = 0;
    fail_count = 0;

    @(posedge clk);
    reset = 0;

    @(posedge clk);

    start = 1;

    @(posedge clk);

    start = 0;

    for(i=0;i<300;i=i+1) begin

        @(posedge clk);

        butterfly_done = 1;

        @(posedge clk);

        butterfly_done = 0;

        if(valid) begin

            if(addr_b == addr_a + (1 << DUT.stage)) begin
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: addr_b incorrect");
                $display("Stage = %0d",DUT.stage);
                $display("A = %0d",addr_a);
                $display("B = %0d",addr_b);
                fail_count = fail_count + 1;
            end

            if(addr_a < 256)
                pass_count = pass_count + 1;
            else begin
                $display("FAIL: addr_a out of range");
                fail_count = fail_count + 1;
            end

            if(addr_b < 256)
                pass_count = pass_count + 1;
            else begin
                $display("FAIL: addr_b out of range");
                fail_count = fail_count + 1;
            end

            if(twiddle_addr < 128)
                pass_count = pass_count + 1;
            else begin
                $display("FAIL: twiddle address out of range");
                fail_count = fail_count + 1;
            end

        end

        if(done) begin
            $display("NTT COMPLETE");
            break;
        end

    end

    $display("--------------------------------");
    $display("Passed = %0d",pass_count);
    $display("Failed = %0d",fail_count);
    $display("--------------------------------");

    $finish;

end

endmodule