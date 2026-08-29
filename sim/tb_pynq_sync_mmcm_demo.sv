`timescale 1ns / 1ps

module tb_pynq_sync_mmcm_demo;
    logic sys_clk = 1'b0;
    logic [3:0] btn = 4'b0001;
    logic [3:0] led;
    integer i;

    always #4 sys_clk = ~sys_clk; // 125 MHz board oscillator

    rv32_pynq_z2_sync_mmcm_demo dut (
        .sys_clk(sys_clk), .btn(btn), .led(led)
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

    always @(posedge dut.cpu_clk) begin
        #1;
        if (!dut.cpu_rst && dut.imem_req_valid &&
            $isunknown(dut.imem_req_addr))
            $fatal(1, "MMCM PYNQ FAIL: X/Z on instruction request");
        if (!dut.cpu_rst && dut.dmem_req_valid &&
            $isunknown({dut.dmem_req_write, dut.dmem_req_addr,
                        dut.dmem_req_wstrb, dut.dmem_req_wdata}))
            $fatal(1, "MMCM PYNQ FAIL: X/Z on data request");
        if (!dut.cpu_rst && $isunknown(led))
            $fatal(1, "MMCM PYNQ FAIL: X/Z on LED output");
    end

    initial begin
        for (i = 0; i < 64; i = i + 1)
            dut.imem.mem[i] = 32'h0000_0013;
        dut.imem.mem[0] = enc_u(20'h80200, 5'd1, 7'b0110111); // LED base
        dut.imem.mem[1] = enc_i(5, 5'd0, 3'b000, 5'd2, 7'b0010011);
        dut.imem.mem[2] = enc_s(64, 5'd2, 5'd1, 3'b010);       // LED <= 5
        dut.imem.mem[3] = 32'h0000_006f;                       // loop

        // The MMCM model needs several input cycles to assert LOCKED, then
        // the reset synchronizer needs four generated-clock cycles.
        repeat (8) @(posedge sys_clk);
        btn[0] = 1'b0;
        i = 0;
        while (led !== 4'h5 && i < 500) begin
            @(posedge dut.cpu_clk);
            i = i + 1;
        end
        if (led !== 4'h5)
            $fatal(1, "MMCM PYNQ FAIL: LED did not reach 5 after cold reset");

        // Exercise BTN0 after the CPU is already running.  cpu_clk stops while
        // the MMCM is reset, so the board-clock reset capture must preserve the
        // request until the generated clock has restarted.
        btn[0] = 1'b1;
        repeat (8) @(posedge sys_clk);
        if (dut.mmcm_locked !== 1'b0)
            $fatal(1, "MMCM PYNQ FAIL: MMCM stayed locked during BTN0 reset");
        btn[0] = 1'b0;

        i = 0;
        while (dut.cpu_rst !== 1'b1 && i < 500) begin
            @(posedge dut.cpu_clk);
            #1;
            i = i + 1;
        end
        if (dut.cpu_rst !== 1'b1)
            $fatal(1, "MMCM PYNQ FAIL: runtime reset did not reach CPU domain");

        i = 0;
        while (led !== 4'h0 && i < 20) begin
            @(posedge dut.cpu_clk);
            #1;
            i = i + 1;
        end
        if (led !== 4'h0)
            $fatal(1, "MMCM PYNQ FAIL: runtime reset did not clear LED");

        i = 0;
        while (led !== 4'h5 && i < 500) begin
            @(posedge dut.cpu_clk);
            #1;
            i = i + 1;
        end
        if (led !== 4'h5)
            $fatal(1, "MMCM PYNQ FAIL: CPU did not restart after BTN0 reset");

        $display("MMCM PYNQ PASS: cold start and runtime reset, LOCKED=%b LED=%x",
                 dut.mmcm_locked, led);
        $finish;
    end
endmodule
