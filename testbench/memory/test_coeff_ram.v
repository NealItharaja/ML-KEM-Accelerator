`timescale 1ns/1ps

module coeff_ram_tb;

reg clk;

reg rd_en;
reg wr_en;

reg [7:0] rd_addr_a;
reg [7:0] rd_addr_b;

reg [7:0] wr_addr_a;
reg [7:0] wr_addr_b;

reg [11:0] wr_data_a;
reg [11:0] wr_data_b;

wire [11:0] rd_data_a;
wire [11:0] rd_data_b;

integer i;
integer errors;

coeff_ram DUT(
    .clk(clk),
    .rd_en(rd_en),
    .wr_en(wr_en),
    .rd_addr_a(rd_addr_a),
    .wr_addr_a(wr_addr_a),
    .rd_addr_b(rd_addr_b),
    .wr_addr_b(wr_addr_b),
    .wr_data_a(wr_data_a),
    .wr_data_b(wr_data_b),
    .rd_data_a(rd_data_a),
    .rd_data_b(rd_data_b)
);

always #5 clk = ~clk;

initial begin

    clk = 0;

    rd_en = 0;
    wr_en = 0;

    rd_addr_a = 0;
    rd_addr_b = 0;
    wr_addr_a = 0;
    wr_addr_b = 0;

    wr_data_a = 0;
    wr_data_b = 0;

    errors = 0;

    //---------------------------------------------------------
    // Write four butterfly pairs
    //---------------------------------------------------------

    $display("--------------------------------");
    $display("Writing memory...");
    $display("--------------------------------");

    for(i=0;i<4;i=i+1) begin

        @(negedge clk);

        wr_en = 1;

        wr_addr_a = 2*i;
        wr_addr_b = 2*i+1;

        wr_data_a = i+1;
        wr_data_b = i+101;

        $display("WRITE (%0d,%0d) <= (%0d,%0d)",
            wr_addr_a,
            wr_addr_b,
            wr_data_a,
            wr_data_b);

    end

    @(negedge clk);
    wr_en = 0;

    //---------------------------------------------------------
    // Read them back
    //---------------------------------------------------------

    $display("");
    $display("--------------------------------");
    $display("Reading memory...");
    $display("--------------------------------");

    rd_en = 1;

    for(i=0;i<4;i=i+1) begin

        @(negedge clk);

        rd_addr_a = 2*i;
        rd_addr_b = 2*i+1;

        @(posedge clk);

        #1;

        $display(
            "READ (%0d,%0d) -> (%0d,%0d)",
            rd_addr_a,
            rd_addr_b,
            rd_data_a,
            rd_data_b
        );

        if(rd_data_a != i+1) begin
            errors = errors + 1;
            $display("FAIL A");
        end

        if(rd_data_b != i+101) begin
            errors = errors + 1;
            $display("FAIL B");
        end

    end

    rd_en = 0;

    //---------------------------------------------------------
    // Dump internal memory
    //---------------------------------------------------------

    $display("");
    $display("--------------------------------");
    $display("Bank0");
    $display("--------------------------------");

    for(i=0;i<8;i=i+1)
        $display("bank0[%0d] = %0d",i,DUT.bank0[i]);

    $display("");

    $display("--------------------------------");
    $display("Bank1");
    $display("--------------------------------");

    for(i=0;i<8;i=i+1)
        $display("bank1[%0d] = %0d",i,DUT.bank1[i]);

    $display("");

    //---------------------------------------------------------
    // Cross-stage consistency test
    //
    // Write addresses 0..3 as STAGE-0 pairs (0,1),(2,3), then read them
    // back as STAGE-1 pairs (0,2),(1,3). A correct memory maps each address
    // to the same bank no matter how it is paired, so the values must match.
    // LSB-only banking stores 2 and 3 in swapped banks vs. parity banking,
    // so this read comes back wrong under LSB banking.
    //---------------------------------------------------------

    $display("--------------------------------");
    $display("Cross-stage consistency...");
    $display("--------------------------------");

    // Write as stage-0 pairs
    @(negedge clk);
    wr_en = 1;
    wr_addr_a = 0; wr_addr_b = 1; wr_data_a = 500; wr_data_b = 501;

    @(negedge clk);
    wr_addr_a = 2; wr_addr_b = 3; wr_data_a = 502; wr_data_b = 503;

    @(negedge clk);
    wr_en = 0;

    // Read as stage-1 pairs
    rd_en = 1;

    @(negedge clk);
    rd_addr_a = 0; rd_addr_b = 2;
    @(posedge clk);
    #1;
    $display("READ (0,2) -> (%0d,%0d)", rd_data_a, rd_data_b);
    if(rd_data_a != 500) begin errors = errors + 1; $display("FAIL: (0,2) A"); end
    if(rd_data_b != 502) begin errors = errors + 1; $display("FAIL: (0,2) B"); end

    @(negedge clk);
    rd_addr_a = 1; rd_addr_b = 3;
    @(posedge clk);
    #1;
    $display("READ (1,3) -> (%0d,%0d)", rd_data_a, rd_data_b);
    if(rd_data_a != 501) begin errors = errors + 1; $display("FAIL: (1,3) A"); end
    if(rd_data_b != 503) begin errors = errors + 1; $display("FAIL: (1,3) B"); end

    rd_en = 0;

    $display("");

    if(errors==0)
        $display("ALL TESTS PASSED");
    else
        $display("%0d TESTS FAILED",errors);

    $finish;

end

endmodule