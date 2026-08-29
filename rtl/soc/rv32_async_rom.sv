`timescale 1ns / 1ps

// Simple instruction memory matching the current core's zero-latency port.
// The INIT_FILE parameter is empty by default so simulation can load a program
// hierarchically; Vivado projects may override it with a .mem file.
module rv32_async_rom #(
    parameter integer DEPTH_WORDS = 4096,
    parameter logic [31:0] BASE_ADDR = 32'h8000_0000,
    parameter string INIT_FILE = ""
) (
    input  logic [31:0] addr,
    output logic [31:0] rdata
);
    localparam logic [31:0] NOP = 32'h0000_0013;
    logic [31:0] mem [0:DEPTH_WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH_WORDS; i = i + 1)
            mem[i] = NOP;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    always_comb begin
        rdata = NOP;
        if ((addr >= BASE_ADDR) &&
            (addr < BASE_ADDR + DEPTH_WORDS * 4))
            rdata = mem[(addr - BASE_ADDR) >> 2];
    end
endmodule
