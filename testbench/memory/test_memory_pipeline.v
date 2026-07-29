`timescale 1ns/1ps

module kyber_ntt_pipeline_tb;

    reg clk;
    reg reset;
    reg start;
    reg butterfly_done;

    wire [7:0] addr_a;
    wire [7:0] addr_b;
    wire [6:0] twiddle_addr;
    wire [11:0] twiddle_data;
    wire valid;
    wire done;

    // Expected memory array loaded from file
    reg [11:0] expected_rom [0:127];

    // Pipeline delay registers to track 1-cycle BRAM read latency
    reg [6:0] pipe_addr;
    reg       pipe_valid;

    integer pass_count;
    integer fail_count;
    integer total_checked;

    // Instantiate Top Pipeline Unit
    kyber_ntt_twiddle_pipeline DUT (
        .clk(clk),
        .reset(reset),
        .start(start),
        .butterfly_done(butterfly_done),
        .addr_a(addr_a),
        .addr_b(addr_b),
        .twiddle_addr(twiddle_addr),
        .twiddle_data(twiddle_data),
        .valid(valid),
        .done(done)
    );

    // 100MHz clock generation (10ns period)
    always #5 clk = ~clk;

    // Pipeline register process: captures address on Cycle N to check data on Cycle N+1
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pipe_addr  <= 0;
            pipe_valid <= 0;
        end else begin
            pipe_addr  <= twiddle_addr;
            pipe_valid <= valid;
        end
    end

    // Verification Process
    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        butterfly_done = 0;

        pass_count = 0;
        fail_count = 0;
        total_checked = 0;

        // Load reference twiddle factors
        $readmemh("src/memory/twiddle.mem", expected_rom);

        // Release reset
        @(negedge clk);
        reset = 0;

        // Pulse start signal
        @(negedge clk);
        start = 1;

        @(negedge clk);
        start = 0;

        // Main simulation loop
        while (!done && total_checked < 500) begin

            @(posedge clk);
            #1; // Delta delay for non-blocking assignment settling

            // Simulate butterfly completion when address generator is in GEN state
            if (DUT.addr_gen_inst.state == 2'b01) begin
                butterfly_done = 1;
            end else begin
                butterfly_done = 0;
            end

            // Check pipelined memory data output on Cycle N+1
            if (pipe_valid) begin
                total_checked = total_checked + 1;

                if (twiddle_data === expected_rom[pipe_addr]) begin
                    $display("[PASS #%0d] ROM[%0d] => Got: 0x%03h | Exp: 0x%03h | AddrA=%0d AddrB=%0d",
                             total_checked, pipe_addr, twiddle_data, expected_rom[pipe_addr], addr_a, addr_b);
                    pass_count = pass_count + 1;
                end else begin
                    $display("[FAIL #%0d] ROM[%0d] => Got: 0x%03h | Exp: 0x%03h (MISMATCH!)",
                             total_checked, pipe_addr, twiddle_data, expected_rom[pipe_addr]);
                    fail_count = fail_count + 1;
                end
            end
        end

        // Wait 1 final cycle for last pipeline drain
        @(posedge clk);
        #1;
        if (pipe_valid) begin
            total_checked = total_checked + 1;
            if (twiddle_data === expected_rom[pipe_addr]) begin
                $display("[PASS #%0d] ROM[%0d] => Got: 0x%03h | Exp: 0x%03h",
                         total_checked, pipe_addr, twiddle_data, expected_rom[pipe_addr]);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL #%0d] ROM[%0d] => Got: 0x%03h | Exp: 0x%03h",
                         total_checked, pipe_addr, twiddle_data, expected_rom[pipe_addr]);
                fail_count = fail_count + 1;
            end
        end

        $display("\n==================================================");
        $display("   KYBER NTT PIPELINE TESTBENCH COMPLETE");
        $display("   Total Butterflies Tested : %0d", total_checked);
        $display("   Passed                   : %0d", pass_count);
        $display("   Failed                   : %0d", fail_count);
        $display("==================================================\n");

        $finish;
    end

endmodule