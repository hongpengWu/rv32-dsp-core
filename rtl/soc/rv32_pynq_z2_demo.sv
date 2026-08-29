`timescale 1ns / 1ps

// Minimal standalone PYNQ-Z2 PL design. Button 0 is an active-high reset;
// the remaining buttons are reserved for later run-control integration.
module rv32_pynq_z2_demo #(
    parameter string IMEM_INIT_FILE = "",
    parameter string DMEM_INIT_FILE = ""
) (
    input  logic       sys_clk,
    input  logic [3:0] btn,
    output logic [3:0] led
);
    localparam logic [31:0] RESET_PC  = 32'h8000_0000;
    localparam logic [31:0] DATA_BASE = 32'h8010_0000;
    localparam logic [31:0] DATA_END  = 32'h8010_0100;
    localparam logic [31:0] LED_ADDR  = 32'h8020_0040;

    logic [31:0] irom_addr;
    logic [31:0] irom_data;
    logic [31:0] perip_addr;
    logic        perip_wen;
    logic [1:0]  perip_mask;
    logic [31:0] perip_wdata;
    logic [31:0] perip_rdata;
    logic [31:0] dmem_rdata;
    logic        cpu_rst;
    logic [3:0]  reset_sync = 4'hf;

    // Assert reset immediately and release it only on clock edges. The
    // initialized shift register also supplies a short power-on reset after
    // the FPGA is configured.
    always_ff @(posedge sys_clk or posedge btn[0]) begin
        if (btn[0])
            reset_sync <= 4'hf;
        else
            reset_sync <= {reset_sync[2:0], 1'b0};
    end

    assign cpu_rst = reset_sync[3];
    assign perip_rdata = ((perip_addr >= DATA_BASE) &&
                          (perip_addr < DATA_END)) ? dmem_rdata : 32'h0;

    myCPU core (
        .cpu_clk            (sys_clk),
        .cpu_rst            (cpu_rst),
        .irom_addr          (irom_addr),
        .irom_data          (irom_data),
        .perip_addr         (perip_addr),
        .perip_wen          (perip_wen),
        .perip_mask         (perip_mask),
        .perip_wdata        (perip_wdata),
        .perip_rdata        (perip_rdata),
        .debug_wb_have_inst (),
        .debug_wb_pc        (),
        .debug_wb_ena       (),
        .debug_wb_reg       (),
        .debug_wb_value     ()
    );

    rv32_async_rom #(
        .DEPTH_WORDS (64),
        .BASE_ADDR   (RESET_PC),
        .INIT_FILE   (IMEM_INIT_FILE)
    ) imem (
        .addr  (irom_addr),
        .rdata (irom_data)
    );

    rv32_byte_ram #(
        .DEPTH_BYTES (256),
        .BASE_ADDR   (DATA_BASE),
        .INIT_FILE   (DMEM_INIT_FILE)
    ) dmem (
        .clk   (sys_clk),
        .addr  (perip_addr),
        .wen   (perip_wen && (perip_addr >= DATA_BASE) &&
                (perip_addr < DATA_END)),
        .mask  (perip_mask),
        .wdata (perip_wdata),
        .rdata (dmem_rdata)
    );

    always_ff @(posedge sys_clk) begin
        if (cpu_rst)
            led <= 4'b0000;
        else if (perip_wen && (perip_addr == LED_ADDR))
            led <= perip_wdata[3:0];
    end
endmodule
