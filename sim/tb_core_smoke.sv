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

        imem[0] = 32'h0050_0013; // addi x0, x0, 5 (must be discarded)
        imem[1] = 32'h0050_0093; // addi x1, x0, 5
        imem[2] = 32'h0000_837f; // illegal opcode, rd=x6, rs1=x1
        imem[3] = 32'h0070_0113; // addi x2, x0, 7
        imem[4] = 32'h0020_81b3; // add  x3, x1, x2
        imem[5] = 32'h8010_0237; // lui  x4, 0x80100
        imem[6] = 32'h0032_2023; // sw   x3, 0(x4)
        imem[7] = 32'h0000_006f; // jal  x0, 0

        repeat (5) @(posedge clk);
        rst = 1'b0;
    end

    always @(posedge clk) begin
        if (rst) begin
            cycles <= 0;
        end else begin
            cycles <= cycles + 1;

            if (perip_wen) begin
                if ((perip_addr === 32'h8010_0000) &&
                    (perip_wdata === 32'd12) &&
                    (perip_mask === 2'b10)) begin
                    $display("SMOKE PASS: cycle=%0d addr=%08x data=%08x",
                             cycles, perip_addr, perip_wdata);
                    $finish;
                end

                $fatal(1, "SMOKE FAIL: cycle=%0d addr=%08x data=%08x mask=%b",
                       cycles, perip_addr, perip_wdata, perip_mask);
            end

            if (debug_wb_have_inst && debug_wb_ena && (debug_wb_reg === 5'd6)) begin
                $fatal(1, "SMOKE FAIL: illegal instruction wrote x6=%08x", debug_wb_value);
            end

            if (cycles >= 100) begin
                $fatal(1, "SMOKE TIMEOUT: no expected store observed");
            end
        end
    end
endmodule
