`timescale 1ns / 1ps

// Standalone RT-Thread Nano top level for the PYNQ-Z2 PL.
//
// The board provides a 125 MHz PL reference clock on H16.  A real 7-series
// MMCM derives the 80 MHz clock used by the synchronous Core, BRAMs, timer,
// and UART.  BTN0 is an active-high reset.  The design deliberately contains
// no PS7, AXI, DDR, or Linux dependency.
//
// UART TX is exported to Raspberry-Pi header pin 37 (PL pin W9).  The
// on-board FT2232 USB-UART is wired to PS MIO14/15, so it cannot be driven by
// this PS-free top; use a 3.3 V USB-TTL adapter on W9 and a board GND pin.
module rv32_pynq_z2_nano #(
    parameter integer IMEM_WORDS = 16384,
    parameter integer DMEM_BYTES = 32768,
    parameter string IMEM_INIT_FILE = "",
    parameter string DMEM_INIT_FILE = "",
    parameter real CORE_CLKOUT_DIVIDE_F = 12.5,
    parameter integer UART_CLK_HZ = 80_000_000,
    parameter integer UART_BAUD = 115_200
) (
    input  logic       sys_clk,
    input  logic [3:0] btn,
    output logic [3:0] led,
    output logic       uart_tx
);
    wire mmcm_clk_unbuf;
    wire mmcm_fb_unbuf;
    wire mmcm_clk_unbuf_b;
    wire mmcm_fb_unbuf_b;
    wire mmcm_clk1_unbuf, mmcm_clk1_unbuf_b;
    wire mmcm_clk2_unbuf, mmcm_clk2_unbuf_b;
    wire mmcm_clk3_unbuf, mmcm_clk3_unbuf_b;
    wire mmcm_clk4_unbuf, mmcm_clk5_unbuf, mmcm_clk6_unbuf;
    wire mmcm_locked;
    wire cpu_clk;
    wire mmcm_fb;

    // 125 MHz * 8 / 12.5 = 80 MHz.  The 1000 MHz VCO is legal for the
    // XC7Z020-1CLG400C and leaves useful timing margin for this Core.
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(8.0),
        .CLKIN1_PERIOD(8.0),
        .DIVCLK_DIVIDE(1),
        .CLKOUT0_DIVIDE_F(CORE_CLKOUT_DIVIDE_F),
        .STARTUP_WAIT("FALSE")
    ) mmcm_i (
        .CLKIN1(sys_clk),
        .CLKFBIN(mmcm_fb),
        .RST(btn[0]),
        .PWRDWN(1'b0),
        .CLKFBOUT(mmcm_fb_unbuf),
        .CLKFBOUTB(mmcm_fb_unbuf_b),
        .CLKOUT0(mmcm_clk_unbuf),
        .CLKOUT0B(mmcm_clk_unbuf_b),
        .CLKOUT1(mmcm_clk1_unbuf),
        .CLKOUT1B(mmcm_clk1_unbuf_b),
        .CLKOUT2(mmcm_clk2_unbuf),
        .CLKOUT2B(mmcm_clk2_unbuf_b),
        .CLKOUT3(mmcm_clk3_unbuf),
        .CLKOUT3B(mmcm_clk3_unbuf_b),
        .CLKOUT4(mmcm_clk4_unbuf),
        .CLKOUT5(mmcm_clk5_unbuf),
        .CLKOUT6(mmcm_clk6_unbuf),
        .LOCKED(mmcm_locked)
    );

    BUFG mmcm_fb_buf_i (.I(mmcm_fb_unbuf), .O(mmcm_fb));
    BUFG cpu_clk_buf_i  (.I(mmcm_clk_unbuf), .O(cpu_clk));

    logic       cpu_rst;
    logic [3:0] reset_sys_sync = 4'hf;
    (* ASYNC_REG = "TRUE" *) logic [1:0] reset_cpu_sync = 2'b11;
    logic reset_request;

    // Capture reset in the always-running board-clock domain.  This matters
    // during a runtime BTN0 press because the MMCM-generated CPU clock stops
    // while the primitive is held in reset.
    always_ff @(posedge sys_clk) begin
        if (btn[0] || !mmcm_locked)
            reset_sys_sync <= 4'hf;
        else
            reset_sys_sync <= {reset_sys_sync[2:0], 1'b0};
    end
    assign reset_request = reset_sys_sync[3];

    // Synchronize the reset level into the generated-clock domain.  Assertion
    // is held until the MMCM has been locked for several board-clock cycles.
    always_ff @(posedge cpu_clk) begin
        reset_cpu_sync <= {reset_cpu_sync[0], reset_request};
    end
    assign cpu_rst = reset_cpu_sync[1];

    logic       status_running;
    logic [31:0] cycle_count;
    logic [31:0] retired_count;
    logic       debug_wb_have_inst;
    logic [31:0] debug_wb_pc;
    logic       uart_tx_busy;
    logic       uart_tx_valid;
    logic [7:0] uart_tx_data;

    rv32_nano_soc #(
        .IMEM_WORDS(IMEM_WORDS),
        .DMEM_BYTES(DMEM_BYTES),
        .IMEM_INIT_FILE(IMEM_INIT_FILE),
        .DMEM_INIT_FILE(DMEM_INIT_FILE),
        .UART_CLK_HZ(UART_CLK_HZ),
        .UART_BAUD(UART_BAUD)
    ) nano_soc_i (
        .clk(cpu_clk),
        .reset(cpu_rst),
        .led(led),
        .uart_tx(uart_tx),
        .uart_tx_busy(uart_tx_busy),
        .uart_tx_valid(uart_tx_valid),
        .uart_tx_data(uart_tx_data),
        .status_running(status_running),
        .cycle_count(cycle_count),
        .retired_count(retired_count),
        .debug_wb_have_inst(debug_wb_have_inst),
        .debug_wb_pc(debug_wb_pc)
    );
endmodule
