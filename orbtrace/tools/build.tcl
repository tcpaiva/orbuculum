#get current dir
set this_dir [file dirname [file normalize [info script]]]

# importing functionality provided by our tcl lib
set lib_path [file join ${this_dir} lib.tcl]
source -notrace ${lib_path}

set config_path [file join [lindex ${argv} 0] "config.tcl"]
source -notrace ${config_path}

set part [get_value part]
puts "part: ${part}"

create_project -in_memory -part ${part}

set_property target_language Verilog [current_project]
set_property source_mgmt_mode All [current_project]

set top [get_value top]
puts "top: ${top}"
set_property top ${top} [current_fileset]

foreach src_file ${::sources} {
    add_files -norecurse "${src_file}"
    # read_verilog "${src_file}"
}

update_compile_order -fileset sources_1

synth_design 
write_checkpoint -force "${::build_dir}/post_synth.dcp"

# opt_design
# write_checkpoint -force "${::build_dir}/post_opt.dcp"
# 
# place_design
# phys_opt_design
# write_checkpoint -force "${::build_dir}/post_place.dcp"
# report_clock_utilization -file "${::build_dir}/clock_util.rpt"
# report_utilization -file "${::build_dir}/post_place_util.rpt"
# report_timing_summary -file "${::build_dir}/post_place_timing_summary.rpt"
# 
# route_design -directive Explore
# write_checkpoint -force "${::build_dir}/post_route.dcp"
# report_route_status -file "${::build_dir}/post_route_status.rpt"
# report_timing_summary -file "${::build_dir}/post_route_timing_summary.rpt"
# report_power -file "${::build_dir}/post_route_power.rpt"
# report_drc -file "${::build_dir}/post_imp_drc.rpt"
# 
# write_bitstream -force "${::build_dir}/orbtrace.bit"

start_gui

