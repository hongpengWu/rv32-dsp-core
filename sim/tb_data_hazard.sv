`timescale 1ns / 1ps

module tb_data_hazard;
    logic [4:0] IDU_rs1;
    logic [4:0] IDU_rs2;
    logic       IDU_uses_rs1;
    logic       IDU_uses_rs2;
    logic [4:0] EXU_rd;
    logic [4:0] MEM_rd;
    logic       IDU_valid;
    logic       EXU_valid;
    logic       MEM_valid;
    logic       MEM_mem_ren;
    logic       EXU_R_Wen;
    logic       MEM_R_Wen;
    logic [1:0] IDU_rs1_choice;
    logic [1:0] IDU_rs2_choice;

    Data_hazard dut (.*);

    task automatic check(input logic [1:0] expected_rs1,
                         input logic [1:0] expected_rs2,
                         input string name);
        #1;
        if (IDU_rs1_choice !== expected_rs1 || IDU_rs2_choice !== expected_rs2) begin
            $fatal(1, "HAZARD FAIL (%s): rs1=%b rs2=%b expected rs1=%b rs2=%b",
                   name, IDU_rs1_choice, IDU_rs2_choice,
                   expected_rs1, expected_rs2);
        end
    endtask

    initial begin
        IDU_rs1 = 5'd3;
        IDU_rs2 = 5'd4;
        IDU_uses_rs1 = 1'b1;
        IDU_uses_rs2 = 1'b1;
        EXU_rd = 5'd3;
        MEM_rd = 5'd4;
        IDU_valid = 1'b1;
        EXU_valid = 1'b1;
        MEM_valid = 1'b1;
        MEM_mem_ren = 1'b0;
        EXU_R_Wen = 1'b1;
        MEM_R_Wen = 1'b1;
        check(2'b01, 2'b10, "EXU priority and MEM ALU");

        EXU_valid = 1'b0;
        MEM_mem_ren = 1'b1;
        check(2'b00, 2'b11, "invalid EXU and MEM load");

        IDU_valid = 1'b0;
        check(2'b00, 2'b00, "invalid IDU");

        IDU_valid = 1'b1;
        EXU_valid = 1'b1;
        IDU_uses_rs1 = 1'b0;
        IDU_uses_rs2 = 1'b0;
        check(2'b00, 2'b00, "unused immediate fields do not forward");
        IDU_uses_rs1 = 1'b1;
        IDU_uses_rs2 = 1'b1;
        MEM_mem_ren = 1'b0;
        IDU_rs1 = 5'd0;
        IDU_rs2 = 5'd0;
        EXU_rd = 5'd0;
        MEM_rd = 5'd0;
        check(2'b00, 2'b00, "x0 is never forwarded");

        $display("HAZARD PASS");
        $finish;
    end
endmodule
