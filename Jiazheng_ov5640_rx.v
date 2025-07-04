`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
// Module:      Jiazheng_ov5640_rx
// Author:      Jiazheng
// Description: This top-level module encapsulates all the logic required to 
//              interface with an OV5640 CMOS image sensor. It handles two main
//              tasks:
//              1. Initializes the sensor via I2C upon reset.
//              2. Captures the parallel DVP video stream from the sensor and
//                 converts it into a standard format with HS, VS, and DE sync.
//
//////////////////////////////////////////////////////////////////////////////////

module Jiazheng_ov5640_rx #(
    // Parameters
    parameter BIT_CTRL     = 1'b1,  // OV5640 register address width. 0: 8-bit, 1: 16-bit.
    parameter DEVID        = 8'h78, // I2C slave device ID for the OV5640 sensor.
    parameter IMAGE_WIDTH  = 1280,  // Active video width in pixels.
    parameter IMAGE_HEIGHT = 720,   // Active video height in pixels.
    parameter RGB_TYPE     = 0      // Output format. 0: RGB565, 1: RGB888.
)(
    // I/O Ports
    //-- System-level signals
    input  wire        clk_25m,    // 25MHz input clock for I2C and XCLK generation.
    input  wire        rst_n,      // Active-low asynchronous reset.

    //-- I2C Interface to camera
    output wire        cmos_scl,   // I2C clock signal to the camera.
    inout  wire        cmos_sda,   // I2C data signal to the camera.
    
    //-- DVP (Digital Video Port) Input from camera
    input  wire        cmos_pclk_i, // Input pixel clock from the camera.
    input  wire        cmos_href_i, // Input horizontal reference (line valid) from the camera.
    input  wire        cmos_vsync_i,// Input vertical sync from the camera.
    input  wire [7:0]  cmos_data_i, // Input 8-bit parallel video data from the camera.
    
    //-- Camera Control Outputs
    output wire        cmos_xclk_o, // Output clock (XCLK) to drive the camera sensor.
    output wire        cam_rst_n,   // Camera hardware reset signal (active-low).
    output wire        cam_pwdn,    // Camera power-down signal.
    
    //-- Standardized Video Output
    output wire        ov5640_hs,   // Generated Horizontal Sync output.
    output wire        ov5640_vs,   // Generated Vertical Sync output.
    output wire        ov5640_de,   // Generated Data Enable (active video) output.
    output wire [23:0] ov5640_rgb,  // 24-bit RGB pixel data output.

    //-- Status
    output wire        cfg_done     // Flag indicates that the I2C configuration is complete.
);

// Internal wire declarations for connecting sub-modules
wire        i2c_exec;       // Trigger signal to execute an I2C transaction.
wire [23:0] i2c_data;       // Combined I2C register address and data bus.
wire        i2c_done;       // Signal indicating one I2C transaction has finished.
wire        i2c_dri_clk;    // Clock for the I2C driver logic.
wire [ 7:0] i2c_data_r;     // Data read back from the I2C bus.
wire        i2c_rh_wl;      // I2C read/write control signal.

// Tie-off for camera hardware control signals
assign cam_rst_n = 1'b1;    // De-assert camera reset (keep it out of reset).
assign cam_pwdn  = 1'b0;    // De-assert power-down (keep it in normal operating mode).

// Instantiate the I2C configuration module for OV5640
// This module contains the FSM and the list of register values to be written.
i2c_ov5640_rgb565_cfg i2c_ov5640 (
    .clk          (i2c_dri_clk),  // Clock input from I2C driver.
    .rst_n        (rst_n),
    .i2c_exec     (i2c_exec),     // Output: Trigger the I2C driver.
    .i2c_data     (i2c_data),     // Output: Provide address/data for the I2C driver.
    .i2c_rh_wl    (i2c_rh_wl),    // Output: Control read/write operation.
    .i2c_done     (i2c_done),     // Input: Signal that I2C driver is finished.
    .i2c_data_r   (i2c_data_r),
    .cmos_h_pixel (IMAGE_WIDTH),
    .cmos_v_pixel (IMAGE_HEIGHT),
    .total_h_pixel(2570),         // Horizontal total pixels (active + blanking).
    .total_v_pixel(980),          // Vertical total lines (active + blanking).
    .init_done    (cfg_done)      // Output: Asserted high when all registers are configured.
);

// Instantiate the low-level I2C driver
// This module generates the SCL and SDA waveforms.
i2c_dri #(
    .SLAVE_ADDR(DEVID),           // Pass slave device address from parameter.
    .CLK_FREQ  (25000000),        // System clock frequency (25MHz).
    .I2C_FREQ  (250000)           // Desired I2C clock frequency (250kHz).
) u_i2c_driver (
    .clk          (clk_25m),
    .rst_n        (rst_n),
    .i2c_exec     (i2c_exec),     // Input: Start transaction trigger.
    .bit_ctrl     (BIT_CTRL),     // Input: Set 16-bit or 8-bit register addresses.
    .i2c_rh_wl    (i2c_rh_wl),    // Input: Read (1) or Write (0) control.
    .i2c_addr     (i2c_data[23:8]), // Input: Register address to write to.
    .i2c_data_w   (i2c_data[7:0]),  // Input: Data to write.
    .i2c_data_r   (i2c_data_r),   // Output: Data read from sensor.
    .i2c_done     (i2c_done),     // Output: Transaction complete flag.
    .scl          (cmos_scl),     // Output: I2C clock pin.
    .sda          (cmos_sda),     // Inout: I2C data pin.
    .dri_clk      (i2c_dri_clk)   // Output: Divided clock for the config FSM.
);

// Instantiate the DVP video capture module
// This module receives raw camera data and converts it to a standard video stream.
ov5640_rx #(
    .RGB_TYPE(RGB_TYPE)         // Parameter to select output format (RGB565/RGB888).
) u_ov5640_rx (
    .rstn_i       (cfg_done),     // Reset is de-asserted only after camera is configured.
    .cmos_clk_i   (clk_25m),
    .cmos_pclk_i  (cmos_pclk_i),
    .cmos_href_i  (cmos_href_i),
    .cmos_vsync_i (cmos_vsync_i),
    .cmos_data_i  (cmos_data_i),
    .cmos_xclk_o  (cmos_xclk_o),  // Output a clock to drive the camera's internal logic.
    
    // Standard video output stream
    .rgb_o        (ov5640_rgb),
    .de_o         (ov5640_de),
    .vs_o         (ov5640_vs),
    .hs_o         (ov5640_hs)
);

endmodule
