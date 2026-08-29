`timescale 1ns / 1ps

module tb_pynq_demo;
    logic       sys_clk = 1'b0;
    logic [3:0] btn = 4'b0001;
    logic [3:0] led;
    integer i;
    localparam logic [31:0] RESET_PC = 32'h8000_0000;
    localparam logic [31:0] DATA_BASE = 32'h8010_0000;
    localparam logic [31:0] DATA_END = 32'h8010_0100;
    localparam logic [31:0] LED_ADDR = 32'h8020_0040;

    always #5 sys_clk = ~sys_clk;

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

    function automatic [31:0] enc_j(input integer offset, input [4:0] rd);
        reg [20:0] imm;
        begin
            imm = offset;
            enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
        end
    endfunction

    rv32_pynq_z2_demo dut (
        .sys_clk (sys_clk),
        .btn     (btn),
        .led     (led)
    );

    // These checks turn common integration mistakes into deterministic test
    // failures instead of allowing an X/Z value to be hidden by === checks.
    always @(posedge sys_clk) begin
        #1;
        if (!$isunknown({dut.cpu_rst, dut.irom_addr, dut.irom_data,
                         dut.perip_addr, dut.perip_wen, dut.perip_rdata,
                         led})) begin
            if (dut.irom_addr < RESET_PC || dut.irom_addr >= RESET_PC + 256)
                $fatal(1, "instruction address escaped ROM: %h", dut.irom_addr);
            if (dut.perip_wen &&
                !((dut.perip_addr >= DATA_BASE && dut.perip_addr < DATA_END) ||
                  (dut.perip_addr == LED_ADDR)))
                $fatal(1, "write escaped PL address map: %h", dut.perip_addr);
            if (dut.perip_wen && dut.perip_addr == LED_ADDR &&
                (dut.perip_mask !== 2'b10 || $isunknown(dut.perip_wdata)))
                $fatal(1, "LED write was not a full-word store");
            if (dut.perip_wen && dut.perip_addr != LED_ADDR &&
                $isunknown({dut.perip_mask, dut.perip_wdata}))
                $fatal(1, "X/Z detected on an active data write");
            if (btn[0] && !dut.cpu_rst)
                $fatal(1, "reset synchronizer released while BTN0 is pressed");
        end else if ($time > 0) begin
            $display("X/Z PL signals at %0t: rst=%b iaddr=%h idata=%h paddr=%h wen=%b mask=%b wdata=%h rdata=%h led=%h",
                     $time, dut.cpu_rst, dut.irom_addr, dut.irom_data,
                     dut.perip_addr, dut.perip_wen, dut.perip_mask,
                     dut.perip_wdata, dut.perip_rdata, led);
            $fatal(1, "X/Z detected on PL integration signals at %0t", $time);
        end
    end

    initial begin
        for (i = 0; i < 64; i = i + 1)
            dut.imem.mem[i] = 32'h0000_0013;

        dut.imem.mem[0] = enc_u(20'h80200, 5'd1, 7'b0110111); // x1=LED base
        dut.imem.mem[1] = enc_i(12'h0a5, 5'd0, 3'b000, 5'd2, 7'b0010011);
        dut.imem.mem[2] = enc_s(64, 5'd2, 5'd1, 3'b010);     // LED <= 0xa5
        dut.imem.mem[3] = enc_j(0, 5'd0);

        repeat (5) @(posedge sys_clk);
        btn[0] = 1'b0;

        repeat (3) @(posedge sys_clk);
        if (!dut.cpu_rst)
            $fatal(1, "reset released too early");
        @(posedge sys_clk);
        if (dut.cpu_rst)
            $fatal(1, "reset synchronizer did not release after four clocks");

        for (i = 0; i < 100; i = i + 1) begin
            @(posedge sys_clk);
            if (led === 4'h5) begin
                $display("PYNQ DEMO PASS: LED=%x cycle=%0d", led, i);
                $finish;
            end
        end

        $fatal(1, "PYNQ DEMO FAIL: LED=%x", led);
    end
endmodule
