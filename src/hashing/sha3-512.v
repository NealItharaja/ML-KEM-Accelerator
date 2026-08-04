// SHA3-512 hash
module sha3_512(
    input clk,
    input reset,
    input start,
    input [7:0] din,
    input din_valid,
    input din_last,
    input squeeze,
    output reg [7:0] dout,
    output reg dout_valid,
    output absorb_done,
    output ready
    );

    localparam RATE = 72;
    localparam OUT_LEN = 64;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] ABSORB = 3'd1;
    localparam [2:0] PAD = 3'd2;
    localparam [2:0] PERM = 3'd3;
    localparam [2:0] SQUEEZE = 3'd4;

    reg [2:0] state;
    reg [2:0] return_st;
    reg [1599:0] s;
    reg [7:0] offset;
    reg [5:0] out_cnt;
    reg k_start;

    wire k_done;
    wire [1599:0] k_out;

    assign ready = (state == ABSORB);
    assign absorb_done = (state == SQUEEZE);

    keccack perm (
        .clk(clk),
        .reset(reset),
        .start(k_start),
        .state_in(s),
        .state_out(k_out),
        .done(k_done)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            return_st <= IDLE;
            s <= 1600'd0;
            offset <= 8'd0;
            out_cnt <= 6'd0;
            k_start <= 1'b0;
            dout <= 8'd0;
            dout_valid <= 1'b0;
        end
        else begin
            k_start <= 1'b0;
            dout_valid <= 1'b0;

            if (start && (state == IDLE || state == SQUEEZE)) begin
                s <= 1600'd0;
                offset <= 8'd0;
                out_cnt <= 6'd0;
                state <= ABSORB;
            end
            else begin
                case (state)
                    ABSORB: begin
                        if (din_valid) begin
                            s[8*offset +: 8] <= s[8*offset +: 8] ^ din;

                            if (offset == (RATE - 1)) begin
                                k_start <= 1'b1;
                                offset <= 8'd0;
                                if (din_last)
                                    return_st <= PAD;
                                else
                                    return_st <= ABSORB;
                                state <= PERM;
                            end
                            else begin
                                offset <= offset + 8'd1;
                                if (din_last)
                                    state <= PAD;
                            end
                        end
                        else if (din_last) begin
                            state <= PAD;
                        end
                    end

                    PAD: begin
                        if (offset == (RATE - 1))
                            s[8*(RATE-1) +: 8] <= s[8*(RATE-1) +: 8] ^ 8'h86;
                        else begin
                            s[8*offset +: 8] <= s[8*offset +: 8] ^ 8'h06;
                            s[8*(RATE-1) +: 8] <= s[8*(RATE-1) +: 8] ^ 8'h80;
                        end
                        k_start <= 1'b1;
                        return_st <= SQUEEZE;
                        offset <= 8'd0;
                        out_cnt <= 6'd0;
                        state <= PERM;
                    end

                    PERM: begin
                        if (k_done) begin
                            s <= k_out;
                            state <= return_st;
                        end
                    end

                    SQUEEZE: begin
                        if (squeeze) begin
                            dout <= s[8*offset +: 8];
                            dout_valid <= 1'b1;
                            offset <= offset + 8'd1;
                            out_cnt <= out_cnt + 6'd1;

                            if (out_cnt == (OUT_LEN - 1))
                                state <= IDLE;
                        end
                    end

                    default: state <= IDLE;
                endcase
            end
        end
    end
endmodule
