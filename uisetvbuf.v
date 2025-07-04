`timescale 1ns / 1ps

module uisetvbuf#(
parameter  integer                  BUF_DELAY     = 1,
parameter  integer                  BUF_LENTH     = 3
)
(

input      [7   :0]                 bufn_i,
output     [7   :0]                 bufn_o
);    

assign bufn_o = (bufn_i+(BUF_LENTH-1'b1-BUF_DELAY))%BUF_LENTH;


endmodule

