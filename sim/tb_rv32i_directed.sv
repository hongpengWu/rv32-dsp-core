`timescale 1ns / 1ps

module tb_rv32i_directed;
    localparam logic [31:0] RESET_PC = 32'h8000_0000;
    localparam logic [31:0] DATA_BASE = 32'h9000_0000;
    localparam int IMEM_WORDS = 256;
    localparam int MAX_STORES = 64;

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

    always #5 clk = ~clk;

    function automatic [31:0] enc_r(
        input [6:0] funct7, input [4:0] rs2, input [4:0] rs1,
        input [2:0] funct3, input [4:0] rd);
        enc_r = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
    endfunction

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

    function automatic [31:0] enc_u(
        input [19:0] imm20, input [4:0] rd, input [6:0] opcode);
        enc_u = {imm20, rd, opcode};
    endfunction

    task automatic emit(input [31:0] instruction);
        begin
            imem[p] = instruction;
            p = p + 1;
        end
    endtask

    task automatic emit_store(input [4:0] rs2, input integer offset,
                               input [31:0] value);
        begin
            imem[p] = enc_s(offset, rs2, 5'd20, 3'b010);
            p = p + 1;
            expected_addr[expected_count] = DATA_BASE + offset;
            expected_data[expected_count] = value;
            expected_count = expected_count + 1;
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
        .debug_wb_reg        (debug_wb_reg),
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
                    $fatal(1, "DIRECTED FAIL: unexpected store cycle=%0d addr=%08x data=%08x",
                           cycles, perip_addr, perip_wdata);
                end
                if (perip_addr !== expected_addr[observed_count] ||
                    perip_wdata !== expected_data[observed_count] ||
                    perip_mask !== 2'b10) begin
                    $fatal(1, "DIRECTED FAIL: store %0d cycle=%0d got addr=%08x data=%08x mask=%b expected addr=%08x data=%08x",
                           observed_count, cycles, perip_addr, perip_wdata, perip_mask,
                           expected_addr[observed_count], expected_data[observed_count]);
                end
                observed_count <= observed_count + 1;
            end
        end
    end

    initial begin
        for (i = 0; i < IMEM_WORDS; i = i + 1) begin
            imem[i] = 32'h0000_006f;
        end
        expected_count = 0;
        observed_count = 0;
        p = 0;

        // x20 is the output base address.
        emit(enc_u(20'h90000, 5'd20, 7'b0110111)); // lui x20, 0x90000
        emit(enc_i(5, 5'd0, 3'b000, 5'd1, 7'b0010011)); // addi x1, x0, 5
        emit_store(5'd1, 0, 32'd5);
        emit(enc_i(7, 5'd0, 3'b000, 5'd2, 7'b0010011)); // addi x2, x0, 7
        emit_store(5'd2, 4, 32'd7);
        emit(enc_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3)); // add x3, x1, x2
        emit_store(5'd3, 8, 32'd12);
        emit(enc_r(7'b0100000, 5'd1, 5'd3, 3'b000, 5'd4)); // sub x4, x3, x1
        emit_store(5'd4, 12, 32'd7);
        emit(enc_r(7'b0000000, 5'd4, 5'd3, 3'b111, 5'd5)); // and x5, x3, x4
        emit_store(5'd5, 16, 32'd4);
        emit(enc_r(7'b0000000, 5'd4, 5'd3, 3'b110, 5'd6)); // or x6, x3, x4
        emit_store(5'd6, 20, 32'd15);
        emit(enc_r(7'b0000000, 5'd4, 5'd3, 3'b100, 5'd7)); // xor x7, x3, x4
        emit_store(5'd7, 24, 32'd11);
        emit(enc_i(1, 5'd0, 3'b000, 5'd8, 7'b0010011)); // addi x8, x0, 1
        emit(enc_r(7'b0000000, 5'd1, 5'd8, 3'b001, 5'd9)); // sll x9, x8, x1
        emit_store(5'd9, 28, 32'd32);
        emit(enc_r(7'b0000000, 5'd1, 5'd9, 3'b101, 5'd10)); // srl x10, x9, x1
        emit_store(5'd10, 32, 32'd1);
        emit(enc_i(-2, 5'd0, 3'b000, 5'd11, 7'b0010011)); // addi x11, x0, -2
        emit(enc_r(7'b0100000, 5'd1, 5'd11, 3'b101, 5'd12)); // sra x12, x11, x1
        emit_store(5'd12, 36, 32'hffff_ffff);
        emit(enc_r(7'b0000000, 5'd1, 5'd11, 3'b010, 5'd13)); // slt x13, x11, x1
        emit_store(5'd13, 40, 32'd1);
        emit(enc_r(7'b0000000, 5'd1, 5'd11, 3'b011, 5'd14)); // sltu x14, x11, x1
        emit_store(5'd14, 44, 32'd0);
        emit(enc_i(-3, 5'd1, 3'b000, 5'd15, 7'b0010011)); // addi x15, x1, -3
        emit_store(5'd15, 48, 32'd2);
        emit(enc_i(6, 5'd1, 3'b010, 5'd16, 7'b0010011)); // slti x16, x1, 6
        emit_store(5'd16, 52, 32'd1);
        emit(enc_i(0, 5'd11, 3'b011, 5'd17, 7'b0010011)); // sltiu x17, x11, 0
        emit_store(5'd17, 56, 32'd0);
        emit(enc_i(10, 5'd1, 3'b100, 5'd18, 7'b0010011)); // xori x18, x1, 10
        emit_store(5'd18, 60, 32'd15);
        emit(enc_i(10, 5'd1, 3'b110, 5'd19, 7'b0010011)); // ori x19, x1, 10
        emit_store(5'd19, 64, 32'd15);
        emit(enc_i(3, 5'd1, 3'b111, 5'd21, 7'b0010011)); // andi x21, x1, 3
        emit_store(5'd21, 68, 32'd1);
        emit(enc_i(2, 5'd1, 3'b001, 5'd22, 7'b0010011)); // slli x22, x1, 2
        emit_store(5'd22, 72, 32'd20);
        emit(enc_i(2, 5'd22, 3'b101, 5'd23, 7'b0010011)); // srli x23, x22, 2
        emit_store(5'd23, 76, 32'd5);
        emit(enc_i(12'h401, 5'd11, 3'b101, 5'd24, 7'b0010011)); // srai x24, x11, 1
        emit_store(5'd24, 80, 32'hffff_ffff);
        emit(enc_u(20'h00000, 5'd25, 7'b0010111)); // auipc x25, 0
        emit_store(5'd25, 84, RESET_PC + ((p - 1) * 4));
        emit(enc_u(20'h12345, 5'd26, 7'b0110111)); // lui x26, 0x12345
        emit_store(5'd26, 88, 32'h1234_5000);
        emit(enc_u(20'hfffff, 5'd27, 7'b0110111)); // lui x27, 0xfffff
        emit_store(5'd27, 92, 32'hffff_f000);
        emit(enc_j(0, 5'd0));

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (400) @(posedge clk);
        if (observed_count !== expected_count) begin
            $fatal(1, "DIRECTED FAIL: observed %0d/%0d stores", observed_count, expected_count);
        end
        $display("DIRECTED PASS: %0d stores", observed_count);
        $finish;
    end

    function automatic [31:0] enc_j(input integer offset, input [4:0] rd);
        reg [20:0] imm;
        begin
            imm = offset;
            enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
        end
    endfunction
endmodule
