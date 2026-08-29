`timescale 1ns / 1ps

// Instruction fetch unit for a one-cycle synchronous memory response.
//
// The legacy IFU consumes an asynchronous instruction word.  This version
// keeps a one-entry response buffer and tags the response with its PC.  A
// redirect kills both a buffered wrong-path response and an in-flight request
// whose response arrives on the redirect edge.
module IFU_sync (
    input  logic        clock,
    input  logic        reset,
    input  logic [31:0] dnpc,
    input  logic        dnpc_flag,
    input  logic        stall,
    input  logic        ready,
    input  logic        irom_rsp_valid,
    input  logic [31:0] irom_rsp_data,
    output logic        irom_req_valid,
    output logic [31:0] irom_req_addr,
    output logic [31:0] snpc,
    output logic [31:0] pc,
    output logic [31:0] inst,
    output logic        valid
);
    localparam logic [31:0] RESET_PC = 32'h8000_0000;

    logic [31:0] fetch_pc;
    logic [31:0] request_pc;
    logic [31:0] response_pc;
    logic [31:0] response_inst;
    logic        request_pending;
    logic        request_killed;
    logic        response_valid;

    // response_inst is meaningful only while response_valid is asserted.  Do
    // not reset the payload register: this lets Vivado merge the synchronous
    // instruction path into BRAM without putting an asynchronous reset on the
    // BRAM output register.
    // The response buffer is intentionally one entry deep.  This gives a
    // conservative, easy-to-audit implementation before adding prefetch
    // depth or a full ready/valid instruction queue.
    assign irom_req_valid = !reset && !request_pending && !response_valid &&
                            !stall && !dnpc_flag;
    assign irom_req_addr  = fetch_pc;
    assign valid          = response_valid;
    assign pc             = response_pc;
    assign inst           = response_inst;
    assign snpc          = response_pc + 32'd4;

    always_ff @(posedge clock) begin
        if (reset) begin
            fetch_pc        <= RESET_PC;
            request_pc      <= RESET_PC;
            response_pc     <= RESET_PC;
            request_pending <= 1'b0;
            request_killed  <= 1'b0;
            response_valid  <= 1'b0;
        end else if (dnpc_flag) begin
            // A redirect has priority over a same-edge memory response.
            fetch_pc       <= dnpc;
            response_valid <= 1'b0;
            if (irom_rsp_valid && request_pending) begin
                request_pending <= 1'b0;
                request_killed  <= 1'b0;
            end else if (request_pending) begin
                request_killed <= 1'b1;
            end else begin
                request_killed <= 1'b0;
            end
        end else begin
            if (response_valid && ready && !stall)
                response_valid <= 1'b0;

            if (irom_rsp_valid && request_pending) begin
                request_pending <= 1'b0;
                if (!request_killed) begin
                    response_pc    <= request_pc;
                    response_inst  <= irom_rsp_data;
                    response_valid <= 1'b1;
                end
                request_killed <= 1'b0;
            end

            if (irom_req_valid) begin
                request_pc      <= fetch_pc;
                fetch_pc        <= fetch_pc + 32'd4;
                request_pending <= 1'b1;
            end
        end
    end
endmodule
