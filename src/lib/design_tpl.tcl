# lib/design_tpl.tcl

proc design_template {mod_name fp {inputs {}} {outputs {}} {params {}}} {
    # 1. Format parameter block #(...)
    set param_block ""
    if {[llength $params] > 0} {
        set max_pname_len 0
        dict for {pname pval} $params {
            if {[string length $pname] > $max_pname_len} {
                set max_pname_len [string length $pname]
            }
        }
        set param_lines {}
        dict for {pname pval} $params {
            lappend param_lines [format "    parameter %-${max_pname_len}s = %s" $pname $pval]
        }
        set formatted_params [join $param_lines ",\n"]
        set param_block " #(\n$formatted_params\n)"
    }

    # 2. Flatten all ports into a uniform list: {dir_and_type width name}
    set all_ports {}

	foreach out $outputs {
        set ptype [lindex $out 0]
        set width [lindex $out 1]
        set name  [lindex $out 2]
        set dir_str [string trim "output $ptype"]
        lappend all_ports [list $dir_str $width $name]
    }

    foreach in $inputs {
        set ptype [lindex $in 0]
        set width [lindex $in 1]
        set name  [lindex $in 2]
        set dir_str [string trim "input $ptype"]
        lappend all_ports [list $dir_str $width $name]
    }
    
    # 3. Calculate max field widths for dynamic columnar alignment
    set max_dir_len   0
    set max_width_len 0

    foreach p $all_ports {
        set d_len [string length [lindex $p 0]]
        set w_len [string length [lindex $p 1]]
        if {$d_len > $max_dir_len}   { set max_dir_len   $d_len }
        if {$w_len > $max_width_len} { set max_width_len $w_len }
    }

    # 4. Format port lines
    set port_lines {}
    foreach p $all_ports {
        set dir_str [lindex $p 0]
        set w       [lindex $p 1]
        set name    [lindex $p 2]

        if {$max_width_len > 0} {
            lappend port_lines [format "    %-${max_dir_len}s %-${max_width_len}s %s" $dir_str $w $name]
        } else {
            lappend port_lines [format "    %-${max_dir_len}s %s" $dir_str $name]
        }
    }

    set port_block [join $port_lines ",\n"]
    if {$port_block ne ""} {
        set port_block "(\n$port_block\n)"
    } else {
        set port_block "()"
    }

    # 5. Assemble template
    set raw {
        module @MOD_NAME@@PARAMS@ @PORTS@;

        endmodule
    }

    set clean [outdent $raw]
    set design [string map [list @MOD_NAME@ $mod_name @PARAMS@ $param_block @PORTS@ $port_block] $clean]

    puts $fp $design
}
