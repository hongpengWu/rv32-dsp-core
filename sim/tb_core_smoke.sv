`timescale 1ns / 1ps

module tb_core_smoke;
    localparam logic [31:0] RESET_PC = 32'h8000_0000;
    localparam int IMEM_WORDS = 64;

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic [31:0] irom_addr;
    logic [31:0] irom_data;
    logic [31:0] perip_addr;
    logic        perip_wen;
    logic [ 1:0] perip_mask;
    logic [31:0] perip_wdata;
    logic [31:0] perip_rdata = 32'b0;
    logic        debug_wb_have_inst;
    logic [31:0] debug_wb_pc;
    logic        debug_wb_ena;
    logic [ 4:0] debug_wb_reg;
    logic [31:0] debug_wb_value;

    logic [31:0] imem [0:IMEM_WORDS-1];
    integer i;
    integer cycles;
    integer store_count;
    logic   saw_expected_store;

    always #5 clk = ~clk;

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

    initial begin
        for (i = 0; i < IMEM_WORDS; i = i + 1) begin
            imem[i] = 32'h0000_006f;
        end

        imem[0] = 32'h8000_02b7; // lui  x5, 0x80000
        imem[1] = 32'h0402_8293; // addi x5, x5, 64 (trap handler)
        imem[2] = {12'h305, 5'd5, 3'b001, 5'd0, 7'b1110011}; // csrrw x0, mtvec, x5
        imem[3] = 32'h0000_0013; // nop
        imem[4] = 32'h0000_0013; // nop
        imem[5] = 32'h0050_0093; // addi x1, x0, 5
        imem[6] = 32'h0000_837f; // illegal opcode, rd=x6, rs1=x1
        imem[7] = 32'h0070_0113; // addi x2, x0, 7
        imem[8] = 32'h0020_81b3; // add  x3, x1, x2
        imem[9] = 32'h8010_0237; // lui  x4, 0x80100
        imem[10] = 32'h0032_2023; // sw   x3, 0(x4)
        imem[11] = 32'h0000_006f; // jal  x0, 0

        imem[16] = {12'h341, 5'd0, 3'b010, 5'd7, 7'b1110011}; // csrrs x7, mepc, x0
        imem[17] = 32'h0043_8393; // addi x7, x7, 4
        imem[18] = {12'h341, 5'd7, 3'b001, 5'd0, 7'b1110011}; // csrrw x0, mepc, x7
        imem[19] = 32'h0000_0013;
        imem[20] = 32'h0000_0013;
        imem[21] = 32'h0000_0013;
        imem[22] = 32'h0000_0013;
        imem[23] = 32'h3020_0073; // mret
        imem[24] = 32'h0000_006f;

        repeat (5) @(posedge clk);
        rst = 1'b0;
        store_count = 0;
        saw_expected_store = 1'b0;
    end

    always @(posedge clk) begin
        if (rst) begin
            cycles <= 0;
            store_count <= 0;
            saw_expected_store <= 1'b0;
        end else begin
            cycles <= cycles + 1;

            if (perip_wen) begin
                if (store_count != 0) begin
                    $fatal(1, "SMOKE FAIL: repeated store at cycle=%0d", cycles);
                end
                store_count <= store_count + 1;
                if ((perip_addr === 32'h8010_0000) &&
                    (perip_wdata === 32'd12) &&
                    (perip_mask === 2'b10)) begin
                    saw_expected_store <= 1'b1;
                end else begin
                    $fatal(1, "SMOKE FAIL: cycle=%0d addr=%08x data=%08x mask=%b",
                           cycles, perip_addr, perip_wdata, perip_mask);
                end

            end

            if (debug_wb_have_inst && debug_wb_ena && (debug_wb_reg === 5'd6)) begin
                $fatal(1, "SMOKE FAIL: illegal instruction wrote x6=%08x", debug_wb_value);
            end

            if (saw_expected_store && cycles >= 40) begin
                $display("SMOKE PASS: cycle=%0d expected_store=80100000/0000000c stores=%0d",
                         cycles, store_count);
                $finish;
            end

            if (cycles >= 300) begin
                $fatal(1, "SMOKE TIMEOUT: no expected store observed");
            end
        end
    end
endmodule
