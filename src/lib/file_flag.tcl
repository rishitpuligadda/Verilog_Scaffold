# lib/file_flag.tcl 

proc file_flag {file_name} {
    if {$file_name eq ""} {
        puts stderr "USAGE: ./generate_verilog.tcl [-file] <filename> \[-config <config.json>\]"
        exit 1
    }

    # Guard: prevent clobbering JSON configuration files
    if {[file extension $file_name] eq ".json"} {
        puts stderr "ERROR: '$file_name' is a JSON config file. Did you mean to use '-config $file_name'?"
        exit 1
    }

    # Ensure .v extension
    if {[file extension $file_name] eq ""} {
        set file_name "${file_name}.v"
    }

    # Extract clean module name without directory paths
    set mod_name [file rootname [file tail $file_name]]

    # Ensure parent directory exists if a path was supplied
    set out_dir [file dirname $file_name]
    if {$out_dir ne "" && $out_dir ne "." && ![file exists $out_dir]} {
        file mkdir $out_dir
    }

    set fp [open $file_name w] 

    if {[string match "tb_*" $mod_name] || [string match "*_tb" $mod_name] || $mod_name eq "tb"} {
        tb_template $mod_name $fp
    } else {
        design_template $mod_name $fp
    }

    close $fp
    puts "Generated file: $file_name (module: $mod_name)"
}
