# lib/file_flag.tcl - generate an empty design or testbench from a file name
#
#   counter / counter.v   -> design module "counter"
#   tb_counter            -> testbench "tb_counter" for DUT "counter"
#   counter_tb            -> testbench "counter_tb" for DUT "counter"
#
# The path is used as given (relative to the current directory).

proc file_flag {file_name {force 0}} {
    if {$file_name eq ""} {
        error "no file name given"
    }

    set ext [string tolower [file extension $file_name]]
    if {$ext eq ".json"} {
        error "'$file_name' is a JSON config file. Did you mean '-config $file_name'?"
    }
    if {$ext eq ""} {
        append file_name ".v"
    } elseif {$ext ni {.v .sv}} {
        error "unsupported extension '$ext' (expected .v or .sv)"
    }

    set mod_name [file rootname [file tail $file_name]]
    check_ident "module" $mod_name

    if {[regexp {^tb_(.+)$} $mod_name -> dut] || [regexp {^(.+)_tb$} $mod_name -> dut]} {
        set content [tb_template $dut {} {} {} {} $mod_name]
    } elseif {$mod_name eq "tb"} {
        set content [tb_template "" {} {} {} {} $mod_name]
    } else {
        set content [design_template $mod_name]
    }

    check_writable [list $file_name] $force
    write_output $file_name $content
    puts "Generated file: $file_name (module: $mod_name)"
}
