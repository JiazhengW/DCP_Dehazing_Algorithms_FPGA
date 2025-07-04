`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
// Module:      video_timing_control
// Description: This module generates standard video timing signals (HS, VS, DE)
//              for a specific resolution. It takes a pixel clock as input and 
//              uses horizontal and vertical counters to generate the sync pulses
//              and active video area (Data Enable) according to VESA standards.
//
//////////////////////////////////////////////////////////////////////////////////

// Macro to select the target video resolution. Only one should be active.
`define VIDEO_1280_720 

module video_timing_control #(
    // Parameters to define a smaller active video window within the generated timing.
    // Default is to use the full resolution.
    parameter VIDEO_H       = 1280,
    parameter VIDEO_V       = 720,
    parameter VIDEO_START_X = 0,
    parameter VIDEO_START_Y = 0
) (
    // Inputs
    input  wire        i_clk,      // Pixel clock input
    input  wire        i_rst_n,    // Active-low asynchronous reset
    input  wire [23:0] i_rgb,      // Input pixel data (from a source like memory or camera)

    // Outputs
    output reg         o_hs,       // Horizontal Sync signal
    output reg         o_vs,       // Vertical Sync signal
    output reg         o_de,       // Data Enable (indicates active video region)
    output wire [23:0] o_rgb,      // Output pixel data (gated by o_data_req)
    output wire        o_data_req, // Request signal for new pixel data
    output wire [10:0] o_h_dis,    // Horizontal display size (active width)
    output wire [10:0] o_v_dis,    // Vertical display size (active height)
    output reg  [10:0] o_x_pos,    // Current X-coordinate (horizontal position)
    output reg  [10:0] o_y_pos     // Current Y-coordinate (vertical position)
);

//==============================================================================
// Video Timing Parameters for 1280x720 @ 60Hz (Pixel Clock: 74.25MHz)
// Based on VESA standard timings.
//==============================================================================
`ifdef VIDEO_1280_720
    // Horizontal Timing (in pixel clock cycles)
    localparam H_ACTIVE      = 1280; // Active video width
    localparam H_FRONT_PORCH = 110;  // Front porch duration
    localparam H_SYNC_TIME   = 40;   // H-Sync pulse width
    localparam H_BACK_PORCH  = 220;  // Back porch duration
    localparam H_POLARITY    = 1;    // H-Sync polarity (1 for active-high)
    
    // Vertical Timing (in line counts)
    localparam V_ACTIVE      = 720;  // Active video height
    localparam V_FRONT_PORCH = 5;    // Front porch duration
    localparam V_SYNC_TIME   = 5;    // V-Sync pulse width
    localparam V_BACK_PORCH  = 20;   // Back porch duration
    localparam V_POLARITY    = 1;    // V-Sync polarity (1 for active-high)
`endif

// Total time for one horizontal line and one vertical frame
localparam H_TOTAL_TIME = H_ACTIVE + H_FRONT_PORCH + H_SYNC_TIME + H_BACK_PORCH;
localparam V_TOTAL_TIME = V_ACTIVE + V_FRONT_PORCH + V_SYNC_TIME + V_BACK_PORCH;

// Output the active display dimensions
assign o_h_dis = H_ACTIVE;
assign o_v_dis = V_ACTIVE;

// Generate data request signal only for the defined active window
assign o_data_req = (o_y_pos >= VIDEO_START_Y) && (o_y_pos < VIDEO_START_Y + VIDEO_V) && 
                    (o_x_pos >= VIDEO_START_X) && (o_x_pos < VIDEO_START_X + VIDEO_H);

// Internal registers and wires for signal generation
reg [12:0] h_syn_cnt; // Horizontal counter
reg [12:0] v_syn_cnt; // Vertical counter
reg        r_hs;      // Registered horizontal sync
reg        r_vs;      // Registered vertical sync
reg        r_de;      // Registered data enable

// Registered output stage for better timing
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        o_hs <= 1'b0;
        o_vs <= 1'b0;
        o_de <= 1'b0;
    end else begin
        o_hs <= r_hs;
        o_vs <= r_vs;
        o_de <= r_de;
    end
end

// Gate the output RGB data. Output black (0) outside the active region.
assign o_rgb = o_de ? i_rgb : 24'h000000;

// Horizontal counter: counts pixels in one line
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) 
        h_syn_cnt <= 0;
    else if (h_syn_cnt == H_TOTAL_TIME - 1) 
        h_syn_cnt <= 0;
    else 
        h_syn_cnt <= h_syn_cnt + 1;
end

// Vertical counter: counts lines in one frame, increments at the end of each horizontal line
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) 
        v_syn_cnt <= 0;
    else if (h_syn_cnt == H_TOTAL_TIME - 1) begin
        if (v_syn_cnt == V_TOTAL_TIME - 1) 
            v_syn_cnt <= 0;
        else 
            v_syn_cnt <= v_syn_cnt + 1;
    end
end

// Horizontal Sync (HS) signal generation
always @(posedge i_clk) begin
    if (h_syn_cnt >= H_FRONT_PORCH && h_syn_cnt < H_FRONT_PORCH + H_SYNC_TIME) 
        r_hs <= ~H_POLARITY;
    else 
        r_hs <= H_POLARITY;
end

// Vertical Sync (VS) signal generation
always @(posedge i_clk) begin
    if (v_syn_cnt >= V_FRONT_PORCH && v_syn_cnt < V_FRONT_PORCH + V_SYNC_TIME) 
        r_vs <= ~V_POLARITY;
    else 
        r_vs <= V_POLARITY;
end

// Data Enable (DE) signal generation (active video area)
always @(posedge i_clk) begin
    if ( (h_syn_cnt >= H_FRONT_PORCH + H_SYNC_TIME + H_BACK_PORCH) && (h_syn_cnt < H_TOTAL_TIME) &&
         (v_syn_cnt >= V_FRONT_PORCH + V_SYNC_TIME + V_BACK_PORCH) && (v_syn_cnt < V_TOTAL_TIME) ) 
    begin
        r_de <= 1'b1;
    end else begin
        r_de <= 1'b0;
    end
end

// X-coordinate counter (increments only when DE is high)
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) 
        o_x_pos <= 0;
    else if (h_syn_cnt == H_FRONT_PORCH + H_SYNC_TIME + H_BACK_PORCH - 1)
        o_x_pos <= 0;
    else if (o_de) 
        o_x_pos <= o_x_pos + 1'b1;
end

// Y-coordinate counter (increments at the start of each active line)
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) 
        o_y_pos <= 0;
    else if (v_syn_cnt == V_FRONT_PORCH + V_SYNC_TIME + V_BACK_PORCH -1 && h_syn_cnt == H_TOTAL_TIME - 1)
        o_y_pos <= 0;
    else if (h_syn_cnt == H_TOTAL_TIME - 1 && o_de) 
        o_y_pos <= o_y_pos + 1'b1;
end

endmodule
