`timescale 1ns / 1ps
`include "para.sv"

// CPU-level RV32M/Zmmul regression.  The program exercises all four
// multiplication encodings and stores the architectural results through the
// synchronous data-memory interface.
module tb_mul;
    localparam logic [31:0] RESET_PC = 32'h8000_0000;
    localparam logic [31:0] DATA_BASE = 32'h8010_0000;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic imem_req_valid;
    logic [31:0] imem_req_addr;
    logic imem_rsp_valid;
    logic [31:0] imem_rsp_data;
    logic dmem_req_valid;
    logic dmem_req_write;
    logic [31:0] dmem_req_addr;
    logic [3:0] dmem_req_wstrb;
    logic [31:0] dmem_req_wdata;
    logic dmem_rsp_valid;
    logic [31:0] dmem_rsp_rdata;
    logic debug_wb_have_inst;
    logic [31:0] debug_wb_pc;
    logic debug_wb_ena;
    logic [4:0] debug_wb_reg;
    logic [31:0] debug_wb_value;
    logic [31:0] alu_a, alu_b, alu_result;
    logic [4:0]  alu_choice;
    integer i;

    always #5 clk = ~clk;

    myCPU_sync dut (
        .timer_irq(1'b0),
        .cpu_clk(clk), .cpu_rst(reset),
        .imem_req_valid(imem_req_valid), .imem_req_addr(imem_req_addr),
        .imem_rsp_valid(imem_rsp_valid), .imem_rsp_data(imem_rsp_data),
        .dmem_req_valid(dmem_req_valid), .dmem_req_write(dmem_req_write),
        .dmem_req_addr(dmem_req_addr), .dmem_req_wstrb(dmem_req_wstrb),
        .dmem_req_wdata(dmem_req_wdata), .dmem_rsp_valid(dmem_rsp_valid),
        .dmem_rsp_rdata(dmem_rsp_rdata), .debug_wb_have_inst(debug_wb_have_inst),
        .debug_wb_pc(debug_wb_pc), .debug_wb_ena(debug_wb_ena),
        .debug_wb_reg(debug_wb_reg), .debug_wb_value(debug_wb_value)
    );

    // A direct ALU model check complements the CPU program below.  It covers
    // the signedness boundary cases without relying on a particular register
    // or memory sequence.
    ALU alu_dut (.d1(alu_a), .d2(alu_b), .choice(alu_choice), .res(alu_result));

    function automatic [31:0] model_mul(
        input logic [31:0] a, input logic [31:0] b, input logic [4:0] op);
        logic signed [32:0] ma, mb;
        logic signed [65:0] product;
        begin
            ma = (op == `alu_mulhu) ? {1'b0, a} : {a[31], a};
            mb = ((op == `alu_mulhsu) || (op == `alu_mulhu)) ?
                 {1'b0, b} : {b[31], b};
            product = ma * mb;
            model_mul = (op == `alu_mul) ? product[31:0] : product[63:32];
        end
    endfunction

    task automatic check_alu_mul(input logic [31:0] a, input logic [31:0] b);
        begin
            alu_a = a;
            alu_b = b;
            for (integer op = `alu_mul; op <= `alu_mulhu; op = op + 1) begin
                alu_choice = op[4:0];
                #1;
                if (alu_result !== model_mul(a, b, alu_choice))
                    $fatal(1, "MUL ALU FAIL: op=%h a=%h b=%h got=%h exp=%h",
                           alu_choice, a, b, alu_result,
                           model_mul(a, b, alu_choice));
            end
        end
    endtask

    rv32_sync_rom #(.DEPTH_WORDS(64), .BASE_ADDR(RESET_PC)) imem (
        .clk(clk), .req_valid(imem_req_valid), .req_addr(imem_req_addr),
        .rsp_valid(imem_rsp_valid), .rsp_data(imem_rsp_data),
        .data_req_valid(1'b0), .data_req_addr(32'd0),
        .data_rsp_valid(), .data_rsp_data()
    );

    rv32_sync_byte_ram #(.DEPTH_BYTES(64), .BASE_ADDR(DATA_BASE)) dmem (
        .clk(clk), .req_valid(dmem_req_valid), .req_write(dmem_req_write),
        .req_addr(dmem_req_addr), .req_wstrb(dmem_req_wstrb),
        .req_wdata(dmem_req_wdata), .rsp_valid(dmem_rsp_valid),
        .rsp_rdata(dmem_rsp_rdata)
    );

    function automatic [31:0] enc_i(
        input integer imm, input [4:0] rs1, input [2:0] funct3,
        input [4:0] rd, input [6:0] opcode);
        enc_i = {imm[11:0], rs1, funct3, rd, opcode};
    endfunction

    function automatic [31:0] enc_u(
        input [19:0] imm20, input [4:0] rd, input [6:0] opcode);
        enc_u = {imm20, rd, opcode};
    endfunction

    function automatic [31:0] enc_r(
        input [6:0] funct7, input [4:0] rs2, input [4:0] rs1,
        input [2:0] funct3, input [4:0] rd);
        enc_r = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
    endfunction

    function automatic [31:0] enc_s(
        input integer imm, input [4:0] rs2, input [4:0] rs1,
        input [2:0] funct3);
        enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
    endfunction

    always @(posedge clk) begin
        #1;
        if (!reset && imem_req_valid && $isunknown(imem_req_addr))
            $fatal(1, "MUL FAIL: X/Z instruction request");
        if (!reset && dmem_req_valid &&
            $isunknown({dmem_req_write, dmem_req_addr,
                        dmem_req_wstrb, dmem_req_wdata}))
            $fatal(1, "MUL FAIL: X/Z data request");
    end

    initial begin
        check_alu_mul(32'h8000_0000, 32'h0000_0002);
        check_alu_mul(32'hffff_ffff, 32'h0000_0002);
        check_alu_mul(32'h7fff_ffff, 32'h7fff_ffff);
        check_alu_mul(32'h8000_0000, 32'hffff_ffff);
        for (i = 0; i < 32; i = i + 1)
            check_alu_mul($urandom, $urandom);

        for (i = 0; i < 64; i = i + 1)
            imem.mem[i] = 32'h0000_0013;

        // x1 = DATA_BASE, x2 = 0x80000000, x3 = 2.
        imem.mem[0]  = enc_u(20'h80100, 5'd1, 7'b0110111);
        imem.mem[1]  = enc_u(20'h80000, 5'd2, 7'b0110111);
        imem.mem[2]  = enc_i(2, 5'd0, 3'b000, 5'd3, 7'b0010011);
        // -2147483648 * 2 = 0xFFFF_FFFF_0000_0000.
        imem.mem[3]  = enc_r(7'b0000001, 5'd3, 5'd2, 3'b000, 5'd4); // MUL
        imem.mem[4]  = enc_r(7'b0000001, 5'd3, 5'd2, 3'b001, 5'd5); // MULH
        imem.mem[5]  = enc_r(7'b0000001, 5'd3, 5'd2, 3'b010, 5'd6); // MULHSU
        imem.mem[6]  = enc_r(7'b0000001, 5'd3, 5'd2, 3'b011, 5'd7); // MULHU
        imem.mem[7]  = enc_s(0,  5'd4, 5'd1, 3'b010);
        imem.mem[8]  = enc_s(4,  5'd5, 5'd1, 3'b010);
        imem.mem[9]  = enc_s(8,  5'd6, 5'd1, 3'b010);
        imem.mem[10] = enc_s(12, 5'd7, 5'd1, 3'b010);
        imem.mem[11] = 32'h0000_006f;

        repeat (3) @(posedge clk);
        reset = 1'b0;
        repeat (220) @(posedge clk);

        if (dmem.mem[0] !== 32'h0000_0000)
            $fatal(1, "MUL FAIL: MUL low=%h", dmem.mem[0]);
        if (dmem.mem[1] !== 32'hffff_ffff)
            $fatal(1, "MUL FAIL: MULH high=%h", dmem.mem[1]);
        if (dmem.mem[2] !== 32'hffff_ffff)
            $fatal(1, "MUL FAIL: MULHSU high=%h", dmem.mem[2]);
        if (dmem.mem[3] !== 32'h0000_0001)
            $fatal(1, "MUL FAIL: MULHU high=%h", dmem.mem[3]);

        $display("MUL PASS: MUL/MULH/MULHSU/MULHU signedness and high halves verified");
        $finish;
    end
endmodule
