// Keccak-f[1600] permuation for hashing
module keccack(
    input clk,
    input reset,
    input start,
    input [1599:0] state_in,
    output reg [1599:0] state_out,
    output reg done
    );

    integer k;

    reg active;
    reg [4:0] round_i;
    reg [63:0] S [0:24];
    reg [63:0] A [0:24];
    reg [63:0] B [0:24];
    reg [63:0] C0, C1, C2, C3, C4;
    reg [63:0] D0, D1, D2, D3, D4;
    reg [63:0] rc;

    function [63:0] ROL;
        input [63:0] v;
        input integer n;

        begin
            if (n == 0)
                ROL = v;
            else
                ROL = (v << n) | (v >> (64 - n));
        end
    endfunction

    function [63:0] round_const;
        input [4:0] rnd;
        begin
            case (rnd)
                5'd0: round_const = 64'h0000000000000001;
                5'd1: round_const = 64'h0000000000008082;
                5'd2: round_const = 64'h800000000000808A;
                5'd3: round_const = 64'h8000000080008000;
                5'd4: round_const = 64'h000000000000808B;
                5'd5: round_const = 64'h0000000080000001;
                5'd6: round_const = 64'h8000000080008081;
                5'd7: round_const = 64'h8000000000008009;
                5'd8: round_const = 64'h000000000000008A;
                5'd9: round_const = 64'h0000000000000088;
                5'd10: round_const = 64'h0000000080008009;
                5'd11: round_const = 64'h000000008000000A;
                5'd12: round_const = 64'h000000008000808B;
                5'd13: round_const = 64'h800000000000008B;
                5'd14: round_const = 64'h8000000000008089;
                5'd15: round_const = 64'h8000000000008003;
                5'd16: round_const = 64'h8000000000008002;
                5'd17: round_const = 64'h8000000000000080;
                5'd18: round_const = 64'h000000000000800A;
                5'd19: round_const = 64'h800000008000000A;
                5'd20: round_const = 64'h8000000080008081;
                5'd21: round_const = 64'h8000000000008080;
                5'd22: round_const = 64'h0000000080000001;
                5'd23: round_const = 64'h8000000080008008;
                default: round_const = 64'h0;
            endcase
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            active <= 1'b0;
            done <= 1'b0;
            round_i <= 5'd0;
            state_out <= 1600'd0;

            for (k = 0; k < 25; k = k + 1)
                S[k] <= 64'd0;
        end
        else if (start) begin
            active <= 1'b1;
            done <= 1'b0;
            round_i <= 5'd0;
            S[0] <= state_in[63:0];
            S[1] <= state_in[127:64];
            S[2] <= state_in[191:128];
            S[3] <= state_in[255:192];
            S[4] <= state_in[319:256];
            S[5] <= state_in[383:320];
            S[6] <= state_in[447:384];
            S[7] <= state_in[511:448];
            S[8] <= state_in[575:512];
            S[9] <= state_in[639:576];
            S[10] <= state_in[703:640];
            S[11] <= state_in[767:704];
            S[12] <= state_in[831:768];
            S[13] <= state_in[895:832];
            S[14] <= state_in[959:896];
            S[15] <= state_in[1023:960];
            S[16] <= state_in[1087:1024];
            S[17] <= state_in[1151:1088];
            S[18] <= state_in[1215:1152];
            S[19] <= state_in[1279:1216];
            S[20] <= state_in[1343:1280];
            S[21] <= state_in[1407:1344];
            S[22] <= state_in[1471:1408];
            S[23] <= state_in[1535:1472];
            S[24] <= state_in[1599:1536];
        end
        else if (active) begin
            rc = round_const(round_i);

            // Theta
            C0 = S[0] ^ S[5] ^ S[10] ^ S[15] ^ S[20];
            C1 = S[1] ^ S[6] ^ S[11] ^ S[16] ^ S[21];
            C2 = S[2] ^ S[7] ^ S[12] ^ S[17] ^ S[22];
            C3 = S[3] ^ S[8] ^ S[13] ^ S[18] ^ S[23];
            C4 = S[4] ^ S[9] ^ S[14] ^ S[19] ^ S[24];

            D0 = C4 ^ ROL(C1, 1);
            D1 = C0 ^ ROL(C2, 1);
            D2 = C1 ^ ROL(C3, 1);
            D3 = C2 ^ ROL(C4, 1);
            D4 = C3 ^ ROL(C0, 1);

            A[0] = S[0] ^ D0;
            A[1] = S[1] ^ D1;
            A[2] = S[2] ^ D2;
            A[3] = S[3] ^ D3;
            A[4] = S[4] ^ D4;
            A[5] = S[5] ^ D0;
            A[6] = S[6] ^ D1;
            A[7] = S[7] ^ D2;
            A[8] = S[8] ^ D3;
            A[9] = S[9] ^ D4;
            A[10] = S[10] ^ D0;
            A[11] = S[11] ^ D1;
            A[12] = S[12] ^ D2;
            A[13] = S[13] ^ D3;
            A[14] = S[14] ^ D4;
            A[15] = S[15] ^ D0;
            A[16] = S[16] ^ D1;
            A[17] = S[17] ^ D2;
            A[18] = S[18] ^ D3;
            A[19] = S[19] ^ D4;
            A[20] = S[20] ^ D0;
            A[21] = S[21] ^ D1;
            A[22] = S[22] ^ D2;
            A[23] = S[23] ^ D3;
            A[24] = S[24] ^ D4;

            // Rho & Pi
            B[0] = ROL(A[0], 0);
            B[10] = ROL(A[1], 1);
            B[20] = ROL(A[2], 62);
            B[5] = ROL(A[3], 28);
            B[15] = ROL(A[4], 27);
            B[16] = ROL(A[5], 36);
            B[1] = ROL(A[6], 44);
            B[11] = ROL(A[7], 6);
            B[21] = ROL(A[8], 55);
            B[6] = ROL(A[9], 20);
            B[7] = ROL(A[10], 3);
            B[17] = ROL(A[11], 10);
            B[2] = ROL(A[12], 43);
            B[12] = ROL(A[13], 25);
            B[22] = ROL(A[14], 39);
            B[23] = ROL(A[15], 41);
            B[8] = ROL(A[16], 45);
            B[18] = ROL(A[17], 15);
            B[3] = ROL(A[18], 21);
            B[13] = ROL(A[19], 8);
            B[14] = ROL(A[20], 18);
            B[24] = ROL(A[21], 2);
            B[9] = ROL(A[22], 61);
            B[19] = ROL(A[23], 56);
            B[4] = ROL(A[24], 14);

            // Chi
            A[0] = B[0] ^ ((~B[1]) & B[2]);
            A[1] = B[1] ^ ((~B[2]) & B[3]);
            A[2] = B[2] ^ ((~B[3]) & B[4]);
            A[3] = B[3] ^ ((~B[4]) & B[0]);
            A[4] = B[4] ^ ((~B[0]) & B[1]);
            A[5] = B[5] ^ ((~B[6]) & B[7]);
            A[6] = B[6] ^ ((~B[7]) & B[8]);
            A[7] = B[7] ^ ((~B[8]) & B[9]);
            A[8] = B[8] ^ ((~B[9]) & B[5]);
            A[9] = B[9] ^ ((~B[5]) & B[6]);
            A[10] = B[10] ^ ((~B[11]) & B[12]);
            A[11] = B[11] ^ ((~B[12]) & B[13]);
            A[12] = B[12] ^ ((~B[13]) & B[14]);
            A[13] = B[13] ^ ((~B[14]) & B[10]);
            A[14] = B[14] ^ ((~B[10]) & B[11]);
            A[15] = B[15] ^ ((~B[16]) & B[17]);
            A[16] = B[16] ^ ((~B[17]) & B[18]);
            A[17] = B[17] ^ ((~B[18]) & B[19]);
            A[18] = B[18] ^ ((~B[19]) & B[15]);
            A[19] = B[19] ^ ((~B[15]) & B[16]);
            A[20] = B[20] ^ ((~B[21]) & B[22]);
            A[21] = B[21] ^ ((~B[22]) & B[23]);
            A[22] = B[22] ^ ((~B[23]) & B[24]);
            A[23] = B[23] ^ ((~B[24]) & B[20]);
            A[24] = B[24] ^ ((~B[20]) & B[21]);

            // Iota
            A[0] = A[0] ^ rc;

            for (k = 0; k < 25; k = k + 1)
                S[k] <= A[k];

            if (round_i == 5'd23) begin
                active <= 1'b0;
                done <= 1'b1;
                state_out[63:0] <= A[0];
                state_out[127:64] <= A[1];
                state_out[191:128] <= A[2];
                state_out[255:192] <= A[3];
                state_out[319:256] <= A[4];
                state_out[383:320] <= A[5];
                state_out[447:384] <= A[6];
                state_out[511:448] <= A[7];
                state_out[575:512] <= A[8];
                state_out[639:576] <= A[9];
                state_out[703:640] <= A[10];
                state_out[767:704] <= A[11];
                state_out[831:768] <= A[12];
                state_out[895:832] <= A[13];
                state_out[959:896] <= A[14];
                state_out[1023:960] <= A[15];
                state_out[1087:1024] <= A[16];
                state_out[1151:1088] <= A[17];
                state_out[1215:1152] <= A[18];
                state_out[1279:1216] <= A[19];
                state_out[1343:1280] <= A[20];
                state_out[1407:1344] <= A[21];
                state_out[1471:1408] <= A[22];
                state_out[1535:1472] <= A[23];
                state_out[1599:1536] <= A[24];
            end
            else begin
                done <= 1'b0;
                round_i <= round_i + 5'd1;
            end
        end
        else begin
            done <= 1'b0;
        end
    end
endmodule
