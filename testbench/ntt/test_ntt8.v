`timescale 1ns/1ps

module ntt8_tb;

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

    //---------------------------------------
    // DUT
    //---------------------------------------

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

    //---------------------------------------
    // Clock
    //---------------------------------------

    always #5 clk = ~clk;

    //---------------------------------------
    // Test
    //---------------------------------------

    initial begin

        clk = 0;
        reset = 1;
        start = 0;
        load = 0;

        load_addr = 0;
        read_addr = 0;
        load_data = 0;

        #20;
        reset = 0;

        //--------------------------------------------------
        // Load polynomial
        //--------------------------------------------------

        $display("--------------------------------");
        $display("Loading coefficients...");
        $display("--------------------------------");

        load = 1;

        for(i=0;i<8;i=i+1) begin
            @(posedge clk);
            load_addr = i;
            load_data = i + 1;

            $display("Loaded addr=%0d data=%0d",
                        load_addr,
                        load_data);
        end

        @(posedge clk);
        load = 0;

        //--------------------------------------------------
        // Start NTT
        //--------------------------------------------------

        $display("--------------------------------");
        $display("Starting NTT...");
        $display("--------------------------------");

        @(posedge clk);
        start = 1;

        @(posedge clk);
        start = 0;

        //--------------------------------------------------
        // Wait for completion
        //--------------------------------------------------

        wait(done);

        $display("--------------------------------");
        $display("NTT Complete");
        $display("--------------------------------");

        //--------------------------------------------------
        // Read memory back
        //--------------------------------------------------

        for(i=0;i<8;i=i+1) begin

            @(posedge clk);
            read_addr = i;

            @(posedge clk);

            $display("MEM[%0d] = %0d",
                        i,
                        read_data);

        end

        $display("--------------------------------");
        $display("TEST COMPLETE");
        $display("--------------------------------");

        $finish;

    end
endmodule