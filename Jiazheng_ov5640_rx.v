module Jiazheng_ov5640_rx #(
	parameter BIT_CTRL     = 1'b1 ,//OV5640çš„å­—èŠ‚åœ°å?€ä¸º16ä½?  0:8ä½? 1:16ä½?
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
	output        cmos_xclk_o ,	//output clock to cmos sensor.å¦‚æžœä½ çš„æ‘„åƒ?å¤´è‡ªå¸¦æ™¶æŒ¯ï¼Œåˆ™æ­¤ä¿¡å?·ä¸?éœ€è¦?
    output        ov5640_hs   ,	
    output        ov5640_vs   ,
    output        ov5640_de   ,
    output [23:0] ov5640_rgb  ,	
	output        cfg_done    ,
    output        cam_rst_n   ,  //cmos å¤?ä½?ä¿¡å?·ï¼Œä½Žç”µå¹³æœ‰æ•ˆ
    output        cam_pwdn       //ç”µæº?ä¼‘çœ æ¨¡å¼?é€‰æ‹©	
);

wire        i2c_exec       ;  //I2Cè§¦å?‘æ‰§è¡Œä¿¡å?·
wire [23:0] i2c_data       ;  //I2Cè¦?é…?ç½®çš„åœ°å?€ä¸Žæ•°æ?®(é«˜8ä½?åœ°å?€,ä½Ž8ä½?æ•°æ?®)          
wire        i2c_done       ;  //I2Cå¯„å­˜å™¨é…?ç½®å®Œæˆ?ä¿¡å?·
wire        i2c_dri_clk    ;  //I2Cæ“?ä½œæ—¶é’Ÿ
wire [ 7:0] i2c_data_r     ;  //I2Cè¯»å‡ºçš„æ•°æ?®
wire        i2c_rh_wl      ;  //I2Cè¯»å†™æŽ§åˆ¶ä¿¡å?·

//ä¸?å¯¹æ‘„åƒ?å¤´ç¡¬ä»¶å¤?ä½?,å›ºå®šé«˜ç”µå¹³
assign  cam_rst_n = 1'b1;
//ç”µæº?ä¼‘çœ æ¨¡å¼?é€‰æ‹© 0ï¼šæ­£å¸¸æ¨¡å¼? 1ï¼šç”µæº?ä¼‘çœ æ¨¡å¼?
assign  cam_pwdn  = 1'b0;

//I2Cé…?ç½®æ¨¡å?—
i2c_ov5640_rgb565_cfg i2c_ov5640(
    .clk          (i2c_dri_clk ),
    .rst_n        (rst_n       ),            
    .i2c_exec     (i2c_exec    ),
    .i2c_data     (i2c_data    ),
    .i2c_rh_wl    (i2c_rh_wl   ),      //I2Cè¯»å†™æŽ§åˆ¶ä¿¡å?·
    .i2c_done     (i2c_done    ), 
    .i2c_data_r   (i2c_data_r  ),                  
    .cmos_h_pixel (IMAGE_WIDTH ),    //CMOSæ°´å¹³æ–¹å?‘åƒ?ç´ ä¸ªæ•°
    .cmos_v_pixel (IMAGE_HEIGHT),    //CMOSåž‚ç›´æ–¹å?‘åƒ?ç´ ä¸ªæ•°
    .total_h_pixel(2570        ),    //æ°´å¹³æ€»åƒ?ç´ å¤§å°?
    .total_v_pixel(980         ),    //åž‚ç›´æ€»åƒ?ç´ å¤§å°?       
    .init_done    (cfg_done    ) 
);    

//I2Cé©±åŠ¨æ¨¡å?—
i2c_dri #(
    .SLAVE_ADDR(DEVID   ),    //å?‚æ•°ä¼ é€’
    .CLK_FREQ  (25000000),              
    .I2C_FREQ  (250000  ) 
)u_i2c_driver(
    .clk                (clk_25m       ),
    .rst_n              (rst_n         ),
    .i2c_exec           (i2c_exec      ),   
    .bit_ctrl           (BIT_CTRL      ),   
    .i2c_rh_wl          (i2c_rh_wl     ),     //å›ºå®šä¸º0ï¼Œå?ªç”¨åˆ°äº†IICé©±åŠ¨çš„å†™æ“?ä½œ   
    .i2c_addr           (i2c_data[23:8]),   
    .i2c_data_w         (i2c_data[7:0] ),   
    .i2c_data_r         (i2c_data_r    ),   
    .i2c_done           (i2c_done      ),    
    .scl                (cmos_scl      ),   
    .sda                (cmos_sda      ),
    .dri_clk            (i2c_dri_clk   )       //I2Cæ“?ä½œæ—¶é’Ÿ
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
	.cmos_xclk_o (cmos_xclk_o ),//output clock to cmos sensor.å¦‚æžœä½ çš„æ‘„åƒ?å¤´è‡ªå¸¦æ™¶æŒ¯ï¼Œåˆ™æ­¤ä¿¡å?·ä¸?éœ€è¦?
    .rgb_o       (ov5640_rgb  ),
    .de_o        (ov5640_de   ),
    .vs_o        (ov5640_vs   ),
    .hs_o        (ov5640_hs   )
);

endmodule