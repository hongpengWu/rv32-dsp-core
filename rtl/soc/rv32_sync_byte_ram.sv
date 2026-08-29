`timescale 1ns / 1ps

// Synchronous 32-bit data RAM with four byte write strobes.
//
// Requests are sampled on a rising edge.  A read request returns rsp_valid
// and rsp_rdata in the following cycle.  Writes have no response.  The byte
// strobes are relative to the aligned 32-bit word selected by req_addr[31:2]
// (AXI/Wishbone-style semantics), which makes the interface suitable for a
// future Core adapter and a second PS/AXI port.
module rv32_sync_byte_ram #(
    parameter integer DEPTH_BYTES = 4096,
    parameter logic [31:0] BASE_ADDR = 32'h8010_0000,
    parameter string INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        req_valid,
    input  logic        req_write,
    input  logic [31:0] req_addr,
    input  logic [3:0]  req_wstrb,
    input  logic [31:0] req_wdata,
    output logic        rsp_valid,
    output logic [31:0] rsp_rdata
);
    localparam integer DEPTH_WORDS = (DEPTH_BYTES + 3) / 4;
    localparam logic [31:0] LAST_ADDR = BASE_ADDR + DEPTH_WORDS * 4;

    (* ram_style = "block" *) logic [31:0] mem [0:DEPTH_WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH_WORDS; i = i + 1)
            mem[i] = 32'h0000_0000;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    always_ff @(posedge clk) begin
        rsp_valid <= req_valid && !req_write &&
                     (req_addr >= BASE_ADDR) &&
                     (req_addr < LAST_ADDR) &&
                     (req_addr[1:0] == 2'b00);
        if (req_valid && !req_write &&
            (req_addr >= BASE_ADDR) &&
            (req_addr < LAST_ADDR) &&
            (req_addr[1:0] == 2'b00))
            rsp_rdata <= mem[(req_addr - BASE_ADDR) >> 2];
        else
            rsp_rdata <= 32'h0000_0000;

        if (req_valid && req_write &&
            (req_addr >= BASE_ADDR) &&
            (req_addr < LAST_ADDR) &&
            (req_addr[1:0] == 2'b00)) begin
            if (req_wstrb[0]) mem[(req_addr - BASE_ADDR) >> 2][7:0]   <= req_wdata[7:0];
            if (req_wstrb[1]) mem[(req_addr - BASE_ADDR) >> 2][15:8]  <= req_wdata[15:8];
            if (req_wstrb[2]) mem[(req_addr - BASE_ADDR) >> 2][23:16] <= req_wdata[23:16];
            if (req_wstrb[3]) mem[(req_addr - BASE_ADDR) >> 2][31:24] <= req_wdata[31:24];
        end
    end
endmodule
