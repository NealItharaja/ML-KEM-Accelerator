// Address generator for Kyber
module address_gen(
    input clk,
    input reset,
    input start,
    input butterfly_done,
    output reg [7:0] addr_a,
    output reg [7:0] addr_b,
    output reg [7:0] twiddle_addr,
    output reg done,
    output reg valid
    );

    reg [2:0] stage;
    reg [7:0] j, group;

    wire [7:0] d;
    wire [7:0] groups_per_stage;

    assign d = 1 << stage;
    assign groups_per_stage = 1 << (8 - (stage + 1));

    parameter IDLE = 2'b00;
    parameter GEN = 2'b01;
    parameter WAIT = 2'b10;
    parameter CHECK = 2'b11;;

    reg [1:0] state, next_state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            stage <= 0;
            group <= 0;
            j <= 0;
            done <= 0;
        end
        else begin
            state <= next_state;

            if (start) begin
                done <= 0;
            end
        
            if (state == CHECK) begin
                if (j < d - 1) begin
                    j <= j + 1;
                end
                else begin
                    j <= 0;

                    if (group < groups_per_stage - 1) begin
                        group <= group + 1;
                    end
                    else begin
                        group <= 0;

                        if (stage < 7) begin
                            stage <= stage + 1;
                        end
                        else begin
                            done <= 1;
                        end
                    end
                end
            end
        end
    end

    always @(*) begin
        next_state = state;

        case (state)
            IDLE:
                if (start)
                    next_state = GEN;
            
            GEN:
                next_state = WAIT;
            
            WAIT:
                if (butterfly_done)
                    next_state = CHECK;
            
            CHECK:
                if (stage == 7 && group == groups_per_stage - 1 && j == d - 1)
                    next_state = IDLE;
            
            default:
                next_state = IDLE;
        endcase
    end

    always @(*) begin
        if (state == IDLE) begin
            addr_a = 0;
            addr_b = 0;
            twiddle_addr = 0;
            valid = 0;
        end
        else begin
            valid = (state == WAIT);
            addr_a = (group << (stage + 1)) + j;
            addr_b = addr_a + d;
            twiddle_addr = j << (6 - stage);
        end
    end
endmodule