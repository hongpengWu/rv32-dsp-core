`timescale 1ns / 1ps

module tb_control_hazard;
    logic        clock;
    logic        reset;
    logic [31:0] mtvec_out;
    logic [31:0] mepc_out;
    logic [31:0] branch_pc;
    logic [31:0] Ex_result;
    logic [31:0] MEM_Ex_result;
    logic [31:0] MEM_Rdata;
    logic [31:0] IDU_rs1_value;
    logic [31:0] IDU_rs2_value;
    logic        branch_flag;
    logic        jump_flag;
    logic        mret_flag;
    logic        ecall_flag;
    logic        MEM_mem_ren;
    logic        fence_i_flag;
    logic [4:0]  IDU_rs1;
    logic [4:0]  IDU_rs2;
    logic        IDU_uses_rs1;
    logic        IDU_uses_rs2;
    logic        IDU_valid;
    logic        EXU_valid;
    logic        MEM_valid;
    logic [4:0]  EXU_rd;
    logic [4:0]  MEM_rd;
    logic        EXU_mem_ren;
    logic        EXU_R_Wen;
    logic        MEM_R_Wen;
    logic        IFU_stall;
    logic [31:0] EXU_rs1_in;
    logic [31:0] EXU_rs2_in;
    logic        icache_clr;
    logic        EXU_inst_clear;
    logic [31:0] dnpc;
    logic        dnpc_flag;

    Control dut (.*);

    task automatic check_stall(input logic expected, input string name);
        #1;
        if (IFU_stall !== expected)
            $fatal(1, "CONTROL HAZARD FAIL (%s): stall=%b expected=%b",
                   name, IFU_stall, expected);
        if (EXU_inst_clear !== expected)
            $fatal(1, "CONTROL HAZARD FAIL (%s): clear=%b expected=%b",
                   name, EXU_inst_clear, expected);
    endtask

    initial begin
        clock = 1'b0;
        reset = 1'b0;
        mtvec_out = 32'b0;
        mepc_out = 32'b0;
        branch_pc = 32'b0;
        Ex_result = 32'b0;
        MEM_Ex_result = 32'b0;
        MEM_Rdata = 32'b0;
        IDU_rs1_value = 32'b0;
        IDU_rs2_value = 32'b0;
        branch_flag = 1'b0;
        jump_flag = 1'b0;
        mret_flag = 1'b0;
        ecall_flag = 1'b0;
        MEM_mem_ren = 1'b0;
        fence_i_flag = 1'b0;
        IDU_rs1 = 5'd5;
        IDU_rs2 = 5'd6;
        IDU_uses_rs1 = 1'b0;
        IDU_uses_rs2 = 1'b0;
        IDU_valid = 1'b1;
        EXU_valid = 1'b1;
        MEM_valid = 1'b0;
        EXU_rd = 5'd5;
        MEM_rd = 5'd0;
        EXU_mem_ren = 1'b1;
        EXU_R_Wen = 1'b1;
        MEM_R_Wen = 1'b0;

        check_stall(1'b0, "matching unused immediate fields");

        IDU_uses_rs1 = 1'b1;
        check_stall(1'b1, "true rs1 load-use dependency");

        IDU_uses_rs1 = 1'b0;
        IDU_uses_rs2 = 1'b1;
        EXU_rd = 5'd6;
        check_stall(1'b1, "true rs2 load-use dependency");

        IDU_valid = 1'b0;
        check_stall(1'b0, "invalid consumer");

        IDU_valid = 1'b1;
        EXU_rd = 5'd0;
        IDU_rs2 = 5'd0;
        check_stall(1'b0, "x0 dependency is ignored");

        $display("CONTROL HAZARD PASS");
        $finish;
    end
endmodule
