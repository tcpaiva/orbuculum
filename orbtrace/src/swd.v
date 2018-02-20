`default_nettype none

module swd (
	    input 	      clk, // The master clock for this module
	    input 	      rst, // Synchronous reset.

	    // UP interface to routines making use of swd
	    // ==========================================
	    input [4:0]       bits, // Number of bits to be collected or sent
	    input 	      useParity, // Flag indicating parity is required (on reception or transmission) 
	    output 	      parityGood, // Indicator that tx or rx parity was OK

	    input 	      txReq, // Indicator of a transmission request
	    input [31:0]      dataToSWD, // Data to be sent to swd interface
	    
	    input 	      rxReq, // Indicator of a reception request
	    output reg [31:0] dataFromSWD,// Data received from SWD

	    output 	      busy, // Indicator that SWD mechanism is busy

	    // DOWN Interface to SWD pins
	    // ==========================
	    output 	      swdIsOutput, // Direction of communication
	    input 	      swdIn, // Input Data
	    output reg 	      swdOut, // Output Data
	    output reg 	      swclk         // Clock Signal
	    );
   
   reg [1:0] 		  state;
   reg [5:0] 		  bitCount;
   reg [31:0] 		  workingWord;
   reg 			  workingParity;
   reg [2:0] 		  tick;
   reg 			  parityPending;
   reg [2:0] 		  rxReqi;
   reg 			  oldrxReqi;
   reg [2:0] 		  txReqi;
   reg 			  oldtxReqi;
   reg [4:0] 		  writePos;
   reg 			  turning;
   reg 			  currentlyOp;

   parameter 
     STATE_IDLE=0,
     STATE_RX=1,
     STATE_TX=2;
   
   assign swdIsOutput=currentlyOp;   
   assign busy=(state!=STATE_IDLE);
   
   always @(posedge clk) begin
      if (rst)
	begin
	   state<=STATE_IDLE;
	   swclk<=0;
	   swdOut<=0;
	   currentlyOp<=0;
	   turning<=0;
	end
      else
	begin
	   /* Make the clock run if we're not idle, or its not zero */
	   tick<=tick+1;
	   rxReqi={rxReqi[1:0],rxReq};
	   txReqi={txReqi[1:0],txReq};

	   if (tick==0)
	     begin

		if ((state!=STATE_IDLE) || (swclk==0)) swclk<=!swclk;
		
		/* This is just about to be a rising edge on the next clock - sample data and set next */

		case (state) 
		  STATE_IDLE: // -------------------------------------------------------------------
		    begin
		       parityPending<=useParity;
		       workingParity<=0;
		       oldrxReqi<=rxReqi[2];
		       oldtxReqi<=txReqi[2];			    
			    
		       if ((rxReqi[2]==1'b1) && (oldrxReqi==0))
			 begin
			    turning<=(currentlyOp==1);
			    bitCount<={1'b0,bits}+1;
			    writePos<=0;
			    dataFromSWD<=0;
			    currentlyOp<=0;
			    state<=STATE_RX;
			 end
		       else
			 begin
			    if ((txReqi[2]==1'b1) && (oldtxReqi==0))
			      begin
				 turning<=(currentlyOp==0);
				 bitCount<={1'b0,bits}+1;
				 currentlyOp<=1;
				 workingWord<=dataToSWD;
				 state<=STATE_TX;
			      end
			    else
			      begin
				 state<=STATE_IDLE;
			      end
			 end // else: !if((rxReqi[2]==1'b1) && (oldrxReqi==0))
		    end // case: STATE_IDLE
		       
		  STATE_RX: // ==========================================================
		    begin
		       currentlyOp<=0;		       
		       if (swclk==1) /* Sampling just before the falling edge */
			 begin
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
			 end // if (swclk==0)
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
			    currentlyOp<=1;
			    if (turning==0)
			      begin
				 if ((bitCount!=0) || (parityPending!=0))
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
				   end
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

   

  
  
