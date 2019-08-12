module input_global_buffer (input i,
                            output o);
   SB_GB u_SB_GB (.USER_SIGNAL_TO_GLOBAL_BUFFER(i),
                  .GLOBAL_BUFFER_OUTPUT(o));
endmodule;

module input_io_buffer (input i,
                        output o);
   SB_GB_IO #(.PIN_TYPE(6'b0000_00)) u_SB_GB_IO 
     (.PACKAGE_PIN(i),
      .GLOBAL_BUFFER_OUTPUT(o));
endmodule;
