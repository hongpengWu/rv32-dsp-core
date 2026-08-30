`timescale 1ns / 1ps

// One-cycle-latency instruction ROM interface.
//
// A request is sampled on a rising edge.  The corresponding response is
// presented with rsp_valid asserted during the following cycle.  Keeping the
// latency explicit lets the Core fetch from a synchronous BRAM instead of
// relying on a zero-latency distributed-ROM read.
module rv32_sync_rom #(
    parameter integer DEPTH_WORDS = 4096,
    parameter logic [31:0] BASE_ADDR = 32'h8000_0000,
    parameter string INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        req_valid,
    input  logic [31:0] req_addr,
    output logic        rsp_valid,
    output logic [31:0] rsp_data,
    // Optional second read port for Harvard systems that execute from ROM
    // but still need to read .rodata/.data initializers over the data bus.
    // Existing single-port instantiations may leave these ports unconnected;
    // the strict 1'b1 check below keeps that case inactive.
    input  logic        data_req_valid,
    input  logic [31:0] data_req_addr,
    output logic        data_rsp_valid,
    output logic [31:0] data_rsp_data
);
    localparam logic [31:0] NOP = 32'h0000_0013;
    localparam logic [31:0] LAST_ADDR = BASE_ADDR + DEPTH_WORDS * 4;

    // The synchronous read style is intentional: Vivado can map this array
    // to RAMB18/RAMB36 when the depth is increased for the real design.
    (* ram_style = "block" *) logic [31:0] mem [0:DEPTH_WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH_WORDS; i = i + 1)
            mem[i] = NOP;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    always_ff @(posedge clk) begin
        rsp_valid <= req_valid &&
                     (req_addr >= BASE_ADDR) &&
                     (req_addr < LAST_ADDR) &&
                     (req_addr[1:0] == 2'b00);
        if (req_valid &&
            (req_addr >= BASE_ADDR) &&
            (req_addr < LAST_ADDR) &&
            (req_addr[1:0] == 2'b00))
            rsp_data <= mem[(req_addr - BASE_ADDR) >> 2];
        else
            rsp_data <= NOP;

        data_rsp_valid <= (data_req_valid === 1'b1) &&
                          (data_req_addr >= BASE_ADDR) &&
                          (data_req_addr < LAST_ADDR) &&
                          (data_req_addr[1:0] == 2'b00);
        if ((data_req_valid === 1'b1) &&
            (data_req_addr >= BASE_ADDR) &&
            (data_req_addr < LAST_ADDR) &&
            (data_req_addr[1:0] == 2'b00))
            data_rsp_data <= mem[(data_req_addr - BASE_ADDR) >> 2];
        else
            data_rsp_data <= NOP;
    end
endmodule
