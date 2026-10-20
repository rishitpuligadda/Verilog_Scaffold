# lib/design_tpl.tcl - Verilog design module template
#
# inputs / outputs: lists of {type width name}, e.g. {reg {[7:0]} data}
# params:           dict of parameter name -> default value
# instances:        list of submodule instances, each a dict with keys
#                   module, name, params {{name default} ...}, ports {{dir range name} ...}
# Returns the generated source as a string.

# ".name ()" connection lines, aligned, comma-separated, each with an
# optional comment. ENTRIES is a list of {name comment}.
proc instance_lines {entries} {
    set w [max_len [lmap e $entries {lindex $e 0}]]
    set last [expr {[llength $entries] - 1}]
    set out {}
    set k 0
    foreach e $entries {
        lassign $e name comment
        set sep [expr {$k == $last ? " " : ","}]
        set line [format "        .%-*s ()%s" $w $name $sep]
        if {$comment ne ""} {
            append line "  // $comment"
        }
        lappend out $line
        incr k
    }
    return $out
}

# One submodule instance with every parameter and port left unconnected:
#     fifo #(
#         .DEPTH ()    // default: 16
#     ) u_fifo (
#         .clk   (),   // input
#         .dout  ()    // output [7:0]
#     );
proc instance_block {inst} {
    set mod    [dict get $inst module]
    set name   [dict get $inst name]
    set params [dict get $inst params]
    set ports  [dict get $inst ports]

    set lines {}
    if {[llength $params] > 0} {
        set entries [lmap p $params {
            lassign $p pn pd
            list $pn [expr {$pd eq "" ? "" : "default: $pd"}]
        }]
        lappend lines "    $mod #(" {*}[instance_lines $entries] "    ) $name ("
    } else {
        lappend lines "    $mod $name ("
    }
    if {[llength $ports] == 0} {
        lset lines end "[lindex $lines end]);"
        return [join $lines "\n"]
    }
    set entries [lmap p $ports {
        lassign $p pdir prange pn
        list $pn [string trim "$pdir $prange"]
    }]
    lappend lines {*}[instance_lines $entries] "    );"
    return [join $lines "\n"]
}

proc design_template {mod_name {inputs {}} {outputs {}} {params {}} {instances {}}} {
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

    # 4. Body: submodule instances (if any), then the TODO marker
    set body {}
    if {[llength $instances] > 0} {
        lappend body "    // Submodule instances: connect each port inside its ( )"
        foreach inst $instances {
            lappend body "" [instance_block $inst]
        }
        lappend body ""
    }
    lappend body "    // TODO: implement design logic"

    # 5. Assemble
    return [join [list \
        $::TIMESCALE \
        "" \
        "module ${mod_name}${param_block}${port_block};" \
        "" \
        {*}$body \
        "" \
        "endmodule" \
    ] "\n"]
}
