`include "para.sv"

module IDU(
    input                               clock                      ,
    input                               reset                      ,

    input              [  31: 0]        inst                       ,
    input              [  31: 0]        snpc                       ,
    input              [  31: 0]        pc                         ,

    input              [  31: 0]        rd_value                   ,
    input              [  31: 0]        csrd                       ,
    input              [   4: 0]        rd                         ,
    input                               R_wen                      ,
    input              [   5: 0]        csr_wen                    ,
    input                               timer_irq                  ,

    input              [  31: 0]        EXU_rs1_in                 ,
    input              [  31: 0]        EXU_rs2_in                 ,

    output             [   4: 0]        rd_next                    ,
    output             [   2: 0]        funct3                     ,
    output                              mret_flag                  ,
    output                              ecall_flag                 ,
    output                              ebreak_flag                ,
    output                              fence_i_flag               ,
    output                              illegal_inst               ,
    output             [  31: 0]        trap_cause                 ,
    output             [  31: 0]        trap_tval                  ,

    output             [  31: 0]        branch_pc                  ,
    output             [  31: 0]        rs1_value                  ,
    output             [  31: 0]        rs2_value                  ,
    
    output             [  31: 0]        add1_value                 ,
    output             [  31: 0]        add2_value                 ,
    output             [   5: 0]        csr_wen_next               ,
    output                              R_wen_next                 ,
    output             [  31: 0]        rd_value_next              ,

    output                              mem_wen                    ,
    output                              mem_ren                    ,
    output                              inv_flag                   ,
    output                              branch_flag                ,
    output                              jump_flag                  ,
    output                              uses_rs1                   ,
    output                              uses_rs2                   ,

    output             [   3: 0]        alu_opcode                 ,

    output             [   4: 0]        rs1                        ,
    output             [   4: 0]        rs2                        ,
    output             [  31: 0]        a0_value                   ,
    output             [  31: 0]        mepc_out                   ,
    output             [  31: 0]        mtvec_out                  ,
    output             [31:0]   pc_out,

    input                               trap_fire                  ,
    input                               mret_fire                  ,
    input                               irq_fire                   ,


    input                               valid_last                 ,
    output                              ready_last                 ,

    input                               ready_next                 ,
    output                              valid_next                  ,
    output             [  31: 0]        mstatus_out                 ,
    output             [  31: 0]        mie_out
);


    wire               [  31: 0]        csr_addr                    ;
    wire               [   6: 0]        oprand                      ;
    wire               [   6: 0]        opcode                      ;

    wire               [  31: 0]        imm_I                       ;
    wire               [  31: 0]        imm_U                       ;
    wire               [  31: 0]        imm_R                       ;
    wire               [  31: 0]        imm_S                       ;
    wire               [  31: 0]        imm_B                       ;
    wire               [  31: 0]        imm_J                       ;
    wire               [  31: 0]        csrs                        ;
    wire               [  31: 0]        mscratch_csr_out             ;
    wire               [  31: 0]        imm                         ;
    wire               [  11: 0]        csr_addr12                  ;
    wire                               csr_addr_supported            ;
    wire                               csr_access                    ;
    wire                               csr_write_req                 ;
    wire                               csr_writeable                 ;
    wire               [  31: 0]        csr_source                   ;
    wire               [  31: 0]        memory_address                ;
    wire               [   1: 0]        memory_address_low              ;
    wire                               misaligned_access              ;
    reg                                legal_inst                  ;

    assign                              ready_last                  = ready_next;
    // Keep the decoded instruction visible for one cycle so Control can take
    // a precise trap.  EXU_inst_clear (driven by illegal_inst below) removes a
    // misaligned access before it can become a live LSU transaction.
    // Keep valid_next independent of irq_fire.  irq_fire is derived from
    // IDU_valid in Control, so gating valid_next with irq_fire would create
    // a combinational feedback loop (IDU_valid -> irq_fire -> valid_next).
    // Control's EXU_inst_clear synchronously flushes the instruction when
    // an interrupt is taken.
    assign                              valid_next                  = valid_last && legal_inst;



    assign                              oprand                      = inst[31:25];
    assign                              opcode                      = inst[6:0];
    assign                              rs1                         = inst[19:15];
    assign                              rs2                         = inst[24:20];
    assign                              funct3                      = inst[14:12];
    assign                              rd_next                     = inst[11:7];

    assign                              ecall_flag                  = (inst == 32'b00000000000000000000000001110011);//ecall
    assign                              mret_flag                   = (inst == 32'b00110000001000000000000001110011);// mret
    assign                              ebreak_flag                  = (inst == 32'h0010_0073);
    assign                              fence_i_flag                = (inst == 32'b00000000000000000001000000001111);

    assign                              csr_addr12                  = inst[31:20];
    assign                              csr_addr_supported           = (csr_addr12 == 12'h300) ||
                                                                       (csr_addr12 == 12'h304) ||
                                                                       (csr_addr12 == 12'h305) ||
                                                                       (csr_addr12 == 12'h344) ||
                                                                       (csr_addr12 == 12'h341) ||
                                                                       (csr_addr12 == 12'h342) ||
                                                                       (csr_addr12 == 12'h343) ||
                                                                       (csr_addr12 == 12'hf11) ||
                                                                       (csr_addr12 == 12'hf12) ||
                                                                       (csr_addr12 == 12'hf14) ||
                                                                       (csr_addr12 == 12'h340);
    assign                              csr_access                   = (opcode == `M_opcode) &&
                                                                       (funct3 != 3'b000) &&
                                                                       csr_addr_supported;
    assign                              csr_writeable                = (csr_addr12 == 12'h300) ||
                                                                       (csr_addr12 == 12'h304) ||
                                                                       (csr_addr12 == 12'h305) ||
                                                                       (csr_addr12 == 12'h341) ||
                                                                       (csr_addr12 == 12'h342) ||
                                                                       (csr_addr12 == 12'h340);
    assign                              csr_source                   = funct3[2] ?
                                                                       {27'd0, rs1} : EXU_rs1_in;
    assign                              csr_write_req                = csr_access &&
                                                                       ((funct3 == 3'b001) ||
                                                                        (funct3 == 3'b101) ||
                                                                        (((funct3 == 3'b010) ||
                                                                          (funct3 == 3'b011) ||
                                                                          (funct3 == 3'b110) ||
                                                                          (funct3 == 3'b111)) &&
                                                                         (csr_source != 32'd0)));

    always @(*) begin
        legal_inst = 1'b0;
        case (opcode)
            `R_opcode: begin
                case (funct3)
                    3'b000: legal_inst = (oprand == 7'b0000000) || (oprand == 7'b0100000);
                    3'b001, 3'b010, 3'b011, 3'b100, 3'b110, 3'b111:
                            legal_inst = (oprand == 7'b0000000);
                    3'b101: legal_inst = (oprand == 7'b0000000) || (oprand == 7'b0100000);
                    default: legal_inst = 1'b0;
                endcase
            end
            `I0_opcode: legal_inst = (funct3 == 3'b000) || (funct3 == 3'b001) ||
                                      (funct3 == 3'b010) || (funct3 == 3'b100) ||
                                      (funct3 == 3'b101);
            `I1_opcode: begin
                case (funct3)
                    3'b000, 3'b010, 3'b011, 3'b100, 3'b110, 3'b111: legal_inst = 1'b1;
                    3'b001: legal_inst = (oprand == 7'b0000000);
                    3'b101: legal_inst = (oprand == 7'b0000000) || (oprand == 7'b0100000);
                    default: legal_inst = 1'b0;
                endcase
            end
            `I2_opcode: legal_inst = (funct3 == 3'b000);
            `S_opcode:  legal_inst = (funct3 == 3'b000) || (funct3 == 3'b001) ||
                                      (funct3 == 3'b010);
            `B_opcode:  legal_inst = (funct3 == 3'b000) || (funct3 == 3'b001) ||
                                      (funct3 == 3'b100) || (funct3 == 3'b101) ||
                                      (funct3 == 3'b110) || (funct3 == 3'b111);
            `U0_opcode, `U1_opcode, `J_opcode: legal_inst = 1'b1;
            `M_opcode: legal_inst = ecall_flag || mret_flag || ebreak_flag || csr_access;
            7'b0001111: legal_inst = (funct3 == 3'b000) || (funct3 == 3'b001);
            default: legal_inst = 1'b0;
        endcase
    end

    // Alignment is a low-bit property.  Keep the 2-bit check out of the
    // decode/control critical path; the full address is only needed as the
    // mtval payload when a trap is actually taken.
    assign                              memory_address_low            = add1_value[1:0] + add2_value[1:0];
    assign                              memory_address              = add1_value + add2_value;
    assign                              misaligned_access            = valid_last && legal_inst &&
                                                                       ((opcode == `I0_opcode || opcode == `S_opcode) &&
                                                                        (((funct3 == 3'b001) || (funct3 == 3'b101)) && memory_address_low[0] ||
                                                                         (funct3 == 3'b010 && |memory_address_low)));

    // `illegal_inst` is the existing trap request wire consumed by Control.
    // It now also carries the two mandated load/store-misalignment causes;
    // the instruction is still distinguished by trap_cause/trap_tval below.
    assign                              illegal_inst                = valid_last && (!legal_inst || misaligned_access);
    assign                              trap_cause                  = irq_fire ? 32'h8000_0007 :
                                                                       misaligned_access ?
                                                                       ((opcode == `S_opcode) ? 32'd6 : 32'd4) :
                                                                       ecall_flag ? 32'd11 :
                                                                       ebreak_flag ? 32'd3 : 32'd2;
    assign                              trap_tval                   = irq_fire ? 32'd0 :
                                                                       misaligned_access ? memory_address :
                                                                       (illegal_inst ? inst : 32'd0);

    assign                              csr_wen_next[0]             = csr_write_req && csr_writeable && (csr_addr12 == 12'h341);
    assign                              csr_wen_next[1]             = csr_write_req && csr_writeable && (csr_addr12 == 12'h342);
    assign                              csr_wen_next[2]             = csr_write_req && csr_writeable && (csr_addr12 == 12'h300);
    assign                              csr_wen_next[3]             = csr_write_req && csr_writeable && (csr_addr12 == 12'h305);
    assign                              csr_wen_next[4]             = csr_write_req && csr_writeable && (csr_addr12 == 12'h304);
    assign                              csr_wen_next[5]             = csr_write_req && csr_writeable && (csr_addr12 == 12'h340);

    assign                              R_wen_next                  = legal_inst && !misaligned_access && ((opcode == `R_opcode) || (opcode == `I0_opcode) ||
                                                                       (opcode == `I1_opcode) || (opcode == `I2_opcode) ||
                                                                       (opcode == `U0_opcode) || (opcode == `U1_opcode) ||
                                                                       (opcode == `J_opcode) ||
                                                                       csr_access);
    assign                              mem_wen                     = legal_inst && !misaligned_access && (opcode == `S_opcode);
    assign                              mem_ren                     = legal_inst && !misaligned_access && (opcode == `I0_opcode);

    assign                              jump_flag                   = legal_inst && (opcode == `I2_opcode || opcode == `J_opcode);

    // Source-use metadata is used by the hazard unit.  Immediate fields in
    // LUI/AUIPC/JAL and CSR-immediate instructions are not register sources.
    assign                              uses_rs1                    = legal_inst &&
                                                                       ((opcode == `R_opcode) ||
                                                                        (opcode == `I0_opcode) ||
                                                                        (opcode == `I1_opcode) ||
                                                                        (opcode == `I2_opcode) ||
                                                                        (opcode == `S_opcode) ||
                                                                        (opcode == `B_opcode) ||
                                                                        (opcode == `M_opcode && funct3[2] == 1'b0 && funct3 != 3'b000));
    assign                              uses_rs2                    = legal_inst &&
                                                                       ((opcode == `R_opcode) ||
                                                                        (opcode == `S_opcode) ||
                                                                        (opcode == `B_opcode));

    assign                              inv_flag                    = legal_inst && (opcode == `B_opcode && (funct3 == 3'b101 || funct3 == 3'b111 || funct3 == 3'b000 ));
    assign                              branch_flag                 = legal_inst && (opcode == `B_opcode);
 
    assign                              csr_addr                    = {20'd0, csr_addr12};

    assign                              rd_value_next               = jump_flag ? snpc :
                                                                       csr_access ? csrs : 32'd0;
    assign                              branch_pc                   = pc + imm;
    assign pc_out  = pc;

    assign add1_value = csr_access ?
                        (((funct3 == 3'b001) || (funct3 == 3'b101)) ? csr_source : csrs) :
                        (opcode == `U0_opcode)? 0 :
                        (opcode == `J_opcode || opcode == `U1_opcode )? pc :
                        EXU_rs1_in;

    assign add2_value = csr_access ?
                        (((funct3 == 3'b001) || (funct3 == 3'b101)) ? 32'd0 : csr_source) :
                        (opcode == `R_opcode || opcode == `B_opcode)?  EXU_rs2_in :
                        (opcode == `M_opcode && funct3 == 3'b010)? rd_value_next :
                        (opcode == `M_opcode && funct3 == 3'b001)? 0 : imm;
 

    assign alu_opcode = csr_access ?
                        (((funct3 == 3'b001) || (funct3 == 3'b101)) ? `alu_add :
                         ((funct3 == 3'b010) || (funct3 == 3'b110)) ? `alu_or :
                         `alu_andn) :
                        (opcode == `S_opcode ||  opcode == `I0_opcode
                        || opcode == `U0_opcode || opcode == `U1_opcode
                        || opcode == `J_opcode || opcode == `I2_opcode
                        || (opcode ==`I1_opcode  &&  funct3 == 3'b000)  || (opcode == `R_opcode         &&
                        funct3 == 3'b000 && oprand[5] == 1'b0) || (opcode == `B_opcode                             &&
                        funct3[2:1] == 2'b01                 ))                                                                     ?
                        `alu_add :(opcode == `I1_opcode && funct3 == 3'b010)                            ||
                        (opcode == `R_opcode && funct3 == 3'b010)                                                     ||
                        (opcode == `B_opcode && (funct3 == 3'b101 || funct3 == 3'b100))                               ?
                        `alu_signed_comparator:
                        (opcode == `B_opcode && (funct3 == 3'b110 || funct3 == 3'b111))                               ||
                        (opcode == `I1_opcode && (funct3 == 3'b011))                                                  ||
                        (opcode == `R_opcode && (funct3 ==  3'b011))                                                  ?
                        `alu_unsigned_comparator:
                        (opcode == `I1_opcode && funct3 == 3'b100 )                                                   ||
                        (opcode == `R_opcode && funct3 == 3'b100 )                                                    ?
                        `alu_xor :(opcode == `I1_opcode && funct3 == 3'b110 )                           ||
                        (opcode == `R_opcode && funct3 == 3'b110 )                                                    ||
                        (opcode == `M_opcode && funct3 == 3'b010 )                                                    ?
                        `alu_or  : (opcode == `I1_opcode && funct3 == 3'b111 )                          ||
                        (opcode == `R_opcode && funct3 == 3'b111 )                                                    ?
                        `alu_and :(opcode == `I1_opcode && funct3 == 3'b001  )                          ||
                        (opcode == `R_opcode && funct3 == 3'b001 )                                                    ?
                        `alu_sll :(opcode == `I1_opcode && funct3 == 3'b101 && oprand[5] == 1'b0)    ||
                        (opcode == `R_opcode && funct3 == 3'b101 && oprand[5] == 1'b0)                             ?
                        `alu_srl :(opcode == `I1_opcode && funct3 == 3'b101 && oprand[5] == 1'b1)    ||
                        (opcode == `R_opcode && funct3 == 3'b101 && oprand[5] == 1'b1)                             ?
                        `alu_sra : (opcode == `R_opcode && funct3 == 3'b000 && oprand[5] == 1'b1)    ?
                        `alu_sub : (opcode == `B_opcode && funct3[2:1] == 2'b00)                        ?
                        `alu_equal:`alu_add;


    assign                              imm_I                       = {{20{inst[31]}},inst[31:20]};
    assign                              imm_U                       = {inst[31:12],12'd0};
    assign                              imm_R                       = {25'd0,inst[31:25]};
    assign                              imm_S                       = {{20{inst[31]}},inst[31:25],inst[11:7]};
    assign                              imm_B                       = {{19{inst[31]}}, inst[31], inst[7],
                                                                       inst[30:25], inst[11:8], 1'b0};
    assign                              imm_J                       = {{11{inst[31]}}, inst[31], inst[19:12],
                                                                       inst[20], inst[30:21], 1'b0};
/* verilator lint_off IMPLICIT */

    assign imm = (opcode == `I0_opcode || opcode == `I1_opcode || opcode == `I2_opcode || opcode == `M_opcode)? imm_I:
                 (opcode == `U0_opcode || opcode == `U1_opcode)? imm_U:
                 (opcode == `J_opcode)? imm_J:
                 (opcode == `B_opcode)? imm_B:
                 (opcode == `S_opcode)? imm_S:
                  0;

Reg_Stack Reg_Stack_inst0(
    .reset                              (reset                     ),
    .clock                              (clock                     ),
    .pc                                 (pc                        ),
    .trap_fire                          (trap_fire                 ),
    .trap_pc                            (pc                        ),
    .trap_cause                         (trap_cause                ),
    .trap_tval                          (trap_tval                 ),
    .mret_fire                          (mret_fire                 ),
    .timer_irq                          (timer_irq                 ),

    .rs1                                (rs1                       ),
    .rs2                                (rs2                       ),
    .rd                                 (rd                        ),
    .rd_value                           (rd_value                  ),

    .csr_addr                           (csr_addr                  ),
    .R_wen                              (R_wen                     ),
    .csr_wen                            (csr_wen                   ),
    .csrd                               (csrd                      ),

    .rs1_value                          (rs1_value                 ),
    .rs2_value                          (rs2_value                 ),
    .a0_value                           (a0_value                  ),
    .csrs                               (csrs                      ),
    .mepc_out                           (mepc_out                  ),
    .mtvec_out                          (mtvec_out                 ),
    .mtval_out                           (),
    .mstatus_out                         (mstatus_out),
    .mie_out                             (mie_out)
    ,.mscratch_out                        (mscratch_csr_out)
);





endmodule
