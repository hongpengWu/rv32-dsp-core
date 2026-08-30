`timescale 1ns / 1ps

module tb_sync_mem;
    localparam logic [31:0] ROM_BASE = 32'h8000_0000;
    localparam logic [31:0] RAM_BASE = 32'h8010_0000;

    logic        clk = 1'b0;
    logic        rom_req_valid = 1'b0;
    logic [31:0] rom_req_addr = 32'd0;
    logic        rom_rsp_valid;
    logic [31:0] rom_rsp_data;

    logic        ram_req_valid = 1'b0;
    logic        ram_req_write = 1'b0;
    logic [31:0] ram_req_addr = 32'd0;
    logic [3:0]  ram_req_wstrb = 4'd0;
    logic [31:0] ram_req_wdata = 32'd0;
    logic        ram_rsp_valid;
    logic [31:0] ram_rsp_rdata;

    always #5 clk = ~clk;

    rv32_sync_rom #(.DEPTH_WORDS(4), .BASE_ADDR(ROM_BASE)) rom (
        .clk       (clk),
        .req_valid (rom_req_valid),
        .req_addr  (rom_req_addr),
        .rsp_valid (rom_rsp_valid),
        .rsp_data  (rom_rsp_data),
        .data_req_valid(1'b0), .data_req_addr(32'd0),
        .data_rsp_valid(), .data_rsp_data()
    );

    rv32_sync_byte_ram #(.DEPTH_BYTES(16), .BASE_ADDR(RAM_BASE)) ram (
        .clk        (clk),
        .req_valid  (ram_req_valid),
        .req_write  (ram_req_write),
        .req_addr   (ram_req_addr),
        .req_wstrb  (ram_req_wstrb),
        .req_wdata  (ram_req_wdata),
        .rsp_valid  (ram_rsp_valid),
        .rsp_rdata  (ram_rsp_rdata)
    );

    initial begin
        rom.mem[0] = 32'h1122_3344;
        rom.mem[1] = 32'h5566_7788;

        // ROM response is exactly one cycle after a valid aligned request.
        @(negedge clk);
        rom_req_addr = ROM_BASE + 32'd4;
        rom_req_valid = 1'b1;
        @(posedge clk); #1;
        if (rom_rsp_valid !== 1'b1 || rom_rsp_data !== 32'h5566_7788)
            $fatal(1, "SYNC MEM FAIL: ROM response latency/data");
        @(negedge clk);
        rom_req_valid = 1'b0;
        rom_req_addr = ROM_BASE + 32'd2;
        @(posedge clk); #1;
        if (rom_rsp_valid !== 1'b0)
            $fatal(1, "SYNC MEM FAIL: misaligned ROM request responded");

        // Full-word write followed by a registered read.
        @(negedge clk);
        ram_req_valid = 1'b1;
        ram_req_write = 1'b1;
        ram_req_addr = RAM_BASE;
        ram_req_wstrb = 4'b1111;
        ram_req_wdata = 32'hdead_beef;
        @(posedge clk); #1;
        if (ram_rsp_valid !== 1'b0)
            $fatal(1, "SYNC MEM FAIL: write produced a read response");

        @(negedge clk);
        ram_req_valid = 1'b1;
        ram_req_write = 1'b0;
        ram_req_addr = RAM_BASE;
        ram_req_wstrb = 4'b0000;
        @(posedge clk); #1;
        if (ram_rsp_valid !== 1'b1 || ram_rsp_rdata !== 32'hdead_beef)
            $fatal(1, "SYNC MEM FAIL: RAM readback %h", ram_rsp_rdata);

        // Partial byte write preserves the other lanes.
        @(negedge clk);
        ram_req_valid = 1'b1;
        ram_req_write = 1'b1;
        ram_req_addr = RAM_BASE;
        ram_req_wstrb = 4'b0100;
        ram_req_wdata = 32'h00aa_0000;
        @(posedge clk); #1;

        @(negedge clk);
        ram_req_valid = 1'b1;
        ram_req_write = 1'b0;
        ram_req_wstrb = 4'b0000;
        @(posedge clk); #1;
        if (ram_rsp_valid !== 1'b1 || ram_rsp_rdata !== 32'hdeaa_beef)
            $fatal(1, "SYNC MEM FAIL: byte strobe readback %h", ram_rsp_rdata);

        // Out-of-range requests must not create a response.
        @(negedge clk);
        ram_req_addr = RAM_BASE + 32'd64;
        @(posedge clk); #1;
        if (ram_rsp_valid !== 1'b0)
            $fatal(1, "SYNC MEM FAIL: out-of-range request responded");

        $display("SYNC MEM PASS: registered ROM/RAM latency and byte strobes verified");
        $finish;
    end
endmodule
