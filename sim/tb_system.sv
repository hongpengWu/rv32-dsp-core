`timescale 1ns / 1ps

module tb_system;
    localparam logic [31:0] RESET_PC = 32'h8000_0000;
    localparam logic [31:0] DATA_BASE = 32'h9000_0000;
    localparam int IMEM_WORDS = 128;
    localparam int DMEM_BYTES = 128;
    localparam int HANDLER_INDEX = 64;
    localparam logic [31:0] HANDLER_PC = RESET_PC + HANDLER_INDEX * 4;

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic [31:0] irom_addr;
    logic [31:0] irom_data;
    logic [31:0] perip_addr;
    logic        perip_wen;
    logic [1:0]  perip_mask;
    logic [31:0] perip_wdata;
    logic [31:0] perip_rdata;
    logic        debug_wb_have_inst;
    logic [31:0] debug_wb_pc;
    logic        debug_wb_ena;
    logic [4:0]  debug_wb_reg;
    logic [31:0] debug_wb_value;

    logic [31:0] imem [0:IMEM_WORDS-1];
    logic [7:0]  dmem [0:DMEM_BYTES-1];
    integer i;
    integer p;
    integer cycles;
    integer stores;
    integer trap_count;
    integer read_offset;
    integer write_offset;

    always #5 clk = ~clk;

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

    function automatic [31:0] enc_csr(
        input [11:0] csr, input [4:0] rs1_or_zimm, input [2:0] funct3,
        input [4:0] rd);
        enc_csr = {csr, rs1_or_zimm, funct3, rd, 7'b1110011};
    endfunction

    function automatic [31:0] enc_j(input integer offset, input [4:0] rd);
        reg [20:0] imm;
        begin
            imm = offset;
            enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
        end
    endfunction

    task automatic emit(input [31:0] instruction);
        begin
            imem[p] = instruction;
            p = p + 1;
        end
    endtask

    task automatic emit_nops(input integer count);
        integer n;
        begin
            for (n = 0; n < count; n = n + 1)
                emit(enc_i(0, 5'd0, 3'b000, 5'd0, 7'b0010011));
        end
    endtask

    task automatic check_word(input integer offset, input [31:0] expected);
        reg [31:0] actual;
        begin
            actual = {dmem[offset + 3], dmem[offset + 2],
                      dmem[offset + 1], dmem[offset]};
            if (actual !== expected)
                $fatal(1, "SYSTEM FAIL: dmem[%0d] got=%08x expected=%08x",
                       offset, actual, expected);
        end
    endtask

    always_comb begin
        irom_data = 32'h0000_006f;
        if ((irom_addr >= RESET_PC) &&
            (irom_addr < RESET_PC + IMEM_WORDS * 4))
            irom_data = imem[(irom_addr - RESET_PC) >> 2];
    end

    always_comb begin
        perip_rdata = 32'b0;
        read_offset = perip_addr - DATA_BASE;
        if ((perip_addr >= DATA_BASE) &&
            (perip_addr < DATA_BASE + DMEM_BYTES)) begin
            case (perip_mask)
                2'b00: perip_rdata = {24'b0, dmem[read_offset]};
                2'b01: perip_rdata = {16'b0, dmem[read_offset + 1],
                                               dmem[read_offset]};
                2'b10: perip_rdata = {dmem[read_offset + 3],
                                      dmem[read_offset + 2],
                                      dmem[read_offset + 1],
                                      dmem[read_offset]};
                default: perip_rdata = 32'b0;
            endcase
        end
    end

    always @(posedge clk) begin
        if (!rst && perip_wen) begin
            write_offset = perip_addr - DATA_BASE;
            if ((perip_addr < DATA_BASE) ||
                (perip_addr >= DATA_BASE + DMEM_BYTES))
                $fatal(1, "SYSTEM FAIL: store outside test memory: %08x", perip_addr);
            case (perip_mask)
                2'b00: dmem[write_offset] <= perip_wdata[7:0];
                2'b01: begin
                    dmem[write_offset] <= perip_wdata[7:0];
                    dmem[write_offset + 1] <= perip_wdata[15:8];
                end
                2'b10: begin
                    dmem[write_offset] <= perip_wdata[7:0];
                    dmem[write_offset + 1] <= perip_wdata[15:8];
                    dmem[write_offset + 2] <= perip_wdata[23:16];
                    dmem[write_offset + 3] <= perip_wdata[31:24];
                end
                default: $fatal(1, "SYSTEM FAIL: invalid store mask %b", perip_mask);
            endcase
        end
    end

    myCPU dut (
        .cpu_clk            (clk),
        .cpu_rst            (rst),
        .irom_addr          (irom_addr),
        .irom_data          (irom_data),
        .perip_addr         (perip_addr),
        .perip_wen          (perip_wen),
        .perip_mask         (perip_mask),
        .perip_wdata        (perip_wdata),
        .perip_rdata        (perip_rdata),
        .debug_wb_have_inst (debug_wb_have_inst),
        .debug_wb_pc        (debug_wb_pc),
        .debug_wb_ena       (debug_wb_ena),
        .debug_wb_reg       (debug_wb_reg),
        .debug_wb_value     (debug_wb_value)
    );

    always @(posedge clk) begin
        if (rst) begin
            cycles <= 0;
            stores <= 0;
            trap_count <= 0;
        end else begin
            cycles <= cycles + 1;
            if (perip_wen)
                $display("SYSTEM TRACE store cycle=%0d addr=%08x data=%08x", cycles, perip_addr, perip_wdata);
            if (perip_wen)
                stores <= stores + 1;
            if (dut.trap_fire) begin
                $display("SYSTEM TRACE trap cycle=%0d pc=%08x cause=%0d mtvec=%08x", cycles,
                         dut.IFU_pc, dut.IDU_trap_cause, dut.IDU_mtvec_out);
                trap_count <= trap_count + 1;
            end
        end
    end

    initial begin
        for (i = 0; i < IMEM_WORDS; i = i + 1)
            imem[i] = 32'h0000_006f;
        for (i = 0; i < DMEM_BYTES; i = i + 1)
            dmem[i] = 8'b0;

        p = 0;
        emit(enc_u(20'h90000, 5'd20, 7'b0110111)); // x20 = DATA_BASE
        emit(enc_u(20'h80000, 5'd1, 7'b0110111));  // x1 = RESET_PC
        emit(enc_i(HANDLER_INDEX * 4, 5'd1, 3'b000, 5'd1, 7'b0010011));
        emit(enc_csr(12'h305, 5'd1, 3'b001, 5'd0)); // csrrw x0, mtvec, x1
        emit_nops(4);
        emit(enc_csr(12'h305, 5'd0, 3'b010, 5'd2)); // csrrs x2, mtvec, x0
        emit(enc_s(0, 5'd2, 5'd20, 3'b010));
        emit(enc_i(8, 5'd0, 3'b000, 5'd9, 7'b0010011)); // mstatus.MIE
        emit(enc_csr(12'h300, 5'd9, 3'b001, 5'd10)); // CSRRW
        emit_nops(4);
        emit(enc_csr(12'h300, 5'd9, 3'b010, 5'd11)); // CSRRS
        emit_nops(4);
        emit(enc_csr(12'h300, 5'd9, 3'b011, 5'd12)); // CSRRC
        emit_nops(4);
        emit(enc_csr(12'h300, 5'd8, 3'b101, 5'd13)); // CSRRWI: set MIE
        emit_nops(4);
        emit(enc_csr(12'h300, 5'd0, 3'b110, 5'd14)); // CSRRSI zimm=0, no write
        emit_nops(4);
        emit(enc_csr(12'h300, 5'd8, 3'b111, 5'd15)); // CSRRCI: clear MIE
        emit_nops(4);
        emit(enc_csr(12'h300, 5'd8, 3'b101, 5'd0)); // restore MIE before traps
        emit_nops(4);
        emit(enc_i(0, 5'd0, 3'b000, 5'd6, 7'b0010011));
        emit(32'h0000_0073); // ECALL
        emit(32'h0000_837f); // illegal instruction, mtval must preserve bits
        emit(32'h0010_0073); // EBREAK
        emit(enc_csr(12'h300, 5'd0, 3'b010, 5'd8));
        emit(enc_s(64, 5'd8, 5'd20, 3'b010));
        emit(enc_j(0, 5'd0));

        p = HANDLER_INDEX;
        emit(enc_csr(12'h342, 5'd0, 3'b010, 5'd3)); // mcause
        emit(enc_csr(12'h341, 5'd0, 3'b010, 5'd4)); // mepc
        emit(enc_csr(12'h343, 5'd0, 3'b010, 5'd5)); // mtval
        emit(enc_i(1, 5'd6, 3'b000, 5'd6, 7'b0010011));
        emit(enc_i(4, 5'd6, 3'b001, 5'd7, 7'b0010011)); // x7 = x6 << 4
        emit(enc_r(5'd20, 5'd7, 3'b000, 5'd7, 7'b0000000));
        emit(enc_s(0, 5'd3, 5'd7, 3'b010));
        emit(enc_s(4, 5'd4, 5'd7, 3'b010));
        emit(enc_s(8, 5'd5, 5'd7, 3'b010));
        emit(enc_csr(12'h300, 5'd0, 3'b010, 5'd8));
        emit(enc_s(12, 5'd8, 5'd7, 3'b010));
        emit(enc_i(4, 5'd4, 3'b000, 5'd4, 7'b0010011));
        emit(enc_csr(12'h341, 5'd4, 3'b001, 5'd0));
        emit_nops(4);
        emit(32'h3020_0073); // MRET
        emit(enc_j(0, 5'd0));

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (1500) @(posedge clk);

        check_word(0, HANDLER_PC);
        check_word(16, 32'd11);
        check_word(20, RESET_PC + 47 * 4);
        check_word(24, 32'd0);
        check_word(28, 32'h0000_1880);
        check_word(32, 32'd2);
        check_word(36, RESET_PC + 48 * 4);
        check_word(40, 32'h0000_837f);
        check_word(44, 32'h0000_1880);
        check_word(48, 32'd3);
        check_word(52, RESET_PC + 49 * 4);
        check_word(56, 32'd0);
        check_word(60, 32'h0000_1880);
        check_word(64, 32'h0000_0088);
        if (trap_count !== 3)
            $fatal(1, "SYSTEM FAIL: observed %0d traps, expected 3", trap_count);
        $display("SYSTEM PASS: Zicsr, ECALL, EBREAK, illegal trap, MRET");
        $finish;
    end

    function automatic [31:0] enc_r(
        input [4:0] rs2, input [4:0] rs1, input [2:0] funct3,
        input [4:0] rd, input [6:0] funct7_opcode);
        enc_r = {funct7_opcode, rs2, rs1, funct3, rd, 7'b0110011};
    endfunction
endmodule
