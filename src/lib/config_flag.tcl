# lib/config_flag.tcl
package require json

proc config_flag {config_file} {
    if {![file exists $config_file]} {
        puts stderr "Error: Configuration file '$config_file' not found."
        exit 1
    }

    set ext [file extension $config_file]
    if {$ext ne ".json"} {
        puts stderr "Error: Unsupported config format '$ext'. Expected .json"
        exit 1
    }

    # Read file content cleanly
    set config_fp [open $config_file r]
    set content [read $config_fp]
    close $config_fp

    # Convert JSON string to a native Tcl dictionary
    set data [json::json2dict $content]

    # Extract values using dict get
    set mod_name [dict get $data module]

    set inputs {}
    set outputs {}

    if {[dict exists $data ports]} {
        set ports [dict get $data ports]
        if {[dict exists $ports inputs]} {
            set inputs [dict get $ports inputs]
        }
        if {[dict exists $ports outputs]} {
            set outputs [dict get $ports outputs]
        }
    }

    puts "Module:  $mod_name"
    puts "Inputs:  $inputs"
    puts "Outputs: $outputs"
	puts "Parsed through config file"
}
