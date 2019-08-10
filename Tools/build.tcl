#get current dir
set this_dir [file dirname [file normalize [info script]]]

# importing functionality provided by our tcl lib
source -notrace [file join ${this_dir} lib.tcl]

set_env [lindex $argv 0]

set part [get_value part]

puts "part: ${part}"
create_project -in_memory -part ${part}

set_property target_language Verilog [current_project]

source "${::target_dir}/sources.tcl"
source "${::target_dir}/constraints.tcl"

update_compile_order -fileset sources_1

start_gui

