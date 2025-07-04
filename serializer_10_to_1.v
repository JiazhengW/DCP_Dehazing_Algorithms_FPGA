`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
// Module Name:   serializer_10_to_1
// Description:
//   This module implements a 10-to-1 parallel-to-serial converter using two
//   cascaded Xilinx OSERDESE2 primitives. It takes a 10-bit parallel data word
//   at a slower clock rate (paralell_clk) and outputs a single-bit serial stream
//   at 10x the parallel clock rate. This is achieved by using a 5x serial clock
//   and DDR (Double Data Rate) mode on the output.
//
//////////////////////////////////////////////////////////////////////////////////

module serializer_10_to_1 (
    // Inputs
    input  wire        reset,           // Input: Active-high synchronous reset.
    input  wire        paralell_clk,    // Input: Parallel data clock (e.g., 74.25MHz).
    input  wire        serial_clk_5x,   // Input: High-speed serial clock (5x the parallel clock).
    input  wire [9:0]  paralell_data,   // Input: 10-bit parallel data to be serialized.

    // Output
    output wire        serial_data_out  // Output: Single-bit high-speed serial data stream.
);
    
// Wires for cascading the two OSERDESE2 primitives.
wire cascade1; // Carries data from the Slave to the Master.
wire cascade2;
 
//==============================================================================
// Main Code
//============================================================================== 
    
// Instantiate the first OSERDESE2 primitive in MASTER mode.
// The MASTER primitive handles the lower-order bits of the parallel word and
// drives the final serial output pin (OQ).
OSERDESE2 #(
    .DATA_RATE_OQ  ("DDR"),       // Set output to Double Data Rate (data changes on both clock edges).
    .DATA_RATE_TQ  ("SDR"),       // Tristate output rate (not used).
    .DATA_WIDTH    (10),          // Total effective data width is 10 bits.
    .SERDES_MODE   ("MASTER"),    // Set this instance as the MASTER in the cascade.
    .TRISTATE_WIDTH(1)            // Width of the tristate control signal.
)
OSERDESE2_Master (
    // Clocking and Reset
    .CLK          (serial_clk_5x),// High-speed clock (5x parallel clock).
    .CLKDIV       (paralell_clk), // Low-speed parallel clock.
    .RST          (reset),        // Reset input.
    .OCE          (1'b1),         // Output Clock Enable, permanently enabled.
    
    // Serial Output
    .OQ           (serial_data_out), // Final serialized data output.
    
    // Parallel Data Inputs (D1-D8) for the Master stage
    .D1           (paralell_data[0]),
    .D2           (paralell_data[1]),
    .D3           (paralell_data[2]),
    .D4           (paralell_data[3]),
    .D5           (paralell_data[4]),
    .D6           (paralell_data[5]),
    .D7           (paralell_data[6]),
    .D8           (paralell_data[7]),
    
    // Cascade Interface
    .SHIFTIN1     (cascade1),     // Input from the Slave's SHIFTOUT1.
    .SHIFTIN2     (cascade2),     // Input from the Slave's SHIFTOUT2.
    .SHIFTOUT1    (),             // Master's shift outputs are not used.
    .SHIFTOUT2    (),
    
    // Unused Ports
    .OFB          (), .T1(1'b0), .T2(1'b0), .T3(1'b0), .T4(1'b0), .TBYTEIN(1'b0), 
    .TCE(1'b0), .TBYTEOUT(), .TFB(), .TQ()
);
    
// Instantiate the second OSERDESE2 primitive in SLAVE mode.
// The SLAVE primitive handles the higher-order bits and passes them internally
// to the MASTER via the cascade shift ports.
OSERDESE2 #(
    .DATA_RATE_OQ  ("DDR"),
    .DATA_RATE_TQ  ("SDR"),
    .DATA_WIDTH    (10),
    .SERDES_MODE   ("SLAVE")     // Set this instance as the SLAVE in the cascade.
)
OSERDESE2_Slave (
    // Clocking and Reset (same as Master)
    .CLK          (serial_clk_5x),
    .CLKDIV       (paralell_clk),
    .RST          (reset),
    .OCE          (1'b1),
    
    // Serial Output
    .OQ           (),             // Slave's direct serial output is not used.
    
    // Parallel Data Inputs (D1-D8) for the Slave stage
    // Note how the higher-order bits are connected here.
    .D1           (1'b0),
    .D2           (1'b0),
    .D3           (paralell_data[8]),
    .D4           (paralell_data[9]),
    .D5           (1'b0),
    .D6           (1'b0),
    .D7           (1'b0),
    .D8           (1'b0),
    
    // Cascade Interface
    .SHIFTIN1     (),
    .SHIFTIN2     (),
    .SHIFTOUT1    (cascade1),     // Output to the Master's SHIFTIN1.
    .SHIFTOUT2    (cascade2),     // Output to the Master's SHIFTIN2.
    
    // Unused Ports
    .OFB          (), .T1(1'b0), .T2(1'b0), .T3(1'b0), .T4(1'b0), .TBYTEIN(1'b0), 
    .TCE(1'b0), .TBYTEOUT(), .TFB(), .TQ()
);
        
endmodule
