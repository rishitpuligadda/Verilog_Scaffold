set file_name ""

#function which removes any tailing indentation for cleaner code
proc outdent {text} {
    # Remove leading/trailing empty lines
    set lines [split [string trimright [string trimleft $text "\r\n"]] "\n"]

    # Find minimum indentation among non-empty lines
    set min_indent -1
    foreach line $lines {
        if {[string trim $line] eq ""} continue
        regexp {^(\s*)} $line -> indent
        set len [string length $indent]
        if {$min_indent == -1 || $len < $min_indent} {
            set min_indent $len
        }
    }

    if {$min_indent <= 0} {
        return [join $lines "\n"]
    }

    # Strip that exact prefix from each line
    set result {}
    foreach line $lines {
        lappend result [string range $line $min_indent end]
    }
    return [join $result "\n"]
}

#function which is called to make any design templates
proc design_template {mod_name fp} {
    set raw {
        module $mod_name (

        );

        endmodule
    }

    set clean [outdent $raw]
    set design [subst -nocommands -nobackslashes $clean]

    puts $fp $design
}

#function which is called to make testbench templates
proc tb_template {mod_name fp} {
	set raw {
		module $mod_name;

		endmodule
	}

	set clean [outdent $raw]
	set tb [subst -nocommands -nobackslashes $clean]

	puts $fp $tb
}

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
	puts stderr "USAGE: tclsh generate_verilog.tcl [-file] <filename>"
	exit 1
}

if {[file extension $file_name] eq ""} {
	set file_name "${file_name}.v"
}

set mod_name [file rootname $file_name]

set fp [open $file_name w] 

if {[string match "tb_*" $mod_name] || [string match "*_tb" $mod_name]} {
	tb_template $mod_name $fp
} else {
	design_template $mod_name $fp
}

close $fp

puts "generating file: $file_name"
