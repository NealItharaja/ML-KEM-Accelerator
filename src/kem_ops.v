// Shared polynomial memory ops for ML-KEM
module kem_ops(
    input clk,
    input reset,
    input start,
    input [3:0] cmd,
    input [3:0] slot_a,
    input [3:0] slot_b,
    input [3:0] slot_c,
    output reg busy,
    output reg done,
    output reg [12:0] mem_addr,
    output reg [11:0] mem_wdata,
    output reg mem_we,
    input [11:0] mem_rdata
    );

    localparam [3:0] CMD_CLEAR = 4'd0;
    localparam [3:0] CMD_TOM = 4'd1;
    localparam [3:0] CMD_FRM = 4'd2;
    localparam [3:0] CMD_NTT = 4'd3;
    localparam [3:0] CMD_INTT = 4'd4;
    localparam [3:0] CMD_ADD = 4'd5;
    localparam [3:0] CMD_SUB = 4'd6;
    localparam [3:0] CMD_BMUL = 4'd7;
    localparam [11:0] q = 12'd3329;
    localparam [11:0] F = 12'd512;

    reg [3:0] cmd_r, sa, sb, sc;
    reg [7:0] st;
    reg [15:0] i, j, len, start_i;
    reg [6:0] zaddr;
    reg [11:0] t0, t1, t2, t3, zeta_r, a0, a1, b0, b1, mz;
    reg [11:0] mul_a, mul_b, add_a, add_b, sub_a, sub_b, mont_a;

    wire [11:0] mul_r, add_r, sub_r, tom_r, frm_r, zdata;

    mod_mult u_mul(
        .A(mul_a),
        .B(mul_b),
        .result(mul_r)
    );

    mod_add u_add(
        .A(add_a),
        .B(add_b),
        .result(add_r)
    );

    mod_sub u_sub(
        .A(sub_a),
        .B(sub_b),
        .result(sub_r)
    );

    to_montgomery u_tom(
        .A(mont_a),
        .clk(clk),
        .A_Prime(tom_r)
    );

    from_montgomery u_frm(
        .C(mont_a),
        .clk(clk),
        .result(frm_r)
    );

    twiddle_rom u_z(
        .clk(clk),
        .addr(zaddr),
        .data(zdata)
    );

    function [12:0] PA;
        input [3:0] slot;
        input [15:0] c;

        begin
            PA = slot * 256 + c[7:0];
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            busy <= 1'b0;
            done <= 1'b0;
            mem_we <= 1'b0;
            mem_addr <= 13'd0;
            mem_wdata <= 12'd0;
            st <= 8'd0;
            zaddr <= 7'd0;
        end
        else begin
            done <= 1'b0;
            mem_we <= 1'b0;

            if (start && !busy) begin
                busy <= 1'b1;
                cmd_r <= cmd;
                sa <= slot_a;
                sb <= slot_b;
                sc <= slot_c;
                i <= 16'd0;
                st <= 8'd1;
            end
            else if (busy) begin
                case (cmd_r)
                    CMD_CLEAR: begin
                        mem_addr <= PA(sa, i);
                        mem_wdata <= 12'd0;
                        mem_we <= 1'b1;

                        if (i == 16'd255) begin
                            busy <= 1'b0;
                            done <= 1'b1;
                            st <= 8'd0;
                        end
                        else i <= i + 16'd1;
                    end

                    CMD_TOM: begin
                        if (st == 8'd1) begin
                            mem_addr <= PA(sa, i);
                            st <= 8'd2;
                        end
                        else if (st == 8'd2) begin
                            mont_a <= mem_rdata;
                            st <= 8'd3;
                        end
                        else begin
                            mem_addr <= PA(sa, i);
                            mem_wdata <= tom_r;
                            mem_we <= 1'b1;

                            if (i == 16'd255) begin
                                busy <= 1'b0;
                                done <= 1'b1;
                                st <= 8'd0;
                            end
                            else begin
                                i <= i + 16'd1;
                                st <= 8'd1;
                            end
                        end
                    end

                    CMD_FRM: begin
                        if (st == 8'd1) begin
                            mem_addr <= PA(sa, i);
                            st <= 8'd2;
                        end
                        else if (st == 8'd2) begin
                            mont_a <= mem_rdata;
                            st <= 8'd3;
                        end
                        else begin
                            mem_addr <= PA(sa, i);
                            mem_wdata <= frm_r;
                            mem_we <= 1'b1;
                            if (i == 16'd255) begin
                                busy <= 1'b0;
                                done <= 1'b1;
                                st <= 8'd0;
                            end
                            else begin
                                i <= i + 16'd1;
                                st <= 8'd1;
                            end
                        end
                    end

                    CMD_ADD: begin
                        if (st == 8'd1) begin
                            mem_addr <= PA(sa, i);
                            st <= 8'd2;
                        end
                        else if (st == 8'd2) begin
                            t0 <= mem_rdata;
                            mem_addr <= PA(sb, i);
                            st <= 8'd3;
                        end
                        else if (st == 8'd3) begin
                            add_a <= t0;
                            add_b <= mem_rdata;
                            st <= 8'd4;
                        end
                        else begin
                            mem_addr <= PA(sc, i);
                            mem_wdata <= add_r;
                            mem_we <= 1'b1;
                            if (i == 16'd255) begin
                                busy <= 1'b0;
                                done <= 1'b1;
                                st <= 8'd0;
                            end
                            else begin
                                i <= i + 16'd1;
                                st <= 8'd1;
                            end
                        end
                    end

                    CMD_SUB: begin
                        if (st == 8'd1) begin
                            mem_addr <= PA(sa, i);
                            st <= 8'd2;
                        end
                        else if (st == 8'd2) begin
                            t0 <= mem_rdata;
                            mem_addr <= PA(sb, i);
                            st <= 8'd3;
                        end
                        else if (st == 8'd3) begin
                            sub_a <= t0;
                            sub_b <= mem_rdata;
                            st <= 8'd4;
                        end
                        else begin
                            mem_addr <= PA(sc, i);
                            mem_wdata <= sub_r;
                            mem_we <= 1'b1;

                            if (i == 16'd255) begin
                                busy <= 1'b0;
                                done <= 1'b1;
                                st <= 8'd0;
                            end
                            else begin
                                i <= i + 16'd1;
                                st <= 8'd1;
                            end
                        end
                    end

                    CMD_NTT: begin
                        if (st == 8'd1) begin
                            len <= 16'd128;
                            start_i <= 16'd0;
                            zaddr <= 7'd1;
                            st <= 8'd9;
                        end
                        else if (st == 8'd9) begin
                            st <= 8'd2;
                        end
                        else if (st == 8'd2) begin
                            zeta_r <= zdata;
                            j <= start_i;
                            st <= 8'd3;
                        end
                        else if (st == 8'd3) begin
                            mem_addr <= PA(sa, j + len);
                            st <= 8'd4;
                        end
                        else if (st == 8'd4) begin
                            mul_a <= mem_rdata;
                            mul_b <= zeta_r;
                            mem_addr <= PA(sa, j);
                            st <= 8'd5;
                        end
                        else if (st == 8'd5) begin
                            t1 <= mul_r;
                            t0 <= mem_rdata;
                            st <= 8'd6;
                        end
                        else if (st == 8'd6) begin
                            add_a <= t0;
                            add_b <= t1;
                            sub_a <= t0;
                            sub_b <= t1;
                            st <= 8'd7;
                        end
                        else if (st == 8'd7) begin
                            mem_addr <= PA(sa, j);
                            mem_wdata <= add_r;
                            mem_we <= 1'b1;
                            t2 <= sub_r;
                            st <= 8'd8;
                        end
                        else if (st == 8'd8) begin
                            mem_addr <= PA(sa, j + len);
                            mem_wdata <= t2;
                            mem_we <= 1'b1;

                            if (j + 1 < start_i + len) begin
                                j <= j + 16'd1;
                                st <= 8'd3;
                            end
                            else if (start_i + (len << 1) < 16'd256) begin
                                start_i <= start_i + (len << 1);
                                zaddr <= zaddr + 7'd1;
                                st <= 8'd9;
                            end
                            else if (len > 16'd2) begin
                                len <= len >> 1;
                                start_i <= 16'd0;
                                zaddr <= zaddr + 7'd1;
                                st <= 8'd9;
                            end
                            else begin
                                busy <= 1'b0;
                                done <= 1'b1;
                                st <= 8'd0;
                            end
                        end
                    end

                    CMD_INTT: begin
                        if (st == 8'd1) begin
                            len <= 16'd2;
                            start_i <= 16'd0;
                            zaddr <= 7'd127;
                            st <= 8'd9;
                        end
                        else if (st == 8'd9) begin
                            st <= 8'd2;
                        end
                        else if (st == 8'd2) begin
                            zeta_r <= zdata;
                            j <= start_i;
                            st <= 8'd3;
                        end
                        else if (st == 8'd3) begin
                            mem_addr <= PA(sa, j);
                            st <= 8'd4;
                        end
                        else if (st == 8'd4) begin
                            t0 <= mem_rdata;
                            mem_addr <= PA(sa, j + len);
                            st <= 8'd5;
                        end
                        else if (st == 8'd5) begin
                            t1 <= mem_rdata;
                            add_a <= t0;
                            add_b <= mem_rdata;
                            sub_a <= mem_rdata;
                            sub_b <= t0;
                            st <= 8'd6;
                        end
                        else if (st == 8'd6) begin
                            mem_addr <= PA(sa, j);
                            mem_wdata <= add_r;
                            mem_we <= 1'b1;
                            mul_a <= sub_r;
                            mul_b <= zeta_r;
                            st <= 8'd7;
                        end
                        else if (st == 8'd7) begin
                            mem_addr <= PA(sa, j + len);
                            mem_wdata <= mul_r;
                            mem_we <= 1'b1;

                            if (j + 1 < start_i + len) begin
                                j <= j + 16'd1;
                                st <= 8'd3;
                            end
                            else if (start_i + (len << 1) < 16'd256) begin
                                start_i <= start_i + (len << 1);
                                zaddr <= zaddr - 7'd1;
                                st <= 8'd9;
                            end
                            else if (len < 16'd128) begin
                                len <= len << 1;
                                start_i <= 16'd0;
                                zaddr <= zaddr - 7'd1;
                                st <= 8'd9;
                            end
                            else begin
                                i <= 16'd0;
                                st <= 8'd10;
                            end
                        end
                        else if (st == 8'd10) begin
                            mem_addr <= PA(sa, i);
                            st <= 8'd11;
                        end
                        else if (st == 8'd11) begin
                            mul_a <= mem_rdata;
                            mul_b <= F;
                            st <= 8'd12;
                        end
                        else begin
                            mem_addr <= PA(sa, i);
                            mem_wdata <= mul_r;
                            mem_we <= 1'b1;
                            if (i == 16'd255) begin
                                busy <= 1'b0;
                                done <= 1'b1;
                                st <= 8'd0;
                            end
                            else begin
                                i <= i + 16'd1;
                                st <= 8'd10;
                            end
                        end
                    end

                    CMD_BMUL: begin
                        if (st == 8'd1) begin
                            i <= 16'd0;
                            zaddr <= 7'd64;
                            st <= 8'd40;
                        end
                        else if (st == 8'd40) begin
                            st <= 8'd2;
                        end
                        else if (st == 8'd2) begin
                            zeta_r <= zdata;
                            sub_a <= q;
                            sub_b <= zdata;
                            st <= 8'd3;
                        end
                        else if (st == 8'd3) begin
                            mz <= sub_r;
                            mem_addr <= PA(sa, (i << 2));
                            st <= 8'd4;
                        end
                        else if (st == 8'd4) begin
                            a0 <= mem_rdata;
                            mem_addr <= PA(sa, (i << 2) + 1);
                            st <= 8'd5;
                        end
                        else if (st == 8'd5) begin
                            a1 <= mem_rdata;
                            mem_addr <= PA(sb, (i << 2));
                            st <= 8'd6;
                        end
                        else if (st == 8'd6) begin
                            b0 <= mem_rdata;
                            mem_addr <= PA(sb, (i << 2) + 1);
                            st <= 8'd7;
                        end
                        else if (st == 8'd7) begin
                            b1 <= mem_rdata;
                            mul_a <= a0;
                            mul_b <= b0;
                            st <= 8'd8;
                        end
                        else if (st == 8'd8) begin
                            t0 <= mul_r;
                            mul_a <= a1;
                            mul_b <= b1;
                            st <= 8'd9;
                        end
                        else if (st == 8'd9) begin
                            mul_a <= mul_r;
                            mul_b <= zeta_r;
                            st <= 8'd10;
                        end
                        else if (st == 8'd10) begin
                            add_a <= t0;
                            add_b <= mul_r;
                            st <= 8'd11;
                        end
                        else if (st == 8'd11) begin
                            t2 <= add_r;
                            mul_a <= a0;
                            mul_b <= b1;
                            st <= 8'd12;
                        end
                        else if (st == 8'd12) begin
                            t0 <= mul_r;
                            mul_a <= a1;
                            mul_b <= b0;
                            st <= 8'd13;
                        end
                        else if (st == 8'd13) begin
                            add_a <= t0;
                            add_b <= mul_r;
                            st <= 8'd14;
                        end
                        else if (st == 8'd14) begin
                            t3 <= add_r;
                            mem_addr <= PA(sc, (i << 2));
                            st <= 8'd15;
                        end
                        else if (st == 8'd15) begin
                            add_a <= mem_rdata;
                            add_b <= t2;
                            st <= 8'd16;
                        end
                        else if (st == 8'd16) begin
                            mem_addr <= PA(sc, (i << 2));
                            mem_wdata <= add_r;
                            mem_we <= 1'b1;
                            st <= 8'd17;
                        end
                        else if (st == 8'd17) begin
                            mem_addr <= PA(sc, (i << 2) + 1);
                            st <= 8'd18;
                        end
                        else if (st == 8'd18) begin
                            add_a <= mem_rdata;
                            add_b <= t3;
                            st <= 8'd19;
                        end
                        else if (st == 8'd19) begin
                            mem_addr <= PA(sc, (i << 2) + 1);
                            mem_wdata <= add_r;
                            mem_we <= 1'b1;
                            st <= 8'd20;
                        end
                        else if (st == 8'd20) begin
                            mem_addr <= PA(sa, (i << 2) + 2);
                            st <= 8'd21;
                        end
                        else if (st == 8'd21) begin
                            a0 <= mem_rdata;
                            mem_addr <= PA(sa, (i << 2) + 3);
                            st <= 8'd22;
                        end
                        else if (st == 8'd22) begin
                            a1 <= mem_rdata;
                            mem_addr <= PA(sb, (i << 2) + 2);
                            st <= 8'd23;
                        end
                        else if (st == 8'd23) begin
                            b0 <= mem_rdata;
                            mem_addr <= PA(sb, (i << 2) + 3);
                            st <= 8'd24;
                        end
                        else if (st == 8'd24) begin
                            b1 <= mem_rdata;
                            mul_a <= a0;
                            mul_b <= b0;
                            st <= 8'd25;
                        end
                        else if (st == 8'd25) begin
                            t0 <= mul_r;
                            mul_a <= a1;
                            mul_b <= b1;
                            st <= 8'd26;
                        end
                        else if (st == 8'd26) begin
                            mul_a <= mul_r;
                            mul_b <= mz;
                            st <= 8'd27;
                        end
                        else if (st == 8'd27) begin
                            add_a <= t0;
                            add_b <= mul_r;
                            st <= 8'd28;
                        end
                        else if (st == 8'd28) begin
                            t2 <= add_r;
                            mul_a <= a0;
                            mul_b <= b1;
                            st <= 8'd29;
                        end
                        else if (st == 8'd29) begin
                            t0 <= mul_r;
                            mul_a <= a1;
                            mul_b <= b0;
                            st <= 8'd30;
                        end
                        else if (st == 8'd30) begin
                            add_a <= t0;
                            add_b <= mul_r;
                            st <= 8'd31;
                        end
                        else if (st == 8'd31) begin
                            t3 <= add_r;
                            mem_addr <= PA(sc, (i << 2) + 2);
                            st <= 8'd32;
                        end
                        else if (st == 8'd32) begin
                            add_a <= mem_rdata;
                            add_b <= t2;
                            st <= 8'd33;
                        end
                        else if (st == 8'd33) begin
                            mem_addr <= PA(sc, (i << 2) + 2);
                            mem_wdata <= add_r;
                            mem_we <= 1'b1;
                            st <= 8'd34;
                        end
                        else if (st == 8'd34) begin
                            mem_addr <= PA(sc, (i << 2) + 3);
                            st <= 8'd35;
                        end
                        else if (st == 8'd35) begin
                            add_a <= mem_rdata;
                            add_b <= t3;
                            st <= 8'd36;
                        end
                        else if (st == 8'd36) begin
                            mem_addr <= PA(sc, (i << 2) + 3);
                            mem_wdata <= add_r;
                            mem_we <= 1'b1;
                            if (i == 16'd63) begin
                                busy <= 1'b0;
                                done <= 1'b1;
                                st <= 8'd0;
                            end
                            else begin
                                i <= i + 16'd1;
                                zaddr <= 7'd64 + i[6:0] + 7'd1;
                                st <= 8'd40;
                            end
                        end
                    end

                    default: begin
                        busy <= 1'b0;
                        st <= 8'd0;
                    end
                endcase
            end
        end
    end
endmodule