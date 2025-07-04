module Jiazheng_ov5640_rx #(
	parameter BIT_CTRL     = 1'b1 ,//OV5640的字节地�?�为16�?  0:8�? 1:16�?
	parameter DEVID        = 8'h78,//8'h78 
	parameter IMAGE_WIDTH  = 1280 ,
	parameter IMAGE_HEIGHT = 720  ,
	parameter RGB_TYPE     = 0	//0-->RGB565  1-->RGB888	
)(
	input         clk_25m     ,
	input         rst_n       ,
	output        cmos_scl    ,
	inout         cmos_sda    ,
	input         cmos_pclk_i ,	//input pixel clock.
	input         cmos_href_i ,	//input pixel hs signal.
	input         cmos_vsync_i,	//input pixel vs signal.
	input  [7:0]  cmos_data_i ,	//data.
	output        cmos_xclk_o ,	//output clock to cmos sensor.如果你的摄�?头自带晶振，则此信�?��?需�?
    output        ov5640_hs   ,	
    output        ov5640_vs   ,
    output        ov5640_de   ,
    output [23:0] ov5640_rgb  ,	
	output        cfg_done    ,
    output        cam_rst_n   ,  //cmos �?�?信�?�，低电平有效
    output        cam_pwdn       //电�?休眠模�?选择	
);

wire        i2c_exec       ;  //I2C触�?�执行信�?�
wire [23:0] i2c_data       ;  //I2C�?�?置的地�?�与数�?�(高8�?地�?�,低8�?数�?�)          
wire        i2c_done       ;  //I2C寄存器�?置完�?信�?�
wire        i2c_dri_clk    ;  //I2C�?作时钟
wire [ 7:0] i2c_data_r     ;  //I2C读出的数�?�
wire        i2c_rh_wl      ;  //I2C读写控制信�?�

//�?对摄�?头硬件�?�?,固定高电平
assign  cam_rst_n = 1'b1;
//电�?休眠模�?选择 0：正常模�? 1：电�?休眠模�?
assign  cam_pwdn  = 1'b0;

//I2C�?置模�?�
i2c_ov5640_rgb565_cfg i2c_ov5640(
    .clk          (i2c_dri_clk ),
    .rst_n        (rst_n       ),            
    .i2c_exec     (i2c_exec    ),
    .i2c_data     (i2c_data    ),
    .i2c_rh_wl    (i2c_rh_wl   ),      //I2C读写控制信�?�
    .i2c_done     (i2c_done    ), 
    .i2c_data_r   (i2c_data_r  ),                  
    .cmos_h_pixel (IMAGE_WIDTH ),    //CMOS水平方�?��?素个数
    .cmos_v_pixel (IMAGE_HEIGHT),    //CMOS垂直方�?��?素个数
    .total_h_pixel(2570        ),    //水平总�?素大�?
    .total_v_pixel(980         ),    //垂直总�?素大�?       
    .init_done    (cfg_done    ) 
);    

//I2C驱动模�?�
i2c_dri #(
    .SLAVE_ADDR(DEVID   ),    //�?�数传递
    .CLK_FREQ  (25000000),              
    .I2C_FREQ  (250000  ) 
)u_i2c_driver(
    .clk                (clk_25m       ),
    .rst_n              (rst_n         ),
    .i2c_exec           (i2c_exec      ),   
    .bit_ctrl           (BIT_CTRL      ),   
    .i2c_rh_wl          (i2c_rh_wl     ),     //固定为0，�?�用到了IIC驱动的写�?作   
    .i2c_addr           (i2c_data[23:8]),   
    .i2c_data_w         (i2c_data[7:0] ),   
    .i2c_data_r         (i2c_data_r    ),   
    .i2c_done           (i2c_done      ),    
    .scl                (cmos_scl      ),   
    .sda                (cmos_sda      ),
    .dri_clk            (i2c_dri_clk   )       //I2C�?作时钟
);

ov5640_rx #(
	.RGB_TYPE (RGB_TYPE)	//0-->RGB565  1-->RGB888
)u_ov5640_rx(
    .rstn_i      (cfg_done    ),
	.cmos_clk_i  (clk_25m     ),//cmos senseor clock.
	.cmos_pclk_i (cmos_pclk_i ),//input pixel clock.
	.cmos_href_i (cmos_href_i ),//input pixel hs signal.
	.cmos_vsync_i(cmos_vsync_i),//input pixel vs signal.
	.cmos_data_i (cmos_data_i ),//data.
	.cmos_xclk_o (cmos_xclk_o ),//output clock to cmos sensor.如果你的摄�?头自带晶振，则此信�?��?需�?
    .rgb_o       (ov5640_rgb  ),
    .de_o        (ov5640_de   ),
    .vs_o        (ov5640_vs   ),
    .hs_o        (ov5640_hs   )
);

endmodule