# lib/design_tpl.tcl - Verilog design module template
#
# inputs / outputs: lists of {type width name}, e.g. {reg {[7:0]} data}
# params:           dict of parameter name -> default value
# Returns the generated source as a string.

proc design_template {mod_name {inputs {}} {outputs {}} {params {}}} {
    # 1. Parameter block: #( ... )
    set param_block ""
    if {[dict size $params] > 0} {
        set w [max_len [dict keys $params]]
        set lines {}
        dict for {pname pval} $params {
            lappend lines [format "    parameter %-*s = %s" $w $pname $pval]
        }
        set param_block " #(\n[join $lines ",\n"]\n)"
    }

    # 2. Ports: inputs first (clocks lead), then outputs
    set ports {}
    foreach p $inputs {
        lassign $p ptype width name
        lappend ports [list [string trim "input $ptype"] $width $name]
    }
    foreach p $outputs {
        lassign $p ptype width name
        lappend ports [list [string trim "output $ptype"] $width $name]
    }

    # 3. Port block, aligned in columns
    set port_block ""
    if {[llength $ports] > 0} {
        set dir_w   [max_len [lmap p $ports {lindex $p 0}]]
        set width_w [max_len [lmap p $ports {lindex $p 1}]]
        set lines {}
        foreach p $ports {
            lassign $p dir width name
            if {$width_w > 0} {
                lappend lines [format "    %-*s %-*s %s" $dir_w $dir $width_w $width $name]
            } else {
                lappend lines [format "    %-*s %s" $dir_w $dir $name]
            }
        }
        set port_block " (\n[join $lines ",\n"]\n)"
    }

    # 4. Assemble
    return [join [list \
        $::TIMESCALE \
        "" \
        "module ${mod_name}${param_block}${port_block};" \
        "" \
        "    // TODO: implement design logic" \
        "" \
        "endmodule" \
    ] "\n"]
}
