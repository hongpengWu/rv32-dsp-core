`timescale 1ns / 1ps

module tb_pynq_sync_demo;
    logic sys_clk = 1'b0;
    logic [3:0] btn = 4'b0001;
    logic [3:0] led;
    integer i;

    always #5 sys_clk = ~sys_clk;

    rv32_pynq_z2_sync_demo dut (
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

    always @(posedge sys_clk) begin
        #1;
        if (!dut.cpu_rst && dut.imem_req_valid &&
            $isunknown(dut.imem_req_addr))
            $fatal(1, "SYNC PYNQ FAIL: X/Z on instruction request");
        if (!dut.cpu_rst && dut.dmem_req_valid &&
            $isunknown({dut.dmem_req_write, dut.dmem_req_addr,
                        dut.dmem_req_wstrb, dut.dmem_req_wdata})) begin
            $display("SYNC PYNQ X/Z: dreq=%b dw=%b daddr=%h st=%b wd=%h",
                     dut.dmem_req_valid, dut.dmem_req_write,
                     dut.dmem_req_addr, dut.dmem_req_wstrb,
                     dut.dmem_req_wdata);
            $fatal(1, "SYNC PYNQ FAIL: X/Z on active PL interface at %0t", $time);
        end
        if (!dut.cpu_rst && dut.imem_rsp_valid &&
            $isunknown(dut.imem_rsp_data))
            $fatal(1, "SYNC PYNQ FAIL: X/Z on instruction response");
        if (!dut.cpu_rst && dut.dmem_rsp_valid &&
            $isunknown(dut.dmem_rsp_rdata))
            $fatal(1, "SYNC PYNQ FAIL: X/Z on data response");
        if (!dut.cpu_rst && $isunknown(led))
            $fatal(1, "SYNC PYNQ FAIL: X/Z on LED output");
        if (!dut.cpu_rst && dut.dmem_req_valid &&
            dut.dmem_req_addr != 32'h8020_0040 &&
            (dut.dmem_req_addr < 32'h8010_0000 ||
             dut.dmem_req_addr >= 32'h8010_0100))
            $fatal(1, "SYNC PYNQ FAIL: data address escaped PL map %h",
                   dut.dmem_req_addr);
    end

    initial begin
        for (i = 0; i < 64; i = i + 1)
            dut.imem.mem[i] = 32'h0000_0013;
        dut.imem.mem[0] = enc_u(20'h80200, 5'd1, 7'b0110111); // LED base
        dut.imem.mem[1] = enc_i(5, 5'd0, 3'b000, 5'd2, 7'b0010011);
        dut.imem.mem[2] = enc_s(64, 5'd2, 5'd1, 3'b010);       // LED <= 5
        dut.imem.mem[3] = 32'h0000_006f;                       // loop

        repeat (5) @(posedge sys_clk);
        btn[0] = 1'b0;
        repeat (250) begin
            @(posedge sys_clk);
            if (led === 4'h5) begin
                $display("SYNC PYNQ PASS: LED=%x", led);
                $finish;
            end
        end
        $fatal(1, "SYNC PYNQ FAIL: LED did not reach 5");
    end
endmodule
