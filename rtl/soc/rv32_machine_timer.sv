`timescale 1ns / 1ps

// Minimal machine timer for the single-hart Nano platform.
//
// The map intentionally follows the CLINT register layout for the two
// registers that software needs:
//   BASE + 0x0000 : mtime low  (read/write)
//   BASE + 0x0004 : mtime high (read/write)
//   BASE + 0x4000 : mtimecmp low  (read/write)
//   BASE + 0x4004 : mtimecmp high (read/write)
//
// mtime advances by one on every input clock.  timer_irq is a level signal and
// stays asserted while mtime >= mtimecmp, matching the machine timer contract.
module rv32_machine_timer #(
    parameter logic [31:0] BASE_ADDR = 32'h0200_0000
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        req_valid,
    input  logic        req_write,
    input  logic [31:0] req_addr,
    input  logic [3:0]  req_wstrb,
    input  logic [31:0] req_wdata,
    output logic        rsp_valid,
    output logic [31:0] rsp_rdata,
    output logic        timer_irq
);
    localparam logic [31:0] MTIME_LO_ADDR    = BASE_ADDR + 32'h0000;
    localparam logic [31:0] MTIME_HI_ADDR    = BASE_ADDR + 32'h0004;
    localparam logic [31:0] MTIMECMP_LO_ADDR = BASE_ADDR + 32'h4000;
    localparam logic [31:0] MTIMECMP_HI_ADDR = BASE_ADDR + 32'h4004;

    logic [63:0] mtime;
    logic [63:0] mtimecmp;
    logic        req_hit;
    logic [31:0] read_data;

    assign req_hit = req_valid &&
                     ((req_addr == MTIME_LO_ADDR) ||
                      (req_addr == MTIME_HI_ADDR) ||
                      (req_addr == MTIMECMP_LO_ADDR) ||
                      (req_addr == MTIMECMP_HI_ADDR));

    always_comb begin
        case (req_addr)
            MTIME_LO_ADDR:    read_data = mtime[31:0];
            MTIME_HI_ADDR:    read_data = mtime[63:32];
            MTIMECMP_LO_ADDR: read_data = mtimecmp[31:0];
            MTIMECMP_HI_ADDR: read_data = mtimecmp[63:32];
            default:          read_data = 32'd0;
        endcase
    end

    assign timer_irq = (mtime >= mtimecmp);

    always_ff @(posedge clk) begin
        if (reset) begin
            mtime     <= 64'd0;
            mtimecmp  <= 64'hffff_ffff_ffff_ffff;
            rsp_valid <= 1'b0;
            rsp_rdata <= 32'd0;
        end else begin
            rsp_valid <= req_hit && !req_write;
            rsp_rdata <= req_hit && !req_write ? read_data : 32'd0;

            // A full-word write is not required: byte strobes are honored so
            // software can use the same bus contract as normal data memory.
            if (req_hit && req_write && req_addr == MTIME_LO_ADDR) begin
                if (req_wstrb[0]) mtime[7:0]   <= req_wdata[7:0];
                if (req_wstrb[1]) mtime[15:8]  <= req_wdata[15:8];
                if (req_wstrb[2]) mtime[23:16] <= req_wdata[23:16];
                if (req_wstrb[3]) mtime[31:24] <= req_wdata[31:24];
            end else if (req_hit && req_write && req_addr == MTIME_HI_ADDR) begin
                if (req_wstrb[0]) mtime[39:32] <= req_wdata[7:0];
                if (req_wstrb[1]) mtime[47:40] <= req_wdata[15:8];
                if (req_wstrb[2]) mtime[55:48] <= req_wdata[23:16];
                if (req_wstrb[3]) mtime[63:56] <= req_wdata[31:24];
            end else begin
                mtime <= mtime + 64'd1;
            end

            if (req_hit && req_write && req_addr == MTIMECMP_LO_ADDR) begin
                if (req_wstrb[0]) mtimecmp[7:0]   <= req_wdata[7:0];
                if (req_wstrb[1]) mtimecmp[15:8]  <= req_wdata[15:8];
                if (req_wstrb[2]) mtimecmp[23:16] <= req_wdata[23:16];
                if (req_wstrb[3]) mtimecmp[31:24] <= req_wdata[31:24];
            end else if (req_hit && req_write && req_addr == MTIMECMP_HI_ADDR) begin
                if (req_wstrb[0]) mtimecmp[39:32] <= req_wdata[7:0];
                if (req_wstrb[1]) mtimecmp[47:40] <= req_wdata[15:8];
                if (req_wstrb[2]) mtimecmp[55:48] <= req_wdata[23:16];
                if (req_wstrb[3]) mtimecmp[63:56] <= req_wdata[31:24];
            end
        end
    end
endmodule
