`timescale 1ns / 1ps

// PL-only verification of the real PYNQ-Z2 Nano top.  The test exercises the
// 125 MHz input, MMCM lock/reset sequence, the 80 MHz generated clock, a UART
// write, an LED MMIO write, and a runtime BTN0 reset/restart.  The full
// RT-Thread image is tested separately by tb_rtthread_nano.
module tb_pynq_z2_nano;
    logic sys_clk = 1'b0;
    logic [3:0] btn = 4'b0001;
    logic [3:0] led;
    logic uart_tx;
    integer i;
    integer uart_writes;
    logic [7:0] last_uart_byte;

    always #4 sys_clk = ~sys_clk; // 125 MHz board oscillator

    rv32_pynq_z2_nano #(
        .IMEM_WORDS(64), .DMEM_BYTES(256), .UART_BAUD(1_000_000)
    ) dut (
        .sys_clk(sys_clk), .btn(btn), .led(led), .uart_tx(uart_tx)
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
        if (!dut.cpu_rst && dut.nano_soc_i.uart_tx_valid) begin
            uart_writes = uart_writes + 1;
            last_uart_byte = dut.nano_soc_i.uart_tx_data;
        end
        if (!dut.cpu_rst && $isunknown({dut.nano_soc_i.imem_req_valid,
                                        dut.nano_soc_i.imem_req_addr,
                                        dut.nano_soc_i.dmem_req_valid,
                                        dut.nano_soc_i.dmem_req_write,
                                        dut.nano_soc_i.dmem_req_addr,
                                        dut.nano_soc_i.dmem_req_wstrb,
                                        dut.nano_soc_i.dmem_req_wdata,
                                        led, uart_tx}))
            $fatal(1, "PYNQ NANO FAIL: X/Z on active PL interface");
    end

    initial begin
        uart_writes = 0;
        last_uart_byte = 8'h00;

        for (i = 0; i < 64; i = i + 1)
            dut.nano_soc_i.imem.mem[i] = 32'h0000_0013;

        // x1 = LED base; LED <= 5
        dut.nano_soc_i.imem.mem[0] = enc_u(20'h80200, 5'd1, 7'b0110111);
        dut.nano_soc_i.imem.mem[1] = enc_i(5, 5'd0, 3'b000, 5'd2, 7'b0010011);
        dut.nano_soc_i.imem.mem[2] = enc_s(64, 5'd2, 5'd1, 3'b010);
        // x3 = UART base; UART <= 'N'
        dut.nano_soc_i.imem.mem[3] = enc_u(20'h10000, 5'd3, 7'b0110111);
        dut.nano_soc_i.imem.mem[4] = enc_i(8'h4e, 5'd0, 3'b000, 5'd4, 7'b0010011);
        dut.nano_soc_i.imem.mem[5] = enc_s(0, 5'd4, 5'd3, 3'b010);
        dut.nano_soc_i.imem.mem[6] = 32'h0000_006f; // loop

        repeat (8) @(posedge sys_clk);
        btn[0] = 1'b0;

        i = 0;
        while ((led !== 4'h5 || uart_writes < 1) && i < 1000) begin
            @(posedge dut.cpu_clk);
            i = i + 1;
        end
        if (dut.mmcm_locked !== 1'b1)
            $fatal(1, "PYNQ NANO FAIL: MMCM did not lock");
        if (led !== 4'h5 || uart_writes < 1 || last_uart_byte !== "N")
            $fatal(1, "PYNQ NANO FAIL: first run LED=%h UART writes=%0d byte=%h",
                   led, uart_writes, last_uart_byte);

        // BTN0 must reset the CPU even though the generated clock is stopped.
        btn[0] = 1'b1;
        repeat (8) @(posedge sys_clk);
        if (dut.mmcm_locked !== 1'b0)
            $fatal(1, "PYNQ NANO FAIL: MMCM stayed locked during reset");
        btn[0] = 1'b0;

        i = 0;
        while (dut.cpu_rst !== 1'b1 && i < 1000) begin
            @(posedge dut.cpu_clk);
            i = i + 1;
        end
        if (dut.cpu_rst !== 1'b1)
            $fatal(1, "PYNQ NANO FAIL: CPU reset was not observed");

        i = 0;
        while (led !== 4'h0 && i < 20) begin
            @(posedge dut.cpu_clk);
            i = i + 1;
        end
        if (led !== 4'h0)
            $fatal(1, "PYNQ NANO FAIL: LED did not clear on reset");

        i = 0;
        while (led !== 4'h5 && i < 1000) begin
            @(posedge dut.cpu_clk);
            i = i + 1;
        end
        if (led !== 4'h5)
            $fatal(1, "PYNQ NANO FAIL: CPU did not restart after reset");

        $display("PYNQ NANO PASS: MMCM, reset, UART TX and LED verified");
        $finish;
    end
endmodule
