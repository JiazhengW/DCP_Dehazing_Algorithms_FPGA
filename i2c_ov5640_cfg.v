`timescale 1ns / 1ps

module i2c_ov5640_cfg #(
    parameter CLK_DIV      = 499  , // Corresponds to a reference clock of 25MHz
    parameter DEVID        = 8'h78, // OV5640 Device ID is 8'h78
    parameter IMAGE_WIDTH  = 1280 ,
    parameter IMAGE_HEIGHT = 720
)(
    input      clk_i   ,
    input      rst_n   ,
    output     cmos_scl,
    inout      cmos_sda,
    output reg cfg_done
);

// Reset counter for initial delay time
reg [8:0] rst_cnt = 9'd0;
always@(posedge clk_i) begin
    if(!rst_n)
        rst_cnt <= 9'd0;
    else if(!rst_cnt[8])
        rst_cnt <= rst_cnt + 1'b1;
end

reg  iic_en;
wire iic_busy;
reg  [31:0] wr_data;
reg  [1 :0] TS_S = 2'd0; // State machine register
reg  [8 :0] byte_cnt = 9'd0;
wire [23:0] REG_DATA;
wire [8 :0] REG_SIZE;
reg  [8 :0] REG_INDEX;

// State machine to write configuration registers one by one
always@(posedge clk_i) begin
    if(!rst_cnt[8]) begin // Wait for the initial reset delay to complete
        REG_INDEX<= 9'd0;
        iic_en   <= 1'b0;
        wr_data  <= 32'd0;
        cfg_done <= 1'b0;
        TS_S     <= 2'd0;
    end
    else begin
        case(TS_S)
            0: // Idle state
                if(cfg_done == 1'b0)
                    TS_S <= 2'd1;
            1: // Prepare and start I2C write
                if(!iic_busy) begin
                    iic_en   <= 1'b1;
                    wr_data[7 :0] <= DEVID;           // ov5640 device ID
                    wr_data[15:8] <= REG_DATA[23:16]; // Register Address HIGH byte
                    wr_data[23:16]<= REG_DATA[15:8];  // Register Address LOW byte
                    wr_data[31:24]<= REG_DATA[7:0];   // Register Data
                end
                else
                    TS_S     <= 2'd2;
            2: // Wait for I2C write to finish
                begin
                    iic_en   <= 1'b0;
                    if(!iic_busy) begin
                        REG_INDEX <= REG_INDEX + 1'b1; // Move to the next register
                        TS_S      <= 2'd3;
                    end
                end
            3: // Check for completion
                begin
                    if(REG_INDEX == REG_SIZE) begin
                        cfg_done <= 1'b1; // All registers have been configured
                    end
                    TS_S    <= 2'd0; // Return to idle state
                end
        endcase
    end
end

uii2c#
(
    .WMEN_LEN(5),
    .RMEN_LEN(1),
    .CLK_DIV(CLK_DIV) // 499 for 25MHz -> 50kHz SCL, adjust as needed
)
uii2c_inst
(
    .clk_i(clk_i),
    .iic_scl(cmos_scl),
    .iic_sda(cmos_sda),
    .wr_data(wr_data),
    .wr_cnt(8'd4),   // Write data length = 4 BYTES (ID, Addr_H, Addr_L, Data)
    .rd_data(),      // Read not used
    .rd_cnt(8'd0),   // Read not used
    .iic_mode(1'b0),
    .iic_en(iic_en),
    .iic_busy(iic_busy)
);

// OV5640 Register Table
ui5640reg#(
    .IMAGE_WIDTH (IMAGE_WIDTH ),
    .IMAGE_HEIGHT(IMAGE_HEIGHT),
    .IMAGE_FLIP(8'h40),
    .IMAGE_MIRROR(4'h7)
)
ui5640reg_inst(
    .REG_SIZE(REG_SIZE),
    .REG_INDEX(REG_INDEX),
    .REG_DATA(REG_DATA)
);

endmodule
