module CSR #(
    parameter CSR_WIDTH = 32,
    parameter RESET_VAL  = 0
)(
    input              clock,
    input              reset,
    input              [31:0] csrd,
    input              [3:0]  csr_wen,
    input              trap_fire,
    input              [31:0] trap_pc,
    input              [31:0] trap_cause,
    input              [31:0] trap_tval,
    input              mret_fire,

    output             [31:0] mvendorid_out,
    output             [31:0] marchid_out,
    output             [31:0] mepc_out,
    output             [31:0] mcause_out,
    output             [31:0] mtval_out,
    output             [31:0] mstatus_out,
    output             [31:0] mtvec_out
);

    wire [31:0] mepc_in;
    wire [31:0] mcause_in;
    wire [31:0] mtval_in;
    wire [31:0] mstatus_in;
    wire [31:0] mtvec_in;
    wire [31:0] mstatus_trap;
    wire [31:0] mstatus_mret;

    assign mepc_in = trap_fire ? trap_pc : csrd;
    assign mcause_in = trap_fire ? trap_cause : csrd;
    assign mtval_in = trap_fire ? trap_tval : csrd;
    assign mtvec_in = csrd;

    // Machine trap entry and return update the architecturally visible
    // interrupt state while preserving unrelated mstatus bits.
    assign mstatus_trap = {mstatus_out[31:13], 2'b11, mstatus_out[10:8],
                           mstatus_out[3], mstatus_out[6:4], 1'b0,
                           mstatus_out[2:0]};
    assign mstatus_mret = {mstatus_out[31:13], 2'b00, mstatus_out[10:8],
                          1'b1, mstatus_out[6:4], mstatus_out[7],
                          mstatus_out[2:0]};
    assign mstatus_in = trap_fire ? mstatus_trap :
                        mret_fire ? mstatus_mret : csrd;

    assign mvendorid_out = 32'h7973_7978;
    assign marchid_out   = 32'h016F_BCBD;

    Reg #(.WIDTH(CSR_WIDTH), .RESET_VAL(RESET_VAL)) CSR_MEPC (
        .clock(clock), .reset(reset), .din(mepc_in), .dout(mepc_out),
        .wen(csr_wen[0] | trap_fire)
    );

    Reg #(.WIDTH(CSR_WIDTH), .RESET_VAL(RESET_VAL)) CSR_MCAUSE (
        .clock(clock), .reset(reset), .din(mcause_in), .dout(mcause_out),
        .wen(csr_wen[1] | trap_fire)
    );

    Reg #(.WIDTH(CSR_WIDTH), .RESET_VAL(RESET_VAL)) CSR_MTVAL (
        .clock(clock), .reset(reset), .din(mtval_in), .dout(mtval_out),
        .wen(trap_fire)
    );

    Reg #(.WIDTH(CSR_WIDTH), .RESET_VAL(32'h1800)) CSR_MSTATUS (
        .clock(clock), .reset(reset), .din(mstatus_in), .dout(mstatus_out),
        .wen(csr_wen[2] | trap_fire | mret_fire)
    );

    Reg #(.WIDTH(CSR_WIDTH), .RESET_VAL(RESET_VAL)) CSR_MTVEC (
        .clock(clock), .reset(reset), .din(mtvec_in), .dout(mtvec_out),
        .wen(csr_wen[3])
    );

endmodule
