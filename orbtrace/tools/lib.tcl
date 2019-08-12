variable this_script [file normalize [info script]]

set ::tools_dir [file dirname $this_script]
puts "tools_dir: ${::tools_dir}"

set ::base_dir [file normalize "${::tools_dir}/.."]    
puts "base_dir: ${::base_dir}"

set ::build_dir [file join "${::base_dir}" "build"]
file delete -force ${::build_dir}
file mkdir ${::build_dir}
puts "build_dir: ${::build_dir}"

set ::source_dir [file join "${::base_dir}" "src"]
puts "source_dir: ${::source_dir}"

proc add_src_file {file_path} {
    lappend ::sources "${file_path}"
    puts "Adding source file: ${file_path}"
    return
}

# proc set_env {target_path} {
#     set target_path [file normalize "${target_path}"]
#     set target [file tail "${target_path}"]
# 
#     set ::target_dir [file join "${::board_dir}" "${target}"]
#     add_var target ${target}
# 
#     source -notrace "${::target_dir}/config.tcl"
#     return
# }

proc prepare_environment {} {
    source -notrace "${::target_dir}/config.tcl"
    return
}

proc set_arch {a_value} {
    add_var "arch" ${a_value}
    set ::arch_dir [file join "${::source_dir}" "arch" "${a_value}"]
    puts "arch_dir set: ${::arch_dir}"
}

proc set_target {a_value} {
    add_var "target" ${a_value}
    set ::target_dir [file join "${::base_dir}" "target" "${a_value}"]
    puts "target_dir set: ${::target_dir}"
}

proc set_part {a_value} {
    add_var "part" ${a_value}
    puts "part set: ${a_value}"
}

proc set_top {a_value} {
    add_var "top" ${a_value}
    puts "top module set: ${a_value}"
}

proc add_var {a_variable a_value} {
    set a_variable [string tolower ${a_variable}]
    if {![info exists ::variables]} { 
        dict set ::variables ${a_variable} ${a_value}
    } else {
        if { ${a_variable} ni [dict keys ${::variables}] } {
            dict set ::variables ${a_variable} ${a_value}
        }
    }
    return
}

proc get_value {a_variable} {
    return [dict get "${::variables}" "${a_variable}"]
}


proc write_build_config {} {

    set fp [open "${::build_dir}/config.tcl" w+]
    puts $fp "-- Do not change this file." 
    puts $fp "-- It was automatically generated and it will be overwritten."
    puts $fp ""

    # write tcl script to set variables in the build folder
    dict for {var_name value} ${::variables} {
        puts ${fp} "set ${var_name} ${value};"
    }

    close $fp
}
