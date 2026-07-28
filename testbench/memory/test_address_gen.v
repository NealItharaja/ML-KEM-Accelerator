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

integer pass_count;
integer fail_count;
integer total_butterflies;

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

// 100MHz simulation clock (10ns period)
always #5 clk = ~clk;

initial begin
    clk = 0;
    reset = 1;
    start = 0;
    butterfly_done = 0;

    pass_count = 0;
    fail_count = 0;
    total_butterflies = 0;

    // Reset cycle
    @(posedge clk);
    #1;
    reset = 0;

    // Pulse start signal
    @(posedge clk);
    #1;
    start = 1;

    @(posedge clk);
    #1;
    start = 0;

    // Run through NTT stages until done is asserted
    while (!done && total_butterflies < 2000) begin

        @(posedge clk);
        #1;

        // Drive butterfly_done when address generator enters GEN state (2'b01)
        if (DUT.state == 2'b01) begin
            butterfly_done = 1;
            @(posedge clk);
            #1;
            butterfly_done = 0;
        end

        // Check assertions when output is valid
        if (valid) begin
            total_butterflies = total_butterflies + 1;

            // Assertion 1: Verify butterfly distance (addr_b - addr_a == 1 << stage)
            if (addr_b === addr_a + (1 << DUT.stage)) begin
                $display("PASS [Stage %0d, Group %0d, J %0d]: addr_a=%0d, addr_b=%0d (diff=%0d), twiddle=%0d",
                         DUT.stage, DUT.group, DUT.j, addr_a, addr_b, (1 << DUT.stage), twiddle_addr);
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL [Stage %0d, Group %0d, J %0d]: addr_b incorrect (Got %0d, Expected %0d)",
                         DUT.stage, DUT.group, DUT.j, addr_b, addr_a + (1 << DUT.stage));
                fail_count = fail_count + 1;
            end

            // Assertion 2: addr_a range check
            if (addr_a < 256) begin
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: addr_a out of range (%0d >= 256)", addr_a);
                fail_count = fail_count + 1;
            end

            // Assertion 3: addr_b range check
            if (addr_b < 256) begin
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: addr_b out of range (%0d >= 256)", addr_b);
                fail_count = fail_count + 1;
            end

            // Assertion 4: twiddle_addr range check (ROM depth = 128)
            if (twiddle_addr < 128) begin
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: twiddle_addr out of range (%0d >= 128)", twiddle_addr);
                fail_count = fail_count + 1;
            end
        end

        if (done) begin
            $display("========================================");
            $display("NTT ADDRESS GENERATION COMPLETE!");
            $display("Total Butterflies Simulated: %0d", total_butterflies);
            $display("========================================");
        end
    end

    $display("--------------------------------");
    $display("Passed = %0d", pass_count);
    $display("Failed = %0d", fail_count);
    $display("--------------------------------");

    $finish;
end

endmodule