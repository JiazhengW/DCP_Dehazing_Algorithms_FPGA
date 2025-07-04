`timescale 1 ps / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
// Module Name:   dvi_encoder
// Description:
//   This module implements the Transition-Minimized Differential Signaling (TMDS)
//   encoder algorithm as specified in the DVI 1.0 standard. It takes an 8-bit
//   pixel component (e.g., Red, Green, or Blue), control signals, and a data
//   enable signal, and outputs a 10-bit TMDS encoded symbol. The goal is to
//   minimize signal transitions and maintain DC balance.
//
//////////////////////////////////////////////////////////////////////////////////

module dvi_encoder (
    // Inputs
    input  wire        clkin,   // Input: Pixel clock.
    input  wire        rstin,   // Input: Active-high asynchronous reset.
    input  wire [7:0]  din,     // Input: 8-bit data component (R, G, or B).
    input  wire        c0,      // Input: Control signal 0 (used for H-Sync).
    input  wire        c1,      // Input: Control signal 1 (used for V-Sync).
    input  wire        de,      // Input: Data Enable (high for active video, low for blanking/sync).
    
    // Output
    output reg  [9:0]  dout     // Output: 10-bit TMDS encoded symbol.
);

//==============================================================================
// Stage 0: Count the number of '1's in the input data
// This is a pre-calculation step for the first stage of encoding.
// The input data is also registered to align with the pipelined adder.
//==============================================================================
reg [3:0] n1d;      // Register to hold the number of 1s in the input data 'din'.
reg [7:0] din_q;    // Registered version of the input data.

always @(posedge clkin) begin
    // Sum all bits of the input data to count the number of 1s.
    n1d   <= #1 din[0] + din[1] + din[2] + din[3] + din[4] + din[5] + din[6] + din[7];
    // Register the input data to create a one-cycle pipeline delay.
    din_q <= #1 din;
end

//==============================================================================
// Stage 1: 8-bit to 9-bit Encoding (Minimizing Transitions)
// This stage converts the 8-bit data into a 9-bit code with the minimum
// number of transitions, using either XNOR (for fewer 1s) or XOR (for more 1s).
// Refer to DVI 1.0 Specification, page 29, Figure 3-5.
//==============================================================================
wire decision1; // Control signal to select between XOR and XNOR operations.

// 'decision1' is true if we should invert the data (use XNOR). This happens when:
// 1. The data has more than four 1s.
// 2. The data has exactly four 1s and the first bit is 0.
assign decision1 = (n1d > 4'h4) | ((n1d == 4'h4) & (din_q[0] == 1'b0));

wire [8:0] q_m; // The 9-bit intermediate code.

// Generate the 9-bit code bit-by-bit.
assign q_m[0] = din_q[0];
assign q_m[1] = (decision1) ? (q_m[0] ^~ din_q[1]) : (q_m[0] ^ din_q[1]); // XNOR or XOR
assign q_m[2] = (decision1) ? (q_m[1] ^~ din_q[2]) : (q_m[1] ^ din_q[2]);
assign q_m[3] = (decision1) ? (q_m[2] ^~ din_q[3]) : (q_m[2] ^ din_q[3]);
assign q_m[4] = (decision1) ? (q_m[3] ^~ din_q[4]) : (q_m[3] ^ din_q[4]);
assign q_m[5] = (decision1) ? (q_m[4] ^~ din_q[5]) : (q_m[4] ^ din_q[5]);
assign q_m[6] = (decision1) ? (q_m[5] ^~ din_q[6]) : (q_m[5] ^ din_q[6]);
assign q_m[7] = (decision1) ? (q_m[6] ^~ din_q[7]) : (q_m[6] ^ din_q[7]);
assign q_m[8] = decision1; // The 9th bit indicates whether inversion (XNOR) was used.

//==============================================================================
// Stage 2: 9-bit to 10-bit Encoding (DC Balancing)
// This stage balances the number of 1s and 0s over time to maintain DC balance.
// It may selectively invert the 8 LSBs of the 9-bit code.
//==============================================================================
reg [3:0] n1q_m, n0q_m; // Registers for the number of 1s and 0s in q_m[7:0].

// Count 1s and 0s in the intermediate 9-bit code.
always @(posedge clkin) begin
    n1q_m <= #1 q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7];
    n0q_m <= #1 8 - n1q_m;
end

// Predefined 10-bit control tokens for non-data periods (e.g., H-Sync, V-Sync).
parameter CTRLTOKEN0 = 10'b1101010100;
parameter CTRLTOKEN1 = 10'b0010101011;
parameter CTRLTOKEN2 = 10'b0101010100;
parameter CTRLTOKEN3 = 10'b1010101011;

reg  [4:0] cnt;       // 5-bit signed disparity counter to track DC bias. MSB is the sign.
wire       decision2; // Control signal for inversion based on disparity.
wire       decision3; // Control signal for inversion based on disparity and data content.

assign decision2 = (cnt == 5'h0) | (n1q_m == n0q_m); // True if disparity is zero or data is already balanced.
assign decision3 = (~cnt[4] & (n1q_m > n0q_m)) | (cnt[4] & (n0q_m > n1q_m)); // True if inversion would reduce disparity.

// Pipeline registers to align control signals with the 2-stage calculation pipeline.
reg de_q, de_reg;
reg c0_q, c1_q;
reg c0_reg, c1_reg;
reg [8:0] q_m_reg;

always @(posedge clkin) begin
    de_q    <= #1 de;
    de_reg  <= #1 de_q; // 2-cycle delayed Data Enable signal.
    
    c0_q    <= #1 c0;
    c0_reg  <= #1 c0_q; // 2-cycle delayed Control 0 signal.
    c1_q    <= #1 c1;
    c1_reg  <= #1 c1_q; // 2-cycle delayed Control 1 signal.

    q_m_reg <= #1 q_m;  // 1-cycle delayed intermediate code.
end

//==============================================================================
// Final Output Stage and Disparity Counter
//==============================================================================
always @(posedge clkin or posedge rstin) begin
    if (rstin) begin
        dout <= 10'h0;
        cnt  <= 5'h0; // Reset disparity counter.
    end else begin
        // If Data Enable is active, perform DC-balancing encoding.
        if (de_reg) begin
            if (decision2) begin
                dout[9]   <= #1 ~q_m_reg[8];
                dout[8]   <= #1 q_m_reg[8];
                dout[7:0] <= #1 (q_m_reg[8]) ? q_m_reg[7:0] : ~q_m_reg[7:0];
                cnt       <= #1 (~q_m_reg[8]) ? (cnt + n0q_m - n1q_m) : (cnt + n1q_m - n0q_m);
            end else begin
                if (decision3) begin
                    dout[9]   <= #1 1'b1;
                    dout[8]   <= #1 q_m_reg[8];
                    dout[7:0] <= #1 ~q_m_reg[7:0];
                    cnt       <= #1 cnt + {q_m_reg[8], 1'b0} + (n0q_m - n1q_m);
                end else begin
                    dout[9]   <= #1 1'b0;
                    dout[8]   <= #1 q_m_reg[8];
                    dout[7:0] <= #1 q_m_reg[7:0];
                    cnt       <= #1 cnt - {~q_m_reg[8], 1'b0} + (n1q_m - n0q_m);
                end
            end
        // If Data Enable is inactive, output one of the four control tokens.
        end else begin
            case ({c1_reg, c0_reg})
                2'b00:   dout <= #1 CTRLTOKEN0;
                2'b01:   dout <= #1 CTRLTOKEN1;
                2'b10:   dout <= #1 CTRLTOKEN2;
                default: dout <= #1 CTRLTOKEN3;
            endcase
            cnt <= #1 5'h0; // Reset disparity when not in active video region.
        end
    end
end
    
endmodule
