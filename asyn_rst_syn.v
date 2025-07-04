`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
// Module Name:   asyn_rst_syn
// Description:
//   This module handles a common and critical task in digital design:
//   synchronizing an asynchronous reset signal to a destination clock domain.
//   It takes an active-low asynchronous reset input and produces an
//   active-high synchronous reset output.
//
//   Functionality:
//   1. Asynchronous Assertion: The reset asserts immediately when reset_n goes low.
//   2. Synchronous De-assertion: The reset is released (de-asserted) in sync
//      with the destination clock to prevent metastability issues.
//   3. Polarity Inversion: Converts the active-low input reset to an
//      active-high output reset.
//
//////////////////////////////////////////////////////////////////////////////////

module asyn_rst_syn(
    // Inputs
    input clk,          // Input: Clock signal of the destination domain.
    input reset_n,      // Input: Active-low asynchronous reset from an external source.
    
    // Output
    output syn_reset    // Output: Active-high synchronous reset for the destination clock domain.
);
    
// Internal registers for the 2-stage synchronizer chain.
reg reset_1;
reg reset_2;
    
//==============================================================================
// Main Code
//==============================================================================

// The output reset is directly driven by the second stage of the synchronizer.
assign syn_reset = reset_2;
    
// This always block implements the asynchronous reset and synchronous release logic.
always @(posedge clk or negedge reset_n) begin
    // Asynchronous Assertion:
    // When reset_n is asserted (goes low), immediately force both synchronizer
    // stages high. This makes the output 'syn_reset' go high instantly.
    if (!reset_n) begin
        reset_1 <= 1'b1;
        reset_2 <= 1'b1;
    end
    // Synchronous De-assertion:
    // When reset_n is de-asserted (goes high), this part of the logic is
    // controlled by the rising edge of 'clk'.
    else begin
        reset_1 <= 1'b0;          // The first stage is driven low.
        reset_2 <= reset_1;       // The second stage captures the value of the first,
                                  // ensuring the reset signal is cleanly de-asserted
                                  // in sync with the clock.
    end
end
    
endmodule
