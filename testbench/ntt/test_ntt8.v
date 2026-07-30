`timescale 1ns/1ps

module test_ntt8;

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

    //--------------------------------------------------
    // Load coefficients
    //--------------------------------------------------

    $display("--------------------------------");
    $display("Loading memory");
    $display("--------------------------------");

    load = 1;

    for(i=0;i<8;i=i+1) begin
        load_addr = i;
        load_data = i+1;
        @(posedge clk);

        $display("WRITE addr=%0d data=%0d",
            load_addr,
            load_data);
    end

    load = 0;

    //--------------------------------------------------
    // Start NTT
    //--------------------------------------------------

    @(posedge clk);

    start = 1;
    @(posedge clk);
    start = 0;

    $display("--------------------------------");
    $display("Running NTT");
    $display("--------------------------------");

    //--------------------------------------------------
    // Print every cycle
    //--------------------------------------------------

    while(!done) begin

        @(posedge clk);

        $display("");

        $display("Cycle");

        $display(" Stage      = %0d", DUT.addresses.stage);
        $display(" Group      = %0d", DUT.addresses.group);
        $display(" j          = %0d", DUT.addresses.j);

        $display("");

        $display(" ReadA Addr = %0d", DUT.ram_rd_addr_a);
        $display(" ReadB Addr = %0d", DUT.ram_rd_addr_b);

        $display(" WriteA Addr= %0d", DUT.ram_wr_addr_a);
        $display(" WriteB Addr= %0d", DUT.ram_wr_addr_b);

        $display("");

        $display(" CoeffA     = %0d", DUT.coeff_a);
        $display(" CoeffB     = %0d", DUT.coeff_b);

        $display(" TwiddleAdr = %0d", DUT.twiddle_addr);
        $display(" Twiddle    = %0d", DUT.twiddle);

        $display("");

        $display(" ButterflyA = %0d", DUT.butterfly_a);
        $display(" ButterflyB = %0d", DUT.butterfly_b);

    end

    //--------------------------------------------------
    // Read back memory
    //--------------------------------------------------

    $display("");
    $display("--------------------------------");
    $display("Reading memory");
    $display("--------------------------------");

    for(i=0;i<8;i=i+1) begin

        read_addr = i;

        @(posedge clk);
        @(posedge clk);

        $display("MEM[%0d] = %0d",i,read_data);

    end

    $display("--------------------------------");
    $display("Finished");
    $display("--------------------------------");

    $finish;

end

endmodule