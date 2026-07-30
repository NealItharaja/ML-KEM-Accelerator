`timescale 1ns/1ps

module test_ntt8_debug;

reg clk;
reg reset;
reg start;
reg load;

reg [7:0] load_addr;
reg [7:0] read_addr;
reg [11:0] load_data;

wire [11:0] read_data;
wire done;

integer i;

ntt8 DUT(
    .clk(clk),
    .reset(reset),
    .start(start),
    .load(load),
    .load_addr(load_addr),
    .read_addr(read_addr),
    .load_data(load_data),
    .read_data(read_data),
    .done(done)
);

always #5 clk = ~clk;

initial begin

    clk = 0;
    reset = 1;
    start = 0;
    load = 0;

    #20;
    reset = 0;

    //----------------------------------
    // Load coefficients
    //----------------------------------

    $display("--------------------------------");
    $display("Loading coefficients");
    $display("--------------------------------");

    for(i=0;i<8;i=i+1) begin

        @(posedge clk);

        load = 1;
        load_addr = i;
        load_data = i+1;

    end

    @(posedge clk);
    load = 0;

    //----------------------------------
    // Start NTT
    //----------------------------------

    @(posedge clk);
    start = 1;

    @(posedge clk);
    start = 0;

    //----------------------------------
    // Debug every cycle
    //----------------------------------

    while(!done) begin

        @(posedge clk);

        $display("--------------------------------");
        $display("Stage      = %0d",DUT.addresses.stage);
        $display("Group      = %0d",DUT.addresses.group);
        $display("j          = %0d",DUT.addresses.j);

        $display("Read A     = %0d",DUT.rd_addr_a);
        $display("Read B     = %0d",DUT.rd_addr_b);

        $display("Coeff A    = %0d",DUT.coeff_a);
        $display("Coeff B    = %0d",DUT.coeff_b);

        $display("TwiddleAdr = %0d",DUT.twiddle_addr);
        $display("Twiddle    = %0d",DUT.twiddle);

        $display("Butterfly A= %0d",DUT.butterfly_a);
        $display("Butterfly B= %0d",DUT.butterfly_b);

        $display("Write A    = %0d",DUT.wr_addr_a);
        $display("Write B    = %0d",DUT.wr_addr_b);

    end

    //----------------------------------
    // Dump memory afterwards
    //----------------------------------

    $display("");
    $display("--------------------------------");
    $display("Final Memory");
    $display("--------------------------------");

    for(i=0;i<8;i=i+1) begin

        read_addr = i;

        @(posedge clk);

        $display("MEM[%0d] = %0d",i,read_data);

    end

    $finish;

end

endmodule