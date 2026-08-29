module Control (

    input                               clock                      ,
    input                               reset                      ,

    input              [  31: 0]        mtvec_out                  ,
    input              [  31: 0]        mepc_out                   ,

    input              [  31: 0]        branch_pc                  ,
    input              [  31: 0]        Ex_result                  ,
    input              [  31: 0]        MEM_Ex_result              ,

    input              [  31: 0]        MEM_Rdata                  ,
    input              [  31: 0]        IDU_rs1_value              ,
    input              [  31: 0]        IDU_rs2_value              ,

    input                               branch_flag                ,
    input                               jump_flag                  ,
    input                               mret_flag                  ,
    input                               ecall_flag                 ,
    input                               MEM_mem_ren                ,
    input                               fence_i_flag               ,

    input              [   4: 0]        IDU_rs1                    ,
    input              [   4: 0]        IDU_rs2                    ,
    input                               IDU_uses_rs1               ,
    input                               IDU_uses_rs2               ,

    input                               IDU_valid                  ,
    input                               EXU_valid                  ,
    input                               MEM_valid                  ,

    input              [   4: 0]        EXU_rd                     ,
    input              [   4: 0]        MEM_rd                     ,

    input                               EXU_mem_ren                ,
    input                               EXU_R_Wen                  ,
    input                               MEM_R_Wen                  ,


    output                              IFU_stall                  ,
    output             [  31: 0]        EXU_rs1_in                 ,
    output             [  31: 0]        EXU_rs2_in                 ,

    output                              icache_clr                 ,
    output                              EXU_inst_clear             ,
    output             [  31: 0]        dnpc                       ,
    output                              dnpc_flag                   
);


    wire               [   1: 0]        IDU_rs1_choice              ;
    wire               [   1: 0]        IDU_rs2_choice              ;



    wire exu_branch_taken = EXU_valid && branch_flag && Ex_result[0];
    wire exu_jump         = EXU_valid && jump_flag;
    wire exu_fence_i      = EXU_valid && fence_i_flag;
    wire idu_mret         = IDU_valid && mret_flag;
    wire idu_ecall        = IDU_valid && ecall_flag;

    assign                              dnpc_flag                   = exu_branch_taken ||
                                                                       exu_jump ||
                                                                       idu_mret ||
                                                                       idu_ecall;
    assign                              EXU_inst_clear              = exu_branch_taken ||
                                                                       exu_jump ||
                                                                       exu_fence_i ||
                                                                       IFU_stall;
    assign                              IFU_stall                   = IDU_valid && EXU_valid &&
                                                                       EXU_mem_ren &&
                                                                       (EXU_rd != 5'd0) &&
                                                                       ((IDU_uses_rs1 && (EXU_rd == IDU_rs1)) ||
                                                                        (IDU_uses_rs2 && (EXU_rd == IDU_rs2)));


    assign                              icache_clr                  = exu_fence_i;


    assign                              dnpc                        = exu_jump ? Ex_result :
                                                                       exu_branch_taken ? branch_pc :
                                                                       idu_mret ? mepc_out :
                                                                       mtvec_out;



    assign EXU_rs1_in = (IDU_rs1_choice == 2'b01)? Ex_result:
                        (IDU_rs1_choice == 2'b11)? MEM_Rdata:
                        (IDU_rs1_choice == 2'b10)? MEM_Ex_result:
                        IDU_rs1_value;

    assign EXU_rs2_in = (IDU_rs2_choice == 2'b01)? Ex_result:
                        (IDU_rs2_choice == 2'b11)? MEM_Rdata:
                        (IDU_rs2_choice == 2'b10)? MEM_Ex_result:
                        IDU_rs2_value;


Data_hazard Data_hazard_inst(
    .IDU_rs1                            (IDU_rs1                   ),
    .IDU_rs2                            (IDU_rs2                   ),
    .IDU_uses_rs1                       (IDU_uses_rs1              ),
    .IDU_uses_rs2                       (IDU_uses_rs2              ),

    .EXU_rd                             (EXU_rd                    ),
    .MEM_rd                             (MEM_rd                    ),

    .MEM_valid                          (MEM_valid                 ),
    .EXU_valid                          (EXU_valid                 ),
    .IDU_valid                          (IDU_valid                 ),

    .MEM_mem_ren                        (MEM_mem_ren               ),
    .EXU_R_Wen                          (EXU_R_Wen                 ),
    .MEM_R_Wen                          (MEM_R_Wen                 ),

    .IDU_rs1_choice                     (IDU_rs1_choice            ),
    .IDU_rs2_choice                     (IDU_rs2_choice            ) 
);

endmodule                                                           //PC_Control

