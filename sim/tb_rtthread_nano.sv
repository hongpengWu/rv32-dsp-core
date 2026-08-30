`timescale 1ns / 1ps

// Software-in-the-loop regression for the RT-Thread Nano BSP.  The testbench
// observes only the PL contract (UART writes, LED MMIO, and timer progress),
// so it remains valid without a PS or a physical PYNQ-Z2 board.
module tb_rtthread_nano #(
    parameter string IMEM_FILE = "program.mem",
    parameter integer MAX_CYCLES = 250000
);
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
    integer led_changes;
    logic [3:0] last_led;

    always #5 clk = ~clk;

    rv32_nano_soc #(
        .IMEM_WORDS(16384), .DMEM_BYTES(32768),
        .IMEM_INIT_FILE(IMEM_FILE), .UART_CLK_HZ(80_000_000),
        // A faster simulated baud keeps the regression short; the hardware
        // top-level defaults to the real 115200-baud setting.
        .UART_BAUD(1_000_000)
    ) dut (
        .clk(clk), .reset(reset), .led(led), .uart_tx(uart_tx),
        .uart_tx_busy(uart_tx_busy), .uart_tx_valid(uart_tx_valid),
        .uart_tx_data(uart_tx_data), .status_running(status_running),
        .cycle_count(cycle_count), .retired_count(retired_count),
        .debug_wb_have_inst(debug_wb_have_inst), .debug_wb_pc(debug_wb_pc)
    );

    always @(posedge clk) begin
        if (!reset && uart_tx_valid) begin
            uart_writes = uart_writes + 1;
            $write("%c", uart_tx_data);
        end
        if (!reset && led !== last_led) begin
            led_changes = led_changes + 1;
            last_led = led;
        end
        if (!reset && dut.dmem_req_valid &&
            $isunknown({dut.dmem_req_write, dut.dmem_req_addr,
                        dut.dmem_req_wstrb, dut.dmem_req_wdata})) begin
            $display("RF1=%h inst=%h rs2a=%h idurs2=%h exrs2reg=%h rs2reg=%h rs2in=%h exreg=%h exin=%h memwen=%b valid=%b exvalid=%b",
                     dut.core.IDU_Inst0.Reg_Stack_inst0.Reg_inst.rf[1],
                     dut.core.IDU_Inst0.inst, dut.core.IDU_Inst0.rs2,
                     dut.core.IDU_Inst0.rs2_value,
                     dut.core.EXU_Inst0.rs2_value_reg,
                     dut.core.LSU_Inst0.rs2_value_reg, dut.core.LSU_Inst0.rs2_value,
                     dut.core.LSU_Inst0.Ex_result_reg, dut.core.LSU_Inst0.Ex_result,
                     dut.core.LSU_Inst0.mem_wen, dut.core.LSU_Inst0.valid_last,
                     dut.core.EXU_Inst0.valid_next);
            $fatal(1, "NANO RTT FAIL: X/Z on data request write=%b addr=%h strb=%b data=%h pc=%h",
                   dut.dmem_req_write, dut.dmem_req_addr, dut.dmem_req_wstrb,
                   dut.dmem_req_wdata, dut.debug_wb_pc);
        end
    end

    initial begin
        uart_writes = 0;
        led_changes = 0;
        last_led = 4'd0;
        // Keep the RAM deterministic even when this test is run with a
        // simulator that does not initialize inferred block RAMs.
        for (i = 0; i < 8192; i = i + 1)
            dut.dmem.mem[i] = 32'd0;

        repeat (5) @(posedge clk);
        reset = 1'b0;
        repeat (MAX_CYCLES) @(posedge clk);

        if (uart_writes < 3)
            $fatal(1, "NANO RTT FAIL: too few UART writes (%0d) pc=%h mtime=%0d cmp=%0d mcause=%h mstatus=%h",
                   uart_writes, dut.debug_wb_pc, dut.timer.mtime, dut.timer.mtimecmp,
                   dut.core.IDU_Inst0.Reg_Stack_inst0.CSR_inst.mcause_out,
                   dut.core.IDU_Inst0.Reg_Stack_inst0.CSR_inst.mstatus_out);
        if (led_changes < 2 || led === 4'd0) begin
            $display("STATE pc=%h mtime=%0d cmp=%0d mcause=%h mstatus=%h mie=%h mepc=%h sp=%h",
                     dut.debug_wb_pc, dut.timer.mtime, dut.timer.mtimecmp,
                     dut.core.IDU_Inst0.Reg_Stack_inst0.CSR_inst.mcause_out,
                     dut.core.IDU_Inst0.Reg_Stack_inst0.CSR_inst.mstatus_out,
                     dut.core.IDU_Inst0.Reg_Stack_inst0.CSR_inst.mie_out,
                     dut.core.IDU_Inst0.Reg_Stack_inst0.CSR_inst.mepc_out,
                     dut.core.LSU_Inst0.rs2_value_reg);
            $fatal(1, "NANO RTT FAIL: scheduler/LED not active changes=%0d led=%h",
                   led_changes, led);
        end
        if (dut.timer.mtime == 0 || dut.retired_count < 100)
            $fatal(1, "NANO RTT FAIL: timer/core did not advance mtime=%0d retired=%0d",
                   dut.timer.mtime, dut.retired_count);

        $display("\nNANO RTT PASS: RT-Thread boot, UART, timer ticks and thread scheduling verified (writes=%0d led=%h retired=%0d)",
                 uart_writes, led, dut.retired_count);
        $finish;
    end
endmodule
