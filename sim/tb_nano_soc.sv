`timescale 1ns / 1ps

// PL-only Nano platform contract test.  This is deliberately independent of
// the RT-Thread C sources: it proves the hardware ABI that the Nano port will
// use (synchronous memory, polling UART, LED MMIO, and machine timer IRQ).
module tb_nano_soc;
    localparam logic [31:0] RESET_PC  = 32'h8000_0000;
    localparam logic [31:0] DATA_BASE = 32'h8010_0000;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [3:0] led;
    logic uart_tx;
    logic uart_tx_busy;
    logic uart_tx_valid;
    logic [7:0] uart_tx_data;
    logic status_running;
    logic [31:0] cycle_count;
    logic [31:0] retired_count;
    logic debug_wb_have_inst;
    logic [31:0] debug_wb_pc;
    integer i;
    integer uart_writes;
    logic [7:0] last_uart_byte;

    always #5 clk = ~clk;

    rv32_nano_soc #(
        .IMEM_WORDS(512), .DMEM_BYTES(256), .RESET_PC(RESET_PC),
        .DATA_BASE(DATA_BASE), .UART_CLK_HZ(80_000_000), .UART_BAUD(115_200)
    ) dut (
        .clk(clk), .reset(reset), .led(led), .uart_tx(uart_tx),
        .uart_tx_busy(uart_tx_busy), .uart_tx_valid(uart_tx_valid),
        .uart_tx_data(uart_tx_data), .status_running(status_running),
        .cycle_count(cycle_count), .retired_count(retired_count),
        .debug_wb_have_inst(debug_wb_have_inst), .debug_wb_pc(debug_wb_pc)
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
        if (!reset && uart_tx_valid) begin
            uart_writes = uart_writes + 1;
            last_uart_byte = uart_tx_data;
        end
        if (!reset && dut.dmem_req_valid &&
            $isunknown({dut.dmem_req_write, dut.dmem_req_addr,
                        dut.dmem_req_wstrb, dut.dmem_req_wdata}))
            $fatal(1, "NANO FAIL: X/Z on data request");
    end

    initial begin
        uart_writes = 0;
        last_uart_byte = 8'd0;
        for (i = 0; i < 512; i = i + 1)
            dut.imem.mem[i] = 32'h0000_0013;

        // Main program: emit one UART byte, set LED=0xa, enable MTIP, and
        // program a near-future timer compare value.
        dut.imem.mem[0]  = enc_u(20'h10000, 5'd2, 7'b0110111); // UART_BASE
        dut.imem.mem[1]  = enc_i(78, 5'd0, 3'b000, 5'd4, 7'b0010011); // 'N'
        dut.imem.mem[2]  = enc_s(0, 5'd4, 5'd2, 3'b010); // UART TXDATA
        dut.imem.mem[3]  = enc_u(20'h80200, 5'd3, 7'b0110111); // LED upper
        dut.imem.mem[4]  = enc_i(64, 5'd3, 3'b000, 5'd3, 7'b0010011);
        dut.imem.mem[5]  = enc_i(10, 5'd0, 3'b000, 5'd4, 7'b0010011);
        dut.imem.mem[6]  = enc_s(0, 5'd4, 5'd3, 3'b010); // LED write
        dut.imem.mem[7]  = enc_u(20'h80000, 5'd1, 7'b0110111);
        dut.imem.mem[8]  = enc_i(256, 5'd1, 3'b000, 5'd1, 7'b0010011);
        dut.imem.mem[9]  = enc_csr(12'h305, 5'd1, 3'b001, 5'd0); // mtvec
        dut.imem.mem[10] = enc_i(8, 5'd0, 3'b000, 5'd4, 7'b0010011);
        dut.imem.mem[11] = enc_csr(12'h300, 5'd4, 3'b010, 5'd0); // mstatus.MIE
        dut.imem.mem[12] = enc_i(128, 5'd0, 3'b000, 5'd5, 7'b0010011);
        dut.imem.mem[13] = enc_csr(12'h304, 5'd5, 3'b010, 5'd0); // mie.MTIE
        dut.imem.mem[14] = enc_u(20'h02004, 5'd6, 7'b0110111); // mtimecmp
        dut.imem.mem[15] = enc_i(200, 5'd0, 3'b000, 5'd7, 7'b0010011);
        dut.imem.mem[16] = enc_s(4, 5'd0, 5'd6, 3'b010); // mtimecmp high=0
        dut.imem.mem[17] = enc_s(0, 5'd7, 5'd6, 3'b010); // mtimecmp low
        dut.imem.mem[18] = 32'h0000_006f; // spin

        // Handler at 0x80000100: record marker and mcause, then MRET.
        dut.imem.mem[64] = enc_i(85, 5'd0, 3'b000, 5'd4, 7'b0010011);
        dut.imem.mem[65] = enc_u(20'h80100, 5'd10, 7'b0110111);
        dut.imem.mem[66] = enc_s(0, 5'd4, 5'd10, 3'b010);
        dut.imem.mem[67] = enc_csr(12'h342, 5'd0, 3'b010, 5'd6);
        dut.imem.mem[68] = enc_s(4, 5'd6, 5'd10, 3'b010);
        dut.imem.mem[69] = 32'h3020_0073; // mret
        dut.imem.mem[70] = 32'h0000_006f;

        repeat (3) @(posedge clk);
        reset = 1'b0;
        repeat (900) @(posedge clk);

        if (led !== 4'ha)
            $fatal(1, "NANO FAIL: LED=%h expected=a", led);
        if (uart_writes != 1 || last_uart_byte !== "N")
            $fatal(1, "NANO FAIL: UART writes=%0d byte=%h", uart_writes, last_uart_byte);
        if (dut.dmem.mem[0] !== 32'h0000_0055)
            $fatal(1, "NANO FAIL: handler marker=%h", dut.dmem.mem[0]);
        if (dut.dmem.mem[1] !== 32'h8000_0007)
            $fatal(1, "NANO FAIL: mcause=%h", dut.dmem.mem[1]);
        if (retired_count == 0 || cycle_count == 0)
            $fatal(1, "NANO FAIL: debug counters did not advance");

        $display("NANO PASS: PL shell, UART, LED, timer IRQ/MRET and debug counters verified");
        $finish;
    end
endmodule
