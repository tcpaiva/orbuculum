`default_nettype none

// SWD Interface for ARM CORTEX-M Chips
// ====================================
//
// This module interfaces directly to the SWD for I/O. It automatically 
// inserts turn-arounds as needed and the interface is clock-domain isolated.
//
// Copyright (C) 2018  Dave Marples  <dave@marples.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

module swd (
	    input 	      clk,         // The master clock for this module
	    input 	      rst,         // Synchronous reset.

	    // UP interface to routines making use of swd
	    // ==========================================
	    input [4:0]       bits,        // Number of bits remaining to be collected or sent
	    input 	      useParity,   // Flag indicating parity is required (on reception or transmission) 
	    output 	      parityGood,  // Indicator that tx or rx parity was OK
            input [5:0]       speedDivisor,// How much to slow SWD down by

	    input 	      txReq,       // Indicator of a transmission request
	    input [31:0]      dataToSWD,   // Data to be sent to swd interface
	    
	    input 	      rxReq,       // Indicator of a reception request
	    output reg [31:0] dataFromSWD, // Data received from SWD

	    output 	      busy,        // Indicator that SWD mechanism is busy

	    // DOWN Interface to SWD pins
	    // ==========================
	    output 	      swdIsOutput, // Direction of communication
	    input 	      swdIn,       // Input Data
	    output reg 	      swdOut,      // Output Data
	    output reg 	      swclk        // Clock Signal
	    );

   reg [1:0] 		  state;           // Current state of the machine
   reg [5:0] 		  bitCount;        // Number of bits processed
   reg [31:0] 		  workingWord;     // Work currently being processed
   reg 			  workingParity;   // Parity under construction
   reg [5:0] 		  tick;            // Divisor for incoming clock

   reg 			  parityPending;   // Flag indicating we need to consider parity (in or out)

   reg [2:0] 		  rxReqi;          // Receive request including clock alignment
   reg [2:0] 		  txReqi;          // Transmission request including clock alignment
   reg [4:0] 		  writePos;        // Position in output frame (number of bits received)

   reg 			  turning;         // Flag indicating transmission direction is changing

   parameter 
     STATE_IDLE=2'h0,        // SWD is idle
     STATE_RX=2'h1,          // SWD is receiving
     STATE_TX=2'h2;          // SWD is transmitting
   
   assign busy=(state!=STATE_IDLE);
   
   always @(posedge clk) begin
      if (rst)
	begin
	   state<=STATE_IDLE;
	   swclk<=0;
	   swdOut<=0;
	   swdIsOutput<=0;
	   turning<=0;
	end
      else
	begin
	   if (tick!=0)
	     tick<=tick-1;
	   else
	     begin
		tick<=speedDivisor;

		/* Make the clock run if we're not idle, or its not zero */
		if ((state!=STATE_IDLE) || (swclk==0)) swclk<=!swclk;
		
		/* This is just about to be a rising edge on the next clock - sample data and set next */

		case (state) 
		  STATE_IDLE: // -------------------------------------------------------------------
		    begin
		       parityPending<=useParity;
		       workingParity<=0;
		       bitCount<={1'b0,bits}+1;
		       writePos<=0;

		       if (swclk==1'b1)
			 begin
			    /* Move reception and transmission signals into our timing domain */
			    rxReqi={rxReqi[1:0],rxReq};
			    txReqi={txReqi[1:0],txReq};

			    /* Start TX or RX if there's a rising edge on either of  those signals */
			    if (rxReqi[2:1]==2'b01)
			      begin
				 turning<=(swdIsOutput==1);
				 dataFromSWD<=0;
				 swdIsOutput<=0;
				 state<=STATE_RX;
			      end
			    else
			      if (txReqi[2:1]==2'b01)
				begin
				   turning<=(swdIsOutput==0);
				   swdIsOutput<=1;
				   workingWord<=dataToSWD;
				   state<=STATE_TX;
				end
			      else
				state<=STATE_IDLE;
			 end
		       else
			 state<=STATE_IDLE;
		    end // case: STATE_IDLE
		       
		  STATE_RX: // ==========================================================
		    begin
		       if (swclk==1) /* Sampling just before the falling edge */
			 begin
			    state<=STATE_RX;
			    turning<=0;
			    if (turning==0)
			      begin
				 if (bitCount>0)
				   begin
				      /* Something to arrive - either data or parity */
				      dataFromSWD[writePos]<=swdIn;
				      workingParity<=workingParity+swdIn;
				      writePos<=writePos+1;
				      bitCount<=bitCount-1;
				   end
				 else
				   begin
				      if (parityPending)
					begin
					   parityGood<=(workingParity==swdIn);
					   parityPending<=0;
					end
				   end
			      end // if (turning==0)
			 end // if (swclk==1)
		       else
		       	 begin
			    if ((bitCount==0) && (parityPending==0))
			      state<=STATE_IDLE;
			    else
			      state<=STATE_RX;
			 end
		    end // case: STATE_RX
		  
		  STATE_TX: // ==========================================================
		    begin
		       if (swclk==1)
			 begin
			    state<=STATE_TX;
			    turning<=0;
			    if (turning==0)
			      begin
				 if (bitCount==0)
				   begin
				      parityPending<=0;
				      /* We can only get here if there's parity to output */ 
				      swdOut<=workingParity;
				   end
				 else
				   begin
				      /* SWD is output LSB first...best respect that */
				      workingParity<=workingParity+workingWord[0];
				      swdOut<=workingWord[0];
				      workingWord<={1'b0,workingWord[31:1]};
				      bitCount<=bitCount-1;
				   end // else: !if(bitCount==0)
			      end // if (turning==0)
			 end // if (swclk==1)
		       else
			 begin
			    if ((bitCount==0) && (parityPending==0))
			      state<=STATE_IDLE;
			    else
			      state<=STATE_TX;
			 end
		    end // case: STATE_TX
		  
		  default: begin end
		endcase // case (state)
	     end // if (tick==0)
	end // else: !if(rst)
   end // always @ (posedge clk)
endmodule // swd

   

  
  
