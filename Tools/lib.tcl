variable this_script [file normalize [info script]]
set ::tools_dir [file dirname $this_script]
puts "tools_dir: ${::tools_dir}"

set ::base_dir [file normalize "${::tools_dir}/.."]    
puts "base_dir: ${::base_dir}"

set ::arch_dir [file join "${::base_dir}" "arch"]
puts "arch_dir: ${::arch_dir}"

set ::build_dir [file join "${::base_dir}" "build"]
puts "build_dir: ${::build_dir}"

set ::board_dir [file join "${::base_dir}" "board"]    
puts "board_dir: ${::board_dir}"


proc set_env {target_path} {
    set target_path [file normalize "${target_path}"]
    set target [file tail "${target_path}"]

    set ::target_dir [file join "${::board_dir}" "${target}"]
    add_var target ${target}

    source -notrace "${::target_dir}/config.tcl"
    return
}

proc add_var {a_variable a_value} {
    set a_variable [string tolower ${a_variable}]
    set a_value [string tolower ${a_value}]
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
