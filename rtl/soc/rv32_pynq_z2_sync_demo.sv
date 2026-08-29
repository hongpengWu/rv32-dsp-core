`timescale 1ns / 1ps

// PL-only PYNQ-Z2 demo using the synchronous-memory Core migration path.
// BTN0 is an active-high reset; LED writes are decoded locally and are not
// sent to the data BRAM.  No PS7 or AXI block is instantiated.
module rv32_pynq_z2_sync_demo #(
    parameter integer IMEM_WORDS = 64,
    parameter integer DMEM_BYTES = 256,
    parameter string IMEM_INIT_FILE = "",
    parameter string DMEM_INIT_FILE = ""
) (
    input  logic       sys_clk,
    input  logic [3:0] btn,
    output logic [3:0] led
);
    localparam logic [31:0] RESET_PC  = 32'h8000_0000;
    localparam logic [31:0] DATA_BASE = 32'h8010_0000;
    localparam logic [31:0] DATA_END  = DATA_BASE + DMEM_BYTES;
    localparam logic [31:0] LED_ADDR  = 32'h8020_0040;

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

    always_ff @(posedge sys_clk or posedge btn[0]) begin
        if (btn[0])
            reset_sync <= 4'hf;
        else
            reset_sync <= {reset_sync[2:0], 1'b0};
    end
    assign cpu_rst = reset_sync[3];

    // Only the data-memory window reaches BRAM.  LED writes are consumed by
    // the MMIO register below; reads from the peripheral window return zero.
    assign dmem_ram_req_valid = dmem_req_valid &&
                                 (dmem_req_addr >= DATA_BASE) &&
                                 (dmem_req_addr < DATA_END);

    myCPU_sync core (
        .cpu_clk(sys_clk),
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
        .clk(sys_clk), .req_valid(imem_req_valid), .req_addr(imem_req_addr),
        .rsp_valid(imem_rsp_valid), .rsp_data(imem_rsp_data)
    );

    rv32_sync_byte_ram #(
        .DEPTH_BYTES(DMEM_BYTES), .BASE_ADDR(DATA_BASE),
        .INIT_FILE(DMEM_INIT_FILE)
    ) dmem (
        .clk(sys_clk), .req_valid(dmem_ram_req_valid),
        .req_write(dmem_req_write), .req_addr(dmem_req_addr),
        .req_wstrb(dmem_req_wstrb), .req_wdata(dmem_req_wdata),
        .rsp_valid(dmem_rsp_valid), .rsp_rdata(dmem_rsp_rdata)
    );

    always_ff @(posedge sys_clk) begin
        if (cpu_rst)
            led <= 4'b0000;
        else if (dmem_req_valid && dmem_req_write &&
                 dmem_req_addr == LED_ADDR && dmem_req_wstrb == 4'b1111)
            led <= dmem_req_wdata[3:0];
    end
endmodule
