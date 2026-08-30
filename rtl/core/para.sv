/*interface define*/


// __opcode__

`define R_opcode  7'b0110011
`define I0_opcode 7'b0000011                          //lw
`define I1_opcode 7'b0010011                          //addi
`define I2_opcode 7'b1100111                          //jalr
`define S_opcode  7'b0100011
`define B_opcode  7'b1100011
`define U0_opcode 7'b0110111                          //lui
`define U1_opcode 7'b0010111                          //auipc
`define J_opcode  7'b1101111                          //jal
`define M_opcode  7'b1110011

// alu
`define alu_add                   4'b0000
`define alu_sub                   4'b0001
`define alu_or                    4'b0010
`define alu_and                   4'b0011
`define alu_xor                   4'b0100
`define alu_signed_comparator     4'b0101
`define alu_unsigned_comparator   4'b0110
`define alu_equal                 4'b0111
`define alu_sll                   4'b1000
`define alu_srl                   4'b1001
`define alu_sra                   4'b1010
`define alu_andn                  4'b1011
// RV32M/Zmmul operations.  The ALU selector is five bits so the standard
// multiply operations and project-specific custom-0 operations share the
// existing single-cycle EXU path.
`define alu_mul                   5'b01100  // low 32 bits, signed x signed
`define alu_mulh                  5'b01101  // high 32 bits, signed x signed
`define alu_mulhsu                5'b01110  // high 32 bits, signed x unsigned
`define alu_mulhu                 5'b01111  // high 32 bits, unsigned x unsigned
// custom-0 packed fixed-point DSP operations
`define alu_dotp16                5'b10000  // two signed 16x16 lanes, summed
`define alu_q15mul                5'b10001  // rounded/saturated signed Q1.15

`define custom0_opcode            7'b0001011


`define Performance_Count
