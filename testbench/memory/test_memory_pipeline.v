// Integrated Memory Pipeline Testbench for Kyber NTT
// Verifies address_gen + twiddle_rom + coeff_ram working in tandem before Butterfly Unit integration.

`timescale 1ns / 1ps

module ntt_memory_pipeline_tb;

    reg clk;
    reg reset;
    reg start;
    reg butterfly_done;

    // Address Generator outputs
    wire [7:0] addr_a;
    wire [7:0] addr_b;
    wire [7:0] twiddle_addr;
    wire done;
    wire valid;

    // RAM control signals
    reg we_a;
    reg we_b;
    reg [7:0] pre_addr_a;
    reg [7:0] pre_addr_b;
    reg [11:0] din_a;
    reg [11:0] din_b;

    wire [7:0] ram_addr_a;
    wire [7:0] ram_addr_b;

    // Registered memory outputs (Inputs to future Butterfly Unit)
    wire [11:0] dout_a;
    wire [11:0] dout_b;
    wire [11:0] twiddle_factor;

    // Verification Counters
    integer pass_count = 0;
    integer fail_count = 0;
    integer total_butterflies = 0;
    integer i;

    // Golden array to hold expected twiddle ROM values
    reg [11:0] expected_twiddle [0:127];

    // =========================================================================
    // MODULE INSTANTIATIONS
    // =========================================================================

    // 1. Address Generator
    address_gen AG (
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

    // Mux RAM addresses: Connect pre-load generator or address_gen pipeline
    assign ram_addr_a = (we_a) ? pre_addr_a : addr_a;
    assign ram_addr_b = (we_b) ? pre_addr_b : addr_b;

    // 2. Coefficient RAM A (Even / Operand A Memory)
    coeff_ram RAM_A (
        .clk(clk),
        .we(we_a),
        .addr(ram_addr_a),
        .din(din_a),
        .dout(dout_a)
    );

    // 3. Coefficient RAM B (Odd / Operand B Memory)
    coeff_ram RAM_B (
        .clk(clk),
        .we(we_b),
        .addr(ram_addr_b),
        .din(din_b),
        .dout(dout_b)
    );

    // 4. Twiddle Factor ROM
    twiddle_rom TW_ROM (
        .clk(clk),
        .addr(twiddle_addr[6:0]),
        .data(twiddle_factor)
    );

    // Clock Generation: 100 MHz (10ns period)
    always #5 clk = ~clk;

    // =========================================================================
    // TEST PROCEDURE
    // =========================================================================

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        butterfly_done = 0;
        we_a = 0;
        we_b = 0;
        pre_addr_a = 0;
        pre_addr_b = 0;
        din_a = 0;
        din_b = 0;

        // Load expected hex values into golden array for assertions
        $readmemh("src/memory/twiddle.mem", expected_twiddle);

        // -------------------------------------------------------------
        // STEP 1: Pre-load 256 test polynomial coefficients into RAM_A & RAM_B
        // -------------------------------------------------------------
        $display("=================================================");
        $display("Step 1: Pre-loading 256 coefficients into RAM_A & RAM_B");
        $display("=================================================");
        for (i = 0; i < 256; i = i + 1) begin
            @(negedge clk);
            we_a = 1;
            we_b = 1;
            pre_addr_a = i;
            pre_addr_b = i;
            // Pre-load known test polynomial: poly[i] = i * 5 + 1
            din_a = i * 12'h005 + 12'h001; 
            din_b = i * 12'h005 + 12'h001; 
        end
        @(negedge clk);
        we_a = 0;
        we_b = 0;

        // -------------------------------------------------------------
        // STEP 2: Release Reset & Start Address Generator
        // -------------------------------------------------------------
        $display("=================================================");
        $display("Step 2: Starting Address Generator & Memory Pipeline");
        $display("=================================================");
        reset = 0;
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        // -------------------------------------------------------------
        // STEP 3: Monitor Memory Pipeline outputs when valid == 1
        // -------------------------------------------------------------
        while (!done && total_butterflies < 2500) begin
            @(posedge clk);
            #1; // Wait 1ns for registered RAM/ROM outputs to update

            if (valid) begin
                total_butterflies = total_butterflies + 1;

                // Test Assertion 1: Verify Twiddle Factor read from ROM
                if (twiddle_factor === expected_twiddle[twiddle_addr[6:0]]) begin
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL [Twiddle ROM]: twiddle_addr=%0d Expected=%03h Got=%03h",
                             twiddle_addr[6:0], expected_twiddle[twiddle_addr[6:0]], twiddle_factor);
                    fail_count = fail_count + 1;
                end

                // Test Assertion 2: Verify RAM_A coefficient read
                if (dout_a === (addr_a * 12'h005 + 12'h001)) begin
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL [coeff_ram A]: addr_a=%0d Expected=%03h Got=%03h",
                             addr_a, (addr_a * 12'h005 + 12'h001), dout_a);
                    fail_count = fail_count + 1;
                end

                // Test Assertion 3: Verify RAM_B coefficient read
                if (dout_b === (addr_b * 12'h005 + 12'h001)) begin
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL [coeff_ram B]: addr_b=%0d Expected=%03h Got=%03h",
                             addr_b, (addr_b * 12'h005 + 12'h001), dout_b);
                    fail_count = fail_count + 1;
                end

                // Pulse butterfly_done on falling clock edge to simulate butterfly unit finishing
                butterfly_done = 1;
                @(negedge clk);
                butterfly_done = 0;
            end
        end

        // -------------------------------------------------------------
        // STEP 4: Print Test Summary
        // -------------------------------------------------------------
        $display("=================================================");
        $display("INTEGRATED PIPELINE TEST SUMMARY");
        $display("Total Butterflies Simulated: %0d", total_butterflies);
        $display("Passed Checks: %0d", pass_count);
        $display("Failed Checks: %0d", fail_count);
        $display("=================================================");

        $finish;
    end

endmodule