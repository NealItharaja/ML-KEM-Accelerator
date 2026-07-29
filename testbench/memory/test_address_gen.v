`timescale 1ns/1ps

// Testbench for the streaming address generator
module address_gen_tb;

localparam integer L = 4;   // must match the DUT PIPE_LATENCY below

reg clk;
reg reset;
reg start;

wire        rd_en;
wire [7:0]  rd_addr_a, rd_addr_b;
wire [6:0]  twiddle_addr;
wire        wr_en;
wire [7:0]  wr_addr_a, wr_addr_b;
wire        done;

integer pass_count;
integer fail_count;
integer rd_count;
integer wr_count;
integer cyc;
integer t;
reg     finished;

address_gen #(.PIPE_LATENCY(L)) DUT(
    .clk(clk),
    .reset(reset),
    .start(start),
    .rd_en(rd_en),
    .rd_addr_a(rd_addr_a),
    .rd_addr_b(rd_addr_b),
    .twiddle_addr(twiddle_addr),
    .wr_en(wr_en),
    .wr_addr_a(wr_addr_a),
    .wr_addr_b(wr_addr_b),
    .done(done)
);

// 100 MHz simulation clock (10ns period)
always #5 clk = ~clk;

task check_read;
begin
    rd_count = rd_count + 1;

    // Butterfly distance = 1 << stage
    if (rd_addr_b === rd_addr_a + (8'd1 << DUT.stage)) begin
        pass_count = pass_count + 1;
    end else begin
        $display("FAIL [stage %0d]: distance Got=%0d Expected=%0d (a=%0d b=%0d)",
                 DUT.stage, rd_addr_b - rd_addr_a, (8'd1 << DUT.stage),
                 rd_addr_a, rd_addr_b);
        fail_count = fail_count + 1;
    end

    // Conflict-free: opposite parity -> different banks
    if ((^rd_addr_a) !== (^rd_addr_b)) begin
        pass_count = pass_count + 1;
    end else begin
        $display("FAIL [stage %0d]: read pair (%0d,%0d) share a bank",
                 DUT.stage, rd_addr_a, rd_addr_b);
        fail_count = fail_count + 1;
    end

    // Twiddle address within ROM depth (compare in 8-bit width)
    if ({1'b0, twiddle_addr} < 8'd128) begin
        pass_count = pass_count + 1;
    end else begin
        $display("FAIL: twiddle_addr out of range (%0d)", twiddle_addr);
        fail_count = fail_count + 1;
    end
end
endtask

task check_write;
begin
    wr_count = wr_count + 1;
    if ((^wr_addr_a) !== (^wr_addr_b)) begin
        pass_count = pass_count + 1;
    end else begin
        $display("FAIL: write pair (%0d,%0d) share a bank", wr_addr_a, wr_addr_b);
        fail_count = fail_count + 1;
    end
end
endtask

initial begin
    clk = 0;
    reset = 1;
    start = 0;
    pass_count = 0;
    fail_count = 0;
    rd_count = 0;
    wr_count = 0;
    cyc = 0;

    // Release reset
    @(posedge clk); #1;
    reset = 0;

    // Pulse start
    @(posedge clk); #1;
    start = 1;
    @(posedge clk); #1;
    start = 0;
    // start=1 was sampled on the last edge, so we are now in the first RUN
    // cycle: sample the current cycle first, THEN advance (check-then-advance),
    // otherwise the very first read pair is skipped.

    finished = 0;
    while (!finished && cyc < 6000) begin
        if (rd_en) check_read;
        if (wr_en) check_write;
        if (done) finished = 1;
        else begin
            @(posedge clk); #1;
            cyc = cyc + 1;
        end
    end

    // Drain any write-backs still in the delay line after done latches
    for (t = 0; t < L + 3; t = t + 1) begin
        @(posedge clk); #1;
        if (wr_en) check_write;
    end

    $display("========================================");
    $display("NTT address generation complete");
    $display("Read pairs  = %0d (expected 1024)", rd_count);
    $display("Write pairs = %0d (expected 1024)", wr_count);
    $display("========================================");

    if (rd_count == 1024) pass_count = pass_count + 1;
    else begin $display("FAIL: read count %0d != 1024", rd_count); fail_count = fail_count + 1; end

    if (wr_count == 1024) pass_count = pass_count + 1;
    else begin $display("FAIL: write count %0d != 1024", wr_count); fail_count = fail_count + 1; end

    $display("--------------------------------");
    $display("Passed = %0d", pass_count);
    $display("Failed = %0d", fail_count);
    $display("--------------------------------");
    if (fail_count == 0) $display("TEST PASSED"); else $display("TEST FAILED");

    $finish;
end

endmodule
