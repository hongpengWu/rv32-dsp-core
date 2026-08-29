`timescale 1ns / 1ps

// Timing-safe PL-only PYNQ-Z2 demo.
//
// The board oscillator is 125 MHz.  The synchronous Core and both BRAM
// interfaces run from a real MMCM-generated 80 MHz clock, leaving timing
// margin for the intentionally conservative educational pipeline.  The
// original direct-125-MHz top remains available as a comparison baseline.
// BTN0 is an active-high board reset connected directly to the MMCM reset;
// the Core reset is then sampled and released synchronously after lock.
module rv32_pynq_z2_sync_mmcm_demo #(
    parameter integer IMEM_WORDS = 64,
    parameter integer DMEM_BYTES = 256,
    parameter string IMEM_INIT_FILE = "",
    parameter string DMEM_INIT_FILE = "",
    parameter real CORE_CLKOUT_DIVIDE_F = 12.5
) (
    input  logic       sys_clk,
    input  logic [3:0] btn,
    output logic [3:0] led
);
    localparam logic [31:0] RESET_PC  = 32'h8000_0000;
    localparam logic [31:0] DATA_BASE = 32'h8010_0000;
    localparam logic [31:0] DATA_END  = DATA_BASE + DMEM_BYTES;
    localparam logic [31:0] LED_ADDR  = 32'h8020_0040;

    wire mmcm_clk_unbuf;
    wire mmcm_fb_unbuf;
    wire mmcm_fb_unbuf_b;
    wire mmcm_clk_unbuf_b;
    wire mmcm_clk1_unbuf, mmcm_clk1_unbuf_b;
    wire mmcm_clk2_unbuf, mmcm_clk2_unbuf_b;
    wire mmcm_clk3_unbuf, mmcm_clk3_unbuf_b;
    wire mmcm_clk4_unbuf, mmcm_clk5_unbuf, mmcm_clk6_unbuf;
    wire mmcm_locked;
    wire cpu_clk;
    wire mmcm_fb;

    // 125 MHz * 8 / 12.5 = 80 MHz.  The 1000 MHz VCO is in the 7-series
    // MMCM legal range and the input period matches the PYNQ-Z2 oscillator.
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

    logic cpu_rst;
    logic [3:0] reset_sync = 4'hf;
    logic imem_req_valid;
    logic [31:0] imem_req_addr, imem_rsp_data;
    logic imem_rsp_valid;
    logic dmem_req_valid, dmem_req_write;
    logic [31:0] dmem_req_addr, dmem_req_wdata;
    logic [3:0] dmem_req_wstrb;
    logic dmem_rsp_valid;
    logic [31:0] dmem_rsp_rdata;
    logic dmem_ram_req_valid;

    // Sample the external reset and MMCM lock status in the generated clock
    // domain, then release reset after four clean clock edges.  Keeping this
    // synchronizer synchronous avoids propagating an asynchronous reset
    // attribute onto inferred BRAM control pins.
    always_ff @(posedge cpu_clk) begin
        if (btn[0] || !mmcm_locked)
            reset_sync <= 4'hf;
        else
            reset_sync <= {reset_sync[2:0], 1'b0};
    end
    assign cpu_rst = reset_sync[3];

    assign dmem_ram_req_valid = dmem_req_valid &&
                                 (dmem_req_addr >= DATA_BASE) &&
                                 (dmem_req_addr < DATA_END);

    myCPU_sync core (
        .cpu_clk(cpu_clk),
        .cpu_rst(cpu_rst),
        .imem_req_valid(imem_req_valid), .imem_req_addr(imem_req_addr),
        .imem_rsp_valid(imem_rsp_valid), .imem_rsp_data(imem_rsp_data),
        .dmem_req_valid(dmem_req_valid), .dmem_req_write(dmem_req_write),
        .dmem_req_addr(dmem_req_addr), .dmem_req_wstrb(dmem_req_wstrb),
        .dmem_req_wdata(dmem_req_wdata), .dmem_rsp_valid(dmem_rsp_valid),
        .dmem_rsp_rdata(dmem_rsp_rdata),
        .debug_wb_have_inst(), .debug_wb_pc(), .debug_wb_ena(),
        .debug_wb_reg(), .debug_wb_value()
    );

    rv32_sync_rom #(
        .DEPTH_WORDS(IMEM_WORDS), .BASE_ADDR(RESET_PC),
        .INIT_FILE(IMEM_INIT_FILE)
    ) imem (
        .clk(cpu_clk), .req_valid(imem_req_valid), .req_addr(imem_req_addr),
        .rsp_valid(imem_rsp_valid), .rsp_data(imem_rsp_data)
    );

    rv32_sync_byte_ram #(
        .DEPTH_BYTES(DMEM_BYTES), .BASE_ADDR(DATA_BASE),
        .INIT_FILE(DMEM_INIT_FILE)
    ) dmem (
        .clk(cpu_clk), .req_valid(dmem_ram_req_valid),
        .req_write(dmem_req_write), .req_addr(dmem_req_addr),
        .req_wstrb(dmem_req_wstrb), .req_wdata(dmem_req_wdata),
        .rsp_valid(dmem_rsp_valid), .rsp_rdata(dmem_rsp_rdata)
    );

    always_ff @(posedge cpu_clk) begin
        if (cpu_rst)
            led <= 4'b0000;
        else if (dmem_req_valid && dmem_req_write &&
                 dmem_req_addr == LED_ADDR && dmem_req_wstrb == 4'b1111)
            led <= dmem_req_wdata[3:0];
    end
endmodule
