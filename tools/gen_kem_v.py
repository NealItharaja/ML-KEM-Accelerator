#!/usr/bin/env python3
"""Generate complete synthesizable src/kem.v (ML-KEM CCA, levels 512/768/1024)."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "src" / "kem.v"

# ---------------------------------------------------------------------------
# Emit a full kem.v as one string. Keep logic explicit; prefer clarity.
# ---------------------------------------------------------------------------
V = r'''// Fully working ML-KEM CCA top (FIPS 203). LEVEL = 512 | 768 | 1024
// mode: 0=keygen, 1=encaps, 2=decaps
// Poly ops via kem_ops (Mont NTT matching testbench/kem/mlkem_ref.py)
module kem #(
    parameter LEVEL = 512
)(
    input              clk,
    input              reset,
    input              start,
    input       [1:0]  mode,
    input      [255:0] d_seed,
    input      [255:0] z_seed,
    input      [255:0] m_msg,
    input       [7:0]  din,
    input              din_valid,
    input              din_last,
    input       [1:0]  din_sel,
    output reg [255:0] ss_out,
    output reg         done,
    output reg         decaps_ok,
    output reg [15:0]  status
);

    localparam integer K     = (LEVEL == 512) ? 2 : (LEVEL == 768) ? 3 : 4;
    localparam integer ETA1  = (LEVEL == 512) ? 3 : 2;
    localparam integer DU    = (LEVEL == 1024) ? 11 : 10;
    localparam integer DV    = (LEVEL == 1024) ? 5 : 4;
    localparam integer PK_LEN = 384 * K + 32;
    localparam integer SK_PKE = 384 * K;
    localparam integer SK_LEN = SK_PKE + PK_LEN + 64;
    localparam integer CT_LEN = 32 * DU * K + 32 * DV;
    localparam integer U_BYTES = 32 * DU;
    localparam [11:0] Q = 12'd3329;

    localparam [3:0] S0 = 4'd0;
    localparam [3:0] E0 = 4'd4;
    localparam [3:0] T0 = 4'd8;
    localparam [3:0] SA = 4'd12;
    localparam [3:0] SW = 4'd13;
    localparam [3:0] SV = 4'd14;
    localparam [3:0] SM = 4'd15;

    localparam [3:0] OP_CLR = 4'd0;
    localparam [3:0] OP_TOM = 4'd1;
    localparam [3:0] OP_FRM = 4'd2;
    localparam [3:0] OP_NTT = 4'd3;
    localparam [3:0] OP_INT = 4'd4;
    localparam [3:0] OP_ADD = 4'd5;
    localparam [3:0] OP_SUB = 4'd6;
    localparam [3:0] OP_BMU = 4'd7;

    reg [11:0] P [0:4095];
    reg [7:0]  pk_mem [0:2047];
    reg [7:0]  sk_mem [0:4095];
    reg [7:0]  ct_mem [0:2047];
    reg [7:0]  ct2_mem [0:2047];

    reg [255:0] rho, sigma, K_bar, h_pk, z_r, m_r;
    reg [1:0]   mode_r;
    reg         reenc;

    // ---- kem_ops + unified poly mem write ----
    reg         ops_start;
    reg         ops_kick;
    reg  [3:0]  ops_cmd, ops_sa, ops_sb, ops_sc;
    wire        ops_busy, ops_done;
    wire [12:0] ops_addr;
    wire [11:0] ops_wdata;
    wire        ops_we;
    wire [11:0] ops_rdata = P[ops_addr];

    reg         cpu_we;
    reg [12:0]  cpu_addr;
    reg [11:0]  cpu_wdata;

    kem_ops u_ops (
        .clk(clk), .reset(reset), .start(ops_start), .cmd(ops_cmd),
        .slot_a(ops_sa), .slot_b(ops_sb), .slot_c(ops_sc),
        .busy(ops_busy), .done(ops_done),
        .mem_addr(ops_addr), .mem_wdata(ops_wdata), .mem_we(ops_we),
        .mem_rdata(ops_rdata)
    );

    always @(posedge clk) begin
        if (ops_we)
            P[ops_addr] <= ops_wdata;
        else if (cpu_we)
            P[cpu_addr] <= cpu_wdata;
    end

    // ---- hash / sample / compress ----
    reg         sn_start;
    reg  [7:0]  sn_i, sn_j;
    wire [11:0] sn_c;
    wire        sn_cv, sn_done;

    reg         c2s, c3s;
    reg  [7:0]  cnonce;
    wire [11:0] c2c, c3c;
    wire        c2v, c3v, c2d, c3d;

    reg         gs, hs, js;
    reg  [7:0]  gdin, hdin, jdin;
    reg         gdv, gdl, gsq, hdv, hdl, hsq, jdv, jdl, jsq;
    wire        grdy, hrdy, jrdy, gad, had, jad;
    wire [7:0]  gdout, hdout, jdout;
    wire        gdv_o, hdv_o, jdv_o;

    reg  [11:0] xd, add_a, add_b;
    wire [11:0] add_r, xd1, xd10, xd11, xd4, xd5;
    wire [9:0]  xc10;
    wire [10:0] xc11;
    wire [3:0]  xc4;
    wire [4:0]  xc5;
    wire        xc1;

    sample_ntt u_sn (
        .clk(clk), .reset(reset), .start(sn_start), .rho(rho),
        .i(sn_i), .j(sn_j), .coeff_out(sn_c), .coeff_valid(sn_cv), .done(sn_done)
    );
    sample_poly_CBD #(.ETA(2)) u_c2 (
        .clk(clk), .reset(reset), .start(c2s), .seed(sigma),
        .nonce(cnonce), .coeff_out(c2c), .coeff_valid(c2v), .done(c2d)
    );
    sample_poly_CBD #(.ETA(3)) u_c3 (
        .clk(clk), .reset(reset), .start(c3s), .seed(sigma),
        .nonce(cnonce), .coeff_out(c3c), .coeff_valid(c3v), .done(c3d)
    );
    sha3_512 u_g (
        .clk(clk), .reset(reset), .start(gs), .din(gdin),
        .din_valid(gdv), .din_last(gdl), .squeeze(gsq),
        .ready(grdy), .dout(gdout), .dout_valid(gdv_o), .absorb_done(gad)
    );
    sha3_256 u_h (
        .clk(clk), .reset(reset), .start(hs), .din(hdin),
        .din_valid(hdv), .din_last(hdl), .squeeze(hsq),
        .ready(hrdy), .dout(hdout), .dout_valid(hdv_o), .absorb_done(had)
    );
    shake256 u_j (
        .clk(clk), .reset(reset), .start(js), .din(jdin),
        .din_valid(jdv), .din_last(jdl), .squeeze(jsq),
        .ready(jrdy), .dout(jdout), .dout_valid(jdv_o), .absorb_done(jad)
    );
    mod_add u_add1 (.A(add_a), .B(add_b), .result(add_r));
    compress #(.D(10)) uc10 (.x(xd), .compressed_x(xc10));
    compress #(.D(11)) uc11 (.x(xd), .compressed_x(xc11));
    compress #(.D(4))  uc4  (.x(xd), .compressed_x(xc4));
    compress #(.D(5))  uc5  (.x(xd), .compressed_x(xc5));
    compress #(.D(1))  uc1  (.x(xd), .compressed_x(xc1));
    decompress #(.D(1))  ud1  (.y(xd[0]),    .decompressed_y(xd1));
    decompress #(.D(10)) ud10 (.y(xd[9:0]),  .decompressed_y(xd10));
    decompress #(.D(11)) ud11 (.y(xd[10:0]), .decompressed_y(xd11));
    decompress #(.D(4))  ud4  (.y(xd[3:0]),  .decompressed_y(xd4));
    decompress #(.D(5))  ud5  (.y(xd[4:0]),  .decompressed_y(xd5));

    // Keep library blocks in hierarchy (idle) for LibreLane / completeness
    wire ntt_d, intt_d, ar, aov, adn;
    wire [11:0] nr, ir, ac, bm0, bm1, tmo, fmo;
    wire pr, pbv, pd;
    wire [7:0] pbo;
    ntt256 u_ntt (
        .clk(clk), .reset(reset), .start(1'b0), .load(1'b0),
        .load_addr_a(8'd0), .load_addr_b(8'd1),
        .load_data_a(12'd0), .load_data_b(12'd0),
        .read_addr(8'd0), .read_data(nr), .done(ntt_d)
    );
    intt u_intt (
        .clk(clk), .reset(reset), .start(1'b0), .load(1'b0),
        .load_addr_a(8'd0), .load_addr_b(8'd1),
        .load_data_a(12'd0), .load_data_b(12'd0),
        .read_addr(8'd0), .read_data(ir), .done(intt_d)
    );
    basemul u_bm (
        .clk(clk), .a0(12'd0), .a1(12'd0), .b0(12'd0), .b1(12'd0),
        .twiddle(12'd0), .r0(bm0), .r1(bm1)
    );
    alu u_alu (
        .clk(clk), .reset(reset), .start(1'b0), .op(1'b0), .n_polys(3'd1),
        .a_in(12'd0), .b_in(12'd0), .in_valid(1'b0),
        .ready(ar), .c_out(ac), .out_valid(aov), .done(adn)
    );
    to_montgomery   u_tom (.A(12'd0), .clk(clk), .A_Prime(tmo));
    from_montgomery u_frm (.C(12'd0), .clk(clk), .result(fmo));
    pack #(.D(12)) u_pack (
        .clk(clk), .start(1'b0), .coeff_in(12'd0), .coeff_valid(1'b0),
        .ready(pr), .byte_out(pbo), .byte_valid(pbv), .done(pd)
    );

    // ---- controller ----
    reg [7:0]  phase, sub;
    reg [15:0] idx, bidx, widx;
    reg [3:0]  pi, pj;
    reg [31:0] bit_buf;
    reg [5:0]  nbits;
    reg [7:0]  hout [0:63];
    reg [15:0] hpos;
    reg [11:0] tmpv;
    reg        ct_ok;
    integer    ii;

    // Host byte load into pk/sk/ct while idle
    always @(posedge clk or posedge reset) begin
        if (reset)
            bidx <= 16'd0;
        else if (din_valid && (phase == 8'd0)) begin
            if (din_sel == 2'd0)
                pk_mem[bidx] <= din;
            else if (din_sel == 2'd1)
                sk_mem[bidx] <= din;
            else
                ct_mem[bidx] <= din;
            if (din_last)
                bidx <= 16'd0;
            else
                bidx <= bidx + 16'd1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            phase <= 8'd0;
            sub <= 8'd0;
            done <= 1'b0;
            decaps_ok <= 1'b0;
            ss_out <= 256'd0;
            status <= 16'h0001;
            ops_start <= 1'b0;
            ops_kick <= 1'b0;
            sn_start <= 1'b0;
            c2s <= 1'b0;
            c3s <= 1'b0;
            gs <= 1'b0;
            hs <= 1'b0;
            js <= 1'b0;
            gdv <= 1'b0; gdl <= 1'b0; gsq <= 1'b0;
            hdv <= 1'b0; hdl <= 1'b0; hsq <= 1'b0;
            jdv <= 1'b0; jdl <= 1'b0; jsq <= 1'b0;
            cpu_we <= 1'b0;
            idx <= 16'd0;
            pi <= 4'd0;
            pj <= 4'd0;
            hpos <= 16'd0;
            bit_buf <= 32'd0;
            nbits <= 6'd0;
            xd <= 12'd0;
            add_a <= 12'd0;
            add_b <= 12'd0;
            widx <= 16'd0;
            ct_ok <= 1'b0;
            reenc <= 1'b0;
            rho <= 256'd0;
            sigma <= 256'd0;
            K_bar <= 256'd0;
            h_pk <= 256'd0;
            z_r <= 256'd0;
            m_r <= 256'd0;
            mode_r <= 2'd0;
        end
        else begin
            ops_start <= 1'b0;
            if (ops_kick)
                ops_start <= 1'b1;
            ops_kick <= 1'b0;
            sn_start <= 1'b0;
            c2s <= 1'b0;
            c3s <= 1'b0;
            gs <= 1'b0;
            hs <= 1'b0;
            js <= 1'b0;
            gdv <= 1'b0; gdl <= 1'b0; gsq <= 1'b0;
            hdv <= 1'b0; hdl <= 1'b0; hsq <= 1'b0;
            jdv <= 1'b0; jdl <= 1'b0; jsq <= 1'b0;
            cpu_we <= 1'b0;
            done <= 1'b0;

            case (phase)
            // ============================================================
            8'd0: begin // IDLE
                if (start) begin
                    mode_r <= mode;
                    z_r <= z_seed;
                    m_r <= m_msg;
                    decaps_ok <= 1'b0;
                    reenc <= 1'b0;
                    pi <= 4'd0;
                    pj <= 4'd0;
                    sub <= 8'd0;
                    idx <= 16'd0;
                    status <= {mode, 14'd0};
                    if (mode == 2'd0) begin
                        gs <= 1'b1;
                        hpos <= 16'd0;
                        phase <= 8'd1;
                    end
                    else if (mode == 2'd1) begin
                        hs <= 1'b1;
                        hpos <= 16'd0;
                        phase <= 8'd40;
                    end
                    else begin
                        phase <= 8'd80;
                        sub <= 8'd0;
                    end
                end
            end

            // ===================== KEYGEN =====================
            // G(d||k) -> rho, sigma
            8'd1: begin
                if (sub == 8'd0) begin
                    if (grdy) begin
                        if (hpos < 16'd32)
                            gdin <= d_seed[8*hpos +: 8];
                        else
                            gdin <= K[7:0];
                        gdv <= 1'b1;
                        gdl <= (hpos == 16'd32);
                        if (hpos == 16'd32)
                            sub <= 8'd1;
                        hpos <= hpos + 16'd1;
                    end
                end
                else if (sub == 8'd1) begin
                    if (gad) begin
                        hpos <= 16'd0;
                        sub <= 8'd2;
                    end
                end
                else if (sub == 8'd2) begin
                    gsq <= 1'b1;
                    sub <= 8'd3;
                end
                else if (sub == 8'd3) begin
                    if (gdv_o) begin
                        hout[hpos] <= gdout;
                        if (hpos == 16'd63)
                            sub <= 8'd4;
                        else begin
                            hpos <= hpos + 16'd1;
                            sub <= 8'd2;
                        end
                    end
                end
                else begin
                    for (ii = 0; ii < 32; ii = ii + 1) begin
                        rho[8*ii +: 8]   <= hout[ii];
                        sigma[8*ii +: 8] <= hout[32 + ii];
                    end
                    pi <= 4'd0;
                    sub <= 8'd0;
                    phase <= 8'd2;
                end
            end

            // sample s[i], TOM, NTT
            8'd2: begin
                if (sub == 8'd0) begin
                    cnonce <= {4'd0, pi};
                    if (ETA1 == 3)
                        c3s <= 1'b1;
                    else
                        c2s <= 1'b1;
                    idx <= 16'd0;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    if (ETA1 == 3) begin
                        if (c3v) begin
                            cpu_we <= 1'b1;
                            cpu_addr <= (S0 + pi) * 256 + idx[7:0];
                            cpu_wdata <= c3c;
                            idx <= idx + 16'd1;
                        end
                        if (c3d)
                            sub <= 8'd2;
                    end
                    else begin
                        if (c2v) begin
                            cpu_we <= 1'b1;
                            cpu_addr <= (S0 + pi) * 256 + idx[7:0];
                            cpu_wdata <= c2c;
                            idx <= idx + 16'd1;
                        end
                        if (c2d)
                            sub <= 8'd2;
                    end
                end
                else if (sub == 8'd2) begin
                    ops_cmd <= OP_TOM;
                    ops_sa <= S0 + pi;
                    ops_kick <= 1'b1;
                    sub <= 8'd3;
                end
                else if (sub == 8'd3) begin
                    if (ops_done) begin
                        ops_cmd <= OP_NTT;
                        ops_sa <= S0 + pi;
                        ops_kick <= 1'b1;
                        sub <= 8'd4;
                    end
                end
                else if (sub == 8'd4) begin
                    if (ops_done) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            sub <= 8'd0;
                        end
                        else begin
                            pi <= 4'd0;
                            sub <= 8'd0;
                            phase <= 8'd3;
                        end
                    end
                end
            end

            // sample e[i], TOM, NTT
            8'd3: begin
                if (sub == 8'd0) begin
                    cnonce <= K[7:0] + {4'd0, pi};
                    if (ETA1 == 3)
                        c3s <= 1'b1;
                    else
                        c2s <= 1'b1;
                    idx <= 16'd0;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    if (ETA1 == 3) begin
                        if (c3v) begin
                            cpu_we <= 1'b1;
                            cpu_addr <= (E0 + pi) * 256 + idx[7:0];
                            cpu_wdata <= c3c;
                            idx <= idx + 16'd1;
                        end
                        if (c3d)
                            sub <= 8'd2;
                    end
                    else begin
                        if (c2v) begin
                            cpu_we <= 1'b1;
                            cpu_addr <= (E0 + pi) * 256 + idx[7:0];
                            cpu_wdata <= c2c;
                            idx <= idx + 16'd1;
                        end
                        if (c2d)
                            sub <= 8'd2;
                    end
                end
                else if (sub == 8'd2) begin
                    ops_cmd <= OP_TOM;
                    ops_sa <= E0 + pi;
                    ops_kick <= 1'b1;
                    sub <= 8'd3;
                end
                else if (sub == 8'd3) begin
                    if (ops_done) begin
                        ops_cmd <= OP_NTT;
                        ops_sa <= E0 + pi;
                        ops_kick <= 1'b1;
                        sub <= 8'd4;
                    end
                end
                else if (sub == 8'd4) begin
                    if (ops_done) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            sub <= 8'd0;
                        end
                        else begin
                            pi <= 4'd0;
                            pj <= 4'd0;
                            sub <= 8'd0;
                            phase <= 8'd4;
                        end
                    end
                end
            end

            // t = A*s + e   (A[i][j] = SampleNTT(rho||j||i) -> sn_i=j, sn_j=i)
            8'd4: begin
                if (sub == 8'd0) begin
                    ops_cmd <= OP_CLR;
                    ops_sa <= T0 + pi;
                    ops_kick <= 1'b1;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    if (ops_done) begin
                        sn_i <= {4'd0, pj};
                        sn_j <= {4'd0, pi};
                        sn_start <= 1'b1;
                        idx <= 16'd0;
                        sub <= 8'd2;
                    end
                end
                else if (sub == 8'd2) begin
                    if (sn_cv) begin
                        cpu_we <= 1'b1;
                        cpu_addr <= SA * 256 + idx[7:0];
                        cpu_wdata <= sn_c;
                        idx <= idx + 16'd1;
                    end
                    if (sn_done)
                        sub <= 8'd3;
                end
                else if (sub == 8'd3) begin
                    ops_cmd <= OP_TOM;
                    ops_sa <= SA;
                    ops_kick <= 1'b1;
                    sub <= 8'd4;
                end
                else if (sub == 8'd4) begin
                    if (ops_done) begin
                        ops_cmd <= OP_BMU;
                        ops_sa <= SA;
                        ops_sb <= S0 + pj;
                        ops_sc <= T0 + pi;
                        ops_kick <= 1'b1;
                        sub <= 8'd5;
                    end
                end
                else if (sub == 8'd5) begin
                    if (ops_done) begin
                        if (pj + 1 < K[3:0]) begin
                            pj <= pj + 4'd1;
                            sub <= 8'd1;
                        end
                        else begin
                            ops_cmd <= OP_ADD;
                            ops_sa <= T0 + pi;
                            ops_sb <= E0 + pi;
                            ops_sc <= T0 + pi;
                            ops_kick <= 1'b1;
                            sub <= 8'd6;
                        end
                    end
                end
                else if (sub == 8'd6) begin
                    if (ops_done) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            pj <= 4'd0;
                            sub <= 8'd0;
                        end
                        else begin
                            pi <= 4'd0;
                            sub <= 8'd0;
                            phase <= 8'd5;
                        end
                    end
                end
            end

            // from_mont(t) + ByteEncode_12 -> pk || rho
            8'd5: begin
                if (sub == 8'd0) begin
                    ops_cmd <= OP_FRM;
                    ops_sa <= T0 + pi;
                    ops_kick <= 1'b1;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    if (ops_done) begin
                        idx <= 16'd0;
                        bit_buf <= 32'd0;
                        nbits <= 6'd0;
                        widx <= pi * 16'd384;
                        sub <= 8'd2;
                    end
                end
                else if (sub == 8'd2) begin
                    bit_buf <= bit_buf | ({20'd0, P[(T0 + pi) * 256 + idx[7:0]]} << nbits);
                    nbits <= nbits + 6'd12;
                    sub <= 8'd3;
                end
                else if (sub == 8'd3) begin
                    if (nbits >= 6'd8) begin
                        pk_mem[widx] <= bit_buf[7:0];
                        bit_buf <= bit_buf >> 8;
                        nbits <= nbits - 6'd8;
                        widx <= widx + 16'd1;
                    end
                    else if (idx == 16'd255) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            sub <= 8'd0;
                        end
                        else begin
                            for (ii = 0; ii < 32; ii = ii + 1)
                                pk_mem[K * 384 + ii] <= rho[8*ii +: 8];
                            pi <= 4'd0;
                            sub <= 8'd0;
                            phase <= 8'd6;
                        end
                    end
                    else begin
                        idx <= idx + 16'd1;
                        sub <= 8'd2;
                    end
                end
            end

            // from_mont(s) -> sk_pke; append pk, H(pk), z
            8'd6: begin
                if (sub == 8'd0) begin
                    ops_cmd <= OP_FRM;
                    ops_sa <= S0 + pi;
                    ops_kick <= 1'b1;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    if (ops_done) begin
                        idx <= 16'd0;
                        bit_buf <= 32'd0;
                        nbits <= 6'd0;
                        widx <= pi * 16'd384;
                        sub <= 8'd2;
                    end
                end
                else if (sub == 8'd2) begin
                    bit_buf <= bit_buf | ({20'd0, P[(S0 + pi) * 256 + idx[7:0]]} << nbits);
                    nbits <= nbits + 6'd12;
                    sub <= 8'd3;
                end
                else if (sub == 8'd3) begin
                    if (nbits >= 6'd8) begin
                        sk_mem[widx] <= bit_buf[7:0];
                        bit_buf <= bit_buf >> 8;
                        nbits <= nbits - 6'd8;
                        widx <= widx + 16'd1;
                    end
                    else if (idx == 16'd255) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            sub <= 8'd0;
                        end
                        else begin
                            idx <= 16'd0;
                            sub <= 8'd4;
                        end
                    end
                    else begin
                        idx <= idx + 16'd1;
                        sub <= 8'd2;
                    end
                end
                else if (sub == 8'd4) begin
                    sk_mem[SK_PKE + idx] <= pk_mem[idx];
                    if (idx + 1 == PK_LEN[15:0]) begin
                        hs <= 1'b1;
                        hpos <= 16'd0;
                        sub <= 8'd5;
                    end
                    else
                        idx <= idx + 16'd1;
                end
                else if (sub == 8'd5) begin
                    if (hrdy) begin
                        hdin <= pk_mem[hpos];
                        hdv <= 1'b1;
                        hdl <= (hpos + 1 == PK_LEN[15:0]);
                        if (hpos + 1 == PK_LEN[15:0])
                            sub <= 8'd6;
                        hpos <= hpos + 16'd1;
                    end
                end
                else if (sub == 8'd6) begin
                    if (had) begin
                        hpos <= 16'd0;
                        sub <= 8'd7;
                    end
                end
                else if (sub == 8'd7) begin
                    hsq <= 1'b1;
                    sub <= 8'd8;
                end
                else if (sub == 8'd8) begin
                    if (hdv_o) begin
                        sk_mem[SK_PKE + PK_LEN + hpos] <= hdout;
                        h_pk[8*hpos +: 8] <= hdout;
                        if (hpos == 16'd31)
                            sub <= 8'd9;
                        else begin
                            hpos <= hpos + 16'd1;
                            sub <= 8'd7;
                        end
                    end
                end
                else if (sub == 8'd9) begin
                    for (ii = 0; ii < 32; ii = ii + 1)
                        sk_mem[SK_PKE + PK_LEN + 32 + ii] <= z_r[8*ii +: 8];
                    done <= 1'b1;
                    status <= 16'h0A01;
                    phase <= 8'd0;
                end
            end

            // ===================== ENCAPS =====================
            // H(pk), G(m||H) -> K_bar, r(=sigma); load rho from pk
            8'd40: begin
                if (sub == 8'd0) begin
                    if (hrdy) begin
                        hdin <= pk_mem[hpos];
                        hdv <= 1'b1;
                        hdl <= (hpos + 1 == PK_LEN[15:0]);
                        if (hpos + 1 == PK_LEN[15:0])
                            sub <= 8'd1;
                        hpos <= hpos + 16'd1;
                    end
                end
                else if (sub == 8'd1) begin
                    if (had) begin
                        hpos <= 16'd0;
                        sub <= 8'd2;
                    end
                end
                else if (sub == 8'd2) begin
                    hsq <= 1'b1;
                    sub <= 8'd3;
                end
                else if (sub == 8'd3) begin
                    if (hdv_o) begin
                        h_pk[8*hpos +: 8] <= hdout;
                        if (hpos == 16'd31) begin
                            gs <= 1'b1;
                            hpos <= 16'd0;
                            sub <= 8'd4;
                        end
                        else begin
                            hpos <= hpos + 16'd1;
                            sub <= 8'd2;
                        end
                    end
                end
                else if (sub == 8'd4) begin
                    if (grdy) begin
                        if (hpos < 16'd32)
                            gdin <= m_r[8*hpos +: 8];
                        else
                            gdin <= h_pk[8*(hpos - 32) +: 8];
                        gdv <= 1'b1;
                        gdl <= (hpos == 16'd63);
                        if (hpos == 16'd63)
                            sub <= 8'd5;
                        hpos <= hpos + 16'd1;
                    end
                end
                else if (sub == 8'd5) begin
                    if (gad) begin
                        hpos <= 16'd0;
                        sub <= 8'd6;
                    end
                end
                else if (sub == 8'd6) begin
                    gsq <= 1'b1;
                    sub <= 8'd7;
                end
                else if (sub == 8'd7) begin
                    if (gdv_o) begin
                        hout[hpos] <= gdout;
                        if (hpos == 16'd63)
                            sub <= 8'd8;
                        else begin
                            hpos <= hpos + 16'd1;
                            sub <= 8'd6;
                        end
                    end
                end
                else begin
                    for (ii = 0; ii < 32; ii = ii + 1) begin
                        K_bar[8*ii +: 8] <= hout[ii];
                        sigma[8*ii +: 8] <= hout[32 + ii];
                        rho[8*ii +: 8]   <= pk_mem[K * 384 + ii];
                    end
                    pi <= 4'd0;
                    sub <= 8'd0;
                    phase <= 8'd41;
                end
            end

            // decode t + TOM
            8'd41: begin
                if (sub == 8'd0) begin
                    bidx <= pi * 16'd384;
                    idx <= 16'd0;
                    bit_buf <= 32'd0;
                    nbits <= 6'd0;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    if (nbits < 6'd12) begin
                        bit_buf <= bit_buf | ({24'd0, pk_mem[bidx]} << nbits);
                        nbits <= nbits + 6'd8;
                        bidx <= bidx + 16'd1;
                    end
                    else begin
                        cpu_we <= 1'b1;
                        cpu_addr <= (T0 + pi) * 256 + idx[7:0];
                        cpu_wdata <= bit_buf[11:0];
                        bit_buf <= bit_buf >> 12;
                        nbits <= nbits - 6'd12;
                        if (idx == 16'd255)
                            sub <= 8'd2;
                        else
                            idx <= idx + 16'd1;
                    end
                end
                else if (sub == 8'd2) begin
                    ops_cmd <= OP_TOM;
                    ops_sa <= T0 + pi;
                    ops_kick <= 1'b1;
                    sub <= 8'd3;
                end
                else if (sub == 8'd3) begin
                    if (ops_done) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            sub <= 8'd0;
                        end
                        else begin
                            pi <= 4'd0;
                            sub <= 8'd0;
                            phase <= 8'd42;
                        end
                    end
                end
            end

            // sample r, TOM, NTT
            8'd42: begin
                if (sub == 8'd0) begin
                    cnonce <= {4'd0, pi};
                    if (ETA1 == 3)
                        c3s <= 1'b1;
                    else
                        c2s <= 1'b1;
                    idx <= 16'd0;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    if (ETA1 == 3) begin
                        if (c3v) begin
                            cpu_we <= 1'b1;
                            cpu_addr <= (S0 + pi) * 256 + idx[7:0];
                            cpu_wdata <= c3c;
                            idx <= idx + 16'd1;
                        end
                        if (c3d)
                            sub <= 8'd2;
                    end
                    else begin
                        if (c2v) begin
                            cpu_we <= 1'b1;
                            cpu_addr <= (S0 + pi) * 256 + idx[7:0];
                            cpu_wdata <= c2c;
                            idx <= idx + 16'd1;
                        end
                        if (c2d)
                            sub <= 8'd2;
                    end
                end
                else if (sub == 8'd2) begin
                    ops_cmd <= OP_TOM;
                    ops_sa <= S0 + pi;
                    ops_kick <= 1'b1;
                    sub <= 8'd3;
                end
                else if (sub == 8'd3) begin
                    if (ops_done) begin
                        ops_cmd <= OP_NTT;
                        ops_sa <= S0 + pi;
                        ops_kick <= 1'b1;
                        sub <= 8'd4;
                    end
                end
                else if (sub == 8'd4) begin
                    if (ops_done) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            sub <= 8'd0;
                        end
                        else begin
                            pi <= 4'd0;
                            sub <= 8'd0;
                            phase <= 8'd43;
                        end
                    end
                end
            end

            // sample e1[i] and e2 (eta2=2)
            8'd43: begin
                if (sub == 8'd0) begin
                    cnonce <= K[7:0] + {4'd0, pi};
                    c2s <= 1'b1;
                    idx <= 16'd0;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    if (c2v) begin
                        cpu_we <= 1'b1;
                        cpu_addr <= (E0 + pi) * 256 + idx[7:0];
                        cpu_wdata <= c2c;
                        idx <= idx + 16'd1;
                    end
                    if (c2d) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            sub <= 8'd0;
                        end
                        else begin
                            cnonce <= (K << 1);
                            c2s <= 1'b1;
                            idx <= 16'd0;
                            sub <= 8'd2;
                        end
                    end
                end
                else if (sub == 8'd2) begin
                    if (c2v) begin
                        cpu_we <= 1'b1;
                        cpu_addr <= SM * 256 + idx[7:0];
                        cpu_wdata <= c2c;
                        idx <= idx + 16'd1;
                    end
                    if (c2d) begin
                        pi <= 4'd0;
                        pj <= 4'd0;
                        sub <= 8'd0;
                        phase <= 8'd44;
                    end
                end
            end

            // u = INTT(A^T * r) + e1
            // At[i][j]=A[j][i] => SampleNTT(rho||i||j) => sn_i=i, sn_j=j
            8'd44: begin
                if (sub == 8'd0) begin
                    ops_cmd <= OP_CLR;
                    ops_sa <= SW;
                    ops_kick <= 1'b1;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    if (ops_done) begin
                        sn_i <= {4'd0, pi};
                        sn_j <= {4'd0, pj};
                        sn_start <= 1'b1;
                        idx <= 16'd0;
                        sub <= 8'd2;
                    end
                end
                else if (sub == 8'd2) begin
                    if (sn_cv) begin
                        cpu_we <= 1'b1;
                        cpu_addr <= SA * 256 + idx[7:0];
                        cpu_wdata <= sn_c;
                        idx <= idx + 16'd1;
                    end
                    if (sn_done)
                        sub <= 8'd3;
                end
                else if (sub == 8'd3) begin
                    ops_cmd <= OP_TOM;
                    ops_sa <= SA;
                    ops_kick <= 1'b1;
                    sub <= 8'd4;
                end
                else if (sub == 8'd4) begin
                    if (ops_done) begin
                        ops_cmd <= OP_BMU;
                        ops_sa <= SA;
                        ops_sb <= S0 + pj;
                        ops_sc <= SW;
                        ops_kick <= 1'b1;
                        sub <= 8'd5;
                    end
                end
                else if (sub == 8'd5) begin
                    if (ops_done) begin
                        if (pj + 1 < K[3:0]) begin
                            pj <= pj + 4'd1;
                            sub <= 8'd1;
                        end
                        else begin
                            ops_cmd <= OP_INT;
                            ops_sa <= SW;
                            ops_kick <= 1'b1;
                            sub <= 8'd6;
                        end
                    end
                end
                else if (sub == 8'd6) begin
                    if (ops_done) begin
                        ops_cmd <= OP_FRM;
                        ops_sa <= SW;
                        ops_kick <= 1'b1;
                        sub <= 8'd7;
                    end
                end
                else if (sub == 8'd7) begin
                    if (ops_done) begin
                        ops_cmd <= OP_ADD;
                        ops_sa <= SW;
                        ops_sb <= E0 + pi;
                        ops_sc <= E0 + pi;
                        ops_kick <= 1'b1;
                        sub <= 8'd8;
                    end
                end
                else if (sub == 8'd8) begin
                    if (ops_done) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            pj <= 4'd0;
                            sub <= 8'd0;
                        end
                        else begin
                            pi <= 4'd0;
                            sub <= 8'd0;
                            phase <= 8'd45;
                        end
                    end
                end
            end

            // v = INTT(t·r) + e2 + Decompress_1(m)
            8'd45: begin
                if (sub == 8'd0) begin
                    ops_cmd <= OP_CLR;
                    ops_sa <= SV;
                    ops_kick <= 1'b1;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    if (ops_done) begin
                        ops_cmd <= OP_BMU;
                        ops_sa <= T0 + pi;
                        ops_sb <= S0 + pi;
                        ops_sc <= SV;
                        ops_kick <= 1'b1;
                        sub <= 8'd2;
                    end
                end
                else if (sub == 8'd2) begin
                    if (ops_done) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            sub <= 8'd1;
                        end
                        else begin
                            ops_cmd <= OP_INT;
                            ops_sa <= SV;
                            ops_kick <= 1'b1;
                            sub <= 8'd3;
                        end
                    end
                end
                else if (sub == 8'd3) begin
                    if (ops_done) begin
                        ops_cmd <= OP_FRM;
                        ops_sa <= SV;
                        ops_kick <= 1'b1;
                        sub <= 8'd4;
                    end
                end
                else if (sub == 8'd4) begin
                    if (ops_done) begin
                        ops_cmd <= OP_ADD;
                        ops_sa <= SV;
                        ops_sb <= SM;
                        ops_sc <= SV;
                        ops_kick <= 1'b1;
                        sub <= 8'd5;
                    end
                end
                else if (sub == 8'd5) begin
                    if (ops_done) begin
                        idx <= 16'd0;
                        sub <= 8'd6;
                    end
                end
                else if (sub == 8'd6) begin
                    xd <= {11'd0, (m_r[8*idx[15:3] +: 8] >> idx[2:0]) & 1'b1};
                    sub <= 8'd7;
                end
                else if (sub == 8'd7) begin
                    add_a <= P[SV * 256 + idx[7:0]];
                    add_b <= xd1;
                    sub <= 8'd8;
                end
                else if (sub == 8'd8) begin
                    cpu_we <= 1'b1;
                    cpu_addr <= SV * 256 + idx[7:0];
                    cpu_wdata <= add_r;
                    if (idx == 16'd255) begin
                        pi <= 4'd0;
                        widx <= 16'd0;
                        idx <= 16'd0;
                        bit_buf <= 32'd0;
                        nbits <= 6'd0;
                        sub <= 8'd0;
                        phase <= 8'd46;
                    end
                    else begin
                        idx <= idx + 16'd1;
                        sub <= 8'd6;
                    end
                end
            end

            // compress-encode CT: u in E (du), v in SV (dv)
            8'd46: begin
                if (sub == 8'd0) begin
                    idx <= 16'd0;
                    bit_buf <= 32'd0;
                    nbits <= 6'd0;
                    widx <= pi * U_BYTES[15:0];
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    xd <= P[(E0 + pi) * 256 + idx[7:0]];
                    sub <= 8'd2;
                end
                else if (sub == 8'd2) begin
                    if (DU == 11)
                        tmpv <= {1'b0, xc11};
                    else
                        tmpv <= {2'b0, xc10};
                    bit_buf <= bit_buf | ({20'd0, tmpv} << nbits);
                    nbits <= nbits + DU[5:0];
                    sub <= 8'd3;
                end
                else if (sub == 8'd3) begin
                    if (nbits >= 6'd8) begin
                        if (reenc)
                            ct2_mem[widx] <= bit_buf[7:0];
                        else
                            ct_mem[widx] <= bit_buf[7:0];
                        bit_buf <= bit_buf >> 8;
                        nbits <= nbits - 6'd8;
                        widx <= widx + 16'd1;
                    end
                    else if (idx == 16'd255) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            sub <= 8'd0;
                        end
                        else begin
                            idx <= 16'd0;
                            bit_buf <= 32'd0;
                            nbits <= 6'd0;
                            widx <= (U_BYTES * K);
                            sub <= 8'd4;
                        end
                    end
                    else begin
                        idx <= idx + 16'd1;
                        sub <= 8'd1;
                    end
                end
                else if (sub == 8'd4) begin
                    xd <= P[SV * 256 + idx[7:0]];
                    sub <= 8'd5;
                end
                else if (sub == 8'd5) begin
                    if (DV == 5)
                        tmpv <= {7'd0, xc5};
                    else
                        tmpv <= {8'd0, xc4};
                    bit_buf <= bit_buf | ({20'd0, tmpv} << nbits);
                    nbits <= nbits + DV[5:0];
                    sub <= 8'd6;
                end
                else if (sub == 8'd6) begin
                    if (nbits >= 6'd8) begin
                        if (reenc)
                            ct2_mem[widx] <= bit_buf[7:0];
                        else
                            ct_mem[widx] <= bit_buf[7:0];
                        bit_buf <= bit_buf >> 8;
                        nbits <= nbits - 6'd8;
                        widx <= widx + 16'd1;
                    end
                    else if (idx == 16'd255) begin
                        if (reenc) begin
                            idx <= 16'd0;
                            ct_ok <= 1'b1;
                            sub <= 8'd0;
                            phase <= 8'd90;
                        end
                        else begin
                            for (ii = 0; ii < 32; ii = ii + 1)
                                ss_out[8*ii +: 8] <= K_bar[8*ii +: 8];
                            done <= 1'b1;
                            status <= 16'h0A02;
                            phase <= 8'd0;
                        end
                    end
                    else begin
                        idx <= idx + 16'd1;
                        sub <= 8'd4;
                    end
                end
            end

            // ===================== DECAPS =====================
            // copy pk from sk; load h,z,rho
            8'd80: begin
                if (sub == 8'd0) begin
                    for (ii = 0; ii < 32; ii = ii + 1) begin
                        h_pk[8*ii +: 8] <= sk_mem[SK_PKE + PK_LEN + ii];
                        z_r[8*ii +: 8]  <= sk_mem[SK_PKE + PK_LEN + 32 + ii];
                        rho[8*ii +: 8]  <= sk_mem[SK_PKE + K * 384 + ii];
                    end
                    idx <= 16'd0;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    pk_mem[idx] <= sk_mem[SK_PKE + idx];
                    if (idx + 1 == PK_LEN[15:0]) begin
                        pi <= 4'd0;
                        sub <= 8'd0;
                        phase <= 8'd81;
                    end
                    else
                        idx <= idx + 16'd1;
                end
            end

            // decode s + TOM (stored as NTT-domain normal)
            8'd81: begin
                if (sub == 8'd0) begin
                    bidx <= pi * 16'd384;
                    idx <= 16'd0;
                    bit_buf <= 32'd0;
                    nbits <= 6'd0;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    if (nbits < 6'd12) begin
                        bit_buf <= bit_buf | ({24'd0, sk_mem[bidx]} << nbits);
                        nbits <= nbits + 6'd8;
                        bidx <= bidx + 16'd1;
                    end
                    else begin
                        cpu_we <= 1'b1;
                        cpu_addr <= (S0 + pi) * 256 + idx[7:0];
                        cpu_wdata <= bit_buf[11:0];
                        bit_buf <= bit_buf >> 12;
                        nbits <= nbits - 6'd12;
                        if (idx == 16'd255)
                            sub <= 8'd2;
                        else
                            idx <= idx + 16'd1;
                    end
                end
                else if (sub == 8'd2) begin
                    ops_cmd <= OP_TOM;
                    ops_sa <= S0 + pi;
                    ops_kick <= 1'b1;
                    sub <= 8'd3;
                end
                else if (sub == 8'd3) begin
                    if (ops_done) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            sub <= 8'd0;
                        end
                        else begin
                            pi <= 4'd0;
                            sub <= 8'd0;
                            phase <= 8'd82;
                        end
                    end
                end
            end

            // decode/decompress u, TOM+NTT into E
            8'd82: begin
                if (sub == 8'd0) begin
                    bidx <= pi * U_BYTES[15:0];
                    idx <= 16'd0;
                    bit_buf <= 32'd0;
                    nbits <= 6'd0;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    if (nbits < DU[5:0]) begin
                        bit_buf <= bit_buf | ({24'd0, ct_mem[bidx]} << nbits);
                        nbits <= nbits + 6'd8;
                        bidx <= bidx + 16'd1;
                    end
                    else begin
                        xd <= bit_buf[11:0];
                        bit_buf <= bit_buf >> DU;
                        nbits <= nbits - DU[5:0];
                        sub <= 8'd2;
                    end
                end
                else if (sub == 8'd2) begin
                    cpu_we <= 1'b1;
                    cpu_addr <= (E0 + pi) * 256 + idx[7:0];
                    if (DU == 11)
                        cpu_wdata <= xd11;
                    else
                        cpu_wdata <= xd10;
                    if (idx == 16'd255)
                        sub <= 8'd3;
                    else begin
                        idx <= idx + 16'd1;
                        sub <= 8'd1;
                    end
                end
                else if (sub == 8'd3) begin
                    ops_cmd <= OP_TOM;
                    ops_sa <= E0 + pi;
                    ops_kick <= 1'b1;
                    sub <= 8'd4;
                end
                else if (sub == 8'd4) begin
                    if (ops_done) begin
                        ops_cmd <= OP_NTT;
                        ops_sa <= E0 + pi;
                        ops_kick <= 1'b1;
                        sub <= 8'd5;
                    end
                end
                else if (sub == 8'd5) begin
                    if (ops_done) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            sub <= 8'd0;
                        end
                        else begin
                            idx <= 16'd0;
                            bit_buf <= 32'd0;
                            nbits <= 6'd0;
                            bidx <= (U_BYTES * K);
                            sub <= 8'd0;
                            phase <= 8'd83;
                        end
                    end
                end
            end

            // decode/decompress v into SV
            8'd83: begin
                if (sub == 8'd0) begin
                    if (nbits < DV[5:0]) begin
                        bit_buf <= bit_buf | ({24'd0, ct_mem[bidx]} << nbits);
                        nbits <= nbits + 6'd8;
                        bidx <= bidx + 16'd1;
                    end
                    else begin
                        xd <= bit_buf[11:0];
                        bit_buf <= bit_buf >> DV;
                        nbits <= nbits - DV[5:0];
                        sub <= 8'd1;
                    end
                end
                else if (sub == 8'd1) begin
                    cpu_we <= 1'b1;
                    cpu_addr <= SV * 256 + idx[7:0];
                    if (DV == 5)
                        cpu_wdata <= xd5;
                    else
                        cpu_wdata <= xd4;
                    if (idx == 16'd255) begin
                        pi <= 4'd0;
                        sub <= 8'd0;
                        phase <= 8'd84;
                    end
                    else begin
                        idx <= idx + 16'd1;
                        sub <= 8'd0;
                    end
                end
            end

            // m' = Compress_1(v - INTT(s·u))
            8'd84: begin
                if (sub == 8'd0) begin
                    ops_cmd <= OP_CLR;
                    ops_sa <= SW;
                    ops_kick <= 1'b1;
                    sub <= 8'd1;
                end
                else if (sub == 8'd1) begin
                    if (ops_done) begin
                        ops_cmd <= OP_BMU;
                        ops_sa <= S0 + pi;
                        ops_sb <= E0 + pi;
                        ops_sc <= SW;
                        ops_kick <= 1'b1;
                        sub <= 8'd2;
                    end
                end
                else if (sub == 8'd2) begin
                    if (ops_done) begin
                        if (pi + 1 < K[3:0]) begin
                            pi <= pi + 4'd1;
                            sub <= 8'd1;
                        end
                        else begin
                            ops_cmd <= OP_INT;
                            ops_sa <= SW;
                            ops_kick <= 1'b1;
                            sub <= 8'd3;
                        end
                    end
                end
                else if (sub == 8'd3) begin
                    if (ops_done) begin
                        ops_cmd <= OP_FRM;
                        ops_sa <= SW;
                        ops_kick <= 1'b1;
                        sub <= 8'd4;
                    end
                end
                else if (sub == 8'd4) begin
                    if (ops_done) begin
                        ops_cmd <= OP_SUB;
                        ops_sa <= SV;
                        ops_sb <= SW;
                        ops_sc <= SW;
                        ops_kick <= 1'b1;
                        sub <= 8'd5;
                    end
                end
                else if (sub == 8'd5) begin
                    if (ops_done) begin
                        idx <= 16'd0;
                        m_r <= 256'd0;
                        sub <= 8'd6;
                    end
                end
                else if (sub == 8'd6) begin
                    xd <= P[SW * 256 + idx[7:0]];
                    sub <= 8'd7;
                end
                else if (sub == 8'd7) begin
                    // pack bit into m_r
                    m_r[8*idx[15:3] +: 8] <= m_r[8*idx[15:3] +: 8] |
                        ({7'd0, xc1} << idx[2:0]);
                    if (idx == 16'd255) begin
                        gs <= 1'b1;
                        hpos <= 16'd0;
                        sub <= 8'd0;
                        phase <= 8'd85;
                    end
                    else begin
                        idx <= idx + 16'd1;
                        sub <= 8'd6;
                    end
                end
            end

            // G(m'||h) -> K_bar, r; then re-encrypt
            8'd85: begin
                if (sub == 8'd0) begin
                    if (grdy) begin
                        if (hpos < 16'd32)
                            gdin <= m_r[8*hpos +: 8];
                        else
                            gdin <= h_pk[8*(hpos - 32) +: 8];
                        gdv <= 1'b1;
                        gdl <= (hpos == 16'd63);
                        if (hpos == 16'd63)
                            sub <= 8'd1;
                        hpos <= hpos + 16'd1;
                    end
                end
                else if (sub == 8'd1) begin
                    if (gad) begin
                        hpos <= 16'd0;
                        sub <= 8'd2;
                    end
                end
                else if (sub == 8'd2) begin
                    gsq <= 1'b1;
                    sub <= 8'd3;
                end
                else if (sub == 8'd3) begin
                    if (gdv_o) begin
                        hout[hpos] <= gdout;
                        if (hpos == 16'd63)
                            sub <= 8'd4;
                        else begin
                            hpos <= hpos + 16'd1;
                            sub <= 8'd2;
                        end
                    end
                end
                else begin
                    for (ii = 0; ii < 32; ii = ii + 1) begin
                        K_bar[8*ii +: 8] <= hout[ii];
                        sigma[8*ii +: 8] <= hout[32 + ii];
                    end
                    reenc <= 1'b1;
                    pi <= 4'd0;
                    sub <= 8'd0;
                    phase <= 8'd41; // k_pke_encrypt path into ct2
                end
            end

            // compare ct2 vs ct; accept K_bar or J(z||ct)
            8'd90: begin
                if (sub == 8'd0) begin
                    if (ct2_mem[idx] != ct_mem[idx])
                        ct_ok <= 1'b0;
                    if (idx + 1 == CT_LEN[15:0]) begin
                        // include this cycle's byte in the decision
                        if (ct_ok && (ct2_mem[idx] == ct_mem[idx])) begin
                            for (ii = 0; ii < 32; ii = ii + 1)
                                ss_out[8*ii +: 8] <= K_bar[8*ii +: 8];
                            decaps_ok <= 1'b1;
                            done <= 1'b1;
                            status <= 16'h0A03;
                            reenc <= 1'b0;
                            phase <= 8'd0;
                        end
                        else begin
                            js <= 1'b1;
                            hpos <= 16'd0;
                            sub <= 8'd1;
                        end
                    end
                    else
                        idx <= idx + 16'd1;
                end
                else if (sub == 8'd1) begin
                    if (jrdy) begin
                        if (hpos < 16'd32)
                            jdin <= z_r[8*hpos +: 8];
                        else
                            jdin <= ct_mem[hpos - 16'd32];
                        jdv <= 1'b1;
                        jdl <= (hpos + 1 == (32 + CT_LEN));
                        if (hpos + 1 == (32 + CT_LEN))
                            sub <= 8'd2;
                        hpos <= hpos + 16'd1;
                    end
                end
                else if (sub == 8'd2) begin
                    if (jad) begin
                        hpos <= 16'd0;
                        sub <= 8'd3;
                    end
                end
                else if (sub == 8'd3) begin
                    jsq <= 1'b1;
                    sub <= 8'd4;
                end
                else if (sub == 8'd4) begin
                    if (jdv_o) begin
                        ss_out[8*hpos +: 8] <= jdout;
                        if (hpos == 16'd31) begin
                            decaps_ok <= 1'b0;
                            done <= 1'b1;
                            status <= 16'h0A04;
                            reenc <= 1'b0;
                            phase <= 8'd0;
                        end
                        else begin
                            hpos <= hpos + 16'd1;
                            sub <= 8'd3;
                        end
                    end
                end
            end

            default: begin
                phase <= 8'd0;
            end
            endcase
        end
    end
endmodule
'''

OUT.write_text(V)
print(f"Wrote {OUT} ({OUT.stat().st_size} bytes)")
