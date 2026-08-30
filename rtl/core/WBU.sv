/* verilator lint_off UNUSEDSIGNAL */
// signal not use
`include "para.sv"
module WBU (
    input clock,
    input reset,

    input [31:0] MEM_Rdata,
    input [31:0] Ex_result,
    input [31:0] rd_value,
    input [ 4:0] rd,
    input [ 5:0] csr_wen,
    input        R_wen,
    input        mem_ren,
    input        jump_flag,
    input [31:0] pc,

    input  valid,
    output ready,

    output        valid_next,
    output        R_wen_next,
    output [ 5:0] csr_wen_next,
    output [31:0] csrd,

    output logic [31:0] pc_out,
    output       [31:0] rd_value_next,
    output       [ 4:0] rd_next
);

assign pc_out = pc;


  assign valid_next    = valid;
  assign rd_value_next = (jump_flag | (|csr_wen)) ? rd_value : (mem_ren) ? MEM_Rdata : Ex_result;
  assign csrd          = valid ? Ex_result : 32'b0;
  assign csr_wen_next  = valid ? csr_wen : 6'b0;
  assign R_wen_next    = R_wen & valid;
  assign rd_next       = rd;
  assign ready         = 1'b1;

endmodule  //WBU
