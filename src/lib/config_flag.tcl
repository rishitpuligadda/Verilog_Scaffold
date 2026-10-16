# lib/config_flag.tcl
package require json

proc normalize_ports {port_list} {
    set normalized {}
    foreach item $port_list {
        if {[llength $item] > 1 && [dict exists $item name]} {
            set name  [dict get $item name]
            set width ""
            set ptype ""

            # Check for data type (e.g. "reg", "wire", "logic")
            if {[dict exists $item type]} {
                set ptype [string trim [dict get $item type]]
            }

            # Check for width
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
            # Single scalar (e.g. "clk" or "zero_flag") -> no type, no width
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

    # 1. Clean module name (always strip any accidental path or extension)
    set raw_mod [dict get $data module]
    set mod_name [file rootname [file tail $raw_mod]]

    # 2. Determine target file path based on optional "path" key
    set target_path ""
    if {[dict exists $data path]} {
        set target_path [string trim [dict get $data path]]
    }

    if {$target_path eq ""} {
        # Default: current working directory
        set out_file "${mod_name}.v"
    } elseif {[file extension $target_path] eq ".v"} {
        # User specified full filepath with .v
        set out_file $target_path
    } else {
        # User specified a directory
        set out_file [file join $target_path "${mod_name}.v"]
    }

    # 3. Create destination directory if it doesn't exist
    set out_dir [file dirname $out_file]
    if {$out_dir ne "" && ![file exists $out_dir]} {
        file mkdir $out_dir
    }

    # 4. Extract parameters & ports
    set params {}
    if {[dict exists $data parameters]} {
        set params [dict get $data parameters]
    }

    set raw_inputs  {}
    set raw_outputs {}
    if {[dict exists $data ports]} {
        set ports [dict get $data ports]
        if {[dict exists $ports inputs]}  { set raw_inputs  [dict get $ports inputs] }
        if {[dict exists $ports outputs]} { set raw_outputs [dict get $ports outputs] }
    }

    set inputs  [normalize_ports $raw_inputs]
    set outputs [normalize_ports $raw_outputs]

    # 5. Write the Verilog design file
    set fp [open $out_file w]
    design_template $mod_name $fp $inputs $outputs $params
    close $fp

    puts "Generated design: $out_file"
}
