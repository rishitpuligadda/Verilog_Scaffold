#!/usr/bin/env tclsh
# generate_verilog.tcl - generate Verilog designs and testbenches
#
# Usage:
#   ./generate_verilog.tcl [-force] -file <filename>
#   ./generate_verilog.tcl [-force] -config <config.json>

# --- Locate the script (following symlinks) and its lib directory ---
set script_path [file normalize [info script]]
while {[file type $script_path] eq "link"} {
    set target [file readlink $script_path]
    set script_path [file normalize [file join [file dirname $script_path] $target]]
}
set script_dir [file dirname $script_path]
set lib_dir    [file join $script_dir "lib"]

# --- Source libraries in dependency order ---
foreach lib {utils.tcl design_tpl.tcl tb_tpl.tcl file_flag.tcl config_flag.tcl} {
    set path [file join $lib_dir $lib]
    if {![file readable $path]} {
        puts stderr "ERROR: missing library file: $path"
        exit 1
    }
    source $path
}

proc usage {{chan stderr}} {
    puts $chan {USAGE: ./generate_verilog.tcl [-force] -file <filename>
       ./generate_verilog.tcl [-force] -config <config.json>

Options:
  -file <name>     Generate a design and testbench for <name>
                   (the -file keyword is optional: a bare name also works)
  -config <json>   Generate from a JSON config file
  -force           Overwrite files that already exist
  -debug           Show the full Tcl stack trace on errors
  -h, -help        Show this help}
}

proc die {msg} {
    puts stderr "ERROR: $msg"
    usage
    exit 1
}

# --- CLI argument parsing ---
set file_name   ""
set config_file ""
set debug       0
set force       0

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

if {$file_name ne "" && $config_file ne ""} {
    die "use either -file or -config, not both"
}

if {$config_file ne "" && ![file readable $config_file]} {
    die "config file not found or not readable: $config_file"
}

# --- Action execution ---
if {$file_name ne ""} {
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
