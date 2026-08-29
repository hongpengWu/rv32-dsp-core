`timescale 1ns / 1ps

module tb_control_flow;
    localparam logic [31:0] RESET_PC = 32'h8000_0000;
    localparam logic [31:0] DATA_BASE = 32'h9000_0000;
    localparam int IMEM_WORDS = 256;
    localparam int MAX_STORES = 32;
    localparam int JALR_TARGET_INDEX = 200;

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic [31:0] irom_addr;
    logic [31:0] irom_data;
    logic [31:0] perip_addr;
    logic        perip_wen;
    logic [1:0]  perip_mask;
    logic [31:0] perip_wdata;
    logic [31:0] perip_rdata = 32'b0;
    logic        debug_wb_have_inst;
    logic [31:0] debug_wb_pc;
    logic        debug_wb_ena;
    logic [4:0]  debug_wb_reg;
    logic [31:0] debug_wb_value;

    logic [31:0] imem [0:IMEM_WORDS-1];
    logic [31:0] expected_addr [0:MAX_STORES-1];
    logic [31:0] expected_data [0:MAX_STORES-1];
    integer i;
    integer p;
    integer expected_count;
    integer observed_count;
    integer cycles;
    integer negative_jal_base;
    integer positive_jal_index;
    integer jalr_index;

    always #5 clk = ~clk;

    function automatic [31:0] enc_i(
        input integer imm, input [4:0] rs1, input [2:0] funct3,
        input [4:0] rd, input [6:0] opcode);
        enc_i = {imm[11:0], rs1, funct3, rd, opcode};
    endfunction

    function automatic [31:0] enc_s(
        input integer imm, input [4:0] rs2, input [4:0] rs1,
        input [2:0] funct3);
        enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
    endfunction

    function automatic [31:0] enc_b(
        input integer offset, input [4:0] rs2, input [4:0] rs1,
        input [2:0] funct3);
        reg [12:0] imm;
        begin
            imm = offset;
            enc_b = {imm[12], imm[10:5], rs2, rs1, funct3,
                     imm[4:1], imm[11], 7'b1100011};
        end
    endfunction

    function automatic [31:0] enc_u(
        input [19:0] imm20, input [4:0] rd, input [6:0] opcode);
        enc_u = {imm20, rd, opcode};
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

    task automatic emit_store_instruction(input [4:0] rs2, input integer offset);
        begin
            emit(enc_s(offset, rs2, 5'd20, 3'b010));
        end
    endtask

    task automatic expect_store(input integer offset, input [31:0] value);
        begin
            expected_addr[expected_count] = DATA_BASE + offset;
            expected_data[expected_count] = value;
            expected_count = expected_count + 1;
        end
    endtask

    // Each case has a taken target at +16 and a not-taken path that jumps over it.
    task automatic emit_branch_case(
        input [2:0] funct3,
        input integer lhs,
        input integer rhs,
        input logic take,
        input integer not_offset,
        input [31:0] not_value,
        input integer taken_offset,
        input [31:0] taken_value);
        begin
            emit(enc_i(lhs, 5'd0, 3'b000, 5'd1, 7'b0010011));
            emit(enc_i(rhs, 5'd0, 3'b000, 5'd2, 7'b0010011));
            emit(enc_b(16, 5'd2, 5'd1, funct3));
            emit(enc_i(not_value, 5'd0, 3'b000, 5'd31, 7'b0010011));
            emit_store_instruction(5'd31, not_offset);
            emit(enc_j(12, 5'd0));
            emit(enc_i(taken_value, 5'd0, 3'b000, 5'd31, 7'b0010011));
            emit_store_instruction(5'd31, taken_offset);
            if (take)
                expect_store(taken_offset, taken_value);
            else
                expect_store(not_offset, not_value);
        end
    endtask

    always_comb begin
        irom_data = 32'h0000_006f;
        if ((irom_addr >= RESET_PC) &&
            (irom_addr < RESET_PC + IMEM_WORDS * 4)) begin
            irom_data = imem[(irom_addr - RESET_PC) >> 2];
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
            observed_count <= 0;
        end else begin
            cycles <= cycles + 1;
            if (perip_wen === 1'b1) begin
                if (observed_count >= expected_count) begin
                    $fatal(1, "CONTROL FAIL: unexpected store cycle=%0d addr=%08x data=%08x",
                           cycles, perip_addr, perip_wdata);
                end
                if (perip_addr !== expected_addr[observed_count] ||
                    perip_wdata !== expected_data[observed_count] ||
                    perip_mask !== 2'b10) begin
                    $fatal(1, "CONTROL FAIL: store %0d cycle=%0d got addr=%08x data=%08x mask=%b expected addr=%08x data=%08x",
                           observed_count, cycles, perip_addr, perip_wdata, perip_mask,
                           expected_addr[observed_count], expected_data[observed_count]);
                end
                observed_count <= observed_count + 1;
            end
        end
    end

    initial begin
        for (i = 0; i < IMEM_WORDS; i = i + 1)
            imem[i] = 32'h0000_006f;

        expected_count = 0;
        observed_count = 0;
        p = 0;

        emit(enc_u(20'h90000, 5'd20, 7'b0110111)); // lui x20, DATA_BASE

        emit_branch_case(3'b000,  5,  5, 1'b1,  0, 32'd2,  4, 32'd1); // beq
        emit_branch_case(3'b000,  5,  6, 1'b0,  8, 32'd4, 12, 32'd3); // beq not taken
        emit_branch_case(3'b001,  5,  6, 1'b1, 16, 32'd6, 20, 32'd5); // bne
        emit_branch_case(3'b001,  5,  5, 1'b0, 24, 32'd8, 28, 32'd7); // bne not taken
        emit_branch_case(3'b100, -1,  1, 1'b1, 32, 32'd10, 36, 32'd9); // blt
        emit_branch_case(3'b100,  1, -1, 1'b0, 40, 32'd12, 44, 32'd11); // blt not taken
        emit_branch_case(3'b101,  1, -1, 1'b1, 48, 32'd14, 52, 32'd13); // bge
        emit_branch_case(3'b101, -1,  1, 1'b0, 56, 32'd16, 60, 32'd15); // bge not taken
        emit_branch_case(3'b110,  1, -1, 1'b1, 64, 32'd18, 68, 32'd17); // bltu
        emit_branch_case(3'b110, -1,  1, 1'b0, 72, 32'd20, 76, 32'd19); // bltu not taken
        emit_branch_case(3'b111, -1,  1, 1'b1, 80, 32'd22, 84, 32'd21); // bgeu
        emit_branch_case(3'b111,  1, -1, 1'b0, 88, 32'd24, 92, 32'd23); // bgeu not taken

        // Negative B-immediate and simultaneous EXU/MEM operand forwarding.
        emit(enc_i(0, 5'd0, 3'b000, 5'd8, 7'b0010011));
        emit(enc_i(1, 5'd8, 3'b000, 5'd8, 7'b0010011));
        emit(enc_i(2, 5'd0, 3'b000, 5'd9, 7'b0010011));
        emit(enc_b(-8, 5'd9, 5'd8, 3'b100));
        emit_store_instruction(5'd8, 96);
        expect_store(96, 32'd2);

        // Execute a negative-offset JAL once, then escape past its wrong path.
        negative_jal_base = p;
        emit(enc_j(16, 5'd0));
        emit(enc_i(55, 5'd0, 3'b000, 5'd10, 7'b0010011));
        emit_store_instruction(5'd10, 100);
        emit(enc_j(12, 5'd0));
        emit(enc_j(-12, 5'd11));
        emit_store_instruction(5'd0, 104); // wrong path: must not happen
        emit_store_instruction(5'd11, 108);
        expect_store(100, 32'd55);
        expect_store(108, RESET_PC + (negative_jal_base + 5) * 4);

        // JAL must skip both wrong-path instructions and write PC + 4 to x5.
        emit(enc_i(0, 5'd0, 3'b000, 5'd30, 7'b0010011));
        positive_jal_index = p;
        emit(enc_j(12, 5'd5));
        emit(enc_i(99, 5'd0, 3'b000, 5'd30, 7'b0010011));
        emit_store_instruction(5'd30, 112); // wrong path: must not happen
        emit_store_instruction(5'd5, 116);
        emit_store_instruction(5'd30, 120);
        expect_store(116, RESET_PC + (positive_jal_index + 1) * 4);
        expect_store(120, 32'd0);

        // JALR target is deliberately odd; hardware must clear bit 0.
        emit(enc_u(20'h80000, 5'd6, 7'b0110111));
        emit(enc_i(16'h321, 5'd6, 3'b000, 5'd6, 7'b0010011));
        jalr_index = p;
        emit(enc_i(0, 5'd6, 3'b000, 5'd7, 7'b1100111));
        emit(enc_i(77, 5'd0, 3'b000, 5'd30, 7'b0010011));
        emit_store_instruction(5'd30, 124); // wrong path: must not happen

        imem[JALR_TARGET_INDEX] = enc_s(128, 5'd7, 5'd20, 3'b010);
        imem[JALR_TARGET_INDEX + 1] = enc_s(132, 5'd6, 5'd20, 3'b010);
        imem[JALR_TARGET_INDEX + 2] = enc_j(0, 5'd0);
        expect_store(128, RESET_PC + (jalr_index + 1) * 4);
        expect_store(132, 32'h8000_0321);

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (1000) @(posedge clk);
        if (observed_count !== expected_count)
            $fatal(1, "CONTROL FAIL: observed %0d/%0d stores", observed_count, expected_count);
        $display("CONTROL PASS: %0d stores; branch and jump paths verified", observed_count);
        $finish;
    end
endmodule
