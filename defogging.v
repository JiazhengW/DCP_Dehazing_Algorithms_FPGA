`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
// Module:      defogging
// Author:      Jiazheng
// Description: This module performs the final stage of the dehazing algorithm.
//              It restores the haze-free pixel color J(x) based on the original
//              pixel I(x), the estimated transmittance t(x), and the global
//              atmospheric light A, using a hardware-friendly fixed-point
//              implementation of the atmospheric scattering model.
//
// Formula:     J(x) = (I(x) - A) / max(t(x), t0) + A
//
//////////////////////////////////////////////////////////////////////////////////

module defogging (
    // Inputs
    input  wire        pixelclk,       // Pixel clock
    input  wire        reset_n,        // Active-low asynchronous reset
    input  wire [23:0] i_rgb,          // Input hazy pixel data I(x)
    input  wire [ 7:0] i_transmittance,// Estimated transmittance t(x)
    input  wire [ 7:0] dark_max,       // Global atmospheric light A (max value of dark channel)
    input  wire        i_hsync,        // Input Horizontal Sync
    input  wire        i_vsync,        // Input Vertical Sync
    input  wire        i_de,           // Input Data Enable

    // Outputs
    output wire [23:0] o_defogging,    // Output dehazed pixel data J(x)
    output wire        o_hsync,        // Pipelined Horizontal Sync
    output wire        o_vsync,        // Pipelined Vertical Sync
    output wire        o_de            // Pipelined Data Enable
);

// Parameter for fixed-point arithmetic scaling in the reciprocal LUT.
parameter DEVIDER = 255 * 16;

// Pipeline registers to delay sync signals and pixel data
reg  hsync_r, hsync_r0;
reg  vsync_r, vsync_r0;
reg  de_r, de_r0;
reg  [23:0] rgb_r0, rgb_r1, rgb_r2, rgb_r3; // 4-clock delay for pixel data

// Wires for delayed RGB components
wire [7:0] r;
wire [7:0] g;
wire [7:0] b;

// Wire for the transmittance value (with a lower bound applied implicitly)
wire [7:0] transmittance_gray;

// Registers for final fixed-point results (e.g., 8 integer bits, 12 fractional bits)
reg  [19:0] r_r;
reg  [19:0] r_g;
reg  [19:0] r_b;

// Flags to detect potential underflow during subtraction
wire r_flag;
wire g_flag;
wire b_flag;

// Registers for intermediate calculation results
reg  [11:0] mult1;  // Stores the scaled reciprocal of transmittance: DEVIDER / t'(x)
reg  [15:0] mult2;  // Stores the atmospheric light component: A * (1 - t'(x))
reg  [15:0] mult_r; // Stores the scaled input pixel component: I_r * 255
reg  [15:0] mult_g; // Stores the scaled input pixel component: I_g * 255
reg  [15:0] mult_b; // Stores the scaled input pixel component: I_b * 255

// Underflow check: flags are asserted if the haze component is greater than the scaled pixel value.
assign r_flag = (i_de == 1'b1 && mult2 > mult_r) ? 1'b1 : 1'b0;
assign g_flag = (i_de == 1'b1 && mult2 > mult_g) ? 1'b1 : 1'b0;
assign b_flag = (i_de == 1'b1 && mult2 > mult_b) ? 1'b1 : 1'b0;

// Pipeline registers to align sync signals and pixel data with the calculation latency.
always @(posedge pixelclk) begin
    hsync_r  <= i_hsync;
    vsync_r  <= i_vsync;
    de_r     <= i_de;
    
    hsync_r0 <= hsync_r;
    vsync_r0 <= vsync_r;
    de_r0    <= de_r;
    
    rgb_r0   <= i_rgb;
    rgb_r1   <= rgb_r0;
    rgb_r2   <= rgb_r1;
    rgb_r3   <= rgb_r2; // Final delayed pixel data is available here
end

// Extract R, G, B components from the 4-cycle delayed pixel data
assign r = rgb_r3[23:16];
assign g = rgb_r3[15:8];
assign b = rgb_r3[7:0];

// The input transmittance has already been thresholded, so it's t'(x)
assign transmittance_gray = i_transmittance; 
      
// Pass the pipelined sync signals to the output
assign o_hsync = hsync_r0;
assign o_vsync = vsync_r0;
assign o_de    = de_r0;

// Construct the final 24-bit dehazed pixel from the fixed-point results.
// [19:12] takes the integer part of the 8.12 fixed-point number.
assign o_defogging = {r_r[19:12], r_g[19:12], r_b[19:12]};  

// Core fixed-point calculation pipeline for the restoration formula
always @(posedge pixelclk or negedge reset_n) begin
    if (!reset_n) begin
        r_r    <= 'b0;
        r_g    <= 'b0;
        r_b    <= 'b0;
        mult1  <= 12'b0;
        mult2  <= 16'b0;
        mult_r <= 16'b0;
        mult_g <= 16'b0;
        mult_b <= 16'b0;
    end else begin
        // S1: Perform intermediate calculations in the first stage of the pipeline
        // This is a hardware-friendly reciprocal LUT: 1/t'(x) implemented as DEVIDER/t'(x)
        mult1  <= DEVIDER / transmittance_gray; 
        // Calculate the atmospheric light component: A * (255 - t'(x))
        mult2  <= (255 - transmittance_gray) * dark_max;
        // Scale up the input pixel values for fixed-point precision
        mult_r <= r * 255;
        mult_g <= g * 255;
        mult_b <= b * 255;
        
        // S2: Perform the final multiplication in the second stage of the pipeline
        // This implements a hardware-friendly version of J = (I - A(1-t'))/t' + A
        r_r <= (r_flag == 1'b1) ? {r, 12'b0} : (mult_r - mult2) * mult1;
        r_g <= (g_flag == 1'b1) ? {g, 12'b0} : (mult_g - mult2) * mult1;
        r_b <= (b_flag == 1'b1) ? {b, 12'b0} : (mult_b - mult2) * mult1;
    end
end

endmodule
