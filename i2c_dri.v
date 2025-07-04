`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
// Module Name:   i2c_dri
// Description:
//   This module implements a low-level I2C master driver. It generates the
//   SCL and SDA waveforms required to communicate with an I2C slave device,
//   such as a camera sensor. It supports both read and write operations with
//   configurable 8-bit or 16-bit register addressing. The entire operation is
//   controlled by a finite-state machine (FSM).
//
//////////////////////////////////////////////////////////////////////////////////

module i2c_dri #(
    // Parameters
    parameter SLAVE_ADDR = 7'b1010000,    // Default 7-bit I2C slave device address.
    parameter CLK_FREQ   = 50_000_000,    // Frequency of the input system clock (clk).
    parameter I2C_FREQ   = 250_000       // Desired frequency for the I2C SCL clock.
) (
    // System Interface
    input  wire        clk,        // Input system clock.
    input  wire        rst_n,      // Active-low asynchronous reset.

    // User Control Interface
    input  wire        i2c_exec,   // Input: A pulse on this signal starts an I2C transaction.
    input  wire        bit_ctrl,   // Input: Selects register address width (0 for 8-bit, 1 for 16-bit).
    input  wire        i2c_rh_wl,  // Input: I2C operation control (1 for Read, 0 for Write).
    input  wire [15:0] i2c_addr,   // Input: 16-bit internal register address of the slave device.
    input  wire [ 7:0] i2c_data_w, // Input: 8-bit data to be written to the slave.
    output reg  [ 7:0] i2c_data_r, // Output: 8-bit data read from the slave.
    output reg         i2c_done,   // Output: Asserted for one cycle when a transaction completes.
    
    // Physical I2C Bus
    output reg         scl,        // Output: I2C Serial Clock line.
    inout  wire        sda,        // Inout: I2C Serial Data line (bidirectional).
    
    // Internal Driver Clock
    output reg         dri_clk     // Output: A 4x I2C frequency clock to drive the FSM.
);

// State definitions for the main FSM
localparam st_idle    = 8'b0000_0001; // Idle state, waiting for a transaction request.
localparam st_sladdr  = 8'b0000_0010; // State to send the 7-bit slave address.
localparam st_addr16  = 8'b0000_0100; // State to send the high byte of a 16-bit register address.
localparam st_addr8   = 8'b0000_1000; // State to send the low byte of an 8-bit/16-bit register address.
localparam st_data_wr = 8'b0001_0000; // State to write 8 bits of data to the slave.
localparam st_addr_rd = 8'b0010_0000; // State to send the slave address again with the read bit set.
localparam st_data_rd = 8'b0100_0000; // State to read 8 bits of data from the slave.
localparam st_stop    = 8'b1000_0000; // State to generate the I2C stop condition.

// Internal registers
reg        sda_dir;     // Direction control for the SDA line (1 for output, 0 for input/high-Z).
reg        sda_out;     // The value to drive on the SDA line when it's an output.
reg        st_done;     // Internal flag to signal the completion of a state's operation.
reg        wr_flag;     // Latches the read/write control signal for the duration of a transaction.
reg  [6:0] cnt;         // Counter for timing within each state.
reg  [7:0] cur_state;   // Current state of the FSM.
reg  [7:0] next_state;  // Next state of the FSM.
reg  [15:0]addr_t;      // Latched register address for the current transaction.
reg  [7:0] data_r;      // Temporary register for data being read from SDA.
reg  [7:0] data_wr_t;   // Latched data to be written for the current transaction.
reg  [9:0] clk_cnt;     // Counter for generating the internal driver clock.

// Internal wires
wire       sda_in;      // The value of the SDA line read back.
wire [8:0] clk_divide;  // Calculated clock divider factor.

//==============================================================================
// Main Code
//==============================================================================

//-- SDA Line Control
// Controls the bidirectional SDA line. When sda_dir is high, drive sda_out.
// When sda_dir is low, set SDA to high-impedance (Z) to allow the slave to drive it.
assign sda      = sda_dir ? sda_out : 1'bz;
// The input signal is simply the value read from the sda wire.
assign sda_in   = sda;
// Calculate the divider factor for the internal driver clock.
// The I2C SCL has two phases (high/low), and this FSM uses 4 internal clock cycles
// per SCL phase, so we divide the main clock by 8x the desired I2C frequency.
assign clk_divide = (CLK_FREQ / I2C_FREQ) >> 3;

//-- Driver Clock Generation
// Generate 'dri_clk', which is 4x the frequency of the I2C SCL clock.
// This provides four timing phases per SCL cycle for precise control of the FSM.
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dri_clk <= 1'b1;
        clk_cnt <= 10'd0;
    end
    // When the counter reaches the divide value, toggle the driver clock.
    else if (clk_cnt == clk_divide - 1'b1) begin
        clk_cnt <= 10'd0;
        dri_clk <= ~dri_clk;
    end
    else begin
        clk_cnt <= clk_cnt + 1'b1;
    end
end

//-- FSM State Register (1st stage of a 3-stage FSM)
// Synchronously updates the current state on the rising edge of the driver clock.
always @(posedge dri_clk or negedge rst_n) begin
    if (!rst_n)
        cur_state <= st_idle;
    else
        cur_state <= next_state;
end

//-- FSM Next-State Logic (2nd stage of a 3-stage FSM)
// Combinational logic that determines the next state based on the current state
// and the 'st_done' flag from the output logic.
always @(*) begin
    case (cur_state)
        st_idle:    // In idle state, wait for a transaction request.
            next_state = i2c_exec ? st_sladdr : st_idle;

        st_sladdr:  // After sending the slave address...
            if (st_done)
                next_state = bit_ctrl ? st_addr16 : st_addr8; // Decide whether to send 16-bit or 8-bit register address.
            else
                next_state = st_sladdr;

        st_addr16:  // After sending the high byte of a 16-bit address...
            next_state = st_done ? st_addr8 : st_addr16; // Proceed to send the low byte.

        st_addr8:   // After sending the register address...
            if (st_done)
                next_state = wr_flag ? st_addr_rd : st_data_wr; // Decide whether to perform a read or a write.
            else
                next_state = st_addr8;

        st_data_wr: // After writing data...
            next_state = st_done ? st_stop : st_data_wr; // Proceed to the stop condition.

        st_addr_rd: // After sending the slave address for a read operation...
            next_state = st_done ? st_data_rd : st_addr_rd; // Proceed to read the data.

        st_data_rd: // After reading data...
            next_state = st_done ? st_stop : st_data_rd; // Proceed to the stop condition.

        st_stop:    // After the stop condition...
            next_state = st_done ? st_idle : st_stop; // Return to idle.
            
        default:
            next_state = st_idle;
    endcase
end
  
// Describe the state output of the sequential circuit
always @(posedge dri_clk or negedge rst_n) begin
    // Reset initialization
    if(!rst_n) begin
        scl        <= 1'b1;
        sda_out    <= 1'b1;
        sda_dir    <= 1'b1;
        i2c_done   <= 1'b0;
        cnt        <= 1'b0;
        st_done    <= 1'b0;
        data_r     <= 1'b0;
        i2c_data_r <= 1'b0;
        wr_flag    <= 1'b0;
        addr_t     <= 1'b0;
        data_wr_t  <= 1'b0;
    end
    else begin
        st_done <= 1'b0 ;
        cnt     <= cnt + 1'b1 ;
        case(cur_state)
            st_idle: begin                       // Idle state
                scl      <= 1'b1;
                sda_out  <= 1'b1;
                sda_dir  <= 1'b1;
                i2c_done <= 1'b0;
                cnt      <= 7'b0;
                if(i2c_exec) begin
                    wr_flag   <= i2c_rh_wl ;
                    addr_t    <= i2c_addr  ;
                    data_wr_t <= i2c_data_w;
                end
            end
            st_sladdr: begin                     // Write address (device address and word address)
                case(cnt)
                    7'd1 : sda_out <= 1'b0;       // Start I2C
                    7'd3 : scl     <= 1'b0;
                    7'd4 : sda_out <= SLAVE_ADDR[6]; // Transmit device address
                    7'd5 : scl     <= 1'b1;
                    7'd7 : scl     <= 1'b0;
                    7'd8 : sda_out <= SLAVE_ADDR[5];
                    7'd9 : scl     <= 1'b1;
                    7'd11: scl     <= 1'b0;
                    7'd12: sda_out <= SLAVE_ADDR[4];
                    7'd13: scl     <= 1'b1;
                    7'd15: scl     <= 1'b0;
                    7'd16: sda_out <= SLAVE_ADDR[3];
                    7'd17: scl     <= 1'b1;
                    7'd19: scl     <= 1'b0;
                    7'd20: sda_out <= SLAVE_ADDR[2];
                    7'd21: scl     <= 1'b1;
                    7'd23: scl     <= 1'b0;
                    7'd24: sda_out <= SLAVE_ADDR[1];
                    7'd25: scl     <= 1'b1;
                    7'd27: scl     <= 1'b0;
                    7'd28: sda_out <= SLAVE_ADDR[0];
                    7'd29: scl     <= 1'b1;
                    7'd31: scl     <= 1'b0;
                    7'd32: sda_out <= 1'b0;       // 0: Write
                    7'd33: scl     <= 1'b1;
                    7'd35: scl     <= 1'b0;
                    7'd36: begin
                        sda_dir <= 1'b0;       // Slave acknowledge
                        sda_out <= 1'b1;
                    end
                    7'd37: scl     <= 1'b1;
                    7'd38: st_done <= 1'b1;
                    7'd39: begin
                        scl <= 1'b0;
                        cnt <= 1'b0;
                    end
                    default : ;
                endcase
            end
  
            st_addr16: begin
                case(cnt)
                    7'd0 : begin
                        sda_dir <= 1'b1 ;
                        sda_out <= addr_t[15];       // Transmit word address
                    end
                    7'd1 : scl <= 1'b1;
                    7'd3 : scl <= 1'b0;
                    7'd4 : sda_out <= addr_t[14];
                    7'd5 : scl <= 1'b1;
                    7'd7 : scl <= 1'b0;
                    7'd8 : sda_out <= addr_t[13];
                    7'd9 : scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd12: sda_out <= addr_t[12];
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd16: sda_out <= addr_t[11];
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd20: sda_out <= addr_t[10];
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd24: sda_out <= addr_t[9];
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd28: sda_out <= addr_t[8];
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd32: begin
                        sda_dir <= 1'b0;       // Slave acknowledge
                        sda_out <= 1'b1;
                    end
                    7'd33: scl     <= 1'b1;
                    7'd34: st_done <= 1'b1;
                    7'd35: begin
                        scl <= 1'b0;
                        cnt <= 1'b0;
                    end
                    default : ;
                endcase
            end
            st_addr8: begin
                case(cnt)
                    7'd0: begin
                        sda_dir <= 1'b1 ;
                        sda_out <= addr_t[7];        // Word address
                    end
                    7'd1 : scl <= 1'b1;
                    7'd3 : scl <= 1'b0;
                    7'd4 : sda_out <= addr_t[6];
                    7'd5 : scl <= 1'b1;
                    7'd7 : scl <= 1'b0;
                    7'd8 : sda_out <= addr_t[5];
                    7'd9 : scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd12: sda_out <= addr_t[4];
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd16: sda_out <= addr_t[3];
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd20: sda_out <= addr_t[2];
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd24: sda_out <= addr_t[1];
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd28: sda_out <= addr_t[0];
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd32: begin
                        sda_dir <= 1'b0;       // Slave acknowledge
                        sda_out <= 1'b1;
                    end 
                    7'd33: scl     <= 1'b1;
                    7'd34: st_done <= 1'b1;
                    7'd35: begin
                        scl <= 1'b0;
                        cnt <= 1'b0;
                    end
                    default :  ;
                endcase
            end
            st_data_wr: begin                          // Write data (8 bits)
                case(cnt)
                    7'd0: begin
                        sda_out <= data_wr_t[7];       // I2C write 8-bit data
                        sda_dir <= 1'b1;
                    end
                    7'd1 : scl <= 1'b1;
                    7'd3 : scl <= 1'b0;
                    7'd4 : sda_out <= data_wr_t[6];
                    7'd5 : scl <= 1'b1;
                    7'd7 : scl <= 1'b0;
                    7'd8 : sda_out <= data_wr_t[5];
                    7'd9 : scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd12: sda_out <= data_wr_t[4];
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd16: sda_out <= data_wr_t[3];
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd20: sda_out <= data_wr_t[2];
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd24: sda_out <= data_wr_t[1];
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd28: sda_out <= data_wr_t[0];
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd32: begin
                        sda_dir <= 1'b0;               // Slave response
                        sda_out <= 1'b1;
                    end
                    7'd33: scl <= 1'b1;
                    7'd34: st_done <= 1'b1;
                    7'd35: begin
                        scl  <= 1'b0;
                        cnt  <= 1'b0;
                    end
                    default  :  ;
                endcase
            end


            
            st_addr_rd: begin                          // Write address to read data
                case(cnt)
                    7'd0 : begin
                        sda_dir <= 1'b1;
                        sda_out <= 1'b1;
                    end
                    7'd1 : scl <= 1'b1;
                    7'd2 : sda_out <= 1'b0;            // restart
                    7'd3 : scl <= 1'b0;
                    7'd4 : sda_out <= SLAVE_ADDR[6];   // Transmit device address
                    7'd5 : scl <= 1'b1;
                    7'd7 : scl <= 1'b0;
                    7'd8 : sda_out <= SLAVE_ADDR[5];
                    7'd9 : scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd12: sda_out <= SLAVE_ADDR[4];
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd16: sda_out <= SLAVE_ADDR[3];
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd20: sda_out <= SLAVE_ADDR[2];
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd24: sda_out <= SLAVE_ADDR[1];
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd28: sda_out <= SLAVE_ADDR[0];
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd32: sda_out <= 1'b1;            // read
                    7'd33: scl <= 1'b1;
                    7'd35: scl <= 1'b0;
                    7'd36: begin
                        sda_dir <= 1'b0;               // Slave response
                        sda_out <= 1'b1;
                    end
                    7'd37: scl     <= 1'b1;
                    7'd38: st_done <= 1'b1;
                    7'd39: begin
                        scl <= 1'b0;
                        cnt <= 1'b0;
                    end
                    default : ;
                endcase
            end
            st_data_rd: begin                          // Read data (8 bits)
                case(cnt)
                    7'd0: sda_dir <= 1'b0;
                    7'd1: begin
                        data_r[7] <= sda_in;
                        scl       <= 1'b1;
                    end
                    7'd3: scl  <= 1'b0;
                    7'd5: begin
                        data_r[6] <= sda_in ;
                        scl       <= 1'b1   ;
                    end
                    7'd7: scl  <= 1'b0;
                    7'd9: begin
                        data_r[5] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd11: scl  <= 1'b0;
                    7'd13: begin
                        data_r[4] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd15: scl  <= 1'b0;
                    7'd17: begin
                        data_r[3] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd19: scl  <= 1'b0;
                    7'd21: begin
                        data_r[2] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd23: scl  <= 1'b0;
                    7'd25: begin
                        data_r[1] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd27: scl  <= 1'b0;
                    7'd29: begin
                        data_r[0] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd31: scl  <= 1'b0;
                    7'd32: begin
                        sda_dir <= 1'b1;              // No response
                        sda_out <= 1'b1;
                    end
                    7'd33: scl     <= 1'b1;
                    7'd34: st_done <= 1'b1;
                    7'd35: begin
                        scl <= 1'b0;
                        cnt <= 1'b0;
                        i2c_data_r <= data_r;
                    end
                    default  :  ;
                endcase
            end
            st_stop: begin                            // End I2C operation
                case(cnt)
                    7'd0: begin
                        sda_dir <= 1'b1;              // End of I2C
                        sda_out <= 1'b0;
                    end
                    7'd1 : scl     <= 1'b1;
                    7'd3 : sda_out <= 1'b1;
                    7'd15: st_done <= 1'b1;
                    7'd16: begin
                        cnt      <= 1'b0;
                        i2c_done <= 1'b1;             // Pass the I2C end signal to the upper module
                    end
                    default  : ;
                endcase
            end
        endcase
    end
end

endmodule
