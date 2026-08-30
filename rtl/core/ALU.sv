`include "para.sv"
`timescale 1ns / 1ps

module ALU #(
    parameter                           BW                         = 32    
)
(
    input              [BW-1: 0]        d1                         ,
    input              [BW-1: 0]        d2                         ,
    input              [   4: 0]        choice                     ,
    output reg         [BW-1: 0]        res                         
);

    reg                                 choose_add_sub              ;
    wire               [BW-1: 0]        result                      ;
    wire               [BW-1: 0]        d2_inv                      ;
    wire               [BW-1: 0]        d1_inv                      ;
    // Use one shared product datapath for all four Zmmul operations.  The
    // leading zero makes an unsigned RV32 operand positive in the signed
    // multiply, while the sign extension preserves the signed forms.  A
    // single 33x33 product is enough for every RV32M high-half result and
    // avoids instantiating three parallel multiplier networks in the ALU.
    wire signed [BW:0] mul_d1 =
        (choice == `alu_mulhu) ? {1'b0, d1} : {d1[BW-1], d1};
    wire signed [BW:0] mul_d2 =
        ((choice == `alu_mulhsu) || (choice == `alu_mulhu)) ?
        {1'b0, d2} : {d2[BW-1], d2};
    wire signed [2*BW+1:0] mul_product = mul_d1 * mul_d2;

    // Packed signed two-lane dot product.  Each 16-bit lane is sign
    // extended before multiplication; the 33-bit sum covers the complete
    // mathematical range before the architectural 32-bit result is returned.
    wire signed [15:0] dot_d1_lo = d1[15:0];
    wire signed [15:0] dot_d1_hi = d1[31:16];
    wire signed [15:0] dot_d2_lo = d2[15:0];
    wire signed [15:0] dot_d2_hi = d2[31:16];
    wire signed [31:0] dot_product_lo = dot_d1_lo * dot_d2_lo;
    wire signed [31:0] dot_product_hi = dot_d1_hi * dot_d2_hi;
    wire signed [32:0] dot_sum = {{1{dot_product_lo[31]}}, dot_product_lo} +
                                  {{1{dot_product_hi[31]}}, dot_product_hi};

    // Rounded Q1.15 multiply with signed saturation.  The tie rule is
    // round-to-nearest with +0x4000 before the arithmetic shift, which is
    // deterministic and inexpensive in the single-cycle ALU.
    wire signed [31:0] q15_product = $signed(d1[15:0]) * $signed(d2[15:0]);
    wire signed [31:0] q15_rounded = (q15_product + 32'sd16384) >>> 15;
    wire signed [31:0] q15_sat = (q15_rounded > 32'sd32767) ? 32'sd32767 :
                                 (q15_rounded < -32'sd32768) ? -32'sd32768 :
                                 q15_rounded;
    assign                              d2_inv                      = ~d2;
    assign                              d1_inv                      = ~d1;

always@(*)
    begin
    res = 0;
    case(choice)
    `alu_signed_comparator:begin                      // 比较大小
            choose_add_sub = 1'b1;
            if(d1[BW-1] != d2[BW-1])
                begin
                    if(d1[BW-1] == 1'b1)
                        res[0] = 1;
                    else
                        res[0] = 0;
                end
            else
                begin
                    if(result[BW-1] == 1'b1)
                        res[0] = 1;
                    else
                        res[0] = 0;
                end
            end
    `alu_unsigned_comparator:begin
                choose_add_sub = 1'b0;
                if(d1 < d2)
                    res[0] = 1;
                else
                    res[0] = 0;
            end
    `alu_add: begin                                   //加法
            choose_add_sub = 1'b0;
            res =result;
            end
    `alu_sub: begin                                   //减法
            choose_add_sub = 1'b1;
            res =result;
            end
    `alu_and: begin                                   //�?
            res = d1 & d2;
            choose_add_sub = 1'b0;
            end
    `alu_andn: begin
            res = d1 & d2_inv;
            choose_add_sub = 1'b0;
            end
    `alu_or: begin                                    //�?
            res = d1 | d2;
            choose_add_sub = 1'b0;
            end
    `alu_xor: begin                                   //异或
            res = (d1 & d2_inv) | (d1_inv & d2) ;
            choose_add_sub = 1'b0;
            end
    `alu_equal:begin                                  //是否相等
            choose_add_sub = 1'b0;
            if(d1 != d2)
                res[0] =  1;
            else
                res[0] =  0;
            end
    `alu_sll:begin                                    //逻辑左移
            choose_add_sub = 1'b0;
            res = d1<<d2[4:0];
    end
    `alu_mul:begin
            choose_add_sub = 1'b0;
            res = mul_product[BW-1:0];
    end
    `alu_mulh:begin
            choose_add_sub = 1'b0;
            res = mul_product[2*BW-1:BW];
    end
    `alu_mulhsu:begin
            choose_add_sub = 1'b0;
            res = mul_product[2*BW-1:BW];
    end
    `alu_mulhu:begin
            choose_add_sub = 1'b0;
            res = mul_product[2*BW-1:BW];
    end
    `alu_dotp16:begin
            choose_add_sub = 1'b0;
            res = dot_sum[BW-1:0];
    end
    `alu_q15mul:begin
            choose_add_sub = 1'b0;
            res = q15_sat;
    end
/* verilator lint_off WIDTHTRUNC*/
    `alu_srl:begin                                    //逻辑右移
            choose_add_sub = 1'b0;
            res = {{{BW{1'b0}},d1}>>d2[4:0]};                       //[31:0];
    end
    `alu_sra:begin                                    //算术右移
            choose_add_sub = 1'b0;
            res = {{{BW{d1[BW-1]}},d1}>>d2[4:0]};                   //[31:0];
    end
    default:begin
            choose_add_sub = 1'b0;
            res = 0;
    end
    endcase
    
end

add
#(
    .BW                                 (BW                        ) 
)add_inst0
(
    .choose_add_sub                     (choose_add_sub            ),
    .add_1                              (d1                        ),
    .add_2                              (d2                        ),
    .add_2_inv                          (d2_inv                    ),
    .result                             (result                    ) 
);


endmodule
