# lib/file_flag.tcl 

proc file_flag {file_name} {
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
}
