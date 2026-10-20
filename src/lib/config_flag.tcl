# lib/config_flag.tcl - generate a design (and testbench) from a JSON config
#
# The config is JSON with two conveniences: // and /* */ comments are allowed,
# and trailing commas are ignored. "vscaff -init" writes a commented template.
#
# Config keys:
#   module      (required) module name
#   design_path where to write the design: a directory, or a full .v/.sv file
#               path. "path" is accepted as an alias (older configs).
#               Default: the current directory.
#   tb_path     where to write the testbench: a directory, or a full .v/.sv
#               file path. If a file name is given, it also becomes the
#               testbench module name. Default: next to the design.
#
#               Relative paths in design_path / tb_path are resolved against
#               the directory containing the CONFIG FILE, so output lands in
#               the same place no matter where you run the script from.
#   parameters  { "NAME": value, ... }
#   clocks      { "clk_name": period_ns, ... }   (legacy: "clk_period": N)
#   ports       { "inputs": [...], "outputs": [...] }
#               each port is "name" or { "name": ..., "width": ..., "type": ... }
#   generate_tb true/false (alias: "tb"), default true


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

# Read an optional string value from the config ("" if absent).
proc config_str {data key} {
    if {![dict exists $data $key]} {
        return ""
    }
    return [string trim [dict get $data $key]]
}

# Turn a config path value into an absolute output file path.
#   raw:          value from the config ("" if not set)
#   config_file:  relative values are resolved against this file's directory
#   default_dir:  directory used when raw is empty
#   default_name: file name used when raw is empty or names a directory
proc resolve_output {raw config_file default_dir default_name} {
    if {$raw eq ""} {
        return [file normalize [file join $default_dir $default_name]]
    }
    if {[file pathtype $raw] eq "relative"} {
        set raw [file join [file dirname [file normalize $config_file]] $raw]
    }
    if {[string tolower [file extension $raw]] in {.v .sv}} {
        return [file normalize $raw]
    }
    return [file normalize [file join $raw $default_name]]
}

proc config_flag {config_file {force 0}} {
    # Loaded here, not at the top of the file, so -file mode still works
    # on machines without Tcllib.
    if {[catch {package require json}]} {
        error "the Tcl 'json' package (part of Tcllib) is not installed.\
               Install it (e.g. 'sudo apt install tcllib') or re-run ./install.sh"
    }

    if {![file readable $config_file]} {
        error "configuration file '$config_file' not found or not readable"
    }
    set ext [string tolower [file extension $config_file]]
    if {$ext ni {.json .jsonc}} {
        error "unsupported config format '$ext' (expected .json or .jsonc)"
    }

    set fp [open $config_file r]
    set content [read $fp]
    close $fp

    # Allow // and /* */ comments and trailing commas, then make sure no
    # <placeholders> from an -init template are left
    set content [clean_json $content]
    check_placeholders $content

    if {[catch {json::json2dict $content} data]} {
        error "invalid JSON in '$config_file': $data"
    }

    # 1. Module name
    if {![dict exists $data module]} {
        error "'$config_file' has no \"module\" key"
    }
    set mod_name [file rootname [file tail [string trim [dict get $data module]]]]
    check_ident "module" $mod_name

    # 2. Output locations
    if {[dict exists $data path] && [dict exists $data design_path]} {
        error "use either \"design_path\" or \"path\", not both"
    }
    set design_raw [config_str $data design_path]
    if {$design_raw eq ""} {
        set design_raw [config_str $data path]
    }
    set out_file [resolve_output $design_raw $config_file [pwd] "${mod_name}.v"]

    # The testbench defaults to the design's directory and extension
    set tb_raw  [config_str $data tb_path]
    set tb_file [resolve_output $tb_raw $config_file [file dirname $out_file] \
                    "tb_${mod_name}[file extension $out_file]"]
    set tb_name [file rootname [file tail $tb_file]]

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

    if {$generate_tb} {
        check_ident "testbench module" $tb_name
        if {$tb_name eq $mod_name} {
            error "testbench module name '$tb_name' is the same as the design module name"
        }
        if {$tb_file eq $out_file} {
            error "design and testbench would both be written to '$out_file'"
        }
    } elseif {$tb_raw ne ""} {
        puts "Note: \"tb_path\" is ignored because the testbench is disabled"
    }

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
        lappend files $tb_file [tb_template $mod_name $inputs $outputs $params $clocks $tb_name]
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
