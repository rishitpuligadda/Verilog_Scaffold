module tb_andg;


    // DUT Inputs (Driven by TB)
    reg  a;
    reg  b;

    // DUT Outputs (Observed by TB)
    wire y;



    // DUT Instantiation
    andg dut (
        .a (a),
        .b (b),
        .y (y)
    );

    // Stimulus and Monitoring
    initial begin
        $monitor("time=%0t | a=%0h b=%0h y=%0h", $time, a, b, y);

        // Add test stimulus here

        #200 $finish;
    end

endmodule
