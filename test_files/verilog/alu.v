module alu #(
    parameter DATA_WIDTH = 32,
    parameter OP_WIDTH   = 4
) (
    output reg [DATA_WIDTH-1:0] result,
    output reg                  carry_out,
    output                      zero_flag,
    input                       clk,
    input                       rst_n,
    input      [OP_WIDTH-1:0]   opcode,
    input      [DATA_WIDTH-1:0] operand_a,
    input      [DATA_WIDTH-1:0] operand_b
);

endmodule
