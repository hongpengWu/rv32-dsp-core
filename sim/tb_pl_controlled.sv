`timescale 1ns / 1ps

module tb_pl_controlled;
    logic        clk = 1'b0;
    logic        reset = 1'b1;
    logic        ctrl_start = 1'b0;
    logic        ctrl_reset = 1'b0;
    logic        status_running;
    logic        status_done;
    logic [31:0] cycle_count;
    logic [31:0] retired_count;
    logic [3:0]  led;
    integer i;

    always #5 clk = ~clk;

    function automatic [31:0] enc_i(
        input integer imm, input [4:0] rs1, input [2:0] funct3,
        input [4:0] rd, input [6:0] opcode);
        enc_i = {imm[11:0], rs1, funct3, rd, opcode};
    endfunction

    function automatic [31:0] enc_u(
        input [19:0] imm20, input [4:0] rd, input [6:0] opcode);
        enc_u = {imm20, rd, opcode};
    endfunction

    function automatic [31:0] enc_s(
        input integer imm, input [4:0] rs2, input [4:0] rs1,
        input [2:0] funct3);
        enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
    endfunction

    rv32_pl_controlled dut (
        .clk            (clk),
        .reset          (reset),
        .ctrl_start     (ctrl_start),
        .ctrl_reset     (ctrl_reset),
        .status_running (status_running),
        .status_done    (status_done),
        .cycle_count    (cycle_count),
        .retired_count  (retired_count),
        .led            (led)
    );

    // The optional control shell is itself a PL block, so it gets the same
    // unknown-state and status consistency checks as the board demo.
    always @(posedge clk) begin
        #1;
        if ($isunknown({status_running, status_done, cycle_count,
                        retired_count, led, dut.core_reset,
                        dut.perip_addr, dut.perip_wen}))
            $fatal(1, "X/Z detected in controlled PL shell at %0t", $time);
        if (dut.perip_wen &&
            $isunknown({dut.perip_mask, dut.perip_wdata}))
            $fatal(1, "X/Z detected on active controlled-shell write");
        if (status_done && status_running)
            $fatal(1, "controlled shell reports running and done together");
    end

    initial begin
        for (i = 0; i < 64; i = i + 1)
            dut.imem.mem[i] = 32'h0000_0013;

        dut.imem.mem[0] = enc_u(20'h80200, 5'd1, 7'b0110111); // x1=MMIO base
        dut.imem.mem[1] = enc_i(12'h0a5, 5'd0, 3'b000, 5'd2, 7'b0010011);
        dut.imem.mem[2] = enc_s(64, 5'd2, 5'd1, 3'b010);     // LED <= 0xa5
        dut.imem.mem[3] = enc_i(12'h001, 5'd0, 3'b000, 5'd2, 7'b0010011);
        dut.imem.mem[4] = enc_s(68, 5'd2, 5'd1, 3'b010);     // DONE <= 1
        dut.imem.mem[5] = 32'h0000_006f;                     // loop

        repeat (3) @(posedge clk);
        reset = 1'b0;
        repeat (2) @(posedge clk);
        if (status_running !== 1'b0 || status_done !== 1'b0)
            $fatal(1, "shell ran before ctrl_start");

        ctrl_start = 1'b1;
        @(posedge clk);
        ctrl_start = 1'b0;

        for (i = 0; i < 100; i = i + 1) begin
            @(posedge clk);
            if (status_done === 1'b1) begin
                if (led !== 4'h5)
                    $fatal(1, "controlled shell LED mismatch: %x", led);
                if (cycle_count == 0 || retired_count == 0)
                    $fatal(1, "controlled shell counters did not advance");
                $display("CONTROLLED PL PASS: cycles=%0d retired=%0d LED=%x",
                         cycle_count, retired_count, led);
                ctrl_reset = 1'b1;
                @(posedge clk);
                ctrl_reset = 1'b0;
                @(posedge clk);
                if (status_done !== 1'b0 || status_running !== 1'b0 ||
                    cycle_count !== 0 || retired_count !== 0 || led !== 0)
                    $fatal(1, "controlled reset did not clear status");
                $finish;
            end
        end

        $fatal(1, "controlled PL shell did not assert done");
    end
endmodule
