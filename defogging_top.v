`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
// Module Name:   defogging_top
// Description:
//   This is the top-level module for the real-time video dehazing IP core.
//   It connects the three main processing stages in a feed-forward pipeline:
//   1. Dark Channel Calculation (rgb_dark)
//   2. Transmittance and Atmospheric Light Estimation (transmittance_dark)
//   3. Haze-Free Image Restoration (defogging)
//
//////////////////////////////////////////////////////////////////////////////////

module defogging_top (
    // Inputs
    input  wire        pixelclk,      // Main pixel clock for the pipeline
    input  wire        reset_n,       // Active-low asynchronous reset
    input  wire [23:0] i_rgb,         // Input hazy pixel data (24-bit RGB)
    input  wire        i_hsync,       // Input Horizontal Sync
    input  wire        i_vsync,       // Input Vertical Sync
    input  wire        i_de,          // Input Data Enable (active video)
    input  wire [7:0]  i_thre,        // Input threshold for atmospheric light estimation

    // Outputs
    output wire [23:0] o_defog_rgb,   // Output dehazed pixel data
    output wire        o_defog_hsync, // Pipelined Horizontal Sync output
    output wire        o_defog_vsync, // Pipelined Vertical Sync output
    output wire        o_defog_de     // Pipelined Data Enable output
);

// Internal wires to connect the pipeline stages
//-- Wires between Stage 1 and Stage 2
wire [7:0] o_dark;          // Dark channel value from rgb_dark module
wire       o_hsync;         // Pipelined hsync from rgb_dark
wire       o_vsync;         // Pipelined vsync from rgb_dark
wire       o_de;            // Pipelined de from rgb_dark

//-- Wires between Stage 2 and Stage 3
wire [7:0] dark_max;        // Estimated atmospheric light from transmittance_dark
wire [7:0] o_transmittance; // Estimated transmittance from transmittance_dark
wire       o_hsync_1;       // Pipelined hsync from transmittance_dark
wire       o_vsync_1;       // Pipelined vsync from transmittance_dark
wire       o_de_1;          // Pipelined de from transmittance_dark

//==============================================================================
// Pipeline Stage 1: Calculate Per-Pixel Dark Channel
// This module finds the minimum value of the R, G, and B components for each pixel.
//==============================================================================
rgb_dark u_rgb_dark (
    .pixelclk(pixelclk),
    .reset_n (reset_n),
    .i_rgb   (i_rgb),
    .i_hsync (i_hsync),
    .i_vsync (i_vsync),
    .i_de    (i_de),
    .o_dark  (o_dark),      // Output: 8-bit dark channel value
    .o_hsync (o_hsync),
    .o_vsync (o_vsync),
    .o_de    (o_de)
);

//==============================================================================
// Pipeline Stage 2: Estimate Atmospheric Light and Transmittance
// This module finds the global atmospheric light (dark_max) and calculates
// the per-pixel transmittance based on the dark channel stream.
//==============================================================================
transmittance_dark u_transmittance_dark (
    .pixelclk        (pixelclk),
    .reset_n         (reset_n),
    .i_dark          (o_dark),          // Input from Stage 1
    .i_hsync         (o_hsync),
    .i_vsync         (o_vsync),
    .i_de            (o_de),
    .i_thre          (i_thre),
    .o_dark_max      (dark_max),        // Output: Estimated atmospheric light A
    .o_transmittance (o_transmittance), // Output: Estimated transmittance t(x)
    .o_hsync         (o_hsync_1),
    .o_vsync         (o_vsync_1),
    .o_de            (o_de_1)
);

//==============================================================================
// Pipeline Stage 3: Restore Haze-Free Image
// This module uses the original pixel, transmittance, and atmospheric light
// to calculate the final dehazed pixel value.
//==============================================================================
defogging u_defogging (
    .pixelclk        (pixelclk),
    .reset_n         (reset_n),
    .i_rgb           (i_rgb),           // Input: Original hazy pixel data
    .i_transmittance (o_transmittance), // Input from Stage 2
    .dark_max        (dark_max),        // Input from Stage 2
    .i_hsync         (o_hsync_1),
    .i_vsync         (o_vsync_1),
    .i_de            (o_de_1),
    .o_defogging     (o_defog_rgb),     // Output: Final dehazed pixel
    .o_hsync         (o_defog_hsync),
    .o_vsync         (o_defog_vsync),
    .o_de            (o_defog_de)
);

endmodule
