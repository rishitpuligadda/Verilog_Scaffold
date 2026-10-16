set file_name ""

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
            # If the argument starts with '-', it's an unrecognized flag
            if {[string match "-*" $arg]} {
                puts stderr "Warning: Unrecognized option '$arg'"
            } else {
                # If no file has been assigned yet, treat this as a positional filename
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
    puts stderr "USAGE: tclsh generate_verilog.tcl [-file] <filename>"
    exit 1
}

# Automatically add .v extension if omitted
if {[file extension $file_name] eq ""} {
    set file_name "${file_name}.v"
}

# Extract clean module name
set mod_name [file rootname [file tail $file_name]]

set tb "module $mod_name;

endmodule"

set design "module $mod_name (

);

endmodule"

# Open, write, and close
set fp [open $file_name w]

if {[string range $mod_name 0 1] eq "tb"} {
    puts $fp $tb
} else {
    puts $fp $design
}

close $fp

puts "generating file: $file_name"

