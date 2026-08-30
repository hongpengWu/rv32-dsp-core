`timescale 1ns / 1ps

// Load/store stage for a one-cycle synchronous data-memory response.
//
// Requests are driven directly from the EXU output during the cycle before
// the accepting clock edge.  The stage captures the instruction metadata on
// that same edge, so the registered memory response is aligned with the
// following LSU/WBU cycle without requiring a second outstanding queue.
module LSU_sync (
    input  logic        clock,
    input  logic        reset,
    input  logic        mem_ren,
    input  logic        mem_wen,
    input  logic        R_wen,
    input  logic [5:0]  csr_wen,
    input  logic [31:0] Ex_result,
    input  logic [4:0]  rd,
    input  logic [2:0]  funct3,
    input  logic [31:0] rs2_value,
    input  logic        jump_flag,
    input  logic [31:0] rd_value,
    input  logic [31:0] pc,
    input  logic        dmem_rsp_valid,
    input  logic [31:0] dmem_rsp_rdata,
    output logic [31:0] rd_value_next,
    output logic        R_wen_next,
    output logic [31:0] LSU_Rdata,
    output logic [5:0]  csr_wen_next,
    output logic [31:0] Ex_result_next,
    output logic [4:0]  rd_next,
    output logic        mem_ren_next,
    output logic        jump_flag_next,
    output logic [31:0] pc_out,
    output logic        dmem_req_valid,
    output logic        dmem_req_write,
    output logic [31:0] dmem_req_addr,
    output logic [3:0]  dmem_req_wstrb,
    output logic [31:0] dmem_req_wdata,
    input  logic        valid_last,
    output logic        ready_last,
    input  logic        ready_next,
    output logic        valid_next
);
    logic [2:0]  funct3_reg;
    logic [1:0]  addr_low_reg;
    logic        mem_ren_reg;
    logic        mem_wen_reg;
    logic        R_wen_reg;
    logic [5:0]  csr_wen_reg;
    logic [31:0] Ex_result_reg;
    logic [31:0] rd_value_reg;
    logic [4:0]  rd_reg;
    logic [31:0] rs2_value_reg;
    logic        jump_flag_reg;

    logic [3:0]  base_wstrb;
    logic [31:0] shifted_rdata;
    logic [31:0] load_data;

    assign ready_last = ready_next;

    // Translate the legacy size encoding into byte strobes.  Aligning the
    // address and shifting the payload preserves byte/halfword accesses that
    // stay within a 32-bit word; misaligned word-crossing accesses will be
    // rejected by the Core's future alignment trap logic.
    always_comb begin
        case (funct3)
            3'b000: base_wstrb = 4'b0001; // sb
            3'b001: base_wstrb = 4'b0011; // sh
            3'b010: base_wstrb = 4'b1111; // sw
            default: base_wstrb = 4'b0000;
        endcase
    end

    assign dmem_req_valid = valid_last && (mem_ren || mem_wen);
    assign dmem_req_write = mem_wen;
    assign dmem_req_addr  = Ex_result & 32'hffff_fffc;
    assign dmem_req_wstrb = base_wstrb << Ex_result[1:0];
    assign dmem_req_wdata = rs2_value << (Ex_result[1:0] * 8);

    assign shifted_rdata = dmem_rsp_rdata >> (addr_low_reg * 8);
    always_comb begin
        case (funct3_reg)
            3'b000: load_data = {{24{shifted_rdata[7]}}, shifted_rdata[7:0]};
            3'b001: load_data = {{16{shifted_rdata[15]}}, shifted_rdata[15:0]};
            3'b010: load_data = shifted_rdata;
            3'b100: load_data = {24'd0, shifted_rdata[7:0]};
            3'b101: load_data = {16'd0, shifted_rdata[15:0]};
            default: load_data = 32'd0;
        endcase
    end

    assign LSU_Rdata      = dmem_rsp_valid ? load_data : 32'd0;
    assign Ex_result_next = Ex_result_reg;
    assign rd_value_next  = rd_value_reg;
    assign rd_next        = rd_reg;
    assign mem_ren_next   = valid_next && mem_ren_reg;
    assign R_wen_next     = valid_next && R_wen_reg;
    assign jump_flag_next = valid_next && jump_flag_reg;
    assign csr_wen_next   = valid_next ? csr_wen_reg : 6'b0;

    always_ff @(posedge clock) begin
        if (reset) begin
            valid_next    <= 1'b0;
            pc_out        <= 32'd0;
            funct3_reg    <= 3'd0;
            addr_low_reg  <= 2'd0;
            mem_ren_reg   <= 1'b0;
            mem_wen_reg   <= 1'b0;
            R_wen_reg     <= 1'b0;
            csr_wen_reg   <= 4'd0;
            Ex_result_reg <= 32'd0;
            rd_value_reg  <= 32'd0;
            rd_reg        <= 5'd0;
            rs2_value_reg <= 32'd0;
            jump_flag_reg <= 1'b0;
        end else begin
            valid_next <= valid_last && ready_next;
            if (valid_last && ready_next) begin
                pc_out        <= pc;
                funct3_reg    <= funct3;
                addr_low_reg  <= Ex_result[1:0];
                mem_ren_reg   <= mem_ren;
                mem_wen_reg   <= mem_wen;
                R_wen_reg     <= R_wen;
                csr_wen_reg   <= csr_wen;
                Ex_result_reg <= Ex_result;
                rd_value_reg  <= rd_value;
                rd_reg        <= rd;
                rs2_value_reg <= rs2_value;
                jump_flag_reg <= jump_flag;
            end
        end
    end
endmodule
