`default_nettype none

module spi (
	    input 	      clk, // The master clock for this module
	    input 	      rst, // Synchronous reset.
	    input 	      sel, 
	    
	    output reg 	      tx, // Outgoing serial line
	    input 	      rx,
 	 
	    input 	      dClk,
	    input 	      transmitIn, // Signal to transmit
	    input [15:0]      tx_word, // Byte to transmit
	    output 	      tx_free, // Indicator that transmit register is available
	    output 	      is_transmitting, // Low when transmit line is idle.
	    input 	      sync,
	    output [2:0]      widthEnc,
	    output 	      rxFrameReset,

	    // Messages to/from SWD subsystem
	    output 	      rxReq, // Request reception over SWD
	    output 	      txReq, // Request transmission over SWD
	    output 	      useParity, // Do we want parity support?
	    output reg [31:0] SWDinputData, // Data to go over SWD bus
	    output [4:0]      bits, // Number of bits for SWD bus
	    input [31:0]      SWDoutputData, // Data sourced from SWD bus
	    input 	      SWDoutputParity, // Receive parity sourced from SWD bus
	    input 	      SWDbusy // Flag indicating SWD bus is busy
	    );
   
   reg 			 realTransmission;    // Is this real data or an empty frame
   reg [1:0] 		 width;               // How wide the pins are on the CPU (0-->1, 1-->2, 2-->x, 3-->4)
 			 
   reg [15:0] 		 tx_ledstretch;       // Stretch the LED so it can be seen
   reg  		 twobytes;            // How many bytes in this word of the frame left?
   reg [3:0] 		 words_remaining;     // How many words in this frame left
   reg [15:0] 		 tx_data;             // Holding for the data being shifted to line
   reg [7:0] 		 rx_data;             // Holding for the data being received from line
   reg [2:0] 		 bitcount;            // Number of bits of this byte rxed (or txed) so far
	
   reg 			 prevSel;
   reg 			 selEdge;
   reg 			 seenSelEdge;
   reg [31:0] 		 construct;
   reg [2:0] 		 SWDbusyi;
   
   reg [4:0] 		 cwp;                 // Position we are writing in collected word
   
   
   reg [2:0] 		 spiState;            // What we are doing and writing out to the SPI line

   // Light the LED if we are transmitting (or have been recently)
   assign is_transmitting=(tx_ledstretch!=0);

   parameter
     WAIT_COMMAND=0,
     SWD_WRITE_COLLECT=1,
     SWD_WRITE_WAIT=2,
     SEND_SWO=3,
     SWD_READ=4,
     SWD_READ_OUTPUT=5;
   
   

   
   always @(posedge clk)    // Check transmission state and store it (done using main clock) ========
     if (rst) 
       begin
	  tx_ledstretch <= 0;
	  selEdge = 0;
       end
     else
       begin
	  // Logic to deal with spotting SEL falling in absence of spi clk at that point
	  prevSel<=sel;
	  if ((sel==1) || ((sel==0) && (seenSelEdge==1)))
	    selEdge=0;
	  else
	    if ((sel==0) && (prevSel==1))
	      selEdge=1;

	  if (realTransmission) tx_ledstretch<=~0;
	  else
	    if (tx_ledstretch!=0) tx_ledstretch <= tx_ledstretch-1;
       end

   always @(posedge dClk)  // Capture the bit from the SPI master ===================================
     begin
	if (rst) bitcount=0;
	else
	  begin
	     tx=tx_data[15];

	     if (selEdge==1)
	       begin
		  bitcount=0;
		  seenSelEdge=1;
	       end
	     else
	       begin
		  bitcount=bitcount+1;
		  seenSelEdge=0;
	       end
	  end
     end // always @ (posedge dClk)

   
   always @(negedge dClk or posedge rst)  // Send output bits clocked by SPI clk ===================================

     begin
	if (rst)
	  begin
	     width<=3;
	     widthEnc<=4;
	     rxReq<=0;
	     txReq<=0;
	     rx_data=0;
	     bits<=0;
	     spiState<=WAIT_COMMAND;
	  end
	else
	  begin
	     /* Make sure we reset unconditionally at the start of a packet */     
	     if (seenSelEdge==1) 
	       begin
		  spiState<=WAIT_COMMAND;
		  rx_data={7'h00,rx};
		  twobytes<=0;
	       end
	     else
	       begin

	     /* Collect next bit of the input data */
	     rx_data={rx_data[6:0],rx};

	     /* Collect the bits we need, 16 bits if nessessary */
	     if (bitcount==7)
	       if (twobytes==1'b1)
		 twobytes<=1'b0;
	       else
		 begin
		    /* Move along the busy status */
		    SWDbusyi={SWDbusyi[1:0],SWDbusy};

	       case (spiState)
		 WAIT_COMMAND:  // =====================================================================
		   begin
		      txReq<=0;
		      case (rx_data[7:6])
			2'b00: // Idle, or write-----------------------------------------------------
			  begin
			     rxFrameReset<=0;
			     rxReq<=0;
			     
			     if (rx_data!=8'h00)
			       begin // Deal with SWD write request -----------------------------------
				  useParity<=rx_data[5];
				  spiState<=SWD_WRITE_COLLECT;
				  construct=0;
				  bits<=rx_data[4:0];
				  cwp<=7;
				  tx_data={8'b00010000,8'h0};  
				  words_remaining<={2'b00,rx_data[4:3]}+1;
			       end // if (rx_data!=8'h00)
			  end // case: 2'b00

			2'b10: // SWO Management Request --------------------------------------------
			  begin
			     rxReq<=0;
			     if (rx_data==8'hA5) // Deal with frame reset 
			       rxFrameReset<=1;
			     else
			       if ({rx_data[7:2],2'b0}==8'h80) // Handle request for any SWO frames to be sent
				 begin
				    rxFrameReset<=0;
				    spiState<=SEND_SWO;
				    // Only really interested in the one that sets up the transmission
				    width<=rx_data[1:0];
				    widthEnc<={1'b0,rx_data[1:0]}+1;
				 
				    // We need these right now to be able to make sense of the following...
				    words_remaining <= 8;
				    realTransmission <= transmitIn;
				    tx_data = {transmitIn,4'h0,width,sync,8'h00};				    
				 end // if ({rx_data[7:2],2'b0}==8'h10)
			  end // case: 2'b10

			2'b01: // SWD Read Request --------------------------------------------------
			  begin
			     rxFrameReset<=0;
			     rxReq<=1;

			     useParity<=rx_data[5];
			     spiState<=SWD_READ;
			     bits<=rx_data[4:0];
			     words_remaining<={2'b00,rx_data[4:3]}+1;
			     tx_data = {8'b00001000,8'h00};
			  end

			2'b11: // Idle line, ignore
			  begin
			     rxReq<=0;
			     rxFrameReset<=0;
			  end
		      endcase // case (rx_data[7:6])
		   end // case: WAIT_COMMAND
		 
		 SWD_READ: // =====================================================================
		   begin
		      txReq<=0;		      		      
		      rxFrameReset<=0;

		      /* Look for falling edge of the busy signal */
		      if (SWDbusyi[2:1]==2'b10)
			begin
			   /* First byte - read complete and bytes remaining */
			   rxReq<=0;
			   tx_data = {5'b10001,SWDoutputParity,words_remaining[1:0],8'h0};
			   construct=SWDoutputData;
			   spiState<=SWD_READ_OUTPUT;
			end // if (!SWDbusyi[2])
		      else
			tx_data = {8'b00001000,8'h00};
		   end
		 
		 SWD_READ_OUTPUT: // =====================================================================
		   begin
		      rxReq<=0;
		      txReq<=0;
		      rxFrameReset<=0;		      
		      // Hey, we've got data...upload the next bit of it
		      if (words_remaining!=0)
			begin
			   words_remaining<=words_remaining-1;
			   tx_data = {construct[7:0],8'h00};
			   construct={8'h00,construct[31:8]};
			end
		      else
			begin
			   /* Now we spew SWO frames until forced back to idle */
			   spiState<=SEND_SWO;
			   words_remaining <= 8;
			   realTransmission <= transmitIn;
			   tx_data = {transmitIn,4'h0,width,sync,8'h00};				    			   
			   //tx_data = 0;
			   //spiState<=WAIT_COMMAND;
			end
		   end
		 
		 SWD_WRITE_COLLECT:  // =====================================================================
		   begin
		      rxReq<=0;
		      rxFrameReset<=0;
		      tx_data={8'b00010000,8'h0};  
		      
		      if (words_remaining!=0)
			begin
			   // Drag this byte into the tx sequence
			   SWDinputData[cwp -:8]<=rx_data;
			   cwp<=cwp+8;
			   // We still have more to collect
			   words_remaining<=words_remaining-1;
			end
		      else
			begin
			   // We are done collecting - trigger transmission and wait for response
			   spiState<=SWD_WRITE_WAIT;
			   txReq<=1;			 
			end
		   end
		 
		 SWD_WRITE_WAIT: // =====================================================================
		   begin
		      rxReq<=0;
		      rxFrameReset<=0;
		      tx_data={!SWDbusyi[2],7'b0010000,8'h0};
		      if (SWDbusyi[2:1]==2'b10) 
			begin
			   spiState<=SEND_SWO;
			   words_remaining <= 8;
			   realTransmission <= transmitIn;
			   tx_data = {transmitIn,4'h0,width,sync,8'h00};			   
//			   txReq<=0;
//			   spiState<=WAIT_COMMAND;
			end
		   end
		 
		 SEND_SWO:  // =====================================================================
		   begin
		      rxFrameReset<=0;
		      // End of this word, find the next one
		      if (words_remaining==0)
			begin
			   words_remaining <= 8;
			   realTransmission <= transmitIn;
			   tx_data = {transmitIn,4'h0,width,sync,8'h00};
			end
		      else
			begin
			   // We have more words in this frame - get them
			   if (realTransmission)
			     begin
				// We send these to the host the other way up
				tx_data={tx_word[7:0],tx_word[15:8]};
				
				// ...and get the next word ready
				tx_free<=1;
			     end
			   else
			     begin
				// If this isn't a real data frame then transmit zeros
				tx_data=0;
			     end
			   
			   // Whatever happened, we have a frame to transmit now
			   twobytes<=1;
			   words_remaining<=words_remaining-1;
			end // else: !if(words_remaining==0)	 
		   end // case: SEND_SWO
	       endcase // case (spiState)
		  end
	     else
	       begin
		  // Reset next data request if it's stretched for long enough
		  tx_free<=0;
		  tx_data={tx_data[14:0],1'b0};
	       end // else: !if(bitcount==0)
	  end // else: !if(rst)
	     end
     end // always @ (posedge dClk)
endmodule // spi


