#!/usr/bin/env tclsh

# Dynamically find the script's root directory and source libraries
set script_dir [file normalize [file dirname [info script]]]
set lib_dir    [file join $script_dir "lib"]


foreach file [glob -nocomplain -directory $lib_dir *.tcl] {
    source $file
}

set file_name ""
set config_file ""

# --- CLI Argument Parsing ---
for {set i 0} {$i < $argc} {incr i} {
    set arg [lindex $argv $i]

    switch -- $arg {
        "-file" {
            incr i 
            if {$i < $argc} {
                set file_name [lindex $argv $i]
            } else {
                puts stderr "ERROR: -file requires a value"
                exit 1
            }
        }
        "-config" {
            incr i 
            if {$i < $argc} {
                set config_file [lindex $argv $i]
            } else {
                puts stderr "ERROR: -config requires a value"
                exit 1
            }
        }
        default {
            if {[string match "-*" $arg]} {
                puts stderr "Warning: Unrecognized option '$arg'"
            } else {
                if {$file_name eq ""} {
                    set file_name $arg
                } else {
                    puts stderr "Warning: Extra positional argument '$arg' ignored"
                }
            }
        }
    }
}

# --- Action Execution ---
if {$file_name ne ""} {
    file_flag $file_name
} elseif {$config_file ne ""} {
	config_flag $config_file
} else {
    puts stderr "USAGE: ./generate_verilog.tcl [-file] <filename> \[-config <config_file>\]"
    exit 1
}
