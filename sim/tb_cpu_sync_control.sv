`timescale 1ns / 1ps

// Control-flow and synchronous-trap regression for myCPU_sync.  The program
// deliberately puts wrong-path stores after BEQ/JAL/JALR and then vectors an
// ECALL to a handler in the instruction ROM.
module tb_cpu_sync_control;
    localparam logic [31:0] RESET_PC  = 32'h8000_0000;
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
    integer i;

    always #5 clk = ~clk;

    myCPU_sync dut (
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

    rv32_sync_rom #(.DEPTH_WORDS(64), .BASE_ADDR(RESET_PC)) imem (
        .clk(clk), .req_valid(imem_req_valid), .req_addr(imem_req_addr),
        .rsp_valid(imem_rsp_valid), .rsp_data(imem_rsp_data)
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

    function automatic [31:0] enc_b(
        input integer imm, input [4:0] rs2, input [4:0] rs1,
        input [2:0] funct3);
        enc_b = {imm[12], imm[10:5], rs2, rs1, funct3,
                 imm[4:1], imm[11], 7'b1100011};
    endfunction

    function automatic [31:0] enc_j(
        input integer imm, input [4:0] rd);
        enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
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

    function automatic [31:0] enc_csr(
        input [11:0] csr, input [4:0] rs1, input [2:0] funct3,
        input [4:0] rd);
        enc_csr = {csr, rs1, funct3, rd, 7'b1110011};
    endfunction

    always @(posedge clk) begin
        #1;
        if (!reset && imem_req_valid &&
            $isunknown(imem_req_addr))
            $fatal(1, "SYNC CONTROL FAIL: X/Z on instruction request");
        if (!reset && dmem_req_valid &&
            $isunknown({dmem_req_write, dmem_req_addr,
                        dmem_req_wstrb, dmem_req_wdata}))
            $fatal(1, "SYNC CONTROL FAIL: X/Z on data request");
        if (!reset && imem_rsp_valid && $isunknown(imem_rsp_data))
            $fatal(1, "SYNC CONTROL FAIL: X/Z on instruction response");
        if (!reset && dmem_rsp_valid && $isunknown(dmem_rsp_rdata))
            $fatal(1, "SYNC CONTROL FAIL: X/Z on data response");
        if (!reset && imem_req_valid &&
            ((imem_req_addr < RESET_PC) ||
             (imem_req_addr >= RESET_PC + 64 * 4) ||
             (imem_req_addr[1:0] != 2'b00)))
            $fatal(1, "SYNC CONTROL FAIL: invalid instruction request %h", imem_req_addr);
        if (!reset && dmem_req_valid &&
            ((dmem_req_addr < DATA_BASE) ||
             (dmem_req_addr >= DATA_BASE + 64) ||
             (dmem_req_addr[1:0] != 2'b00)))
            $fatal(1, "SYNC CONTROL FAIL: invalid data request %h", dmem_req_addr);
    end

    initial begin
        for (i = 0; i < 64; i = i + 1)
            imem.mem[i] = 32'h0000_0013;

        // Main program at 0x8000_0000.
        imem.mem[0]  = enc_u(20'h80100, 5'd1, 7'b0110111); // x1 = DATA_BASE
        imem.mem[1]  = enc_i(1,  5'd0, 3'b000, 5'd2, 7'b0010011); // x2=1
        imem.mem[2]  = enc_b(8,  5'd2, 5'd2, 3'b000); // BEQ: skip index 3
        imem.mem[3]  = enc_i(99, 5'd0, 3'b000, 5'd2, 7'b0010011); // wrong path
        imem.mem[4]  = enc_i(7,  5'd0, 3'b000, 5'd3, 7'b0010011); // x3=7
        imem.mem[5]  = enc_j(8,  5'd4); // JAL: skip index 6
        imem.mem[6]  = enc_i(88, 5'd0, 3'b000, 5'd3, 7'b0010011); // wrong path
        imem.mem[7]  = enc_s(0,  5'd3, 5'd1, 3'b010); // store 7
        imem.mem[8]  = enc_u(20'h00000, 5'd8, 7'b0010111); // AUIPC x8
        imem.mem[9]  = enc_i(12, 5'd8, 3'b000, 5'd8, 7'b0010011); // target index 11
        imem.mem[10] = enc_i(1,  5'd8, 3'b000, 5'd9, 7'b1100111); // JALR bit0 clear
        imem.mem[11] = enc_i(42, 5'd0, 3'b000, 5'd10, 7'b0010011); // x10=42
        imem.mem[12] = enc_s(4,  5'd10, 5'd1, 3'b010); // store 42
        imem.mem[13] = enc_u(20'h80000, 5'd11, 7'b0110111); // x11=0x80000000
        // Set mtvec to 0x8000_0050 (index 20), then raise ECALL.
        imem.mem[14] = enc_i(80, 5'd11, 3'b000, 5'd11, 7'b0010011);
        imem.mem[15] = enc_csr(12'h305, 5'd11, 3'b001, 5'd0); // mtvec=x11
        imem.mem[16] = 32'h0000_0073; // ECALL

        // Trap handler at mtvec = 0x8000_0050 (index 20).
        imem.mem[20] = enc_i(42, 5'd0, 3'b000, 5'd12, 7'b0010011);
        imem.mem[21] = enc_s(8,  5'd12, 5'd1, 3'b010); // trap marker
        imem.mem[22] = 32'h0000_006f; // stay in handler

        repeat (3) @(posedge clk);
        reset = 1'b0;
        repeat (220) @(posedge clk);

        if (dmem.mem[0] !== 32'h0000_0007)
            $fatal(1, "SYNC CONTROL FAIL: branch/jump store %h", dmem.mem[0]);
        if (dmem.mem[1] !== 32'h0000_002a)
            $fatal(1, "SYNC CONTROL FAIL: JALR target store %h", dmem.mem[1]);
        if (dmem.mem[2] !== 32'h0000_002a)
            $fatal(1, "SYNC CONTROL FAIL: trap handler marker %h", dmem.mem[2]);
        if (dmem.mem[3] !== 32'h0000_0000)
            $fatal(1, "SYNC CONTROL FAIL: wrong-path store was committed %h", dmem.mem[3]);

        $display("SYNC CONTROL PASS: BEQ/JAL/JALR and ECALL redirect verified");
        $finish;
    end
endmodule
