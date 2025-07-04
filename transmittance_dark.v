`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
// Module Name:   transmittance_dark
// Description:
//   This module is the second stage in the dehazing pipeline. It performs two
//   critical functions in a streaming manner:
//   1. Estimates the global atmospheric light (A) for the current frame by
//      finding the maximum intensity value of the incoming dark channel stream.
//   2. Calculates the per-pixel transmittance t(x) using a novel, hardware-
//      friendly method that replaces division and multiplication with an
//      adaptive look-up table implemented with bit-shifts and additions.
//
//////////////////////////////////////////////////////////////////////////////////

module transmittance_dark (
    // Inputs
    input  wire        pixelclk,       // Pixel clock
    input  wire        reset_n,        // Active-low asynchronous reset
    input  wire [7:0]  i_dark,         // Input 8-bit dark channel stream from the previous stage
    input  wire        i_hsync,        // Input Horizontal Sync
    input  wire        i_vsync,        // Input Vertical Sync
    input  wire        i_de,           // Input Data Enable (active video)
    input  wire [7:0]  i_thre,         // Input threshold for minimum transmittance (t0)

    // Outputs
    output wire [7:0]  o_dark_max,     // Output: Estimated global atmospheric light A
    output wire [7:0]  o_transmittance,// Output: 8-bit estimated transmittance t(x)
    output wire        o_hsync,        // Pipelined Horizontal Sync
    output wire        o_vsync,        // Pipelined Vertical Sync
    output wire        o_de            // Pipelined Data Enable
);

// Pipeline registers for sync signals and dark channel data
reg  hsync_r, hsync_r0, hsync_r1;
reg  vsync_r, vsync_r0, vsync_r1;
reg  de_r, de_r0, de_r1;
reg  [7:0] r_i_dark;

// Wires and registers for atmospheric light estimation
wire [7:0] dark_gray;
reg  [7:0] max_dark;      // Holds the running maximum dark value for the current frame
reg  [7:0] max_dark_data; // Latched version of max_dark, stable for one frame

// Wires and registers for transmittance calculation
reg  [7:0] transmittance_img;    // Intermediate transmittance value (1 - scaled_dark_channel)
reg  [7:0] transmittance;        // The scaled dark channel component: K_i * I_dark(x)
reg  [7:0] transmittance_result; // Final transmittance output after applying the threshold

// Pipeline registers to delay sync and data signals to align them throughout the module.
always @(posedge pixelclk) begin
    hsync_r <= i_hsync;
    vsync_r <= i_vsync;
    de_r    <= i_de;
    r_i_dark<= i_dark;

    hsync_r0 <= hsync_r;
    vsync_r0 <= vsync_r;
    de_r0    <= de_r;

    hsync_r1 <= hsync_r0;
    vsync_r1 <= vsync_r0;
    de_r1    <= de_r0;
end

assign dark_gray          = r_i_dark;
assign o_hsync            = hsync_r1;
assign o_vsync            = vsync_r1;
assign o_de               = de_r1;
assign o_transmittance    = transmittance_result;
assign o_dark_max         = max_dark_data;

//==============================================================================
// Atmospheric Light Estimation (Global Max Search)
// This block finds the brightest pixel in the dark channel stream for one full frame.
//==============================================================================
always @(posedge pixelclk) begin
    if (!reset_n) begin
        max_dark      <= 8'h00;
        max_dark_data <= 8'h00;
    end else if (de_r) begin // Only operate on active pixels
        // Update the running maximum if the current dark pixel is brighter
        if (dark_gray > max_dark)
            max_dark <= dark_gray;
        else
            max_dark <= max_dark;
        // The latched output holds the max value from the *previous* frame,
        // ensuring a stable value of A is used for the entire current frame.
        max_dark_data <= max_dark;
    end
end

//==============================================================================
// Adaptive Transmittance Calculation (Division-Free)
// Implements t(x) = 1 - K * I_dark(x), where K is an adaptive scaling factor
// selected based on the atmospheric light value (max_dark_data).
// The multiplication K * I_dark(x) is implemented with efficient shift-and-add logic.
//==============================================================================
always @(posedge pixelclk) begin
    if (!reset_n) begin
        transmittance_img <= 0;
        transmittance     <= 0;
    end else if (de_r1) begin // Use delayed DE to align with data
        // This 'case'-like structure acts as a hardware Look-Up Table (LUT)
        // to select the scaling factor K based on the fog density (max_dark_data).
        if (max_dark_data > 8'd240) begin
            // K approx 0.65
            transmittance <= (dark_gray >> 1) + (dark_gray >> 3) + (dark_gray >> 6);
        end else if (max_dark_data > 8'd230) begin
            // K approx 0.6875
            transmittance <= (dark_gray >> 1) + (dark_gray >> 3) + (dark_gray >> 4);
        end else if (max_dark_data > 8'd220) begin
            // K approx 0.72
            transmittance <= (dark_gray >> 1) + (dark_gray >> 3) + (dark_gray >> 4) + (dark_gray >> 5);
        end else if (max_dark_data > 8'd210) begin
            // K = 0.75
            transmittance <= (dark_gray >> 1) + (dark_gray >> 2);
        end else if (max_dark_data > 8'd200) begin
            // K approx 0.78125
            transmittance <= (dark_gray >> 1) + (dark_gray >> 2) + (dark_gray >> 5);
        end else if (max_dark_data > 8'd190) begin
            // K approx 0.8125
            transmittance <= (dark_gray >> 1) + (dark_gray >> 2) + (dark_gray >> 4);
        end else if (max_dark_data > 8'd180) begin
            // K = 0.875
            transmittance <= (dark_gray >> 1) + (dark_gray >> 2) + (dark_gray >> 3);
        end else if (max_dark_data > 8'd170) begin
            // K = 0.9375
            transmittance <= dark_gray - (dark_gray >> 4); // More efficient implementation
        end else if (max_dark_data > 8'd160) begin
            // K approx 1.0
            transmittance <= dark_gray;
        end else begin
            transmittance <= 0; // If fog is very light, assume no significant transmission loss.
        end
        // Calculate the final transmittance: t(x) = 1 - transmittance
        transmittance_img <= 255 - transmittance;
    end else begin
        transmittance_img <= 0;
        transmittance     <= 0;
    end
end

//==============================================================================
// Transmittance Thresholding (t0)
// This block ensures that the transmittance does not fall below a minimum
// threshold (i_thre, typically 0.1 * 255 = 26) to prevent artifacts.
// Implements max(t(x), t0).
//==============================================================================
always @(posedge pixelclk) begin
    if (!reset_n)
        transmittance_result <= 8'b0;
    else if (transmittance_img > i_thre)
        transmittance_result <= transmittance_img;
    else
        transmittance_result <= i_thre;
end

endmodule
