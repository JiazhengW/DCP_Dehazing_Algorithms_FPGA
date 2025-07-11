module i2c_ov5640_rgb565_cfg
   (
    input               clk          ,  // Clock signal
    input               rst_n        ,  // Reset signal, active low

    input        [7:0]  i2c_data_r   ,  // Data read from I2C
    input               i2c_done     ,  // I2C register configuration complete signal
    input        [12:0] cmos_h_pixel ,  // CMOS horizontal active pixels
    input        [12:0] cmos_v_pixel ,  // CMOS vertical active pixels
    input        [12:0] total_h_pixel,  // Total horizontal pixels
    input        [12:0] total_v_pixel,  // Total vertical pixels
    output   reg        i2c_exec     ,  // I2C execution trigger signal
    output   reg [23:0] i2c_data     ,  // Address and data to be configured via I2C (16-bit address, 8-bit data)
    output   reg        i2c_rh_wl    ,  // I2C read/write control signal
    output   reg        init_done      // Initialization complete signal
    );

//parameter define
localparam  REG_NUM = 8'd250  ;      // Total number of registers to configure

//reg define
reg   [12:0]  start_init_cnt;      // Delay counter for waiting
reg    [7:0]  init_reg_cnt  ;      // Register configuration count

//*****************************************************
//** main code
//*****************************************************

// Configure clock to 250kHz, period is 4us. 5000 * 4us = 20ms
// Wait at least 20ms after OV5640 power-on before starting I2C configuration
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        start_init_cnt <= 13'b0;
    else if(start_init_cnt < 13'd5000) begin
        start_init_cnt <= start_init_cnt + 1'b1;
    end
end

// Register configuration counter
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        init_reg_cnt <= 8'd0;
    else if(i2c_exec)
        init_reg_cnt <= init_reg_cnt + 8'b1;
end

// I2C execution trigger signal
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        i2c_exec <= 1'b0;
    else if(start_init_cnt == 13'd4999)
        i2c_exec <= 1'b1;
    else if(i2c_done && (init_reg_cnt < REG_NUM))
        i2c_exec <= 1'b1;
    else
        i2c_exec <= 1'b0;
end

// Configure I2C read/write control signal
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        i2c_rh_wl <= 1'b1; // Default to write
    else if(init_reg_cnt == 8'd2)
        i2c_rh_wl <= 1'b0; // Switch to read for specific operation if needed
end

// Initialization complete signal
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        init_done <= 1'b0;
    else if((init_reg_cnt == REG_NUM) && i2c_done)
        init_done <= 1'b1;
end

// Configure register address and data
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        i2c_data <= 24'b0;
    else begin
        case(init_reg_cnt)
            // First, perform a software reset on the registers to restore them to their initial values.
            // After a software reset, a delay of 1ms is required before configuring other registers.
            8'd0  : i2c_data <= {16'h300a,8'h0}; //
            8'd1  : i2c_data <= {16'h300b,8'h0}; //
            8'd2  : i2c_data <= {16'h3008,8'h82}; // Bit[7]:Reset, Bit[6]:Power down
            8'd3  : i2c_data <= {16'h3008,8'h02}; // Normal working mode
            8'd4  : i2c_data <= {16'h3103,8'h02}; // Bit[1]:1 PLL Clock
            // Pin input/output control FREX/VSYNC/HREF/PCLK/D[9:6]
            8'd5  : i2c_data <= {16'h3017,8'hff};
            // Pin input/output control D[5:0]/GPIO1/GPIO0
            8'd6  : i2c_data <= {16'h3018,8'hff};
            8'd7  : i2c_data <= {16'h3037,8'h13}; // PLL division control
            8'd8  : i2c_data <= {16'h3108,8'h01}; // System root divider
            8'd9  : i2c_data <= {16'h3630,8'h36};
            8'd10 : i2c_data <= {16'h3631,8'h0e};
            8'd11 : i2c_data <= {16'h3632,8'he2};
            8'd12 : i2c_data <= {16'h3633,8'h12};
            8'd13 : i2c_data <= {16'h3621,8'he0};
            8'd14 : i2c_data <= {16'h3704,8'ha0};
            8'd15 : i2c_data <= {16'h3703,8'h5a};
            8'd16 : i2c_data <= {16'h3715,8'h78};
            8'd17 : i2c_data <= {16'h3717,8'h01};
            8'd18 : i2c_data <= {16'h370b,8'h60};
            8'd19 : i2c_data <= {16'h3705,8'h1a};
            8'd20 : i2c_data <= {16'h3905,8'h02};
            8'd21 : i2c_data <= {16'h3906,8'h10};
            8'd22 : i2c_data <= {16'h3901,8'h0a};
            8'd23 : i2c_data <= {16'h3731,8'h12};
            8'd24 : i2c_data <= {16'h3600,8'h08}; // VCM control, for auto-focus
            8'd25 : i2c_data <= {16'h3601,8'h33}; // VCM control, for auto-focus
            8'd26 : i2c_data <= {16'h302d,8'h60}; // System control
            8'd27 : i2c_data <= {16'h3620,8'h52};
            8'd28 : i2c_data <= {16'h371b,8'h20};
            8'd29 : i2c_data <= {16'h471c,8'h50};
            8'd30 : i2c_data <= {16'h3a13,8'h43}; // AEC (Auto Exposure Control)
            8'd31 : i2c_data <= {16'h3a18,8'h00}; // AEC gain upper limit
            8'd32 : i2c_data <= {16'h3a19,8'hf8}; // AEC gain upper limit
            8'd33 : i2c_data <= {16'h3635,8'h13};
            8'd34 : i2c_data <= {16'h3636,8'h03};
            8'd35 : i2c_data <= {16'h3634,8'h40};
            8'd36 : i2c_data <= {16'h3622,8'h01};
            8'd37 : i2c_data <= {16'h3c01,8'h34};
            8'd38 : i2c_data <= {16'h3c04,8'h28};
            8'd39 : i2c_data <= {16'h3c05,8'h98};
            8'd40 : i2c_data <= {16'h3c06,8'h00}; // light meter 1 threshold [15:8]
            8'd41 : i2c_data <= {16'h3c07,8'h08}; // light meter 1 threshold [7:0]
            8'd42 : i2c_data <= {16'h3c08,8'h00}; // light meter 2 threshold [15:8]
            8'd43 : i2c_data <= {16'h3c09,8'h1c}; // light meter 2 threshold [7:0]
            8'd44 : i2c_data <= {16'h3c0a,8'h9c}; // sample number [15:8]
            8'd45 : i2c_data <= {16'h3c0b,8'h40}; // sample number [7:0]
            8'd46 : i2c_data <= {16'h3810,8'h00}; // Timing Hoffset [11:8]
            8'd47 : i2c_data <= {16'h3811,8'h10}; // Timing Hoffset [7:0]
            8'd48 : i2c_data <= {16'h3812,8'h00}; // Timing Voffset [10:8]
            8'd49 : i2c_data <= {16'h3708,8'h64};
            8'd50 : i2c_data <= {16'h4001,8'h02}; // BLC (Black Level Calibration) compensation start line number
            8'd51 : i2c_data <= {16'h4005,8'h1a}; // BLC (Black Level Calibration) always update
            8'd52 : i2c_data <= {16'h3000,8'h00}; // System block reset control
            8'd53 : i2c_data <= {16'h3004,8'hff}; // Clock enable control
            8'd54 : i2c_data <= {16'h4300,8'h61}; // Format control RGB565
            8'd55 : i2c_data <= {16'h501f,8'h01}; // ISP RGB
            8'd56 : i2c_data <= {16'h440e,8'h00};
            8'd57 : i2c_data <= {16'h5000,8'ha7}; // ISP control
            8'd58 : i2c_data <= {16'h3a0f,8'h30}; // AEC control; stable range in high
            8'd59 : i2c_data <= {16'h3a10,8'h28}; // AEC control; stable range in low
            8'd60 : i2c_data <= {16'h3a1b,8'h30}; // AEC control; stable range out high
            8'd61 : i2c_data <= {16'h3a1e,8'h26}; // AEC control; stable range out low
            8'd62 : i2c_data <= {16'h3a11,8'h60}; // AEC control; fast zone high
            8'd63 : i2c_data <= {16'h3a1f,8'h14}; // AEC control; fast zone low
            // LENC (Lens Correction) control 16'h5800~16'h583d
            8'd64 : i2c_data <= {16'h5800,8'h23};
            8'd65 : i2c_data <= {16'h5801,8'h14};
            8'd66 : i2c_data <= {16'h5802,8'h0f};
            8'd67 : i2c_data <= {16'h5803,8'h0f};
            8'd68 : i2c_data <= {16'h5804,8'h12};
            8'd69 : i2c_data <= {16'h5805,8'h26};
            8'd70 : i2c_data <= {16'h5806,8'h0c};
            8'd71 : i2c_data <= {16'h5807,8'h08};
            8'd72 : i2c_data <= {16'h5808,8'h05};
            8'd73 : i2c_data <= {16'h5809,8'h05};
            8'd74 : i2c_data <= {16'h580a,8'h08};
            8'd75 : i2c_data <= {16'h580b,8'h0d};
            8'd76 : i2c_data <= {16'h580c,8'h08};
            8'd77 : i2c_data <= {16'h580d,8'h03};
            8'd78 : i2c_data <= {16'h580e,8'h00};
            8'd79 : i2c_data <= {16'h580f,8'h00};
            8'd80 : i2c_data <= {16'h5810,8'h03};
            8'd81 : i2c_data <= {16'h5811,8'h09};
            8'd82 : i2c_data <= {16'h5812,8'h07};
            8'd83 : i2c_data <= {16'h5813,8'h03};
            8'd84 : i2c_data <= {16'h5814,8'h00};
            8'd85 : i2c_data <= {16'h5815,8'h01};
            8'd86 : i2c_data <= {16'h5816,8'h03};
            8'd87 : i2c_data <= {16'h5817,8'h08};
            8'd88 : i2c_data <= {16'h5818,8'h0d};
            8'd89 : i2c_data <= {16'h5819,8'h08};
            8'd90 : i2c_data <= {16'h581a,8'h05};
            8'd91 : i2c_data <= {16'h581b,8'h06};
            8'd92 : i2c_data <= {16'h581c,8'h08};
            8'd93 : i2c_data <= {16'h581d,8'h0e};
            8'd94 : i2c_data <= {16'h581e,8'h29};
            8'd95 : i2c_data <= {16'h581f,8'h17};
            8'd96 : i2c_data <= {16'h5820,8'h11};
            8'd97 : i2c_data <= {16'h5821,8'h11};
            8'd98 : i2c_data <= {16'h5822,8'h15};
            8'd99 : i2c_data <= {16'h5823,8'h28};
            8'd100: i2c_data <= {16'h5824,8'h46};
            8'd101: i2c_data <= {16'h5825,8'h26};
            8'd102: i2c_data <= {16'h5826,8'h08};
            8'd103: i2c_data <= {16'h5827,8'h26};
            8'd104: i2c_data <= {16'h5828,8'h64};
            8'd105: i2c_data <= {16'h5829,8'h26};
            8'd106: i2c_data <= {16'h582a,8'h24};
            8'd107: i2c_data <= {16'h582b,8'h22};
            8'd108: i2c_data <= {16'h582c,8'h24};
            8'd109: i2c_data <= {16'h582d,8'h24};
            8'd110: i2c_data <= {16'h582e,8'h06};
            8'd111: i2c_data <= {16'h582f,8'h22};
            8'd112: i2c_data <= {16'h5830,8'h40};
            8'd113: i2c_data <= {16'h5831,8'h42};
            8'd114: i2c_data <= {16'h5832,8'h24};
            8'd115: i2c_data <= {16'h5833,8'h26};
            8'd116: i2c_data <= {16'h5834,8'h24};
            8'd117: i2c_data <= {16'h5835,8'h22};
            8'd118: i2c_data <= {16'h5836,8'h22};
            8'd119: i2c_data <= {16'h5837,8'h26};
            8'd120: i2c_data <= {16'h5838,8'h44};
            8'd121: i2c_data <= {16'h5839,8'h24};
            8'd122: i2c_data <= {16'h583a,8'h26};
            8'd123: i2c_data <= {16'h583b,8'h28};
            8'd124: i2c_data <= {16'h583c,8'h42};
            8'd125: i2c_data <= {16'h583d,8'hce};
            // AWB (Auto White Balance) control 16'h5180~16'h519e
            8'd126: i2c_data <= {16'h5180,8'hff};
            8'd127: i2c_data <= {16'h5181,8'hf2};
            8'd128: i2c_data <= {16'h5182,8'h00};
            8'd129: i2c_data <= {16'h5183,8'h14};
            8'd130: i2c_data <= {16'h5184,8'h25};
            8'd131: i2c_data <= {16'h5185,8'h24};
            8'd132: i2c_data <= {16'h5186,8'h09};
            8'd133: i2c_data <= {16'h5187,8'h09};
            8'd134: i2c_data <= {16'h5188,8'h09};
            8'd135: i2c_data <= {16'h5189,8'h75};
            8'd136: i2c_data <= {16'h518a,8'h54};
            8'd137: i2c_data <= {16'h518b,8'he0};
            8'd138: i2c_data <= {16'h518c,8'hb2};
            8'd139: i2c_data <= {16'h518d,8'h42};
            8'd140: i2c_data <= {16'h518e,8'h3d};
            8'd141: i2c_data <= {16'h518f,8'h56};
            8'd142: i2c_data <= {16'h5190,8'h46};
            8'd143: i2c_data <= {16'h5191,8'hf8};
            8'd144: i2c_data <= {16'h5192,8'h04};
            8'd145: i2c_data <= {16'h5193,8'h70};
            8'd146: i2c_data <= {16'h5194,8'hf0};
            8'd147: i2c_data <= {16'h5195,8'hf0};
            8'd148: i2c_data <= {16'h5196,8'h03};
            8'd149: i2c_data <= {16'h5197,8'h01};
            8'd150: i2c_data <= {16'h5198,8'h04};
            8'd151: i2c_data <= {16'h5199,8'h12};
            8'd152: i2c_data <= {16'h519a,8'h04};
            8'd153: i2c_data <= {16'h519b,8'h00};
            8'd154: i2c_data <= {16'h519c,8'h06};
            8'd155: i2c_data <= {16'h519d,8'h82};
            8'd156: i2c_data <= {16'h519e,8'h38};
            // Gamma control 16'h5480~16'h5490
            8'd157: i2c_data <= {16'h5480,8'h01};
            8'd158: i2c_data <= {16'h5481,8'h08};
            8'd159: i2c_data <= {16'h5482,8'h14};
            8'd160: i2c_data <= {16'h5483,8'h28};
            8'd161: i2c_data <= {16'h5484,8'h51};
            8'd162: i2c_data <= {16'h5485,8'h65};
            8'd163: i2c_data <= {16'h5486,8'h71};
            8'd164: i2c_data <= {16'h5487,8'h7d};
            8'd165: i2c_data <= {16'h5488,8'h87};
            8'd166: i2c_data <= {16'h5489,8'h91};
            8'd167: i2c_data <= {16'h548a,8'h9a};
            8'd168: i2c_data <= {16'h548b,8'haa};
            8'd169: i2c_data <= {16'h548c,8'hb8};
            8'd170: i2c_data <= {16'h548d,8'hcd};
            8'd171: i2c_data <= {16'h548e,8'hdd};
            8'd172: i2c_data <= {16'h548f,8'hea};
            8'd173: i2c_data <= {16'h5490,8'h1d};
            // CMX (Color Matrix) control 16'h5381~16'h538b
            8'd174: i2c_data <= {16'h5381,8'h1e};
            8'd175: i2c_data <= {16'h5382,8'h5b};
            8'd176: i2c_data <= {16'h5383,8'h08};
            8'd177: i2c_data <= {16'h5384,8'h0a};
            8'd178: i2c_data <= {16'h5385,8'h7e};
            8'd179: i2c_data <= {16'h5386,8'h88};
            8'd180: i2c_data <= {16'h5387,8'h7c};
            8'd181: i2c_data <= {16'h5388,8'h6c};
            8'd182: i2c_data <= {16'h5389,8'h10};
            8'd183: i2c_data <= {16'h538a,8'h01};
            8'd184: i2c_data <= {16'h538b,8'h98};
            // SDE (Special Digital Effects) control 16'h5580~16'h558b
            8'd185: i2c_data <= {16'h5580,8'h06};
            8'd186: i2c_data <= {16'h5583,8'h40};
            8'd187: i2c_data <= {16'h5584,8'h10};
            8'd188: i2c_data <= {16'h5589,8'h10};
            8'd189: i2c_data <= {16'h558a,8'h00};
            8'd190: i2c_data <= {16'h558b,8'hf8};
            8'd191: i2c_data <= {16'h501d,8'h40}; // ISP MISC
            // CIP (Color Interpolation) control (16'h5300~16'h530c)
            8'd192: i2c_data <= {16'h5300,8'h08};
            8'd193: i2c_data <= {16'h5301,8'h30};
            8'd194: i2c_data <= {16'h5302,8'h10};
            8'd195: i2c_data <= {16'h5303,8'h00};
            8'd196: i2c_data <= {16'h5304,8'h08};
            8'd197: i2c_data <= {16'h5305,8'h30};
            8'd198: i2c_data <= {16'h5306,8'h08};
            8'd199: i2c_data <= {16'h5307,8'h16};
            8'd200: i2c_data <= {16'h5309,8'h08};
            8'd201: i2c_data <= {16'h530a,8'h30};
            8'd202: i2c_data <= {16'h530b,8'h04};
            8'd203: i2c_data <= {16'h530c,8'h06};
            8'd204: i2c_data <= {16'h5025,8'h00};
            // System clock divider Bit[7:4]: system clock divider, input clock = 24MHz, PCLK = 48MHz
            8'd205: i2c_data <= {16'h3035,8'h11};
            8'd206: i2c_data <= {16'h3036,8'h3c}; // PLL multiplier
            8'd207: i2c_data <= {16'h3c07,8'h08};
            // Timing control 16'h3800~16'h3821
            8'd208: i2c_data <= {16'h3820,8'h46};
            8'd209: i2c_data <= {16'h3821,8'h01};
            8'd210: i2c_data <= {16'h3814,8'h31};
            8'd211: i2c_data <= {16'h3815,8'h31};
            8'd212: i2c_data <= {16'h3800,8'h00};
            8'd213: i2c_data <= {16'h3801,8'h00};
            8'd214: i2c_data <= {16'h3802,8'h00};
            8'd215: i2c_data <= {16'h3803,8'h04};
            8'd216: i2c_data <= {16'h3804,8'h0a};
            8'd217: i2c_data <= {16'h3805,8'h3f};
            8'd218: i2c_data <= {16'h3806,8'h07};
            8'd219: i2c_data <= {16'h3807,8'h9b};
            // Set output pixel count
            // DVP output horizontal pixels high 4 bits
            8'd220: i2c_data <= {16'h3808,{4'd0,cmos_h_pixel[11:8]}};
            // DVP output horizontal pixels low 8 bits
            8'd221: i2c_data <= {16'h3809,cmos_h_pixel[7:0]};
            // DVP output vertical pixels high 3 bits
            8'd222: i2c_data <= {16'h380a,{5'd0,cmos_v_pixel[10:8]}};
            // DVP output vertical pixels low 8 bits
            8'd223: i2c_data <= {16'h380b,cmos_v_pixel[7:0]};
            // Total horizontal pixels high 5 bits
            8'd224: i2c_data <= {16'h380c,{3'd0,total_h_pixel[12:8]}};
            // Total horizontal pixels low 8 bits
            8'd225: i2c_data <= {16'h380d,total_h_pixel[7:0]};
            // Total vertical pixels high 5 bits
            8'd226: i2c_data <= {16'h380e,{3'd0,total_v_pixel[12:8]}};
            // Total vertical pixels low 8 bits
            8'd227: i2c_data <= {16'h380f,total_v_pixel[7:0]};
            8'd228: i2c_data <= {16'h3813,8'h06};
            8'd229: i2c_data <= {16'h3618,8'h00};
            8'd230: i2c_data <= {16'h3612,8'h29};
            8'd231: i2c_data <= {16'h3709,8'h52};
            8'd232: i2c_data <= {16'h370c,8'h03};
            8'd233: i2c_data <= {16'h3a02,8'h17}; // 60Hz max exposure
            8'd234: i2c_data <= {16'h3a03,8'h10}; // 60Hz max exposure
            8'd235: i2c_data <= {16'h3a14,8'h17}; // 50Hz max exposure
            8'd236: i2c_data <= {16'h3a15,8'h10}; // 50Hz max exposure
            8'd237: i2c_data <= {16'h4004,8'h02}; // BLC (Backlight Compensation) 2 lines
            8'd238: i2c_data <= {16'h4713,8'h03}; // JPEG mode 3
            8'd239: i2c_data <= {16'h4407,8'h04}; // Quantization scale
            8'd240: i2c_data <= {16'h460c,8'h22};
            8'd241: i2c_data <= {16'h4837,8'h22}; // DVP CLK divider
            8'd242: i2c_data <= {16'h3824,8'h02}; // DVP CLK divider
            8'd243: i2c_data <= {16'h5001,8'ha3}; // ISP Control
            8'd244: i2c_data <= {16'h3b07,8'h0a}; // Frame exposure mode
            // Color bar test enable
            8'd245: i2c_data <= {16'h503d,8'h00}; // 8'h00: normal mode, 8'h80: color bar display
            // Test flash function
            8'd246: i2c_data <= {16'h3016,8'h02};
            8'd247: i2c_data <= {16'h301c,8'h02};
            8'd248: i2c_data <= {16'h3019,8'h02}; // Turn on flash
            8'd249: i2c_data <= {16'h3019,8'h00}; // Turn off flash
            // Read-only memory, to prevent previous registers from being rewritten in cases not listed.
            default : i2c_data <= {16'h300a,8'h00}; // Device ID high 8 bits
        endcase
    end
end

endmodule
