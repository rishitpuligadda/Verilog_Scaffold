# lib/config_flag.tcl - generate a design (and testbench) from a JSON config
#
# Config keys:
#   module      (required) module name
#   path        output directory, or a full .v/.sv file path. A relative path
#               is resolved against the src/ directory (where
#               generate_verilog.tcl lives), NOT the current directory, so the
#               output lands in the same place wherever you run the script from.
#               Without "path", files go to the current directory.
#   parameters  { "NAME": value, ... }
#   clocks      { "clk_name": period_ns, ... }   (legacy: "clk_period": N)
#   ports       { "inputs": [...], "outputs": [...] }
#               each port is "name" or { "name": ..., "width": ..., "type": ... }
#   generate_tb true/false (alias: "tb"), default true

package require json

# Turn a JSON width into a Verilog range: 8 -> [7:0], "W" -> [W-1:0], "7:0" -> [7:0]
proc parse_width {raw params port_name} {
    set raw [string trim [string trim $raw] {[] }]

    if {$raw eq "" || $raw eq "1"} {
        return ""
    }
    if {[string match "*:*" $raw]} {
        return "\[$raw\]"
    }
    if {[string is integer -strict $raw]} {
        if {$raw < 1} {
            error "port '$port_name': width must be at least 1, got $raw"
        }
        return "\[[expr {$raw - 1}]:0\]"
    }
    if {[is_verilog_ident $raw]} {
        if {![dict exists $params $raw]} {
            error "port '$port_name': width '$raw' is not defined in \"parameters\""
        }
        return "\[$raw-1:0\]"
    }
    # Expression such as "W*2" or "A<<1": parenthesise so "-1" binds correctly
    return "\[($raw)-1:0\]"
}

# Convert the JSON port list into {type width name} triples.
proc normalize_ports {port_list dir params} {
    set allowed [expr {$dir eq "input" ? {wire} : {wire reg}}]
    set normalized {}

    foreach item $port_list {
        set ptype ""
        set width ""

        if {[llength $item] == 1} {
            set name [string trim $item]
        } elseif {[llength $item] % 2 == 0 && [dict exists $item name]} {
            set name [string trim [dict get $item name]]
            if {[dict exists $item type]} {
                set ptype [string tolower [string trim [dict get $item type]]]
                if {$ptype ne "" && $ptype ni $allowed} {
                    error "$dir '$name': type '$ptype' is not allowed\
                           (allowed: [join $allowed {, }])"
                }
            }
            if {[dict exists $item width]} {
                set width [parse_width [dict get $item width] $params $name]
            }
        } else {
            error "invalid $dir port entry: $item"
        }

        check_ident "$dir port" $name
        lappend normalized [list $ptype $width $name]
    }
    return $normalized
}

# Read a boolean config value, rejecting anything that is not true/false.
proc config_bool {data key default} {
    if {![dict exists $data $key]} {
        return $default
    }
    set raw [dict get $data $key]
    if {![string is boolean -strict $raw]} {
        error "\"$key\" must be true or false, got '$raw'"
    }
    return [string is true -strict $raw]
}

proc config_flag {config_file {force 0}} {
    if {![file readable $config_file]} {
        error "configuration file '$config_file' not found or not readable"
    }
    set ext [string tolower [file extension $config_file]]
    if {$ext ne ".json"} {
        error "unsupported config format '$ext' (expected .json)"
    }

    set fp [open $config_file r]
    set content [read $fp]
    close $fp

    if {[catch {json::json2dict $content} data]} {
        error "invalid JSON in '$config_file': $data"
    }

    # 1. Module name
    if {![dict exists $data module]} {
        error "'$config_file' has no \"module\" key"
    }
    set mod_name [file rootname [file tail [string trim [dict get $data module]]]]
    check_ident "module" $mod_name

    # 2. Output location
    set target ""
    if {[dict exists $data path]} {
        set target [string trim [dict get $data path]]
    }
    if {$target ne "" && [file pathtype $target] eq "relative" && [info exists ::script_dir]} {
        set target [file join $::script_dir $target]
    }
    if {$target eq ""} {
        set out_file "${mod_name}.v"
    } elseif {[string tolower [file extension $target]] in {.v .sv}} {
        set out_file $target
    } else {
        set out_file [file join $target "${mod_name}.v"]
    }
    set out_file [file normalize $out_file]
    set out_dir  [file dirname $out_file]

    # 3. Parameters
    set params [dict create]
    if {[dict exists $data parameters]} {
        set params [dict get $data parameters]
    }
    dict for {pname pval} $params {
        check_ident "parameter" $pname
        if {[string trim $pval] eq ""} {
            error "parameter '$pname' has an empty value"
        }
    }

    # 4. Testbench flag ("generate_tb" wins over the "tb" alias)
    set generate_tb [config_bool $data tb 1]
    set generate_tb [config_bool $data generate_tb $generate_tb]

    # 5. Clocks
    set clocks [dict create]
    if {[dict exists $data clocks]} {
        set clocks [dict get $data clocks]
    } elseif {[dict exists $data clk_period]} {
        set clocks [dict create clk [dict get $data clk_period]]
    }
    dict for {clk period} $clocks {
        check_ident "clock" $clk
        if {![string is double -strict $period] || $period <= 0} {
            error "clock '$clk': period must be a positive number, got '$period'"
        }
    }

    # 6. Ports
    set raw_inputs  {}
    set raw_outputs {}
    if {[dict exists $data ports]} {
        set ports [dict get $data ports]
        if {[dict exists $ports inputs]}  { set raw_inputs  [dict get $ports inputs] }
        if {[dict exists $ports outputs]} { set raw_outputs [dict get $ports outputs] }
    }
    set inputs  [normalize_ports $raw_inputs  input  $params]
    set outputs [normalize_ports $raw_outputs output $params]

    set in_names  [lmap p $inputs  {lindex $p 2}]
    set out_names [lmap p $outputs {lindex $p 2}]
    set seen [dict create]
    foreach n [concat $in_names $out_names] {
        dict incr seen $n
        if {[dict get $seen $n] > 1} {
            error "port '$n' is declared more than once"
        }
    }

    # 7. Add declared clocks to the inputs (first), unless already listed
    set clock_ports {}
    dict for {clk _} $clocks {
        if {$clk in $out_names} {
            error "clock '$clk' is declared as an output"
        }
        set idx [lsearch -exact $in_names $clk]
        if {$idx < 0} {
            lappend clock_ports [list "" "" $clk]
        } elseif {[lindex $inputs $idx 1] ne ""} {
            error "clock '$clk' must be 1 bit wide"
        }
    }
    set inputs [concat $clock_ports $inputs]

    # No clocks given: treat clk, clk2, wr_clk, sys_clock... as 10 ns clocks.
    # (Deliberately does not match clk_en, clk_sel, etc.)
    if {[dict size $clocks] == 0} {
        foreach p $inputs {
            set n [lindex $p 2]
            if {[lindex $p 1] eq "" &&
                [regexp -nocase {^(clk|clock)\d*$|_(clk|clock)\d*$} $n]} {
                dict set clocks $n 10
                puts "Note: treating input '$n' as a 10 ns clock (set \"clocks\" to change)"
            }
        }
    }

    # 8. Generate everything first, then write
    set files [list $out_file [design_template $mod_name $inputs $outputs $params]]
    if {$generate_tb} {
        set tb_file [file join $out_dir "tb_${mod_name}[file extension $out_file]"]
        lappend files $tb_file [tb_template $mod_name $inputs $outputs $params $clocks]
    }

    check_writable [dict keys $files] $force
    dict for {path text} $files {
        write_output $path $text
    }

    puts "Generated design:    $out_file"
    if {$generate_tb} {
        puts "Generated testbench: $tb_file"
    } else {
        puts "Skipped testbench:   disabled by config"
    }
}
