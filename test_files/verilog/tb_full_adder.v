`timescale 1ns / 1ps

module tb_full_adder;

    // Parameters
    parameter RESET_TIME = 50;
    parameter SIM_TIME   = 1000;

    // DUT inputs (driven by the TB)
    reg a;
    reg b;
    reg cin;

    // DUT outputs (observed by the TB)
    wire sum;
    wire cout;

    // DUT instantiation
    full_adder dut (
        .a    (a),
        .b    (b),
        .cin  (cin),
        .sum  (sum),
        .cout (cout)
    );

    // Stimulus and monitoring
    initial begin
        a   = 0;
        b   = 0;
        cin = 0;

        $timeformat(-9, 1, " ns", 0);
        $monitor("time=%0t | a=%0h b=%0h cin=%0h sum=%0h cout=%0h", $time, a, b, cin, sum, cout);

        // TODO: add test stimulus here

        #(SIM_TIME) $finish;
    end

endmodule
