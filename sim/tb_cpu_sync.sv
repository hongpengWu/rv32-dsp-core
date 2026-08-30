`timescale 1ns / 1ps

module tb_cpu_sync;
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

    function automatic [31:0] enc_s(
        input integer imm, input [4:0] rs2, input [4:0] rs1,
        input [2:0] funct3);
        enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
    endfunction

    always @(posedge clk) begin
        #1;
        if (!reset && imem_req_valid &&
            $isunknown(imem_req_addr)) begin
            $display("SYNC CORE X/Z: instruction request addr=%h", imem_req_addr);
            $fatal(1, "SYNC CORE FAIL: X/Z on memory interface at %0t", $time);
        end
        if (!reset && dmem_req_valid &&
            $isunknown({dmem_req_write, dmem_req_addr,
                        dmem_req_wstrb, dmem_req_wdata})) begin
            $display("SYNC CORE X/Z: data request write=%b addr=%h st=%b wd=%h",
                     dmem_req_write, dmem_req_addr, dmem_req_wstrb,
                     dmem_req_wdata);
            $fatal(1, "SYNC CORE FAIL: X/Z on memory interface at %0t", $time);
        end
        if (!reset && imem_rsp_valid && $isunknown(imem_rsp_data))
            $fatal(1, "SYNC CORE FAIL: X/Z on instruction response at %0t", $time);
        if (!reset && dmem_rsp_valid && $isunknown(dmem_rsp_rdata))
            $fatal(1, "SYNC CORE FAIL: X/Z on data response at %0t", $time);
        if (!reset && imem_req_valid &&
            ((imem_req_addr < RESET_PC) ||
             (imem_req_addr >= RESET_PC + 64 * 4) ||
             (imem_req_addr[1:0] != 2'b00)))
            $fatal(1, "SYNC CORE FAIL: invalid instruction request %h", imem_req_addr);
        if (!reset && dmem_req_valid &&
            ((dmem_req_addr < DATA_BASE) ||
             (dmem_req_addr >= DATA_BASE + 64) ||
             (dmem_req_addr[1:0] != 2'b00)))
            $fatal(1, "SYNC CORE FAIL: invalid data request %h", dmem_req_addr);
    end

    initial begin
        for (i = 0; i < 64; i = i + 1)
            imem.mem[i] = 32'h0000_0013;

        imem.mem[0] = enc_u(20'h80100, 5'd1, 7'b0110111); // x1=DATA_BASE
        imem.mem[1] = enc_i(32'h055, 5'd0, 3'b000, 5'd2, 7'b0010011);
        imem.mem[2] = enc_s(0, 5'd2, 5'd1, 3'b010);        // sw 55
        imem.mem[3] = enc_i(0, 5'd1, 3'b010, 5'd3, 7'b0000011); // lw
        imem.mem[4] = enc_i(1, 5'd3, 3'b000, 5'd4, 7'b0010011); // addi
        imem.mem[5] = enc_s(4, 5'd4, 5'd1, 3'b010);        // sw 56
        imem.mem[6] = 32'h0000_006f;                      // loop

        repeat (3) @(posedge clk);
        reset = 1'b0;
        repeat (180) @(posedge clk);

        if (dmem.mem[0] !== 32'h0000_0055)
            $fatal(1, "SYNC CORE FAIL: first store %h", dmem.mem[0]);
        if (dmem.mem[1] !== 32'h0000_0056)
            $fatal(1, "SYNC CORE FAIL: load/use store %h", dmem.mem[1]);

        $display("SYNC CORE PASS: synchronous fetch/load/store path verified");
        $finish;
    end
endmodule
