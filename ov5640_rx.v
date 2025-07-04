`timescale 1ns / 1ps

module ov5640_rx #(
    parameter RGB_TYPE = 1'd0    // 0-->RGB565, 1-->RGB888
)(
    input             rstn_i      ,
    input             cmos_clk_i  , // CMOS sensor clock.
    input             cmos_pclk_i , // Input pixel clock.
    input             cmos_href_i , // Input pixel horizontal sync signal.
    input             cmos_vsync_i, // Input pixel vertical sync signal.
    input      [7:0]  cmos_data_i , // Input data.
    output            cmos_xclk_o , // Output clock to CMOS sensor. 
    output     [23:0] rgb_o       ,
    output            de_o        ,
    output            vs_o        ,
    output            hs_o
);

assign cmos_xclk_o = cmos_clk_i;

reg cmos_href_r1 = 1'b0, cmos_href_r2 = 1'b0, cmos_href_r3 = 1'b0;
reg cmos_vsync_r1 = 1'b0, cmos_vsync_r2 = 1'b0;
reg [7:0] cmos_data_r1 = 8'b0;
reg [7:0] cmos_data_r2 = 8'b0;

reg rstn1, rstn2;

// Synchronize reset signal to the pixel clock domain
always@(posedge cmos_pclk_i) begin
    rstn1 <= rstn_i;
    rstn2 <= rstn1;
end

// Register input signals to avoid meta-stability
always@(posedge cmos_pclk_i) begin
    cmos_href_r1  <= cmos_href_i;
    cmos_href_r2  <= cmos_href_r1;
    cmos_href_r3  <= cmos_href_r2;
    cmos_data_r1  <= cmos_data_i;
    cmos_data_r2  <= cmos_data_r1;
    cmos_vsync_r1 <= cmos_vsync_i;
    cmos_vsync_r2 <= cmos_vsync_r1;
end

// Counter to ignore initial unstable frames after reset
parameter FRAM_FREE_CNT = 5;
reg [7:0] vs_cnt;
wire vs_p = !cmos_vsync_r2 && cmos_vsync_r1; // VSYNC rising edge detection

always@(posedge cmos_pclk_i) begin
    if(!rstn2) begin
        vs_cnt <= 8'd0;
    end
    else if(vs_p) begin
        if(vs_cnt < FRAM_FREE_CNT)
            vs_cnt <= vs_cnt + 1'b1;
        else
            vs_cnt <= vs_cnt;
    end
end

wire out_en = (vs_cnt == FRAM_FREE_CNT); // Enable output after stable frames

// Convert 8-bit input data to 16-bit for RGB565 format.
reg href_cnt = 1'b0;
reg data_en  = 1'b0;
reg [15:0] rgb2 = 16'd0;

always@(posedge cmos_pclk_i) begin
    if(vs_p || (~out_en)) begin // Reset on new frame or when output is disabled
        href_cnt <= 1'd0;
        data_en  <= 1'b0;
        rgb2     <= 16'd0;
    end
    else begin
        href_cnt <= cmos_href_r2 ? href_cnt + 1'b1 : 1'b0;
        data_en  <= (href_cnt == 1'd1); // Data enable for the second byte of a pixel
        if(cmos_href_r2) begin
            rgb2 <= {rgb2[7:0], cmos_data_r2}; // Combine two 8-bit data into one 16-bit pixel
        end
    end
end

// Output RGB data based on the selected type (RGB888 or RGB565)
assign rgb_o = RGB_TYPE ? {rgb2[15:11], 3'd0, rgb2[10:5], 2'd0, rgb2[4:0], 3'd0} : {8'h00, rgb2};

assign de_o = out_en && data_en;
assign vs_o = out_en && cmos_vsync_r2;
assign hs_o = out_en && cmos_href_r3;

endmodule
