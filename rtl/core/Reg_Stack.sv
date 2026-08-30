module Reg_Stack(
    input                                  reset                      ,
    input                                  clock                      ,
    input              [  31: 0]           pc                         ,
    input                                  trap_fire                  ,
    input              [  31: 0]           trap_pc                    ,
    input              [  31: 0]           trap_cause                 ,
    input              [  31: 0]           trap_tval                  ,
    input                                  mret_fire                  ,
    input                                  timer_irq                  ,

    input              [   4: 0]           rs1                        ,
    input              [   4: 0]           rs2                        ,
    input              [   4: 0]           rd                         ,
    input              [  31: 0]           rd_value                   ,


    input              [  31: 0]           csr_addr                   ,
    input                                  R_wen                      ,
    input              [   5: 0]           csr_wen                    ,
    input              [  31: 0]           csrd                       ,

    output             [  31: 0]           rs1_value                  ,
    output             [  31: 0]           rs2_value                  ,
    output             [  31: 0]           a0_value                   ,
    output             [  31: 0]           csrs                       ,
    output             [  31: 0]           mepc_out                   ,
    output             [  31: 0]           mtvec_out                  ,
    output             [  31: 0]           mtval_out                  ,
    output             [  31: 0]           mstatus_out                ,
    output             [  31: 0]           mie_out                    ,
    output             [  31: 0]           mscratch_out
);

    wire               [  31: 0]        wdata                       ;

    wire               [  31: 0]        mcause_out                  ;
    wire               [  31: 0]        mvendorid_out               ;
    wire               [  31: 0]        marchid_out                 ;
    wire               [  31: 0]        mip_out                     ;


    assign                              wdata                       = rd_value;

    assign                       csrs                      = (csr_addr == 32'h341)? mepc_out        :
                                                             (csr_addr == 32'h342)? mcause_out      :
                                                             (csr_addr == 32'h300)? mstatus_out     :
                                                             (csr_addr == 32'h304)? mie_out         :
                                                             (csr_addr == 32'h305)? mtvec_out       :
                                                             (csr_addr == 32'h343)? mtval_out       :
                                                             (csr_addr == 32'h344)? mip_out         :
                                                             (csr_addr == 32'h340)? mscratch_out    :
                                                             (csr_addr == 32'hf11)?mvendorid_out    :
                                                             (csr_addr == 32'hf12)?marchid_out      :
                                                             (csr_addr == 32'hf14)?32'd0             :
                                                             32'd0;



CSR #(32,0) CSR_inst(
    .clock                              (clock                     ),
    .reset                              (reset                     ),

    .csrd                               (csrd                      ),
    .csr_wen                            (csr_wen                   ),
    .trap_fire                          (trap_fire                 ),
    .trap_pc                            (trap_pc                   ),
    .trap_cause                         (trap_cause                ),
    .trap_tval                          (trap_tval                 ),
    .mret_fire                          (mret_fire                 ),
    .timer_irq                          (timer_irq                 ),
    
    .mvendorid_out                      (mvendorid_out             ),
    .marchid_out                        (marchid_out               ),
    .mepc_out                           (mepc_out                  ),
    .mcause_out                         (mcause_out                ),
    .mtval_out                          (mtval_out                  ),
    .mstatus_out                        (mstatus_out               ),
    .mtvec_out                          (mtvec_out                 ),
    .mie_out                            (mie_out                   ),
    .mip_out                            (mip_out                   ),
    .mscratch_out                       (mscratch_out              )


);

RegisterFile #(5, 32) Reg_inst(
    .clock                              (clock                     ),
    .wdata                              (wdata                     ),
    .waddr                              (rd                        ),
    .wen                                (R_wen                     ),
    .reset                              (reset                     ),
    .rs1_addr                           (rs1                       ),
    .rs2_addr                           (rs2                       ),

    .rs1_value                          (rs1_value                 ),
    .rs2_value                          (rs2_value                 ),
    .a0_value                           (a0_value                  ) 
);


endmodule
