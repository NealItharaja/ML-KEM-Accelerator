`timescale 1ns/1ps

module memory_pipeline_tb;

// -----------------------------------------------------------------------------
// Testbench Clock & Reset Signals
// -----------------------------------------------------------------------------
reg clk;
reg reset;
reg start;
reg butterfly_done;

// -----------------------------------------------------------------------------
// Address Generator Interconnect Wires
// -----------------------------------------------------------------------------
wire [7:0] addr_a;
wire [7:0] addr_b;
wire [7:0] twiddle_addr;
wire       done;
wire       valid_addr;

// -----------------------------------------------------------------------------
// Memory Output Wires (Arrive 1 Clock Cycle AFTER Valid Address)
// -----------------------------------------------------------------------------
wire [11:0] coeff_a;
wire [11:0] coeff_b;
wire [11:0] twiddle_data;

// Memory Write Interface (For Initializing coeff_ram before NTT)
reg        ram_we;
reg  [7:0] ram_waddr;
reg [11:0] ram_wdata;

integer pass_count;
integer fail_count;
integer cycle_count;

// -----------------------------------------------------------------------------
// 1. Instantiate NTT Address Generator
// -----------------------------------------------------------------------------
address_gen ADDR_GEN_INST (
    .clk(clk),
    .reset(reset),
    .start(start),
    .butterfly_done(butterfly_done),
    .addr_a(addr_a),
    .addr_b(addr_b),
    .twiddle_addr(twiddle_addr[6:0]), // Truncate to 7 bits for 128-entry ROM
    .done(done),
    .valid(valid_addr)
);

// -----------------------------------------------------------------------------
// 2. Instantiate Official Kyber Twiddle ROM (128 x 12-bit)
// -----------------------------------------------------------------------------
twiddle_rom TWIDDLE_ROM_INST (
    .clk(clk),
    .addr(twiddle_addr[6:0]),
    .data(twiddle_data)
);

// -----------------------------------------------------------------------------
// 3. Instantiate Dual-Port Coefficient RAM (256 x 12-bit)
// -----------------------------------------------------------------------------
// Reads coeff_a from addr_a and coeff_b from addr_b concurrently
coeff_ram COEFF_RAM_INST (
    .clk(clk),
    .we(ram_we),
    .waddr(ram_waddr),
    .din(ram_wdata),
    .raddr_a(addr_a),
    .raddr_b(addr_b),
    .dout_a(coeff_a),
    .dout_b(coeff_b)
);

// -----------------------------------------------------------------------------
// Clock Generation (100 MHz, 10ns Period)
// -----------------------------------------------------------------------------
always #5 clk = ~clk;

// -----------------------------------------------------------------------------
// Verification Loop
// -----------------------------------------------------------------------------
initial begin
    clk = 0;
    reset = 1;
    start = 0;
    butterfly_done = 0;
    ram_we = 0;
    ram_waddr = 0;
    ram_wdata = 0;
    pass_count = 0;
    fail_count = 0;
    cycle_count = 0;

    $display("=================================================");
    $display("STARTING KYBER MEMORY PIPELINE INTEGRATION TEST");
    $display("=================================================");

    // Step 1: Initialize Coefficient RAM with test vector: RAM[i] = i
    @(negedge clk);
    reset = 0;
    ram_we = 1;
    for (integer k = 0; k < 256; k = k + 1) begin
        ram_waddr = k;
        ram_wdata = k[11:0]; // Store index as test value
        @(posedge clk);
    end
    ram_we = 0;

    $display("[INFO] Initialized 256 RAM entries in coeff_ram.");

    // Step 2: Pulse START signal for Address Generator
    @(negedge clk);
    start = 1;
    @(posedge clk);
    #1;
    start = 0;

    // Step 3: Run pipeline verification loop
    while (!done && cycle_count < 1000) begin
        cycle_count = cycle_count + 1;

        @(posedge clk);
        #1; // Delta delay to allow non-blocking memory assignments to settle

        // Simulate butterfly completion when address generator is in GEN mode
        if (ADDR_GEN_INST.state == 2'b01) begin
            butterfly_done = 1;
        end else begin
            butterfly_done = 0;
        end

        // Check data pipeline when memory output is valid
        if (valid_addr) begin
            // Verify RAM A output matches initialized value: coeff_a == addr_a
            if (coeff_a === addr_a[11:0]) begin
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL Cycle %0d: coeff_a (Got %03h, Expected %03h)", 
                         cycle_count, coeff_a, addr_a);
                fail_count = fail_count + 1;
            end

            // Verify RAM B output matches initialized value: coeff_b == addr_b
            if (coeff_b === addr_b[11:0]) begin
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL Cycle %0d: coeff_b (Got %03h, Expected %03h)", 
                         cycle_count, coeff_b, addr_b);
                fail_count = fail_count + 1;
            end

            // Verify twiddle address bound check (< 128)
            if (twiddle_addr < 128) begin
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL Cycle %0d: twiddle_addr out of range (%0d >= 128)", 
                         cycle_count, twiddle_addr);
                fail_count = fail_count + 1;
            end

            $display("PIPELINE OK [Stage %0d, Grp %0d]: RAM[%0d]=%03h, RAM[%0d]=%03h, TWIDDLE[%0d]=%03h",
                     ADDR_GEN_INST.stage, ADDR_GEN_INST.group, 
                     addr_a, coeff_a, addr_b, coeff_b, twiddle_addr, twiddle_data);
        end
    end

    $display("=================================================");
    $display("MEMORY PIPELINE INTEGRATION TEST COMPLETE");
    $display("Total Cycle Count : %0d", cycle_count);
    $display("Assertions Passed : %0d", pass_count);
    $display("Assertions Failed : %0d", fail_count);
    $display("=================================================");

    if (fail_count == 0) begin
        $display(">>> SUCCESS: Memory subsystem is 100%% ready for NTT Butterfly Unit! <<<");
    end else begin
        $display(">>> ERROR: Fix timing/address alignment before writing NTT core! <<<");
    end

    $finish;
end

endmodule