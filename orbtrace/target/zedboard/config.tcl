# configuring environment

set_arch 7z020
set_target zedboard
set_part xc7z020clg484-1
set_top top

add_src_file ${::arch_dir}/top.v
add_src_file ${::source_dir}/traceIF.v
add_src_file ${::source_dir}/packSend.v
add_src_file ${::source_dir}/spi.v



