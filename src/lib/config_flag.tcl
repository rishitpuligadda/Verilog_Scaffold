# lib/config_flag.tcl
package require json

proc normalize_ports {port_list} {
    set normalized {}
    foreach item $port_list {
        if {[llength $item] > 1 && [dict exists $item name]} {
            set name  [dict get $item name]
            set width ""
            set ptype ""

            if {[dict exists $item type]} {
                set ptype [string trim [dict get $item type]]
            }

            if {[dict exists $item width]} {
                set raw_w [string trim [dict get $item width]]
                set raw_w [string trim $raw_w {[] }]

                if {$raw_w eq "" || $raw_w eq "1"} {
                    set width ""
                } elseif {[string match "*:*" $raw_w]} {
                    set width "\[$raw_w\]"
                } elseif {[string is integer -strict $raw_w]} {
                    set upper [expr {$raw_w - 1}]
                    set width "\[${upper}:0\]"
                } else {
                    set width "\[${raw_w}-1:0\]"
                }
            }

            lappend normalized [list $ptype $width $name]
        } else {
            lappend normalized [list "" "" $item]
        }
    }
    return $normalized
}

proc config_flag {config_file} {
    if {![file exists $config_file]} {
        puts stderr "Error: Configuration file '$config_file' not found."
        exit 1
    }

    set ext [file extension $config_file]
    if {$ext ne ".json"} {
        puts stderr "Error: Unsupported config format '$ext'. Expected .json"
        exit 1
    }

    set config_fp [open $config_file r]
    set content [read $config_fp]
    close $config_fp

    set data [json::json2dict $content]

    # 1. Clean module name
    set raw_mod [dict get $data module]
    set mod_name [file rootname [file tail $raw_mod]]

    # 2. Determine target file path based on optional "path" key
    set target_path ""
    if {[dict exists $data path]} {
        set target_path [string trim [dict get $data path]]
    }

    if {$target_path eq ""} {
        set out_file "${mod_name}.v"
    } elseif {[file extension $target_path] eq ".v"} {
        set out_file $target_path
    } else {
        set out_file [file join $target_path "${mod_name}.v"]
    }

    # 3. Create destination directory if needed
    set out_dir [file dirname $out_file]
    if {$out_dir ne "" && ![file exists $out_dir]} {
        file mkdir $out_dir
    }

    # 4. Extract parameters
    set params {}
    if {[dict exists $data parameters]} {
        set params [dict get $data parameters]
    }

    # 5. Extract testbench generation flag (default: true / 1)
    set generate_tb 1
    if {[dict exists $data generate_tb]} {
        set raw_tb [dict get $data generate_tb]
        if {[string is boolean -strict $raw_tb]} {
            set generate_tb [string is true -strict $raw_tb]
        }
    } elseif {[dict exists $data tb]} {
        set raw_tb [dict get $data tb]
        if {[string is boolean -strict $raw_tb]} {
            set generate_tb [string is true -strict $raw_tb]
        }
    }

    # 6. Extract clock definitions
    set clocks [dict create]
    if {[dict exists $data clocks]} {
        set clocks [dict get $data clocks]
    } elseif {[dict exists $data clk_period]} {
        set clocks [dict create clk [dict get $data clk_period]]
    }

    # 7. Extract ports
    set raw_inputs  {}
    set raw_outputs {}
    if {[dict exists $data ports]} {
        set ports [dict get $data ports]
        if {[dict exists $ports inputs]}  { set raw_inputs  [dict get $ports inputs] }
        if {[dict exists $ports outputs]} { set raw_outputs [dict get $ports outputs] }
    }

    set inputs  [normalize_ports $raw_inputs]
    set outputs [normalize_ports $raw_outputs]

    # 8. Deduplicate & inject clocks into inputs
    set existing_in_names {}
    foreach in $inputs {
        lappend existing_in_names [lindex $in 2]
    }

    set clock_port_list {}
    dict for {clk_name _} $clocks {
        if {$clk_name ni $existing_in_names} {
            lappend clock_port_list [list "" "" $clk_name]
        }
    }
    set inputs [concat $clock_port_list $inputs]

    # Fallback: if no clocks dictionary specified, search inputs for *clk*
    if {[dict size $clocks] == 0} {
        foreach in $inputs {
            set signame [lindex $in 2]
            if {[string match "*clk*" $signame]} {
                dict set clocks $signame 10
            }
        }
    }

    # 9. Write Verilog design file
    set fp [open $out_file w]
    design_template $mod_name $fp $inputs $outputs $params
    close $fp
    puts "Generated design:    $out_file"

    # 10. Conditionally write testbench file
    if {$generate_tb} {
        set tb_file [file join $out_dir "tb_${mod_name}.v"]
        set tb_fp [open $tb_file w]
        tb_template $mod_name $tb_fp $inputs $outputs $params $clocks
        close $tb_fp
        puts "Generated testbench: $tb_file"
    } else {
        puts "Skipped testbench:   disabled by config"
    }
}
