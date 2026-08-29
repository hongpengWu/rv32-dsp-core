`timescale 1ns / 1ps

module tb_pynq_demo;
    logic       sys_clk = 1'b0;
    logic [3:0] btn = 4'b0001;
    logic [3:0] led;
    integer i;

    always #5 sys_clk = ~sys_clk;

    function automatic [31:0] enc_i(
        input integer imm, input [4:0] rs1, input [2:0] funct3,
        input [4:0] rd, input [6:0] opcode);
        enc_i = {imm[11:0], rs1, funct3, rd, opcode};
    endfunction

    function automatic [31:0] enc_u(
        input [19:0] imm20, input [4:0] rd, input [6:0] opcode);
        enc_u = {imm20, rd, opcode};
    endfunction

    function automatic [31:0] enc_s(
        input integer imm, input [4:0] rs2, input [4:0] rs1,
        input [2:0] funct3);
        enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
    endfunction

    function automatic [31:0] enc_j(input integer offset, input [4:0] rd);
        reg [20:0] imm;
        begin
            imm = offset;
            enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
        end
    endfunction

    rv32_pynq_z2_demo dut (
        .sys_clk (sys_clk),
        .btn     (btn),
        .led     (led)
    );

    initial begin
        for (i = 0; i < 64; i = i + 1)
            dut.imem.mem[i] = 32'h0000_0013;

        dut.imem.mem[0] = enc_u(20'h80200, 5'd1, 7'b0110111); // x1=LED base
        dut.imem.mem[1] = enc_i(12'h0a5, 5'd0, 3'b000, 5'd2, 7'b0010011);
        dut.imem.mem[2] = enc_s(64, 5'd2, 5'd1, 3'b010);     // LED <= 0xa5
        dut.imem.mem[3] = enc_j(0, 5'd0);

        repeat (5) @(posedge sys_clk);
        btn[0] = 1'b0;

        for (i = 0; i < 100; i = i + 1) begin
            @(posedge sys_clk);
            if (led === 4'h5) begin
                $display("PYNQ DEMO PASS: LED=%x cycle=%0d", led, i);
                $finish;
            end
        end

        $fatal(1, "PYNQ DEMO FAIL: LED=%x", led);
    end
endmodule
