`include "para.sv"
module RegisterFile #(ADDR_WIDTH = 32, DATA_WIDTH = 5) (
    input                        clock                        ,
    input              [DATA_WIDTH-1: 0]wdata               ,
    input              [ADDR_WIDTH-1: 0]waddr               ,
    input                        wen                        ,
    input                        reset                      ,
    input              [ADDR_WIDTH-1: 0]rs1_addr            ,
    input              [ADDR_WIDTH-1: 0]rs2_addr            ,

    output             [DATA_WIDTH-1: 0]rs1_value           ,
    output             [DATA_WIDTH-1: 0]rs2_value           ,
    output             [DATA_WIDTH-1: 0]a0_value             

);
    reg                [DATA_WIDTH-1: 0]rf        [2**ADDR_WIDTH-1:0]  ;
    integer i;
  always @(posedge clock) begin
    if (reset) begin
      for (i = 0; i < 2**ADDR_WIDTH; i = i + 1)
        rf[i] <= {DATA_WIDTH{1'b0}};
    end else if (wen && (waddr != 0)) begin
      rf[waddr] <= wdata;
    end
  end



    assign                       rs1_value                 = (rs1_addr == 0) ? 0 : rf[rs1_addr];
    assign                       rs2_value                 = (rs2_addr == 0) ? 0 : rf[rs2_addr];
    assign                       a0_value                  = rf[10];


endmodule
