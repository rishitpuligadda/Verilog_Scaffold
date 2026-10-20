`timescale 1ns / 1ps

module tb_dff;

    // Parameters
    parameter CLK_PERIOD = 10;
    parameter RESET_TIME = 50;
    parameter SIM_TIME   = 1000;

    // DUT inputs (driven by the TB)
    reg clk;
    reg d;
    reg rst;

    // DUT outputs (observed by the TB)
    wire q;

    // Clock generators
    always #(CLK_PERIOD / 2.0) clk = ~clk;

    // DUT instantiation
    dff dut (
        .clk (clk),
        .d   (d),
        .rst (rst),
        .q   (q)
    );

    // Stimulus and monitoring
    initial begin
        clk = 1'b0;
        d   = 0;
        rst = 1'b1;   // reset asserted

        $timeformat(-9, 1, " ns", 0);
        $monitor("time=%0t | d=%0h rst=%0h q=%0h", $time, d, rst, q);

        // Release reset(s)
        #(RESET_TIME);
        rst = 1'b0;

        // TODO: add test stimulus here

        #(SIM_TIME) $finish;
    end

endmodule
