`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
// Module Name:   rgb_dark
// Description: 
//   This module calculates the "dark channel" value for each pixel in a video
//   stream. The dark channel is defined as the minimum intensity value among the
//   three color channels (Red, Green, and Blue) for a given pixel. The calculation
//   is performed in a two-stage pipeline to meet timing requirements.
//
//////////////////////////////////////////////////////////////////////////////////

module rgb_dark (
    // Inputs
    input  wire        pixelclk,      // Pixel clock
    input  wire        reset_n,       // Active-low asynchronous reset
    input  wire [23:0] i_rgb,         // Input 24-bit RGB pixel data
    input  wire        i_hsync,       // Input Horizontal Sync
    input  wire        i_vsync,       // Input Vertical Sync
    input  wire        i_de,          // Input Data Enable (active video)

    // Outputs
    output wire [7:0]  o_dark,        // Output 8-bit dark channel value
    output wire        o_hsync,       // Pipelined Horizontal Sync
    output wire        o_vsync,       // Pipelined Vertical Sync
    output wire        o_de           // Pipelined Data Enable
);

// Pipeline registers for sync signals and one of the color channels
reg hsync_r, hsync_r0;
reg vsync_r, vsync_r0;
reg de_r, de_r0;
reg [7:0] b_r;      // Register to delay the Blue channel to align with the first stage comparator

// Wires for individual color components
wire [7:0] r;
wire [7:0] g;
wire [7:0] b;

// Registers for intermediate and final dark channel results
reg [7:0] dark_r;   // Stage 1 result: min(R, G)
reg [7:0] dark_r1;  // Stage 2 result: min(min(R, G), B)

// Pipeline registers for delaying sync signals and the Blue channel data.
// This ensures that all signals are aligned at the final output stage.
always @(posedge pixelclk) begin
    hsync_r  <= i_hsync;
    vsync_r  <= i_vsync;
    de_r     <= i_de;
    
    hsync_r0 <= hsync_r;
    vsync_r0 <= vsync_r;
    de_r0    <= de_r;
    
    b_r      <= b; // Delay the blue component by one clock cycle
end

// Extract R, G, B components from the 24-bit input pixel
assign r = i_rgb[23:16];
assign g = i_rgb[15:8];
assign b = i_rgb[7:0];

// Pass the pipelined sync signals to the output
assign o_hsync = hsync_r0;
assign o_vsync = vsync_r0;
assign o_de    = de_r0;

// The final dark channel output is the result of the second pipeline stage
assign o_dark = dark_r1;

//==============================================================================
// Pipeline Stage 1: Find the minimum of the Red and Green channels
//==============================================================================
always @(posedge pixelclk) begin
    if (!reset_n)
        dark_r <= 8'h00;
    else if (i_de) begin // Only perform calculation during active video
        if (r > g)
            dark_r <= g;
        else
            dark_r <= r;
    end else
        dark_r <= 8'h00;
end

//==============================================================================
// Pipeline Stage 2: Find the minimum between the Stage 1 result and the Blue channel
//==============================================================================
always @(posedge pixelclk) begin
    if (!reset_n)
        dark_r1 <= 8'h00;
    else if (de_r) begin // Use the delayed DE signal to match the delayed data
        // Compare the result of min(R,G) with the delayed Blue channel
        if (b_r > dark_r)
            dark_r1 <= dark_r;
        else
            dark_r1 <= b_r;
    end else
        dark_r1 <= 8'h00;
end

endmodule
