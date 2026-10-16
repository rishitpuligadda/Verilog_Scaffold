# lib/tb_tpl.tcl

proc tb_template {mod_name fp {inputs {}} {outputs {}} {params {}} {clocks {}}} {
    set tb_name "tb_${mod_name}"

    if {[llength $inputs] == 0 && [llength $outputs] == 0} {
        set raw {
module @TB_NAME@;

    initial begin
        #100 $finish;
    end

endmodule}
        set tb [string map [list @TB_NAME@ $tb_name] $raw]
        puts $fp $tb
        return
    }

    # 1. Parameter definitions
    set param_decls {}
    set param_insts {}
    if {[llength $params] > 0} {
        set max_pname 0
        dict for {pname pval} $params {
            if {[string length $pname] > $max_pname} { set max_pname [string length $pname] }
        }
        dict for {pname pval} $params {
            lappend param_decls [format "    parameter %-${max_pname}s = %s;" $pname $pval]
            lappend param_insts [format "        .%-${max_pname}s (%s)" $pname $pname]
        }
    }

    # Clock parameters
    if {[dict size $clocks] > 0} {
        dict for {clk_name clk_period} $clocks {
            set p_name "CLK_[string toupper $clk_name]_PERIOD"
            lappend param_decls [format "    parameter %-18s = %s;" $p_name $clk_period]
        }
    }

    set param_decl_block [join $param_decls "\n"]
    if {$param_decl_block ne ""} {
        set param_decl_block "    // Parameters\n$param_decl_block\n"
    }

    # 2. Max bus width calculation for alignment
    set max_width_len 0
    foreach item [concat $inputs $outputs] {
        set w [lindex $item 1]
        if {[string length $w] > $max_width_len} {
            set max_width_len [string length $w]
        }
    }

    # 3. Signals: Inputs as reg, Outputs as wire
    set sig_lines {}
    lappend sig_lines "    // DUT Inputs (Driven by TB)"
    foreach in $inputs {
        set w    [lindex $in 1]
        set name [lindex $in 2]
        if {$max_width_len > 0} {
            lappend sig_lines [format "    reg  %-${max_width_len}s %s;" $w $name]
        } else {
            lappend sig_lines [format "    reg  %s;" $name]
        }
    }

    lappend sig_lines "\n    // DUT Outputs (Observed by TB)"
    foreach out $outputs {
        set w    [lindex $out 1]
        set name [lindex $out 2]
        if {$max_width_len > 0} {
            lappend sig_lines [format "    wire %-${max_width_len}s %s;" $w $name]
        } else {
            lappend sig_lines [format "    wire %s;" $name]
        }
    }
    set sig_block [join $sig_lines "\n"]

    # 4. Multi-clock generator block
    set clk_gen_lines {}
    if {[dict size $clocks] > 0} {
        lappend clk_gen_lines "    // Clock Generators"
        dict for {clk_name _} $clocks {
            set p_name "CLK_[string toupper $clk_name]_PERIOD"
            lappend clk_gen_lines "    always #(${p_name} / 2.0) ${clk_name} = ~${clk_name};"
        }
    }
    set clk_gen_block [join $clk_gen_lines "\n"]

    # 5. DUT Instantiation
    set all_port_names {}
    foreach item [concat $inputs $outputs] {
        lappend all_port_names [lindex $item 2]
    }

    set max_port_len 0
    foreach p $all_port_names {
        if {[string length $p] > $max_port_len} { set max_port_len [string length $p] }
    }

    set port_inst_lines {}
    foreach p $all_port_names {
        lappend port_inst_lines [format "        .%-${max_port_len}s (%s)" $p $p]
    }
    set port_inst_block [join $port_inst_lines ",\n"]

    set dut_inst ""
    if {[llength $param_insts] > 0} {
        set p_block [join $param_insts ",\n"]
        set dut_inst "    ${mod_name} #(\n$p_block\n    ) dut (\n$port_inst_block\n    );"
    } else {
        set dut_inst "    ${mod_name} dut (\n$port_inst_block\n    );"
    }

    # 6. Monitor statement (exclude all clock signals)
    set monitor_signals {}
    set fmt_strings {}
    foreach p $all_port_names {
        if {[dict exists $clocks $p]} continue
        lappend monitor_signals $p
        lappend fmt_strings "${p}=%0h"
    }
    set fmt_pattern [join $fmt_strings " "]
    set mon_args [join $monitor_signals ", "]

    # 7. Initial stimulus block
    set init_lines {}
    lappend init_lines "    initial begin"
    if {[dict size $clocks] > 0} {
        dict for {clk_name _} $clocks {
            lappend init_lines "        ${clk_name} = 0;"
        }
    }
    lappend init_lines "        \$monitor(\"time=%0t | $fmt_pattern\", \$time, $mon_args);"
    lappend init_lines ""
    lappend init_lines "        // Add test stimulus here"
    lappend init_lines ""
    lappend init_lines "        #200 \$finish;"
    lappend init_lines "    end"
    set init_block [join $init_lines "\n"]

    # 8. Assemble template
    set template [string trim {
module @TB_NAME@;

@PARAMS@
@SIGNALS@

@CLK_GEN@

    // DUT Instantiation
@DUT_INST@

    // Stimulus and Monitoring
@INIT_BLOCK@

endmodule
}]

    set tb [string map [list \
        @TB_NAME@    $tb_name \
        @PARAMS@     $param_decl_block \
        @SIGNALS@    $sig_block \
        @CLK_GEN@    $clk_gen_block \
        @DUT_INST@   $dut_inst \
        @INIT_BLOCK@ $init_block \
    ] $template]

    puts $fp $tb
}
