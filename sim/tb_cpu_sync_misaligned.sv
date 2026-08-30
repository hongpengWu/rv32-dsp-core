`timescale 1ns / 1ps

// Precise misaligned-access regression for myCPU_sync.  The handler records
// mcause/mtval pairs, advances mepc, and returns with MRET so both a misaligned
// store (cause 6) and a misaligned load (cause 4) can be tested in one run.
module tb_cpu_sync_misaligned;
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

    rv32_sync_byte_ram #(.DEPTH_BYTES(128), .BASE_ADDR(DATA_BASE)) dmem (
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

    function automatic [31:0] enc_s(
        input integer imm, input [4:0] rs2, input [4:0] rs1,
        input [2:0] funct3);
        enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
    endfunction

    function automatic [31:0] enc_u(
        input [19:0] imm20, input [4:0] rd, input [6:0] opcode);
        enc_u = {imm20, rd, opcode};
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
            $fatal(1, "SYNC MISALIGNED FAIL: X/Z on instruction request");
        if (!reset && dmem_req_valid &&
            $isunknown({dmem_req_write, dmem_req_addr,
                        dmem_req_wstrb, dmem_req_wdata}))
            $fatal(1, "SYNC MISALIGNED FAIL: X/Z on data request");
        if (!reset && imem_rsp_valid && $isunknown(imem_rsp_data))
            $fatal(1, "SYNC MISALIGNED FAIL: X/Z on instruction response");
        if (!reset && dmem_rsp_valid && $isunknown(dmem_rsp_rdata))
            $fatal(1, "SYNC MISALIGNED FAIL: X/Z on data response");
        // The LSU receives only aligned requests.  In particular, the two
        // faulting accesses below must never reach this interface.
        if (!reset && dmem_req_valid && dmem_req_addr[1:0] != 2'b00)
            $fatal(1, "SYNC MISALIGNED FAIL: unaligned request escaped LSU");
    end

    initial begin
        for (i = 0; i < 64; i = i + 1)
            imem.mem[i] = 32'h0000_0013;

        // Main program: configure mtvec, fault on SH+1, return, fault on LW+2,
        // return, then perform one aligned store as a completion marker.
        imem.mem[0]  = enc_u(20'h80100, 5'd1, 7'b0110111); // x1=DATA_BASE
        imem.mem[1]  = enc_u(20'h80000, 5'd5, 7'b0110111); // x5=RESET_PC
        imem.mem[2]  = enc_i(32'h80, 5'd5, 3'b000, 5'd5, 7'b0010011);
        imem.mem[3]  = enc_csr(12'h305, 5'd5, 3'b001, 5'd0); // mtvec=+0x80
        imem.mem[4]  = enc_i(32'h123, 5'd0, 3'b000, 5'd2, 7'b0010011);
        imem.mem[5]  = enc_i(8, 5'd1, 3'b000, 5'd9, 7'b0010011); // x9=record ptr
        imem.mem[6]  = enc_s(1, 5'd2, 5'd1, 3'b001); // misaligned SH, cause 6
        imem.mem[7]  = enc_i(7, 5'd0, 3'b000, 5'd6, 7'b0010011);
        imem.mem[8]  = enc_i(2, 5'd1, 3'b010, 5'd7, 7'b0000011); // misaligned LW, cause 4
        imem.mem[9]  = enc_s(0, 5'd6, 5'd1, 3'b010); // aligned completion store
        imem.mem[10] = 32'h0000_006f; // loop

        // Trap handler at 0x8000_0080 (index 32): record cause/tval, advance
        // mepc beyond the faulting instruction, and return to the main path.
        imem.mem[32] = enc_csr(12'h342, 5'd0, 3'b010, 5'd3); // x3=mcause
        imem.mem[33] = enc_s(0, 5'd3, 5'd9, 3'b010); // *record_ptr=mcause
        imem.mem[34] = enc_csr(12'h343, 5'd0, 3'b010, 5'd4); // x4=mtval
        imem.mem[35] = enc_s(4, 5'd4, 5'd9, 3'b010); // *record_ptr+4=mtval
        imem.mem[36] = enc_i(8, 5'd9, 3'b000, 5'd9, 7'b0010011); // next pair
        imem.mem[37] = enc_csr(12'h341, 5'd0, 3'b010, 5'd5); // x5=mepc
        imem.mem[38] = enc_i(4, 5'd5, 3'b000, 5'd5, 7'b0010011);
        imem.mem[39] = enc_csr(12'h341, 5'd5, 3'b001, 5'd0); // mepc=x5
        imem.mem[40] = 32'h3020_0073; // mret

        repeat (3) @(posedge clk);
        reset = 1'b0;
        repeat (500) @(posedge clk);

        if (dmem.mem[0] !== 32'h0000_0007)
            $fatal(1, "SYNC MISALIGNED FAIL: completion store %h", dmem.mem[0]);
        if (dmem.mem[2] !== 32'h0000_0006)
            $fatal(1, "SYNC MISALIGNED FAIL: SH cause %h", dmem.mem[2]);
        if (dmem.mem[3] !== DATA_BASE + 32'd1)
            $fatal(1, "SYNC MISALIGNED FAIL: SH mtval %h", dmem.mem[3]);
        if (dmem.mem[4] !== 32'h0000_0004)
            $fatal(1, "SYNC MISALIGNED FAIL: LW cause %h", dmem.mem[4]);
        if (dmem.mem[5] !== DATA_BASE + 32'd2)
            $fatal(1, "SYNC MISALIGNED FAIL: LW mtval %h", dmem.mem[5]);

        $display("SYNC MISALIGNED PASS: precise load/store traps and MRET verified");
        $finish;
    end
endmodule
