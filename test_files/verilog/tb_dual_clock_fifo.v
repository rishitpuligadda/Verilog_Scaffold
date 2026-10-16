`timescale 1ns / 1ps

module tb_dual_clock_fifo;

    // Parameters
    parameter DATA_WIDTH    = 32;
    parameter DEPTH         = 16;
    parameter WR_CLK_PERIOD = 10;
    parameter RD_CLK_PERIOD = 25;
    parameter RESET_TIME    = 125;
    parameter SIM_TIME      = 2500;

    // DUT inputs (driven by the TB)
    reg                   wr_clk;
    reg                   rd_clk;
    reg                   wr_rst_n;
    reg                   wr_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    reg                   rd_rst_n;
    reg                   rd_en;

    // DUT outputs (observed by the TB)
    wire [DATA_WIDTH-1:0] rd_data;
    wire                  full;
    wire                  empty;

    // Clock generators
    always #(WR_CLK_PERIOD / 2.0) wr_clk = ~wr_clk;
    always #(RD_CLK_PERIOD / 2.0) rd_clk = ~rd_clk;

    // DUT instantiation
    dual_clock_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH)
    ) dut (
        .wr_clk   (wr_clk),
        .rd_clk   (rd_clk),
        .wr_rst_n (wr_rst_n),
        .wr_en    (wr_en),
        .wr_data  (wr_data),
        .rd_rst_n (rd_rst_n),
        .rd_en    (rd_en),
        .rd_data  (rd_data),
        .full     (full),
        .empty    (empty)
    );

    // Stimulus and monitoring
    initial begin
        wr_clk   = 1'b0;
        rd_clk   = 1'b0;
        wr_rst_n = 1'b0;   // reset asserted
        wr_en    = 0;
        wr_data  = 0;
        rd_rst_n = 1'b0;   // reset asserted
        rd_en    = 0;

        $timeformat(-9, 1, " ns", 0);
        $monitor("time=%0t | wr_rst_n=%0h wr_en=%0h wr_data=%0h rd_rst_n=%0h rd_en=%0h rd_data=%0h full=%0h empty=%0h", $time, wr_rst_n, wr_en, wr_data, rd_rst_n, rd_en, rd_data, full, empty);

        // Release reset(s)
        #(RESET_TIME);
        wr_rst_n = 1'b1;
        rd_rst_n = 1'b1;

        // TODO: add test stimulus here

        #(SIM_TIME) $finish;
    end

endmodule
