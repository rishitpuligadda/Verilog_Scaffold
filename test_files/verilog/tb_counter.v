module tb_counter;
    // Parameters
    parameter CLK_CLK_PERIOD     = 10;

    // DUT Inputs (Driven by TB)
    reg        clk;
    reg        rst_n;

    // DUT Outputs (Observed by TB)
    wire [3:0] count;

    // Clock Generators
    always #(CLK_CLK_PERIOD / 2.0) clk = ~clk;

    // DUT Instantiation
    counter dut (
        .clk   (clk),
        .rst_n (rst_n),
        .count (count)
    );

    // Stimulus and Monitoring
    initial begin
        clk = 0;
        $monitor("time=%0t | rst_n=%0h count=%0h", $time, rst_n, count);

        // Add test stimulus here

        #200 $finish;
    end

endmodule
