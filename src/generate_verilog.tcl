#!/usr/bin/env tclsh
# generate_verilog.tcl - generate Verilog designs and testbenches
#
# Usage:
#   generate_verilog.tcl [-force] -file <filename>
#   generate_verilog.tcl [-force] -config <config.json>
#   generate_verilog.tcl [-force] -init [config.json] [-comb] [-i N] [-o N]
#
# Run ./install.sh from the repository root to install it as the
# "vscaff" command, usable from any directory.

if {[catch {package require Tcl 8.6-}]} {
    puts stderr "ERROR: Tcl 8.6 or newer is required (this is Tcl [info patchlevel])"
    exit 1
}

# --- Locate the script (following symlinks) and its lib directory ---
set script_path [file normalize [info script]]
while {[file type $script_path] eq "link"} {
    set target [file readlink $script_path]
    set script_path [file normalize [file join [file dirname $script_path] $target]]
}
set script_dir [file dirname $script_path]
set lib_dir    [file join $script_dir "lib"]

# --- Source libraries in dependency order ---
foreach lib {utils.tcl verilog_parse.tcl design_tpl.tcl tb_tpl.tcl file_flag.tcl config_flag.tcl init_flag.tcl} {
    set path [file join $lib_dir $lib]
    if {![file readable $path]} {
        puts stderr "ERROR: missing library file: $path"
        exit 1
    }
    source $path
}

# The help text shows the name the tool was run as: "vscaff" when
# installed with install.sh, "generate_verilog.tcl" when run directly.
set prog [file tail [info script]]

proc usage {{chan stderr}} {
    set text {USAGE: @PROG@ [-force] -file <filename>
       @PROG@ [-force] -config <config.json>
       @PROG@ [-force] -init [config.json] [-comb] [-i N] [-o N]

Options:
  -file <name>     Generate an empty design (or testbench, if the name is
                   tb_<x> or <x>_tb) skeleton. The -file keyword is optional:
                   a bare name also works.
  -config <json>   Generate a design and testbench from a JSON config file
  -init [json]     Write a commented config template to fill in
                   (default file name: config.json)
    -comb          ...for a combinational design: no "clocks" section
    -i, -inputs N  ...with N input ports (default 1)
    -o, -outputs N ...with N output ports (default 1)
  -force           Overwrite files that already exist
  -debug           Show the full Tcl stack trace on errors
  -h, -help        Show this help

Examples:
  @PROG@ counter                         empty counter.v
  @PROG@ -init uart.json -i 4 -o 2       template with 4 inputs, 2 outputs
  @PROG@ -config uart.json               design + testbench from the config}
    puts $chan [string map [list @PROG@ $::prog] $text]
}

proc die {msg} {
    puts stderr "ERROR: $msg"
    puts stderr "Run '$::prog -h' for help."
    exit 1
}

# --- CLI argument parsing ---
set file_name   ""
set config_file ""
set debug       0
set force       0
set init_mode   0
set init_file   ""
set n_in        ""
set n_out       ""
set comb        0

for {set i 0} {$i < $argc} {incr i} {
    set arg [lindex $argv $i]

    switch -- $arg {
        "-file" - "-config" {
            incr i
            if {$i >= $argc} {
                die "$arg requires a value"
            }
            set value [lindex $argv $i]
            if {[string match "-*" $value]} {
                die "$arg requires a value, got option '$value'"
            }
            set var [expr {$arg eq "-file" ? "file_name" : "config_file"}]
            if {[set $var] ne ""} {
                die "$arg given more than once"
            }
            set $var $value
        }
        "-init" {
            if {$init_mode} {
                die "-init given more than once"
            }
            set init_mode 1
            # The file name is optional: take the next argument unless it is
            # another option
            if {$i + 1 < $argc && ![string match "-*" [lindex $argv [expr {$i + 1}]]]} {
                set init_file [lindex $argv [incr i]]
            }
        }
        "-i" - "-inputs" - "-o" - "-outputs" {
            incr i
            if {$i >= $argc} {
                die "$arg requires a number"
            }
            set value [lindex $argv $i]
            if {![string is integer -strict $value] || $value < 0} {
                die "$arg requires a whole number of 0 or more, got '$value'"
            }
            set var [expr {[string match "-i*" $arg] ? "n_in" : "n_out"}]
            if {[set $var] ne ""} {
                die "$arg given more than once"
            }
            set $var $value
        }
        "-comb" {
            set comb 1
        }
        "-debug" {
            set debug 1
        }
        "-force" {
            set force 1
        }
        "-h" - "-help" - "--help" {
            usage stdout
            exit 0
        }
        default {
            if {[string match "-*" $arg]} {
                die "unrecognized option '$arg'"
            }
            if {$file_name ne ""} {
                die "unexpected extra argument '$arg'"
            }
            set file_name $arg
        }
    }
}

if {$init_mode} {
    if {$config_file ne ""} {
        die "use either -init or -config, not both"
    }
    # "-init -i 3 my.json": a bare name after the flags is the template name
    if {$file_name ne ""} {
        if {$init_file ne ""} {
            die "unexpected extra argument '$file_name'"
        }
        set init_file $file_name
        set file_name ""
    }
} elseif {$n_in ne "" || $n_out ne "" || $comb} {
    die "-comb, -i and -o only work together with -init"
}

if {$file_name ne "" && $config_file ne ""} {
    die "use either -file or -config, not both"
}

if {$config_file ne "" && ![file readable $config_file]} {
    die "config file not found or not readable: $config_file"
}

# --- Action execution ---
if {$init_mode} {
    if {$n_in  eq ""} { set n_in  1 }
    if {$n_out eq ""} { set n_out 1 }
    set cmd [list init_flag $init_file $n_in $n_out $comb $force]
} elseif {$file_name ne ""} {
    set cmd [list file_flag $file_name $force]
} elseif {$config_file ne ""} {
    set cmd [list config_flag $config_file $force]
} else {
    usage
    exit 1
}

if {[catch {{*}$cmd} err]} {
    if {$debug} {
        puts stderr $::errorInfo
    } else {
        puts stderr "ERROR: $err"
        puts stderr "(run again with -debug for the full stack trace)"
    }
    exit 1
}

exit 0
