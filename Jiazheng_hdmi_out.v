`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
// Module Name:   Jiazheng_hdmi_out
// Author:        Jiazheng
// Description:
//   This module implements a complete HDMI 1.4 transmitter physical layer (PHY)
//   in Verilog. It takes a parallel RGB video stream with standard VGA sync
//   signals and converts it into high-speed, differential TMDS signals suitable
//   for driving an HDMI monitor. The process involves three main steps:
//   1. Encoding: 8-bit data channels are converted to 10-bit TMDS symbols.
//   2. Serialization: 10-bit parallel data is converted to a high-speed serial stream.
//   3. Differential Signaling: The serial stream is converted to a differential pair.
//
//////////////////////////////////////////////////////////////////////////////////

module Jiazheng_hdmi_out (
    // Clock and Reset Inputs
    input  wire        clk_hdmi,      // Input: Pixel clock (e.g., 74.25MHz for 720p).
    input  wire        clk_hdmix5,    // Input: A clock at 5x the pixel clock frequency for serialization.
    input  wire        reset_n,       // Input: Active-low asynchronous reset.

    // Parallel Video Stream Input (VGA-style timing)
    input  wire        i_vga_hs,      // Input: Horizontal Sync.
    input  wire        i_vga_vs,      // Input: Vertical Sync.
    input  wire        i_vga_de,      // Input: Data Enable (active video region).
    input  wire [23:0] i_vga_rgb,     // Input: 24-bit parallel RGB pixel data.

    // HDMI Differential Outputs
    output wire        o_hdmi_clk_p,  // Output: HDMI clock, positive line.
    output wire        o_hdmi_clk_n,  // Output: HDMI clock, negative line.
    output wire [2:0]  o_hdmi_data_p, // Output: 3 TMDS data channels, positive lines (0:Blue, 1:Green, 2:Red).
    output wire [2:0]  o_hdmi_data_n  // Output: 3 TMDS data channels, negative lines.
);

// Internal wire for the synchronized, active-high reset signal.
wire reset;

// Internal wires for the 10-bit parallel TMDS encoded data.
wire [9:0] red_10bit;
wire [9:0] green_10bit;
wire [9:0] blue_10bit;
wire [9:0] clk_10bit; // A constant pattern to generate the HDMI clock.

// Internal wires for the high-speed serialized data streams.
wire [2:0] tmds_data_serial;
wire       tmds_clk_serial;

//==============================================================================
// Main Code
//==============================================================================

// The HDMI clock is generated by serializing a constant 10'b1111100000 pattern.
assign clk_10bit = 10'b1111100000;

// Instantiate a reset synchronizer to handle the asynchronous reset safely.
asyn_rst_syn reset_syn (
    .reset_n   (reset_n),  // Input: Active-low async reset.
    .clk       (clk_hdmi), // Input: Destination clock domain.
    .syn_reset (reset)     // Output: Active-high sync reset.
);

//------------------------------------------------------------------------------
// Stage 1: TMDS Encoding
// Instantiate three DVI encoders, one for each color channel (Blue, Green, Red).
//------------------------------------------------------------------------------
dvi_encoder encoder_b (
    .clkin (clk_hdmi),
    .rstin (reset),
    .din   (i_vga_rgb[7:0]),   // Blue channel data
    .c0    (i_vga_hs),
    .c1    (i_vga_vs),
    .de    (i_vga_de),
    .dout  (blue_10bit)
);

dvi_encoder encoder_g (
    .clkin (clk_hdmi),
    .rstin (reset),
    .din   (i_vga_rgb[15:8]),  // Green channel data
    .c0    (i_vga_hs),
    .c1    (i_vga_vs),
    .de    (i_vga_de),
    .dout  (green_10bit)
);

dvi_encoder encoder_r (
    .clkin (clk_hdmi),
    .rstin (reset),
    .din   (i_vga_rgb[23:16]), // Red channel data
    .c0    (i_vga_hs),
    .c1    (i_vga_vs),
    .de    (i_vga_de),
    .dout  (red_10bit)
);

//------------------------------------------------------------------------------
// Stage 2: Parallel-to-Serial Conversion
// Instantiate four 10-to-1 serializers, one for each data channel and one for the clock.
// These modules typically use dedicated hardware primitives like OSERDES.
//------------------------------------------------------------------------------
serializer_10_to_1 serializer_b (
    .reset          (reset),
    .paralell_clk   (clk_hdmi),
    .serial_clk_5x  (clk_hdmix5),
    .paralell_data  (blue_10bit),
    .serial_data_out(tmds_data_serial[0]) // Serialized Blue channel
);

serializer_10_to_1 serializer_g (
    .reset          (reset),
    .paralell_clk   (clk_hdmi),
    .serial_clk_5x  (clk_hdmix5),
    .paralell_data  (green_10bit),
    .serial_data_out(tmds_data_serial[1]) // Serialized Green channel
);

serializer_10_to_1 serializer_r (
    .reset          (reset),
    .paralell_clk   (clk_hdmi),
    .serial_clk_5x  (clk_hdmix5),
    .paralell_data  (red_10bit),
    .serial_data_out(tmds_data_serial[2]) // Serialized Red channel
);

serializer_10_to_1 serializer_clk (
    .reset          (reset),
    .paralell_clk   (clk_hdmi),
    .serial_clk_5x  (clk_hdmix5),
    .paralell_data  (clk_10bit),
    .serial_data_out(tmds_clk_serial)     // Serialized Clock
);

//------------------------------------------------------------------------------
// Stage 3: Differential Signal Conversion
// Use OBUFDS (Output Buffer for Differential Signaling) primitives to drive
// the physical HDMI pins.
//------------------------------------------------------------------------------
OBUFDS #(
    .IOSTANDARD ("TMDS_33") // Set the I/O standard to TMDS for 3.3V LVDS.
) TMDS0 (
    .I  (tmds_data_serial[0]), // Input: Serial Blue data
    .O  (o_hdmi_data_p[0]),    // Output: Positive line
    .OB (o_hdmi_data_n[0])     // Output: Negative line
);

OBUFDS #(
    .IOSTANDARD ("TMDS_33")
) TMDS1 (
    .I  (tmds_data_serial[1]), // Input: Serial Green data
    .O  (o_hdmi_data_p[1]),
    .OB (o_hdmi_data_n[1])
);

OBUFDS #(
    .IOSTANDARD ("TMDS_33")
) TMDS2 (
    .I  (tmds_data_serial[2]), // Input: Serial Red data
    .O  (o_hdmi_data_p[2]),
    .OB (o_hdmi_data_n[2])
);

OBUFDS #(
    .IOSTANDARD ("TMDS_33")
) TMDS3 (
    .I  (tmds_clk_serial),    // Input: Serial clock data
    .O  (o_hdmi_clk_p),
    .OB (o_hdmi_clk_n)
);

endmodule
