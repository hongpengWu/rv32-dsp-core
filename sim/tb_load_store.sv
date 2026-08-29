`timescale 1ns / 1ps

module tb_load_store;
    localparam logic [31:0] RESET_PC = 32'h8000_0000;
    localparam logic [31:0] DATA_BASE = 32'h9000_0000;
    localparam int IMEM_WORDS = 128;
    localparam int DMEM_BYTES = 256;

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
    integer stalls;
    integer false_use_index;
    integer read_offset;
    integer write_offset;

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

    task automatic check_word(input integer offset, input [31:0] expected);
        reg [31:0] actual;
        begin
            actual = {dmem[offset + 3], dmem[offset + 2],
                      dmem[offset + 1], dmem[offset]};
            if (actual !== expected)
                $fatal(1, "LOAD/STORE FAIL: dmem[%0d] got=%08x expected=%08x",
                       offset, actual, expected);
        end
    endtask

    always_comb begin
        irom_data = 32'h0000_006f;
        if ((irom_addr >= RESET_PC) &&
            (irom_addr < RESET_PC + IMEM_WORDS * 4))
            irom_data = imem[(irom_addr - RESET_PC) >> 2];
    end

    // The retained contest-bus contract returns the selected lane right-aligned.
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
                $fatal(1, "LOAD/STORE FAIL: store outside test memory: %08x", perip_addr);
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
                default: $fatal(1, "LOAD/STORE FAIL: invalid store mask %b", perip_mask);
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
            stalls <= 0;
        end else begin
            cycles <= cycles + 1;
            if (perip_wen)
                stores <= stores + 1;
            if (dut.IFU_stall)
                stalls <= stalls + 1;
            if ((irom_addr == RESET_PC + false_use_index * 4) && dut.IFU_stall)
                $fatal(1, "LOAD/STORE FAIL: LUI immediate fields caused a false load-use stall");
        end
    end

    initial begin
        for (i = 0; i < IMEM_WORDS; i = i + 1)
            imem[i] = 32'h0000_006f;
        for (i = 0; i < DMEM_BYTES; i = i + 1)
            dmem[i] = 8'b0;

        p = 0;
        emit(enc_u(20'h90000, 5'd20, 7'b0110111));

        emit(enc_u(20'h11223, 5'd1, 7'b0110111));
        emit(enc_i(12'h344, 5'd1, 3'b000, 5'd1, 7'b0010011));
        emit(enc_s(0, 5'd1, 5'd20, 3'b010)); // sw -> 0x11223344

        emit(enc_i(-86, 5'd0, 3'b000, 5'd2, 7'b0010011));
        emit(enc_s(1, 5'd2, 5'd20, 3'b000)); // sb -> byte 1 = 0xaa

        emit(enc_u(20'h0000c, 5'd3, 7'b0110111));
        emit(enc_i(-273, 5'd3, 3'b000, 5'd3, 7'b0010011));
        emit(enc_s(2, 5'd3, 5'd20, 3'b001)); // sh -> upper half = 0xbeef

        emit(enc_i(1, 5'd20, 3'b000, 5'd4, 7'b0000011)); // lb
        emit(enc_s(64, 5'd4, 5'd20, 3'b010));
        emit(enc_i(1, 5'd20, 3'b100, 5'd5, 7'b0000011)); // lbu
        emit(enc_s(68, 5'd5, 5'd20, 3'b010));
        emit(enc_i(2, 5'd20, 3'b001, 5'd6, 7'b0000011)); // lh
        emit(enc_s(72, 5'd6, 5'd20, 3'b010));
        emit(enc_i(2, 5'd20, 3'b101, 5'd7, 7'b0000011)); // lhu
        emit(enc_s(76, 5'd7, 5'd20, 3'b010));
        emit(enc_i(0, 5'd20, 3'b010, 5'd8, 7'b0000011)); // lw
        emit(enc_s(80, 5'd8, 5'd20, 3'b010));

        emit(enc_i(0, 5'd20, 3'b010, 5'd9, 7'b0000011));
        emit(enc_i(1, 5'd9, 3'b000, 5'd10, 7'b0010011)); // load -> ALU
        emit(enc_s(84, 5'd10, 5'd20, 3'b010));
        emit(enc_i(0, 5'd20, 3'b010, 5'd11, 7'b0000011));
        emit(enc_s(88, 5'd11, 5'd20, 3'b010)); // load -> store data

        emit(enc_i(0, 5'd20, 3'b010, 5'd13, 7'b0000011));
        false_use_index = p;
        // Raw rs1/rs2 fields both equal x13, but LUI reads neither source.
        emit(enc_u(20'h035a0, 5'd14, 7'b0110111));
        emit(enc_s(92, 5'd14, 5'd20, 3'b010));
        emit(enc_j(0, 5'd0));

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (300) @(posedge clk);

        check_word(0, 32'hbeef_aa44);
        check_word(64, 32'hffff_ffaa);
        check_word(68, 32'h0000_00aa);
        check_word(72, 32'hffff_beef);
        check_word(76, 32'h0000_beef);
        check_word(80, 32'hbeef_aa44);
        check_word(84, 32'hbeef_aa45);
        check_word(88, 32'hbeef_aa44);
        check_word(92, 32'h035a_0000);
        if (stores !== 11)
            $fatal(1, "LOAD/STORE FAIL: observed %0d stores, expected 11", stores);
        if (stalls !== 7)
            $fatal(1, "LOAD/STORE FAIL: observed %0d load-use stalls, expected 7", stalls);

        $display("LOAD/STORE PASS: 8 operations, 11 stores, 7 true stalls");
        $finish;
    end
endmodule
