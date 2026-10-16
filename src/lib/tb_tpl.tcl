# lib/tb_tpl.tcl - Verilog testbench template
#
# dut_name: module under test ("" when unknown)
# inputs / outputs: lists of {type width name}, as for design_template
# params:  dict of parameter name -> default value
# clocks:  dict of clock name -> period (in timescale units, i.e. ns)
# tb_name: testbench module name (default: tb_<dut_name>)
# Returns the generated source as a string.

# True for reset-style input names: rst, rst_n, wr_rst_n, reset, arst_n, ...
proc is_reset_name {name} {
    return [regexp -nocase {(^|_)(a?rst|reset)} $name]
}

# True for active-low resets: rst_n, rstn, reset_b, wr_rst_n, ...
proc is_active_low_reset {name} {
    return [regexp -nocase {(^|_)(a?rst|reset)_?(n|b)(_|$)} $name]
}

proc tb_template {dut_name {inputs {}} {outputs {}} {params {}} {clocks {}} {tb_name ""}} {
    if {$tb_name eq ""} {
        set tb_name "tb_${dut_name}"
    }

    # Ports unknown (e.g. -file mode): emit a minimal skeleton.
    if {[llength $inputs] == 0 && [llength $outputs] == 0} {
        set what [expr {$dut_name eq "" ? "the DUT" : $dut_name}]
        set raw {
            @TIMESCALE@

            module @TB_NAME@;

                // TODO: declare signals and instantiate @WHAT@

                initial begin
                    #100 $finish;
                end

            endmodule
        }
        return [string map [list @TIMESCALE@ $::TIMESCALE @TB_NAME@ $tb_name @WHAT@ $what] \
                    [outdent $raw]]
    }

    # 1. Timing: clock period parameters, reset and simulation lengths
    set slowest 0
    set clk_params [dict create]
    dict for {clk period} $clocks {
        dict set clk_params $clk "[string toupper $clk]_PERIOD"
        if {$period > $slowest} { set slowest $period }
    }
    if {$slowest > 0} {
        set reset_time [fmt_num [expr {5 * $slowest}]]
        set sim_time   [fmt_num [expr {100 * $slowest}]]
    } else {
        set reset_time 50
        set sim_time   1000
    }

    set all_params $params
    dict for {clk pname} $clk_params {
        if {[dict exists $all_params $pname]} {
            error "clock period parameter '$pname' clashes with a design parameter of the same name"
        }
        dict set all_params $pname [dict get $clocks $clk]
    }
    foreach {pname pval} [list RESET_TIME $reset_time SIM_TIME $sim_time] {
        if {[dict exists $all_params $pname]} {
            error "testbench parameter '$pname' clashes with a design parameter of the same name"
        }
        dict set all_params $pname $pval
    }

    set param_lines {"    // Parameters"}
    set pw [max_len [dict keys $all_params]]
    dict for {pname pval} $all_params {
        lappend param_lines [format "    parameter %-*s = %s;" $pw $pname $pval]
    }

    # 2. Signals: DUT inputs are regs, DUT outputs are wires
    set ww [max_len [lmap p [concat $inputs $outputs] {lindex $p 1}]]
    set sig_lines {"    // DUT inputs (driven by the TB)"}
    foreach p $inputs {
        lappend sig_lines [string trimright [format "    reg  %-*s %s;" $ww [lindex $p 1] [lindex $p 2]]]
    }
    if {[llength $outputs] > 0} {
        lappend sig_lines "" "    // DUT outputs (observed by the TB)"
        foreach p $outputs {
            lappend sig_lines [format "    wire %-*s %s;" $ww [lindex $p 1] [lindex $p 2]]
        }
    }
    # Collapse the double space left when no port has a width
    if {$ww == 0} {
        set sig_lines [lmap l $sig_lines {regsub {^(    \w+) +} $l {\1 }}]
    }

    # 3. Clock generators
    set clk_lines {}
    if {[dict size $clocks] > 0} {
        lappend clk_lines "    // Clock generators"
        dict for {clk pname} $clk_params {
            lappend clk_lines "    always #(${pname} / 2.0) ${clk} = ~${clk};"
        }
    }

    # 4. DUT instantiation
    set port_names [lmap p [concat $inputs $outputs] {lindex $p 2}]
    set nw [max_len $port_names]
    set conn [lmap n $port_names {format "        .%-*s (%s)" $nw $n $n}]
    set inst_lines {"    // DUT instantiation"}
    if {[dict size $params] > 0} {
        set dpw [max_len [dict keys $params]]
        set pconn [lmap n [dict keys $params] {format "        .%-*s (%s)" $dpw $n $n}]
        lappend inst_lines "    ${dut_name} #(" [join $pconn ",\n"] "    ) dut ("
    } else {
        lappend inst_lines "    ${dut_name} dut ("
    }
    lappend inst_lines [join $conn ",\n"] "    );"

    # 5. Stimulus: start clocks, hold resets, release them, then finish
    set clk_names   [dict keys $clocks]
    set other_ins   {}
    set resets      {}
    foreach p $inputs {
        set n [lindex $p 2]
        if {$n in $clk_names} continue
        lappend other_ins $n
        if {[is_reset_name $n]} { lappend resets $n }
    }

    set mon_names [lmap n $port_names {if {$n in $clk_names} continue; set n}]
    if {[llength $mon_names] > 0} {
        set fmt  [join [lmap n $mon_names {string cat $n "=%0h"}] " "]
        set mon  "        \$monitor(\"time=%0t | $fmt\", \$time, [join $mon_names {, }]);"
    } else {
        set mon  "        \$monitor(\"time=%0t\", \$time);"
    }

    set iw [max_len [concat $clk_names $other_ins]]
    set init_lines {"    // Stimulus and monitoring" "    initial begin"}
    foreach clk $clk_names {
        lappend init_lines [format "        %-*s = 1'b0;" $iw $clk]
    }
    foreach n $other_ins {
        if {$n in $resets} {
            set v [expr {[is_active_low_reset $n] ? "1'b0" : "1'b1"}]
            lappend init_lines [format "        %-*s = %s;   // reset asserted" $iw $n $v]
        } else {
            lappend init_lines [format "        %-*s = 0;" $iw $n]
        }
    }
    lappend init_lines "" "        \$timeformat(-9, 1, \" ns\", 0);" $mon
    if {[llength $resets] > 0} {
        lappend init_lines "" "        // Release reset(s)" "        #(RESET_TIME);"
        foreach n $resets {
            set v [expr {[is_active_low_reset $n] ? "1'b1" : "1'b0"}]
            lappend init_lines [format "        %-*s = %s;" $iw $n $v]
        }
    }
    lappend init_lines "" "        // TODO: add test stimulus here" "" \
                       "        #(SIM_TIME) \$finish;" "    end"

    # 6. Assemble, skipping empty sections
    set out [list $::TIMESCALE "" "module ${tb_name};" ""]
    foreach section [list $param_lines $sig_lines $clk_lines $inst_lines $init_lines] {
        if {[llength $section] == 0} continue
        lappend out {*}$section ""
    }
    lappend out "endmodule"
    return [join $out "\n"]
}
