// 'Packing' data: converts coefficients into byte streams
module pack(
    input clk,
    input start,
    input [11:0] coeff_a,
    input [11:0] coeff_b,
    input coeff_valid,
    output ready,
    output reg [7:0] byte_out,
    output reg byte_valid,
    output reg done
    );

    localparam [1:0] WAIT = 2'd0;
    localparam [1:0] E0 = 2'd1;
    localparam [1:0] E1 = 2'd2;
    localparam [1:0] E2 = 2'd3;

    reg active;
    reg [1:0] state;
    reg [7:0] b0, b1, b2;
    reg [7:0] pairs_done;

    assign ready = active && (state == WAIT);

    always @(posedge clk) begin
        if (start) begin
            active <= 1'b1;
            state <= WAIT;
            pairs_done <= 8'd0;
            byte_valid <= 1'b0;
            byte_out <= 8'd0;
            done <= 1'b0;
            b0 <= 8'd0;
            b1 <= 8'd0;
            b2 <= 8'd0;
        end
        else if (active) begin
            done <= 1'b0;

            case (state)
                WAIT: begin
                    byte_valid <= 1'b0;

                    if (coeff_valid) begin
                        b0 <= coeff_a[7:0];
                        b1 <= {coeff_b[3:0], coeff_a[11:8]};
                        b2 <= coeff_b[11:4];
                        pairs_done <= pairs_done + 8'd1;
                        state <= E0;
                    end
                end

                E0: begin
                    byte_out <= b0;
                    byte_valid <= 1'b1;
                    state <= E1;
                end

                E1: begin
                    byte_out <= b1;
                    byte_valid <= 1'b1;
                    state <= E2;
                end

                E2: begin
                    byte_out <= b2;
                    byte_valid <= 1'b1;

                    if (pairs_done == 8'd128) begin
                        done <= 1'b1;
                        active <= 1'b0;
                    end
                    
                    state <= WAIT;
                end

                default: state <= WAIT;
            endcase
        end
        else begin
            byte_valid <= 1'b0;
        end
    end
endmodule
