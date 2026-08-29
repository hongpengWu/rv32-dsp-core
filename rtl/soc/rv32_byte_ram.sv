`timescale 1ns / 1ps

// Byte-addressable data memory for the legacy two-bit access-size port.
// Reads are combinational; writes are synchronous and support unaligned
// accesses within the configured byte range.
module rv32_byte_ram #(
    parameter integer DEPTH_BYTES = 256,
    parameter logic [31:0] BASE_ADDR = 32'h8010_0000,
    parameter string INIT_FILE = ""
) (
    input  logic        clk,
    input  logic [31:0] addr,
    input  logic        wen,
    input  logic [1:0]  mask,
    input  logic [31:0] wdata,
    output logic [31:0] rdata
);
    // The current Core exposes a combinational read port. Use distributed
    // RAM until the Core is migrated to a synchronous BRAM request/response
    // interface; this keeps Vivado from dissolving a large byte array into
    // an impractical number of flip-flops during synthesis.
    (* ram_style = "distributed" *) logic [7:0] mem [0:DEPTH_BYTES-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH_BYTES; i = i + 1)
            mem[i] = 8'h00;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    always_comb begin
        rdata = 32'h0000_0000;
        if ((addr >= BASE_ADDR) &&
            (addr + 32'd3 < BASE_ADDR + DEPTH_BYTES)) begin
            rdata = {mem[(addr - BASE_ADDR) + 3],
                     mem[(addr - BASE_ADDR) + 2],
                     mem[(addr - BASE_ADDR) + 1],
                     mem[(addr - BASE_ADDR) + 0]};
        end
    end

    always_ff @(posedge clk) begin
        if (wen && (addr >= BASE_ADDR) &&
            (addr < BASE_ADDR + DEPTH_BYTES)) begin
            case (mask)
                2'b00: begin
                    mem[addr - BASE_ADDR] <= wdata[7:0];
                end
                2'b01: begin
                    if (addr + 32'd1 < BASE_ADDR + DEPTH_BYTES) begin
                        mem[(addr - BASE_ADDR) + 0] <= wdata[7:0];
                        mem[(addr - BASE_ADDR) + 1] <= wdata[15:8];
                    end
                end
                2'b10: begin
                    if (addr + 32'd3 < BASE_ADDR + DEPTH_BYTES) begin
                        mem[(addr - BASE_ADDR) + 0] <= wdata[7:0];
                        mem[(addr - BASE_ADDR) + 1] <= wdata[15:8];
                        mem[(addr - BASE_ADDR) + 2] <= wdata[23:16];
                        mem[(addr - BASE_ADDR) + 3] <= wdata[31:24];
                    end
                end
                default: begin
                end
            endcase
        end
    end
endmodule
