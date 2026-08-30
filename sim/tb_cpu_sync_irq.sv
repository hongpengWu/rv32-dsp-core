`timescale 1ns / 1ps

// Machine-timer interrupt regression for the Nano bring-up path.
module tb_cpu_sync_irq;
    localparam logic [31:0] RESET_PC = 32'h8000_0000;
    localparam logic [31:0] DATA_BASE = 32'h8010_0000;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic timer_irq = 1'b0;
    logic imem_req_valid;
    logic [31:0] imem_req_addr, imem_rsp_data;
    logic imem_rsp_valid;
    logic dmem_req_valid, dmem_req_write;
    logic [31:0] dmem_req_addr, dmem_req_wdata;
    logic [3:0] dmem_req_wstrb;
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
        .timer_irq(timer_irq), .cpu_clk(clk), .cpu_rst(reset),
        .imem_req_valid(imem_req_valid), .imem_req_addr(imem_req_addr),
        .imem_rsp_valid(imem_rsp_valid), .imem_rsp_data(imem_rsp_data),
        .dmem_req_valid(dmem_req_valid), .dmem_req_write(dmem_req_write),
        .dmem_req_addr(dmem_req_addr), .dmem_req_wstrb(dmem_req_wstrb),
        .dmem_req_wdata(dmem_req_wdata), .dmem_rsp_valid(dmem_rsp_valid),
        .dmem_rsp_rdata(dmem_rsp_rdata),
        .debug_wb_have_inst(debug_wb_have_inst), .debug_wb_pc(debug_wb_pc),
        .debug_wb_ena(debug_wb_ena), .debug_wb_reg(debug_wb_reg),
        .debug_wb_value(debug_wb_value)
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

    function automatic [31:0] enc_csr(
        input [11:0] csr, input [4:0] rs1, input [2:0] funct3,
        input [4:0] rd);
        enc_csr = {csr, rs1, funct3, rd, 7'b1110011};
    endfunction

    always @(posedge clk) begin
        #1;
        if (!reset && imem_req_valid && $isunknown(imem_req_addr))
            $fatal(1, "IRQ FAIL: X/Z on instruction request");
        if (!reset && dmem_req_valid &&
            $isunknown({dmem_req_write, dmem_req_addr,
                        dmem_req_wstrb, dmem_req_wdata}))
            $fatal(1, "IRQ FAIL: X/Z on data request");
    end

    initial begin
        for (i = 0; i < 64; i = i + 1)
            imem.mem[i] = 32'h0000_0013;

        // Main: set mtvec=0x80000040, enable mstatus.MIE and mie.MTIE,
        // then spin.  x10 points at the data window.
        imem.mem[0] = enc_u(20'h80100, 5'd10, 7'b0110111); // x10=DATA_BASE
        imem.mem[1] = enc_u(20'h80000, 5'd1,  7'b0110111); // x1=RESET_PC
        imem.mem[2] = enc_i(64, 5'd1, 3'b000, 5'd1, 7'b0010011);
        imem.mem[3] = enc_csr(12'h305, 5'd1, 3'b001, 5'd0); // mtvec=x1
        imem.mem[4] = enc_i(8, 5'd0, 3'b000, 5'd2, 7'b0010011);
        imem.mem[5] = enc_csr(12'h300, 5'd2, 3'b010, 5'd0); // mstatus.MIE
        imem.mem[6] = enc_i(128, 5'd0, 3'b000, 5'd3, 7'b0010011);
        imem.mem[7] = enc_csr(12'h304, 5'd3, 3'b010, 5'd0); // mie.MTIE
        imem.mem[8] = enc_i(1, 5'd0, 3'b000, 5'd4, 7'b0010011);
        imem.mem[9] = enc_s(0, 5'd4, 5'd10, 3'b010); // pre-IRQ marker
        imem.mem[10] = 32'h0000_006f; // spin

        // Handler at 0x80000040: record marker and mcause, then return.
        imem.mem[16] = enc_i(85, 5'd0, 3'b000, 5'd5, 7'b0010011);
        imem.mem[17] = enc_s(4, 5'd5, 5'd10, 3'b010);
        imem.mem[18] = enc_csr(12'h342, 5'd0, 3'b010, 5'd6); // csrr x6,mcause
        imem.mem[19] = enc_s(8, 5'd6, 5'd10, 3'b010);
        imem.mem[20] = 32'h3020_0073; // mret
        imem.mem[21] = 32'h0000_006f; // handler safety loop

        repeat (3) @(posedge clk);
        reset = 1'b0;

        // Let the enable sequence retire, then deliver a short timer pulse.
        repeat (80) @(posedge clk);
        timer_irq = 1'b1;
        repeat (3) @(posedge clk);
        timer_irq = 1'b0;
        repeat (180) @(posedge clk);

        if (dmem.mem[0] !== 32'h0000_0001)
            $fatal(1, "IRQ FAIL: pre-IRQ marker %h", dmem.mem[0]);
        if (dmem.mem[1] !== 32'h0000_0055)
            $fatal(1, "IRQ FAIL: handler marker %h", dmem.mem[1]);
        if (dmem.mem[2] !== 32'h8000_0007)
            $fatal(1, "IRQ FAIL: mcause %h", dmem.mem[2]);

        $display("IRQ PASS: timer interrupt, mie/mip, mcause, handler and MRET verified");
        $finish;
    end
endmodule
