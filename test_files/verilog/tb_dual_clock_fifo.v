module tb_dual_clock_fifo;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter DEPTH      = 16;
    parameter CLK_WR_CLK_PERIOD  = 10;
    parameter CLK_RD_CLK_PERIOD  = 25;

    // DUT Inputs (Driven by TB)
    reg                   wr_clk;
    reg                   rd_clk;
    reg                   wr_rst_n;
    reg                   wr_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    reg                   rd_rst_n;
    reg                   rd_en;

    // DUT Outputs (Observed by TB)
    wire [DATA_WIDTH-1:0] rd_data;
    wire                  full;
    wire                  empty;

    // Clock Generators
    always #(CLK_WR_CLK_PERIOD / 2.0) wr_clk = ~wr_clk;
    always #(CLK_RD_CLK_PERIOD / 2.0) rd_clk = ~rd_clk;

    // DUT Instantiation
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

    // Stimulus and Monitoring
    initial begin
        wr_clk = 0;
        rd_clk = 0;
        $monitor("time=%0t | wr_rst_n=%0h wr_en=%0h wr_data=%0h rd_rst_n=%0h rd_en=%0h rd_data=%0h full=%0h empty=%0h", $time, wr_rst_n, wr_en, wr_data, rd_rst_n, rd_en, rd_data, full, empty);

        // Add test stimulus here

        #200 $finish;
    end

endmodule
