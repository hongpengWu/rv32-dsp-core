`timescale 1ns / 1ps

// Generic XSim harness for a single riscv-tests physical (p) image.
// Instruction and data memories intentionally share the same address map so
// that the ELF image's .tohost and signature regions are visible to stores.
module tb_riscv_test #(
    parameter integer IMEM_WORDS = 16384,
    parameter integer MAX_CYCLES = 200000,
    parameter logic [31:0] RESET_PC = 32'h8000_0000,
    parameter string INIT_FILE = "program.mem"
);
    localparam logic [31:0] TOHOST_ADDR = 32'h8000_1000;
    localparam logic [31:0] LAST_ADDR = RESET_PC + IMEM_WORDS * 4;
    localparam logic [31:0] NOP = 32'h0000_0013;

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
    integer cycle = 0;
    integer store_count = 0;
    logic tohost_seen = 1'b0;
    logic [31:0] tohost_value = 32'd0;
    logic [31:0] mem [0:IMEM_WORDS-1];
    integer i;

    always #5 clk = ~clk;

    myCPU_sync dut (
        .cpu_clk(clk), .cpu_rst(reset),
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

    // riscv-tests/fence_i uses self-modifying code.  This unified,
    // synchronous test memory lets a data-side store become visible to a
    // later instruction fetch while preserving the Core's one-cycle ports.
    initial begin
        for (i = 0; i < IMEM_WORDS; i = i + 1)
            mem[i] = 32'd0;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    always_ff @(posedge clk) begin
        imem_rsp_valid <= imem_req_valid &&
                          (imem_req_addr >= RESET_PC) &&
                          (imem_req_addr < LAST_ADDR) &&
                          (imem_req_addr[1:0] == 2'b00);
        if (imem_req_valid &&
            (imem_req_addr >= RESET_PC) &&
            (imem_req_addr < LAST_ADDR) &&
            (imem_req_addr[1:0] == 2'b00))
            imem_rsp_data <= mem[(imem_req_addr - RESET_PC) >> 2];
        else
            imem_rsp_data <= NOP;

        dmem_rsp_valid <= dmem_req_valid && !dmem_req_write &&
                          (dmem_req_addr >= RESET_PC) &&
                          (dmem_req_addr < LAST_ADDR) &&
                          (dmem_req_addr[1:0] == 2'b00);
        if (dmem_req_valid && !dmem_req_write &&
            (dmem_req_addr >= RESET_PC) &&
            (dmem_req_addr < LAST_ADDR) &&
            (dmem_req_addr[1:0] == 2'b00))
            dmem_rsp_rdata <= mem[(dmem_req_addr - RESET_PC) >> 2];
        else
            dmem_rsp_rdata <= 32'd0;

        if (dmem_req_valid && dmem_req_write &&
            (dmem_req_addr >= RESET_PC) &&
            (dmem_req_addr < LAST_ADDR) &&
            (dmem_req_addr[1:0] == 2'b00)) begin
            if (dmem_req_wstrb[0]) mem[(dmem_req_addr - RESET_PC) >> 2][7:0]
                <= dmem_req_wdata[7:0];
            if (dmem_req_wstrb[1]) mem[(dmem_req_addr - RESET_PC) >> 2][15:8]
                <= dmem_req_wdata[15:8];
            if (dmem_req_wstrb[2]) mem[(dmem_req_addr - RESET_PC) >> 2][23:16]
                <= dmem_req_wdata[23:16];
            if (dmem_req_wstrb[3]) mem[(dmem_req_addr - RESET_PC) >> 2][31:24]
                <= dmem_req_wdata[31:24];
        end
    end

    always @(posedge clk) begin
        #1;
        if (!reset) begin
            cycle = cycle + 1;
            if ($isunknown({imem_req_valid, imem_rsp_valid,
                            dmem_req_valid, dmem_rsp_valid}))
                $fatal(1, "RISCV TEST FAIL: X/Z on memory handshake at cycle %0d", cycle);
            if (imem_req_valid && $isunknown(imem_req_addr))
                $fatal(1, "RISCV TEST FAIL: X/Z on instruction request at cycle %0d", cycle);
            if (imem_rsp_valid && $isunknown(imem_rsp_data))
                $fatal(1, "RISCV TEST FAIL: X/Z on instruction response at cycle %0d", cycle);
            if (dmem_req_valid &&
                $isunknown({dmem_req_write, dmem_req_addr,
                            dmem_req_wstrb, dmem_req_wdata}))
                $fatal(1, "RISCV TEST FAIL: X/Z on data request at cycle %0d", cycle);
            if (dmem_rsp_valid && $isunknown(dmem_rsp_rdata))
                $fatal(1, "RISCV TEST FAIL: X/Z on data response at cycle %0d", cycle);

            if (dmem_req_valid && dmem_req_write) begin
                store_count = store_count + 1;
                if (dmem_req_addr == TOHOST_ADDR && dmem_req_wstrb == 4'b1111) begin
                    tohost_seen = 1'b1;
                    tohost_value = dmem_req_wdata;
                    $display("RISCV TEST TOHOST: cycle=%0d value=%08x", cycle, dmem_req_wdata);
                end
            end

            if (cycle >= MAX_CYCLES && !tohost_seen)
                $fatal(1, "RISCV TEST FAIL: timeout after %0d cycles (stores=%0d)",
                       cycle, store_count);
        end
    end

    initial begin
        repeat (5) @(posedge clk);
        reset = 1'b0;
        wait (tohost_seen);
        repeat (3) @(posedge clk);

        if (tohost_value !== 32'd1)
            $fatal(1, "RISCV TEST FAIL: tohost=%08x expected 00000001", tohost_value);

        $display("RISCV TEST PASS: tohost=00000001 cycles=%0d stores=%0d",
                 cycle, store_count);
        $finish;
    end
endmodule
