/* Deal with the Data hazard */

module Data_hazard(
    input              [   4: 0] IDU_rs1                    ,
    input              [   4: 0] IDU_rs2                    ,
    input                        IDU_uses_rs1               ,
    input                        IDU_uses_rs2               ,

    input              [   4: 0] EXU_rd                     ,
    input              [   4: 0] MEM_rd                     ,

    input                        IDU_valid                  ,
    input                        EXU_valid                  ,
    input                        MEM_valid                  ,

    input                        MEM_mem_ren                ,
    input                        EXU_R_Wen                  ,
    input                        MEM_R_Wen                  ,

    output             [   1: 0] IDU_rs1_choice             ,
    output             [   1: 0] IDU_rs2_choice              
);

/*
 * Forwarding is only meaningful for an instruction that is actually in the
 * decode stage and for producer stages carrying a valid instruction.  The
 * pipeline registers intentionally retain their data while a bubble is
 * present, so omitting these valid checks can forward an old rd/control bit.
 */
wire exu_rs1_match = IDU_valid && IDU_uses_rs1 && EXU_valid && EXU_R_Wen &&
                     (EXU_rd != 5'd0) && (EXU_rd == IDU_rs1);
wire mem_rs1_match = IDU_valid && IDU_uses_rs1 && MEM_valid && MEM_R_Wen &&
                     (MEM_rd != 5'd0) && (MEM_rd == IDU_rs1);
wire exu_rs2_match = IDU_valid && IDU_uses_rs2 && EXU_valid && EXU_R_Wen &&
                     (EXU_rd != 5'd0) && (EXU_rd == IDU_rs2);
wire mem_rs2_match = IDU_valid && IDU_uses_rs2 && MEM_valid && MEM_R_Wen &&
                     (MEM_rd != 5'd0) && (MEM_rd == IDU_rs2);

assign IDU_rs1_choice = exu_rs1_match ? 2'b01 :
                        mem_rs1_match ? (MEM_mem_ren ? 2'b11 : 2'b10) :
                        2'b00;

assign IDU_rs2_choice = exu_rs2_match ? 2'b01 :
                        mem_rs2_match ? (MEM_mem_ren ? 2'b11 : 2'b10) :
                        2'b00;

endmodule                                                           //Aribter

