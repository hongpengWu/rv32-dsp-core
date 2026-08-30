`timescale 1ns / 1ps
`include "para.sv"

// CPU-level regression for the custom-0 packed fixed-point DSP operations.
// XDOTP16 performs two signed 16x16 lane products and sums them.  XQ15MUL
// rounds a signed low-half Q1.15 product and saturates to the signed 16-bit
// range, returned sign-extended to XLEN.
module tb_dsp_custom;
    localparam logic [31:0] RESET_PC  = 32'h8000_0000;
    localparam logic [31:0] DATA_BASE = 32'h8010_0000;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic imem_req_valid;
    logic [31:0] imem_req_addr, imem_rsp_data;
    logic imem_rsp_valid;
    logic dmem_req_valid, dmem_req_write;
    logic [31:0] dmem_req_addr, dmem_req_wdata, dmem_rsp_rdata;
    logic [3:0] dmem_req_wstrb;
    logic dmem_rsp_valid;
    logic debug_wb_have_inst, debug_wb_ena;
    logic [31:0] debug_wb_pc, debug_wb_value;
    logic [4:0] debug_wb_reg;
    logic [31:0] alu_a, alu_b, alu_result;
    logic [4:0] alu_choice;
    integer i;

    always #5 clk = ~clk;

    myCPU_sync dut (
        .timer_irq(1'b0), .cpu_clk(clk), .cpu_rst(reset),
        .imem_req_valid(imem_req_valid), .imem_req_addr(imem_req_addr),
        .imem_rsp_valid(imem_rsp_valid), .imem_rsp_data(imem_rsp_data),
        .dmem_req_valid(dmem_req_valid), .dmem_req_write(dmem_req_write),
        .dmem_req_addr(dmem_req_addr), .dmem_req_wstrb(dmem_req_wstrb),
        .dmem_req_wdata(dmem_req_wdata), .dmem_rsp_valid(dmem_rsp_valid),
        .dmem_rsp_rdata(dmem_rsp_rdata), .debug_wb_have_inst(debug_wb_have_inst),
        .debug_wb_pc(debug_wb_pc), .debug_wb_ena(debug_wb_ena),
        .debug_wb_reg(debug_wb_reg), .debug_wb_value(debug_wb_value)
    );

    // Direct ALU checks exercise the custom arithmetic independently of the
    // instruction-fetch and memory plumbing.  The CPU program below then
    // verifies decode, forwarding, writeback, and stores for the same ops.
    ALU alu_dut (.d1(alu_a), .d2(alu_b), .choice(alu_choice), .res(alu_result));

    rv32_sync_rom #(.DEPTH_WORDS(64), .BASE_ADDR(RESET_PC)) imem (
        .clk(clk), .req_valid(imem_req_valid), .req_addr(imem_req_addr),
        .rsp_valid(imem_rsp_valid), .rsp_data(imem_rsp_data),
        .data_req_valid(1'b0), .data_req_addr(32'd0),
        .data_rsp_valid(), .data_rsp_data()
    );

    rv32_sync_byte_ram #(.DEPTH_BYTES(64), .BASE_ADDR(DATA_BASE)) dmem (
        .clk(clk), .req_valid(dmem_req_valid), .req_write(dmem_req_write),
        .req_addr(dmem_req_addr), .req_wstrb(dmem_req_wstrb),
        .req_wdata(dmem_req_wdata), .rsp_valid(dmem_rsp_valid),
        .rsp_rdata(dmem_rsp_rdata)
    );

    function automatic [31:0] enc_u(input [19:0] imm20, input [4:0] rd);
        enc_u = {imm20, rd, 7'b0110111};
    endfunction
    function automatic [31:0] enc_i(input integer imm, input [4:0] rs1,
                                     input [4:0] rd);
        enc_i = {imm[11:0], rs1, 3'b000, rd, 7'b0010011};
    endfunction
    function automatic [31:0] enc_r_custom(input [6:0] funct7, input [4:0] rs2,
                                            input [4:0] rs1, input [2:0] funct3,
                                            input [4:0] rd);
        enc_r_custom = {funct7, rs2, rs1, funct3, rd, `custom0_opcode};
    endfunction
    function automatic [31:0] enc_s(input integer imm, input [4:0] rs2,
                                     input [4:0] rs1);
        enc_s = {imm[11:5], rs2, rs1, 3'b010, imm[4:0], 7'b0100011};
    endfunction

    function automatic [31:0] model_dot(input logic [31:0] a,
                                         input logic [31:0] b);
        logic signed [15:0] a_lo, a_hi, b_lo, b_hi;
        logic signed [32:0] sum;
        begin
            a_lo = a[15:0];
            a_hi = a[31:16];
            b_lo = b[15:0];
            b_hi = b[31:16];
            sum = a_lo * b_lo + a_hi * b_hi;
            model_dot = sum[31:0];
        end
    endfunction

    function automatic [31:0] model_q15(input logic [31:0] a,
                                         input logic [31:0] b);
        logic signed [15:0] a16, b16;
        logic signed [31:0] product, rounded;
        begin
            a16 = a[15:0];
            b16 = b[15:0];
            product = a16 * b16;
            rounded = (product + 32'sd16384) >>> 15;
            if (rounded > 32'sd32767)
                model_q15 = 32'h0000_7fff;
            else if (rounded < -32'sd32768)
                model_q15 = 32'hffff_8000;
            else
                model_q15 = rounded;
        end
    endfunction

    task automatic check_custom_alu(input logic [31:0] a,
                                    input logic [31:0] b);
        begin
            alu_a = a;
            alu_b = b;
            alu_choice = `alu_dotp16;
            #1;
            if (alu_result !== model_dot(a, b))
                $fatal(1, "DSP CUSTOM ALU FAIL: dot a=%h b=%h got=%h exp=%h",
                       a, b, alu_result, model_dot(a, b));
            alu_choice = `alu_q15mul;
            #1;
            if (alu_result !== model_q15(a, b))
                $fatal(1, "DSP CUSTOM ALU FAIL: q15 a=%h b=%h got=%h exp=%h",
                       a, b, alu_result, model_q15(a, b));
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (!reset && $isunknown({imem_req_valid, imem_req_addr,
                                   dmem_req_valid, dmem_req_write,
                                   dmem_req_addr, dmem_req_wstrb,
                                   dmem_req_wdata}))
            $fatal(1, "DSP CUSTOM FAIL: X/Z on active memory interface");
    end

    initial begin
        // Directed boundaries cover signed lane extremes, ties, and both
        // saturation directions before the pseudo-random sweep.
        check_custom_alu(32'h7fff_8000, 32'h7fff_8000);
        check_custom_alu(32'h8000_7fff, 32'h7fff_8000);
        check_custom_alu(32'h0000_4000, 32'h0000_4000);
        check_custom_alu(32'h0000_c000, 32'h0000_4000);
        check_custom_alu(32'h0000_0001, 32'hffff_ffff);
        for (i = 0; i < 64; i = i + 1)
            check_custom_alu($urandom, $urandom);

        for (i = 0; i < 64; i = i + 1)
            imem.mem[i] = 32'h0000_0013;

        // x1 = DATA_BASE; x2 = {signed -2000, signed 1000};
        // x3 = {signed 4, signed 3}; dot product = -5000 (0xffffec78).
        imem.mem[0]  = enc_u(20'h80100, 5'd1);
        imem.mem[1]  = enc_u(20'hf8300, 5'd2);
        imem.mem[2]  = enc_i(1000, 5'd2, 5'd2);
        imem.mem[3]  = enc_u(20'h00040, 5'd3);
        imem.mem[4]  = enc_i(3, 5'd3, 5'd3);
        imem.mem[5]  = enc_r_custom(7'b0000000, 5'd3, 5'd2, 3'b000, 5'd4);

        // A dependent custom instruction checks rs1/rs2 forwarding.  Using
        // x4 immediately after XDOTP16 must see -5000, not the old x4 value.
        imem.mem[6]  = enc_r_custom(7'b0000000, 5'd4, 5'd2, 3'b000, 5'd10);

        // Q1.15: 0.5 * 0.75 = 0.375 -> 0x3000.
        imem.mem[7]  = enc_u(20'h00004, 5'd5);
        imem.mem[8]  = enc_u(20'h00006, 5'd6);
        imem.mem[9]  = enc_r_custom(7'b0000001, 5'd6, 5'd5, 3'b001, 5'd7);

        // (-1.0) * (-1.0) rounds to +1.0 and saturates at 0x7fff.
        imem.mem[10] = enc_u(20'h00008, 5'd8);
        imem.mem[11] = enc_r_custom(7'b0000001, 5'd8, 5'd8, 3'b001, 5'd9);
        imem.mem[12] = enc_s(0, 5'd4, 5'd1);
        imem.mem[13] = enc_s(4, 5'd7, 5'd1);
        imem.mem[14] = enc_s(8, 5'd9, 5'd1);
        imem.mem[15] = enc_s(12, 5'd10, 5'd1);
        imem.mem[16] = 32'h0000_006f;

        repeat (3) @(posedge clk);
        reset = 1'b0;
        repeat (260) @(posedge clk);

        if (dmem.mem[0] !== 32'hffff_ec78)
            $fatal(1, "DSP CUSTOM FAIL: XDOTP16 got=%h", dmem.mem[0]);
        if (dmem.mem[1] !== 32'h0000_3000)
            $fatal(1, "DSP CUSTOM FAIL: XQ15MUL normal got=%h", dmem.mem[1]);
        if (dmem.mem[2] !== 32'h0000_7fff)
            $fatal(1, "DSP CUSTOM FAIL: XQ15MUL saturation got=%h", dmem.mem[2]);
        if (dmem.mem[3] !== 32'hffb3_bc90)
            $fatal(1, "DSP CUSTOM FAIL: dependent XDOTP16 got=%h", dmem.mem[3]);

        $display("DSP CUSTOM PASS: XDOTP16 and rounded/saturated XQ15MUL verified");
        $finish;
    end
endmodule
