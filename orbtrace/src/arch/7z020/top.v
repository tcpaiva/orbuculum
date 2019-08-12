`default_nettype none

module top (
            input wire [3:0] traceDin, // Port is always 4 bits wide, even if we use less
            input wire       traceClk, // Supporting clock for input - must be on a global clock pin
            
            output wire      spitx,
            output wire      spirx, 
            input  wire      spiclk,
	    
            input  wire      uartrx, // Receive data into UART
            output wire      uarttx, // Transmit data from UART 
            
	    // Leds....
            output wire sync_led,
            output wire txInd_led, // Transmitted UART Data indication
            output wire txOvf_led,
            output reg  heartbeat_led,
	    
	    // Config and housekeeping
            input  wire clkIn,
            input  wire rstIn,
            
	    // Other indicators
            output reg D5,
            output reg D4,
            output reg D3,
            output reg D2,
            output reg cts
	                      
`ifdef INCLUDE_SUMP2
            , // Include SUMP2 connections
            input  wire        uartrx,
            output wire        uarttx,
            input  wire [15:0] events_din
`endif		
            );      

	    
   // Parameters =====================================================

   // Maximum bus width that system is set for...not more than 4!! 
   parameter MAX_BUS_WIDTH=4;  

   
   


   
   // Internals ===================================================
   //tcp wire 		   clk;


   // --------------------------------------------
   wire   BtraceClk;
   assign BtraceClk = traceClk;
   
   //tcp `ifdef NO_GB_IO_AVAILABLE
   //tcp // standard input pin for trace clock,
   //tcp // then route it into an internal global buffer.
   //tcp SB_GB BtraceClk0 (
   //tcp  .USER_SIGNAL_TO_GLOBAL_BUFFER(traceClk),
   //tcp  .GLOBAL_BUFFER_OUTPUT(BtraceClk)
   //tcp  );
   //tcp `else
   //tcp // Buffer for trace input clock
   //tcp SB_GB_IO #(.PIN_TYPE(6'b000000)) BtraceClk0
   //tcp (
   //tcp   .PACKAGE_PIN(traceClk),
   //tcp   .GLOBAL_BUFFER_OUTPUT(BtraceClk)
   //tcp );
   //tcp `endif

   // DDR input data
   wire [MAX_BUS_WIDTH-1:0]    tTraceDina;
   wire [MAX_BUS_WIDTH-1:0]    tTraceDinb;

   // --------------------------------------------
   // Trace input pins config   
   genvar i;
   generate
      for (i = 0; i < 4 ; i = i + 1) begin
         IDDR u_IDDR
               (.Q1(tTraceDina[i]), // 1-bit output for positive edge of clock
                .Q2(tTraceDinb[i]), // 1-bit output for negative edge of clock
                .C(BtraceClk),   // 1-bit clock input
                .CE(1'b1), // 1-bit clock enable input
                .D(traceDin[i]),   // 1-bait DDR data input
                .R(1'b0),   // 1-bit reset
                .S(1'b0));  // 1-bit set
      end
   endgenerate
   
   //tcp SB_IO #(.PULLUP(1), .PIN_TYPE(6'b0)) MtraceIn0
   //tcp (
   //tcp  .PACKAGE_PIN (traceDin[0]),
   //tcp  .INPUT_CLK (BtraceClk),
   //tcp  .D_IN_0 (tTraceDina[0]),
   //tcp  .D_IN_1 (tTraceDinb[0])
   //tcp  );
   //tcp
   //tcp SB_IO #(.PULLUP(1), .PIN_TYPE(6'b0)) MtraceIn1
   //tcp (
   //tcp  .PACKAGE_PIN (traceDin[1]),
   //tcp  .INPUT_CLK (BtraceClk),
   //tcp  .D_IN_0 (tTraceDina[1]),
   //tcp  .D_IN_1 (tTraceDinb[1])
   //tcp   );
   //tcp    
   //tcp SB_IO #(.PULLUP(1), .PIN_TYPE(6'b0)) MtraceIn2
   //tcp (
   //tcp  .PACKAGE_PIN (traceDin[2]),
   //tcp  .INPUT_CLK (BtraceClk),
   //tcp  .D_IN_0 (tTraceDina[2]),
   //tcp  .D_IN_1 (tTraceDinb[2])
   //tcp  );
   //tcp    
   //tcp SB_IO #(.PULLUP(1), .PIN_TYPE(6'b0)) MtraceIn3 
   //tcp (
   //tcp  .PACKAGE_PIN (traceDin[3]),
   //tcp  .INPUT_CLK (BtraceClk),
   //tcp  .D_IN_0 (tTraceDina[3]),
   //tcp  .D_IN_1 (tTraceDinb[3])
   //tcp  );

   // --------------------------------------------
   wire spiclkIn;
   reg spirxIn;

   assign spiclkIn = spiclk;

   always @(posedge spiclkIn) begin
      spirxIn <= spirx;
   end

   //tcp SB_IO #(.PULLUP(1), .PIN_TYPE(6'b000001)) SpiClkIn
   //tcp (
   //tcp  .PACKAGE_PIN (spiclk),
   //tcp  .D_IN_0 (spiclkIn),
   //tcp  );
   //tcp 
   //tcp SB_IO #(.PULLUP(1), .PIN_TYPE(6'b000001)) SpiRxIn
   //tcp (
   //tcp  .PACKAGE_PIN (spirx),
   //tcp  .INPUT_CLK (spiclkIn),
   //tcp  .D_IN_0 (spirxIn),
   //tcp  );
   
   // --------------------------------------------
	    
   wire 		    wclk;
   wire                     wdavail;
   wire [15:0]              packetwd;
   wire 		    packetr;
   wire                     rst;
   wire                     clkOut;
   wire [2:0]               widthSet;
   
   traceIF #(.BUSWIDTH(MAX_BUS_WIDTH)) traceif 
     (
      .clk(clkOut), 
      .rst(rst), 
      
      // Downwards interface to trace pins
      .traceDina(tTraceDina),       // Tracedata rising edge ... 1-n bits
      .traceDinb(tTraceDinb),       // Tracedata falling edge (LSB) ... 1-n bits		   
      .traceClkin(BtraceClk),       // Tracedata clock
      .width(widthSet),             // Current trace buffer width 
      
      // Upwards interface to packet processor
      .WdAvail(wdavail),            // Flag indicating word is available
      .PacketWd(packetwd),          // The next packet word
      .PacketReset(packetr),        // Flag indicating to start again
      
      .sync(sync_led));               // Indicator that we are in sync
   
   // --------------------------------------------

   wire [15:0]              filter_data;
   
   wire 		    dataAvail;
   wire 		    dataReady;
   
   wire 		    txFree;
   
   wire [7:0]               rx_byte_tl;
   wire 		    rxTrig_tl;
   wire 		    rxErr_tl;
   wire 		    frameReset;
   
   packSend marshall
     (.clk(clkOut), 
      .rst(rst), 
      
      .sync(sync_led), // Indicator of if we are in sync
      
      // Downwards interface to target interface
      .wrClk(BtraceClk),             // Clock for write side operations to fifo
      .WdAvail(wdavail),             // Flag indicating word is available
      .PacketReset(packetr),         // Flag indicating to start again
      .PacketWd(packetwd),           // The next packet word
      
      // Upwards interface to serial (or other) handler
      .rdClk(spiclkIn),
      .FrameReady(dataReady),
      .DataVal(filter_data),         // Output data value
      .DataNext(txFree),             // Request for data
      .DataFrameReset(frameReset),   // Reset to start of output frame
      .DataOverf(txOvf_led));        // Too much data in buffer


   spi 
     transmitter (.clk(clkOut), // The master clock for this module
		  .rst(rst), // Synchronous reset.
                  
		  .tx(spitx), // Outgoing serial line
		  .rx(spirxIn), // Incoming serial line
		  .dClk(spiclkIn),
		  .transmitIn(dataReady), // Signal to transmit
		  .tx_word(filter_data), // Byte to transmit
		  .tx_free(txFree), // Indicator that transmit register is available
		  .is_transmitting(txInd_led), // Low when transmit line is idle.
		  .sync(sync_led),
		  .widthEnc(widthSet),
		  .rxFrameReset(frameReset)
		  );

   // --------------------------------------------
   
   wire lock; // Indicator that PLL has locked
   wire clk_fb;

   MMCME2_BASE 
     #(
       .CLKFBOUT_MULT_F(20.0), // Multiply value for all CLKOUT
                               // (2.000-64.000).
       .CLKIN1_PERIOD(20.833), // Input clock period in ns to ps
                               // resolution (i.e. 33.333 is 30 MHz).
       .CLKOUT1_DIVIDE(80),
       .DIVCLK_DIVIDE(1), // Master division value (1-106)
       .STARTUP_WAIT("TRUE") // Delays DONE until MMCM is locked
                             // (FALSE, TRUE)
       )
   u_MMCM (
           .CLKOUT0(clkOut), // 1-bit output: CLKOUT0
           .CLKOUT0B(), // 1-bit output: Inverted CLKOUT0
           .CLKOUT1(), // 1-bit output: CLKOUT1
           .CLKOUT1B(), // 1-bit output: Inverted CLKOUT1
           .CLKOUT2(), // 1-bit output: CLKOUT2
           .CLKOUT2B(), // 1-bit output: Inverted CLKOUT2
           .CLKOUT3(), // 1-bit output: CLKOUT3
           .CLKOUT3B(), // 1-bit output: Inverted CLKOUT3
           .CLKOUT4(), // 1-bit output: CLKOUT4
           .CLKOUT5(), // 1-bit output: CLKOUT5
           .CLKOUT6(), // 1-bit output: CLKOUT6 Feedback Clocks: 1-bit
                       // (each) output: Clock feedback ports
           .CLKFBOUT(clk_fb),  // 1-bit output: Feedback clock
           .CLKFBOUTB(), // 1-bit output: Inverted CLKFBOUT
           .LOCKED(lock), // 1-bit output: LOCK
           .CLKIN1(clkIn), // 1-bit input: Clock
           .PWRDWN(1'b0), // 1-bit input: Power-down
           .RST(1'b1), // 1-bit input: Reset
           .CLKFBIN(clk_fb) // 1-bit input: Feedback clock
           );

   
//tcp  // Set up clock for 48Mhz with input of 12MHz
//tcp    SB_PLL40_CORE #(
//tcp 		   .FEEDBACK_PATH("SIMPLE"),
//tcp 		   .PLLOUT_SELECT("GENCLK"),
//tcp 		   .DIVR(4'b0000),
//tcp 		   .DIVF(7'b0111111),
//tcp 		   .DIVQ(3'b100),
//tcp 		   .FILTER_RANGE(3'b001)
//tcp 		   ) uut (
//tcp 			  .LOCK(lock),
//tcp 			  .RESETB(1'b1),
//tcp 			  .BYPASS(1'b0),
//tcp 			  .REFERENCECLK(clkIn),
//tcp 			  .PLLOUTCORE(clkOut)
//tcp 			  );
//tcp
   
   reg [25:0]               clkCount;
   
   // We don't want anything awake until the clocks are stable
   assign rst=(lock&rstIn);
   
   always @(posedge clkOut) begin
      if (rst) begin
	 cts<=1'b0;
	 clkCount <= 0;
         // sync_led<=0;
         // txOvf_led<=0;
         // txInd_led<=0;
         // heartbeat_led<=0;
         // D5<=0;
         // D4<=0;
         // D3<=0;
         // D2<=0;
      end
      else begin	  
	 clkCount <= clkCount + 1;
	 heartbeat_led<=clkCount[25];
      end // else: !if(rst)
   end // always @ (posedge clkOut)

   // ================================================================
   // ================================================================
   // ================================================================
   // SUMP SETUP
   // ================================================================
   // ================================================================
   // ================================================================
   
//tcp    
//tcp `ifdef INCLUDE_SUMP2
//tcp 
//tcp    wire          lb_wr;
//tcp    wire          lb_rd;
//tcp    wire [31:0] 	 lb_addr;
//tcp    wire [31:0] 	 lb_wr_d;
//tcp    wire [31:0] 	 lb_rd_d;
//tcp    wire          lb_rd_rdy;
//tcp    wire [23:0] 	 events_loc;
//tcp    
//tcp    wire          clk_96m_loc;
//tcp    wire          clk_cap_tree;
//tcp    wire          clk_lb_tree;
//tcp    //wire          reset_core;
//tcp    wire          reset_loc;
//tcp    wire          pll_lock;
//tcp    
//tcp    wire          mesa_wi_loc;
//tcp    wire          mesa_wo_loc;
//tcp    wire          mesa_ri_loc;
//tcp    wire          mesa_ro_loc;
//tcp    
//tcp    wire          mesa_wi_nib_en;
//tcp    wire [3:0] 	 mesa_wi_nib_d;
//tcp    wire          mesa_wo_byte_en;
//tcp    wire [7:0] 	 mesa_wo_byte_d;
//tcp    wire          mesa_wo_busy;
//tcp    wire          mesa_ro_byte_en;
//tcp    wire [7:0] 	 mesa_ro_byte_d;
//tcp    wire          mesa_ro_busy;
//tcp    wire          mesa_ro_done;
//tcp    wire [7:0] 	 mesa_core_ro_byte_d;
//tcp    wire          mesa_core_ro_byte_en;
//tcp    wire          mesa_core_ro_done;
//tcp    wire          mesa_core_ro_busy;
//tcp    
//tcp    
//tcp    wire          mesa_wi_baudlock;
//tcp    wire [3:0] 	 led_bus;
//tcp    reg [7:0] 	 test_cnt;
//tcp    reg           ck_togl;
//tcp    
//tcp    wire 	 mesaspisck;
//tcp    wire 	 mesaspics;
//tcp    wire 	 mesaspimiso;
//tcp    wire 	 mesaspimosi;
//tcp    
//tcp 
//tcp    assign D5 = led_bus[0];
//tcp    assign D4 = led_bus[1];
//tcp    assign D3 = led_bus[2];
//tcp    assign D2 = led_bus[3];
//tcp    
//tcp    assign reset_loc = 0;
//tcp    //assign reset_core = ~ pll_lock;// didn't fit
//tcp    
//tcp    // Hookup FTDI RX and TX pins to MesaBus Phy
//tcp    assign mesa_wi_loc = uartrx;
//tcp    assign uarttx     = mesa_ro_loc;
//tcp    
//tcp    assign events_loc[3:0] = tTraceDina;
//tcp    assign events_loc[7:4] = tTraceDinb;   
//tcp    assign events_loc[8] = clkIn;
//tcp    assign events_loc[9] = txOvf_led;
//tcp 
//tcp    assign events_loc[10] = BtraceClk;
//tcp    assign events_loc[11] = wdavail;
//tcp    assign events_loc[12] = packetr;
//tcp    assign events_loc[13] = packetwd;
//tcp    
//tcp    assign events_loc[14] = dataReady;
//tcp //   assign events_loc[15] = txFree;
//tcp //   assign events_loc[11] = frameReset;
//tcp 
//tcp    assign events_loc[15] = sync_led;
//tcp    
//tcp   
//tcp //   assign events_loc[7:0]   = events_din[7:0];
//tcp //   assign events_loc[15:8]  = events_din[15:8];
//tcp    //assign events_loc[23:16] = { p119,p118,p117,p116,p115,p114,p113,p112 };
//tcp    assign events_loc[23:16] = 8'd0;// Didn't fit
//tcp    
//tcp    
//tcp    //-----------------------------------------------------------------------------
//tcp // PLL generated by Lattice GUI to multiply 12 MHz to 96 MHz
//tcp // PLL's RESET port is active low. How messed up of a signal name is that?
//tcp //-----------------------------------------------------------------------------
//tcp    top_pll u_top_pll
//tcp      (
//tcp       .REFERENCECLK ( clkIn     ),
//tcp       .PLLOUTCORE   (             ),
//tcp       .PLLOUTGLOBAL ( clk_96m_loc ),
//tcp       .LOCK         ( pll_lock    ),
//tcp       .RESET        ( 1'b1        )
//tcp       );
//tcp    
//tcp    
//tcp    SB_GB u0_sb_gb 
//tcp      (
//tcp       //.USER_SIGNAL_TO_GLOBAL_BUFFER ( clk_12m      ),
//tcp       .USER_SIGNAL_TO_GLOBAL_BUFFER ( ck_togl      ),
//tcp       //.USER_SIGNAL_TO_GLOBAL_BUFFER ( clk_96m_loc  ),
//tcp       .GLOBAL_BUFFER_OUTPUT         ( clk_lb_tree  )
//tcp       );
//tcp    // Note: sump2.v modified to conserve resources requires single clock domain
//tcp    //assign clk_cap_tree = clk_lb_tree;
//tcp 
//tcp    SB_GB u1_sb_gb 
//tcp      (
//tcp       //.USER_SIGNAL_TO_GLOBAL_BUFFER ( ck_cap_togl  ),
//tcp       .USER_SIGNAL_TO_GLOBAL_BUFFER ( clk_96m_loc  ),
//tcp       .GLOBAL_BUFFER_OUTPUT         ( clk_cap_tree )
//tcp       );
//tcp    // assign clk_lb_tree = clk_12m;
//tcp    
//tcp    
//tcp    //-----------------------------------------------------------------------------
//tcp    // Note: 40kHz modulated ir_rxd signal looks like this
//tcp    //  \_____/                       \___/                      \___/
//tcp    //  |<2us>|<-------24us----------->
//tcp    //-----------------------------------------------------------------------------
//tcp    
//tcp    
//tcp    //-----------------------------------------------------------------------------
//tcp    // Toggle Flop To generate slower capture clocks.
//tcp    // 12MHz div-6  = 1 MHz toggle   1uS Sample
//tcp    // 12MHz div-48 = 125 kHz toggle 8uS Sample
//tcp    //-----------------------------------------------------------------------------
//tcp    //always @ ( posedge clk_12m ) begin : proc_div
//tcp    always @ ( posedge clk_cap_tree ) begin : proc_div
//tcp       begin
//tcp 	 test_cnt <= test_cnt[7:0] + 1;
//tcp 	 // ck_togl  <= ~ ck_togl;// 48 MHz
//tcp 	 ck_togl  <= test_cnt[1];// 24 MHz
//tcp       end
//tcp    end // proc_div
//tcp    
//tcp    
//tcp    
//tcp    //-----------------------------------------------------------------------------
//tcp    // FSM for reporting ID : This also muxes in Ro Byte path from Core
//tcp    // This didn't fit in ICE-Stick, so removed.
//tcp    //-----------------------------------------------------------------------------
//tcp    //mesa_id u_mesa_id
//tcp    //(
//tcp    //  .reset                 ( reset_loc                ),
//tcp    //  .clk                   ( clk_lb_tree              ),
//tcp    //  .report_id             ( report_id                ),
//tcp    //  .id_mfr                ( 32'h00000001             ),
//tcp    //  .id_dev                ( 32'h00000002             ),
//tcp    //  .id_snum               ( 32'h00000001             ),
//tcp    //
//tcp    //  .mesa_core_ro_byte_en  ( mesa_core_ro_byte_en     ),
//tcp    //  .mesa_core_ro_byte_d   ( mesa_core_ro_byte_d[7:0] ),
//tcp    //  .mesa_core_ro_done     ( mesa_core_ro_done        ),
//tcp    //  .mesa_ro_byte_en       ( mesa_ro_byte_en          ),
//tcp    //  .mesa_ro_byte_d        ( mesa_ro_byte_d[7:0]      ),
//tcp    //  .mesa_ro_done          ( mesa_ro_done             ),
//tcp    //  .mesa_ro_busy          ( mesa_ro_busy             )
//tcp    //);// module mesa_id
//tcp    assign mesa_ro_byte_d[7:0] = mesa_core_ro_byte_d[7:0];
//tcp    assign mesa_ro_byte_en     = mesa_core_ro_byte_en;
//tcp    assign mesa_ro_done        = mesa_core_ro_done;
//tcp    assign mesa_core_ro_busy   = mesa_ro_busy;
//tcp    
//tcp    //-----------------------------------------------------------------------------
//tcp    // MesaBus Phy : Convert UART serial to/from binary for Mesa Bus Interface
//tcp    //  This translates between bits and bytes
//tcp    //-----------------------------------------------------------------------------
//tcp    mesa_phy u_mesa_phy
//tcp      (
//tcp       //.reset            ( reset_core          ),
//tcp       .reset            ( reset_loc           ),
//tcp       .clk              ( clk_lb_tree         ),
//tcp       .clr_baudlock     ( 1'b0                ),
//tcp       .disable_chain    ( 1'b1                ),
//tcp       .mesa_wi_baudlock ( mesa_wi_baudlock    ),
//tcp       .mesa_wi          ( mesa_wi_loc         ),
//tcp       .mesa_ro          ( mesa_ro_loc         ),
//tcp       .mesa_wo          ( mesa_wo_loc         ),
//tcp       .mesa_ri          ( mesa_ri_loc         ),
//tcp       .mesa_wi_nib_en   ( mesa_wi_nib_en      ),
//tcp       .mesa_wi_nib_d    ( mesa_wi_nib_d[3:0]  ),
//tcp       .mesa_wo_byte_en  ( mesa_wo_byte_en     ),
//tcp       .mesa_wo_byte_d   ( mesa_wo_byte_d[7:0] ),
//tcp       .mesa_wo_busy     ( mesa_wo_busy        ),
//tcp       .mesa_ro_byte_en  ( mesa_ro_byte_en     ),
//tcp       .mesa_ro_byte_d   ( mesa_ro_byte_d[7:0] ),
//tcp       .mesa_ro_busy     ( mesa_ro_busy        ),
//tcp       .mesa_ro_done     ( mesa_ro_done        )
//tcp       );// module mesa_phy
//tcp    
//tcp    
//tcp    //-----------------------------------------------------------------------------
//tcp    // MesaBus Core : Decode Slot,Subslot,Command Info and translate to LocalBus
//tcp    //-----------------------------------------------------------------------------
//tcp    mesa_core 
//tcp      #
//tcp      (
//tcp       .spi_prom_en       ( 1'b0                       )
//tcp       )
//tcp    
//tcp    u_mesa_core
//tcp      (
//tcp       //.reset               ( reset_core               ),
//tcp       .reset               ( ~mesa_wi_baudlock        ),
//tcp       .clk                 ( clk_lb_tree              ),
//tcp       .spi_sck             ( mesaspisck               ),
//tcp       .spi_cs_l            ( mesaspics                ),
//tcp       .spi_mosi            ( mesaspimosi              ),
//tcp       .spi_miso            ( mesaspimiso              ),
//tcp       .rx_in_d             ( mesa_wi_nib_d[3:0]       ),
//tcp       .rx_in_rdy           ( mesa_wi_nib_en           ),
//tcp       .tx_byte_d           ( mesa_core_ro_byte_d[7:0] ),
//tcp       .tx_byte_rdy         ( mesa_core_ro_byte_en     ),
//tcp       .tx_done             ( mesa_core_ro_done        ),
//tcp       .tx_busy             ( mesa_core_ro_busy        ),
//tcp       .tx_wo_byte          ( mesa_wo_byte_d[7:0]      ),
//tcp       .tx_wo_rdy           ( mesa_wo_byte_en          ),
//tcp       .subslot_ctrl        (                          ),
//tcp       .bist_req            (                          ),
//tcp       .reconfig_req        (                          ),
//tcp       .reconfig_addr       (                          ),
//tcp       .oob_en              ( 1'b0                     ),
//tcp       .oob_done            ( 1'b0                     ),
//tcp       .lb_wr               ( lb_wr                    ),
//tcp       .lb_rd               ( lb_rd                    ),
//tcp       .lb_wr_d             ( lb_wr_d[31:0]            ),
//tcp       .lb_addr             ( lb_addr[31:0]            ),
//tcp       .lb_rd_d             ( lb_rd_d[31:0]            ),
//tcp       .lb_rd_rdy           ( lb_rd_rdy                )
//tcp       );// module mesa_core
//tcp    
//tcp    
//tcp    //-----------------------------------------------------------------------------
//tcp    // Design Specific Logic
//tcp    //-----------------------------------------------------------------------------
//tcp    core u_core 
//tcp      (
//tcp       //.reset               ( reset_core               ),
//tcp       .reset               ( ~mesa_wi_baudlock        ),
//tcp       .clk_lb              ( clk_lb_tree              ),
//tcp       .clk_cap             ( clk_cap_tree             ),
//tcp       .lb_wr               ( lb_wr                    ),
//tcp       .lb_rd               ( lb_rd                    ),
//tcp       .lb_wr_d             ( lb_wr_d[31:0]            ),
//tcp       .lb_addr             ( lb_addr[31:0]            ),
//tcp       .lb_rd_d             ( lb_rd_d[31:0]            ),
//tcp       .lb_rd_rdy           ( lb_rd_rdy                ),
//tcp       .led_bus             ( led_bus[3:0]             ),
//tcp       .events_din          ( events_loc[23:0]         )
//tcp       );  
//tcp 
//tcp `endif
//tcp // ========================================================================================================================
//tcp // ========================================================================================================================
//tcp // ========================================================================================================================
//tcp // END OF SUMP2 SETUP
//tcp // ========================================================================================================================
//tcp // ========================================================================================================================
//tcp // ========================================================================================================================

endmodule // top
