`timescale 1ns/1ps

// Testbench for Keccak-f[1600] (module keccack).

module test_keccack;

    reg clk;
    reg reset;
    reg start;
    reg [1599:0] state_in;
    wire [1599:0] state_out;
    wire done;

    integer i, errors, checks;
    reg [63:0] lane;
    reg [63:0] exp_zero [0:24];
    reg [63:0] exp_one0 [0:3];

    keccack DUT(
        .clk(clk),
        .reset(reset),
        .start(start),
        .state_in(state_in),
        .state_out(state_out),
        .done(done)
    );

    always #5 clk = ~clk;

    task run_perm;
        begin
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            wait (done);
            #1;
        end
    endtask

    task check_lane;
        input integer idx;
        input [63:0] got;
        input [63:0] exp;
        input [255:0] name;
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL %0s lane[%0d]: got=%016h exp=%016h",
                         name, idx, got, exp);
            end
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        state_in = 1600'd0;
        errors = 0;
        checks = 0;
        #20;
        reset = 0;

        // Golden: Keccak-f[1600](0)
        exp_zero[0]  = 64'hF1258F7940E1DDE7;
        exp_zero[1]  = 64'h84D5CCF933C0478A;
        exp_zero[2]  = 64'hD598261EA65AA9EE;
        exp_zero[3]  = 64'hBD1547306F80494D;
        exp_zero[4]  = 64'h8B284E056253D057;
        exp_zero[5]  = 64'hFF97A42D7F8E6FD4;
        exp_zero[6]  = 64'h90FEE5A0A44647C4;
        exp_zero[7]  = 64'h8C5BDA0CD6192E76;
        exp_zero[8]  = 64'hAD30A6F71B19059C;
        exp_zero[9]  = 64'h30935AB7D08FFC64;
        exp_zero[10] = 64'hEB5AA93F2317D635;
        exp_zero[11] = 64'hA9A6E6260D712103;
        exp_zero[12] = 64'h81A57C16DBCF555F;
        exp_zero[13] = 64'h43B831CD0347C826;
        exp_zero[14] = 64'h01F22F1A11A5569F;
        exp_zero[15] = 64'h05E5635A21D9AE61;
        exp_zero[16] = 64'h64BEFEF28CC970F2;
        exp_zero[17] = 64'h613670957BC46611;
        exp_zero[18] = 64'hB87C5A554FD00ECB;
        exp_zero[19] = 64'h8C3EE88A1CCF32C8;
        exp_zero[20] = 64'h940C7922AE3A2614;
        exp_zero[21] = 64'h1841F924A2C509E4;
        exp_zero[22] = 64'h16F53526E70465C2;
        exp_zero[23] = 64'h75F644E97F30A13B;
        exp_zero[24] = 64'hEAF1FF7B5CECA249;

        // Golden: lane0=1, rest 0 -> first 4 lanes
        exp_one0[0] = 64'hE2A944396F0B13C6;
        exp_one0[1] = 64'h70FEC06CEB0B06C4;
        exp_one0[2] = 64'h721DFC5018F27A42;
        exp_one0[3] = 64'h64A2AF57149F7096;

        // ---------------------------------------------------------------
        $display("================================");
        $display("Test 1: all-zero state");
        $display("================================");
        state_in = 1600'd0;
        run_perm;
        for (i = 0; i < 25; i = i + 1) begin
            lane = state_out[64*i +: 64];
            check_lane(i, lane, exp_zero[i], "zero");
        end
        if (errors == 0)
            $display("PASS all 25 lanes for zero input");

        // ---------------------------------------------------------------
        $display("================================");
        $display("Test 2: state with lane0 = 1");
        $display("================================");
        state_in = 1600'd0;
        state_in[63:0] = 64'd1;
        run_perm;
        for (i = 0; i < 4; i = i + 1) begin
            lane = state_out[64*i +: 64];
            check_lane(i, lane, exp_one0[i], "lane0=1");
        end
        if (errors == 0)
            $display("PASS first 4 lanes for lane0=1");

        // ---------------------------------------------------------------
        $display("================================");
        $display("Test 3: done is a pulse, second run still works");
        $display("================================");
        state_in = 1600'd0;
        run_perm;
        for (i = 0; i < 25; i = i + 1) begin
            lane = state_out[64*i +: 64];
            check_lane(i, lane, exp_zero[i], "rerun");
        end
        if (errors == 0)
            $display("PASS second zero permutation");

        $display("--------------------------------");
        $display("Checked %0d, mismatches %0d", checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $display("--------------------------------");
        $finish;
    end

endmodule
