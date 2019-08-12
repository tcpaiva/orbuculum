module input_global_buffer(input i,
                           output o);
   IBUFG u_ibufg (.I(i), .O(o));
endmodule;

module input_io_buffer(input i,
                       output o);
   OBUF u_obuf (.I(i), .O(o));
endmodule;

