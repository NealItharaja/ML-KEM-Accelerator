// Address generator for Kyber
module address_gen(
    input clk,
    input reset,
    input start,
    output reg rd_en,
    output reg [7:0] rd_addr_a,
    output reg [7:0] rd_addr_b,
    output reg [6:0] twiddle_addr,
    output wr_en,
    output [7:0] wr_addr_a,
    output [7:0] wr_addr_b,
    output reg done
    );

    integer k;
    parameter integer PIPE_LATENCY = 4;
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] RUN = 2'd1;
    localparam [1:0] DRAIN = 2'd2;
    localparam [1:0] FIN = 2'd3;

    reg [1:0] state;
    reg [2:0] stage;
    reg [7:0] group;
    reg [7:0] j;
    reg [7:0] drain_cnt;
    reg we_sr [0:PIPE_LATENCY-1];
    reg [7:0] addra_sr [0:PIPE_LATENCY-1];
    reg [7:0] addrb_sr [0:PIPE_LATENCY-1];

    wire [7:0] d = 8'd1 << stage;               
    wire [7:0] groups_per_stage = 8'd1 << (3'd7 - stage);
    wire last_j = (j == d - 8'd1);
    wire last_group = (group == groups_per_stage - 8'd1);
    wire stage_last = last_j & last_group;
    wire final_stage = (stage == 3'd7);
    wire [3:0] tw_shift = (4'd6 >= {1'b0, stage}) ? (4'd6 - {1'b0, stage}) : 4'd0;

    always @(*) begin
        rd_en = (state == RUN);
        rd_addr_a = (group << (stage + 3'd1)) + j;
        rd_addr_b = rd_addr_a + d;
        twiddle_addr = (j << tw_shift);
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            stage <= 3'd0;
            group <= 8'd0;
            j <= 8'd0;
            drain_cnt <= 8'd0;
            done <= 1'b0;
        end 
        else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        stage <= 3'd0;
                        group <= 8'd0;
                        j <= 8'd0;
                        done <= 1'b0;
                        state <= RUN;
                    end
                end

                RUN: begin
                    if (stage_last) begin
                        drain_cnt <= PIPE_LATENCY[7:0];
                        state <= DRAIN;
                    end 
                    else if (last_j) begin
                        j <= 8'd0;
                        group <= group + 8'd1;
                    end 
                    else begin
                        j <= j + 8'd1;
                    end
                end

                DRAIN: begin
                    if (drain_cnt == 8'd0) begin
                        if (final_stage) begin
                            state <= FIN;
                        end else begin
                            stage <= stage + 3'd1;
                            group <= 8'd0;
                            j <= 8'd0;
                            state <= RUN;
                        end
                    end 
                    else begin
                        drain_cnt <= drain_cnt - 8'd1;
                    end
                end

                FIN: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (k = 0; k < PIPE_LATENCY; k = k + 1) begin
                we_sr[k] <= 1'b0;
                addra_sr[k] <= 8'd0;
                addrb_sr[k] <= 8'd0;
            end
        end 
        else begin
            we_sr[0] <= rd_en;
            addra_sr[0] <= rd_addr_a;
            addrb_sr[0] <= rd_addr_b;
            
            for (k = 1; k < PIPE_LATENCY; k = k + 1) begin
                we_sr[k] <= we_sr[k-1];
                addra_sr[k] <= addra_sr[k-1];
                addrb_sr[k] <= addrb_sr[k-1];
            end
        end
    end

    assign wr_en = we_sr[PIPE_LATENCY-1];
    assign wr_addr_a = addra_sr[PIPE_LATENCY-1];
    assign wr_addr_b = addrb_sr[PIPE_LATENCY-1];
endmodule