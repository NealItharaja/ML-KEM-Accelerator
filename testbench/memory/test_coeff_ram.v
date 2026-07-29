`timescale 1ns/1ps

// Testbench for the 2-bank, conflict-free coefficient SRAM

module coeff_ram_tb;

reg clk;
reg        rd_en;
reg  [7:0] rd_addr_a, rd_addr_b;
wire [11:0] rd_data_a, rd_data_b;
reg        wr_en;
reg  [7:0] wr_addr_a, wr_addr_b;
reg [11:0] wr_data_a, wr_data_b;

integer pass_count;
integer fail_count;

coeff_ram DUT(
    .clk(clk),
    .rd_en(rd_en),
    .rd_addr_a(rd_addr_a),
    .rd_addr_b(rd_addr_b),
    .rd_data_a(rd_data_a),
    .rd_data_b(rd_data_b),
    .wr_en(wr_en),
    .wr_addr_a(wr_addr_a),
    .wr_addr_b(wr_addr_b),
    .wr_data_a(wr_data_a),
    .wr_data_b(wr_data_b)
);

always #5 clk = ~clk;

task check;
    input [11:0] got;
    input [11:0] expected;
    input [255:0] name;
begin
    if (got === expected) begin
        $display("PASS: %0s", name);
        pass_count = pass_count + 1;
    end
    else begin
        $display("FAIL: %0s  Expected=%0d  Got=%0d", name, expected, got);
        fail_count = fail_count + 1;
    end
end
endtask

// Write both operands of a pair in a single cycle.
task write_pair;
    input [7:0]  a;
    input [7:0]  b;
    input [11:0] da;
    input [11:0] db;
begin
    if ((^a) === (^b))
        $display("WARN: write pair (%0d,%0d) share a bank - illegal", a, b);
    @(negedge clk);
    wr_en = 1; wr_addr_a = a; wr_addr_b = b; wr_data_a = da; wr_data_b = db;
    @(negedge clk);
    wr_en = 0;
end
endtask

// Present a read pair, wait the 1-cycle latency, then check both results.
task read_check;
    input [7:0]  a;
    input [7:0]  b;
    input [11:0] ea;
    input [11:0] eb;
    input [255:0] name;
begin
    if ((^a) === (^b))
        $display("WARN: read pair (%0d,%0d) share a bank - illegal", a, b);
    @(negedge clk);
    rd_en = 1; rd_addr_a = a; rd_addr_b = b;
    @(posedge clk);          // RAM latches the read here
    #1;                      // registered data settles onto rd_data_*
    check(rd_data_a, ea, name);
    check(rd_data_b, eb, name);
    @(negedge clk);
    rd_en = 0;
end
endtask

initial begin
    clk = 0;
    rd_en = 0; wr_en = 0;
    rd_addr_a = 0; rd_addr_b = 0;
    wr_addr_a = 0; wr_addr_b = 0;
    wr_data_a = 0; wr_data_b = 0;
    pass_count = 0;
    fail_count = 0;

    // Pair (0,1): 0->bank0, 1->bank1
    write_pair(8'd0, 8'd1, 12'd1234, 12'd3456);
    read_check(8'd0, 8'd1, 12'd1234, 12'd3456, "pair (0,1)");

    // Same data, operands swapped -> exercises the a/b crossbar
    read_check(8'd1, 8'd0, 12'd3456, 12'd1234, "pair (1,0) crossbar");

    // Second pair in the SAME two banks but a different offset (2->bank1 off1,
    // 3->bank0 off1). Must not disturb pair (0,1) at offset 0.
    write_pair(8'd2, 8'd3, 12'd100, 12'd200);
    read_check(8'd2, 8'd3, 12'd100, 12'd200, "pair (2,3)");
    read_check(8'd0, 8'd1, 12'd1234, 12'd3456, "pair (0,1) undisturbed");

    // Overwrite pair (0,1)
    write_pair(8'd0, 8'd1, 12'd111, 12'd222);
    read_check(8'd0, 8'd1, 12'd111, 12'd222, "overwrite (0,1)");

    // A non-adjacent conflict-free pair (10=even, 7=odd)
    write_pair(8'd10, 8'd7, 12'd900, 12'd800);
    read_check(8'd10, 8'd7, 12'd900, 12'd800, "pair (10,7)");

    // Top addresses: 254=odd-parity->bank1, 255=even-parity->bank0
    write_pair(8'd254, 8'd255, 12'd4095, 12'd3210);
    read_check(8'd254, 8'd255, 12'd4095, 12'd3210, "pair (254,255)");

    $display("--------------------------------");
    $display("Passed = %0d", pass_count);
    $display("Failed = %0d", fail_count);
    $display("--------------------------------");
    if (fail_count == 0) $display("TEST PASSED"); else $display("TEST FAILED");

    $finish;
end

endmodule
