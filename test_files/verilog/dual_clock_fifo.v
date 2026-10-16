`timescale 1ns / 1ps

module dual_clock_fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16
) (
    input                       wr_clk,
    input                       rd_clk,
    input                       wr_rst_n,
    input                       wr_en,
    input      [DATA_WIDTH-1:0] wr_data,
    input                       rd_rst_n,
    input                       rd_en,
    output reg [DATA_WIDTH-1:0] rd_data,
    output                      full,
    output                      empty
);

    // TODO: implement design logic

endmodule
