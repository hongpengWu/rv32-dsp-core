`timescale 1ns / 1ps

// Optional PL control shell for a future PS7/AXI-Lite connection.
//
// The shell is self-contained and does not instantiate PS7. A future AXI
// register block can drive ctrl_start/ctrl_reset and sample the status and
// counters without changing myCPU or the PL memory map.
module rv32_pl_controlled #(
    parameter integer IMEM_WORDS = 64,
    parameter integer DMEM_BYTES = 256,
    parameter logic [31:0] RESET_PC = 32'h8000_0000,
    parameter logic [31:0] DATA_BASE = 32'h8010_0000,
    parameter logic [31:0] LED_ADDR = 32'h8020_0040,
    parameter logic [31:0] DONE_ADDR = 32'h8020_0044,
    parameter string IMEM_INIT_FILE = "",
    parameter string DMEM_INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        ctrl_start,
    input  logic        ctrl_reset,
    output logic        status_running,
    output logic        status_done,
    output logic [31:0] cycle_count,
    output logic [31:0] retired_count,
    output logic [3:0]  led
);
    localparam logic [31:0] DATA_END = DATA_BASE + DMEM_BYTES;

    logic [31:0] irom_addr;
    logic [31:0] irom_data;
    logic [31:0] perip_addr;
    logic        perip_wen;
    logic [1:0]  perip_mask;
    logic [31:0] perip_wdata;
    logic [31:0] perip_rdata;
    logic [31:0] dmem_rdata;
    logic        run_latch;
    logic        debug_wb_have_inst;

    wire core_reset = reset | ctrl_reset | ~run_latch | status_done;
    wire active_write = perip_wen && (perip_mask == 2'b10);

    assign perip_rdata = ((perip_addr >= DATA_BASE) &&
                          (perip_addr < DATA_END)) ? dmem_rdata : 32'h0;
    assign status_running = run_latch && !status_done && !reset && !ctrl_reset;

    myCPU core (
        .cpu_clk            (clk),
        .cpu_rst            (core_reset),
        .irom_addr          (irom_addr),
        .irom_data          (irom_data),
        .perip_addr         (perip_addr),
        .perip_wen          (perip_wen),
        .perip_mask         (perip_mask),
        .perip_wdata        (perip_wdata),
        .perip_rdata        (perip_rdata),
        .debug_wb_have_inst (debug_wb_have_inst),
        .debug_wb_pc        (),
        .debug_wb_ena       (),
        .debug_wb_reg       (),
        .debug_wb_value     ()
    );

    rv32_async_rom #(
        .DEPTH_WORDS (IMEM_WORDS),
        .BASE_ADDR   (RESET_PC),
        .INIT_FILE   (IMEM_INIT_FILE)
    ) imem (
        .addr  (irom_addr),
        .rdata (irom_data)
    );

    rv32_byte_ram #(
        .DEPTH_BYTES (DMEM_BYTES),
        .BASE_ADDR   (DATA_BASE),
        .INIT_FILE   (DMEM_INIT_FILE)
    ) dmem (
        .clk   (clk),
        .addr  (perip_addr),
        .wen   (perip_wen && (perip_addr >= DATA_BASE) &&
                (perip_addr < DATA_END)),
        .mask  (perip_mask),
        .wdata (perip_wdata),
        .rdata (dmem_rdata)
    );

    always_ff @(posedge clk) begin
        if (reset || ctrl_reset) begin
            run_latch    <= 1'b0;
            status_done  <= 1'b0;
            cycle_count  <= 32'd0;
            retired_count <= 32'd0;
            led          <= 4'd0;
        end else begin
            if (ctrl_start)
                run_latch <= 1'b1;

            if (ctrl_start)
                status_done <= 1'b0;
            else if (active_write && perip_addr == DONE_ADDR)
                status_done <= 1'b1;

            if (status_running) begin
                cycle_count <= cycle_count + 32'd1;
                if (debug_wb_have_inst)
                    retired_count <= retired_count + 32'd1;
            end

            if (active_write && perip_addr == LED_ADDR)
                led <= perip_wdata[3:0];
        end
    end
endmodule
