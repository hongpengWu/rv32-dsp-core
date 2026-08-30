`timescale 1ns / 1ps

module tb_machine_timer;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic req_valid = 1'b0;
    logic req_write = 1'b0;
    logic [31:0] req_addr = 32'd0;
    logic [3:0] req_wstrb = 4'd0;
    logic [31:0] req_wdata = 32'd0;
    logic rsp_valid;
    logic [31:0] rsp_rdata;
    logic timer_irq;

    localparam logic [31:0] BASE = 32'h0200_0000;
    localparam logic [31:0] MTIME_LO = BASE + 32'h0000;
    localparam logic [31:0] MTIME_HI = BASE + 32'h0004;
    localparam logic [31:0] MTIMECMP_LO = BASE + 32'h4000;
    localparam logic [31:0] MTIMECMP_HI = BASE + 32'h4004;

    always #5 clk = ~clk;

    rv32_machine_timer #(.BASE_ADDR(BASE)) dut (
        .clk(clk), .reset(reset), .req_valid(req_valid), .req_write(req_write),
        .req_addr(req_addr), .req_wstrb(req_wstrb), .req_wdata(req_wdata),
        .rsp_valid(rsp_valid), .rsp_rdata(rsp_rdata), .timer_irq(timer_irq)
    );

    task automatic write_reg(input logic [31:0] addr, input logic [31:0] data);
        begin
            @(negedge clk);
            req_valid = 1'b1;
            req_write = 1'b1;
            req_addr = addr;
            req_wstrb = 4'b1111;
            req_wdata = data;
            @(negedge clk);
            req_valid = 1'b0;
            req_write = 1'b0;
            req_wstrb = 4'd0;
            req_wdata = 32'd0;
        end
    endtask

    task automatic read_reg(input logic [31:0] addr, output logic [31:0] data);
        begin
            @(negedge clk);
            req_valid = 1'b1;
            req_write = 1'b0;
            req_addr = addr;
            req_wstrb = 4'd0;
            @(negedge clk);
            req_valid = 1'b0;
            #1;
            if (!rsp_valid)
                $fatal(1, "TIMER FAIL: missing read response");
            data = rsp_rdata;
        end
    endtask

    logic [31:0] value;
    integer i;
    initial begin
        repeat (2) @(posedge clk);
        reset = 1'b0;

        // Program a near-term compare value and verify the level interrupt.
        write_reg(MTIMECMP_HI, 32'd0);
        write_reg(MTIMECMP_LO, 32'd6);
        i = 0;
        while (!timer_irq && i < 20) begin
            @(posedge clk);
            i = i + 1;
        end
        if (!timer_irq)
            $fatal(1, "TIMER FAIL: timer_irq did not assert");

        // Move the compare point forward and verify the interrupt deasserts.
        write_reg(MTIMECMP_LO, 32'hffff_ffff);
        if (timer_irq)
            $fatal(1, "TIMER FAIL: timer_irq did not clear after compare update");

        read_reg(MTIME_HI, value);
        if (value !== 32'd0)
            $fatal(1, "TIMER FAIL: unexpected mtime high word %08x", value);

        $display("TIMER PASS: mtime compare interrupt and MMIO read/write verified");
        $finish;
    end
endmodule
