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

    integer i;

    initial begin

        clk = 0;
        reset = 1;
        start = 0;
        butterfly_done = 0;

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

            $display("--------------------------------");
            $display("Stage   = %d", DUT.stage);
            $display("Group   = %d", DUT.group);
            $display("j       = %d", DUT.j);
            $display("A Addr  = %d", addr_a);
            $display("B Addr  = %d", addr_b);
            $display("Twiddle = %d", twiddle_addr);

            if(done) begin
                $display("NTT COMPLETE");
                $finish;
            end

        end

        $finish;

    end

endmodule