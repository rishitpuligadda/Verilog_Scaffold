#!/usr/bin/env tclsh

# Dynamically find the script's root directory and source libraries
set script_dir [file normalize [file dirname [info script]]]
set lib_dir    [file join $script_dir "lib"]

source [file join $lib_dir "utils.tcl"]
source [file join $lib_dir "design_tpl.tcl"]
source [file join $lib_dir "tb_tpl.tcl"]

set file_name ""

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

if {$file_name eq ""} {
    puts stderr "USAGE: tclsh vlog_scaffold.tcl [-file] <filename>"
    exit 1
}

if {[file extension $file_name] eq ""} {
    set file_name "${file_name}.v"
}

set mod_name [file rootname $file_name]
set fp [open $file_name w] 

if {[string match "tb_*" $mod_name] || [string match "*_tb" $mod_name] || $mod_name eq "tb"} {
    tb_template $mod_name $fp
} else {
    design_template $mod_name $fp
}

close $fp
puts "Generated file: $file_name"
