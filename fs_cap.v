`timescale 1ns / 1ps

module fs_cap#(
parameter  integer  VIDEO_ENABLE   = 1
)
(
input  clk_i,
input  rstn_i,
input  vs_i,
output reg fs_cap_o
);
    
//----CH0_CNT_FS�źŵ�ƽ���� ʵ�ʾ��ǲ���VS�ź�----------------
reg[4:0]CNT_FS   = 6'b0;
reg[4:0]CNT_FS_n = 6'b0;
reg     FS       = 1'b0;
reg vs_i_r1;
reg vs_i_r2;
reg vs_i_r3;
reg vs_i_r4;
//----ͬ�����ε�·��֮ǰ����û�����ε�·�������ǲɼ�vs����-----
always@(posedge clk_i) begin
      vs_i_r1 <= vs_i;
      vs_i_r2 <= vs_i_r1;
      vs_i_r3 <= vs_i_r2;
      vs_i_r4 <= vs_i_r3;
end

always@(posedge clk_i) begin
   if(!rstn_i)begin
      fs_cap_o <= 1'd0;
   end
   else if(VIDEO_ENABLE == 1)begin
      if({vs_i_r4,vs_i_r3} == 2'b01)begin
         fs_cap_o <= 1'b1;
      end
      else begin
         fs_cap_o <= 1'b0;
      end
   end 
   else begin
         fs_cap_o <= vs_i_r4;
   end
end
        
endmodule
