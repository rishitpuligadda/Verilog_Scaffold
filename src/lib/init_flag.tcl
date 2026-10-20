# lib/init_flag.tcl - write a commented config template (vscaff -init)
#
#   file_name  template to write ("" -> config.json); .json added if missing
#   n_in       number of input ports in the template
#   n_out      number of output ports in the template
#   comb       1 = combinational design: leave out the "clocks" section
#
# Values the user must change are written as "<placeholders>". "-config"
# refuses to run until every placeholder has been replaced.

# One port entry, with the name column padded so entries line up
proc init_port_entry {name name_w} {
    return [format {{ "name": %-*s "width": 1, "type": "wire" }} \
                [expr {$name_w + 3}] "\"$name\","]
}

proc init_ports_block {dir count} {
    if {$count == 0} {
        return "\"${dir}s\": \[\]"
    }
    set names {}
    for {set k 1} {$k <= $count} {incr k} {
        lappend names "<${dir}_$k>"
    }
    set w [max_len $names]
    set entries [lmap n $names {string cat "            " [init_port_entry $n $w]}]
    return "\"${dir}s\": \[\n[join $entries ",\n"]\n        \]"
}

proc init_flag {file_name {n_in 1} {n_out 1} {comb 0} {force 0}} {
    if {$file_name eq ""} {
        set file_name "config.json"
    }
    set ext [string tolower [file extension $file_name]]
    if {$ext eq ""} {
        append file_name ".json"
    } elseif {$ext ni {.json .jsonc}} {
        error "a config template must be a .json or .jsonc file, got '$ext'"
    }
    foreach {what n} [list inputs $n_in outputs $n_out] {
        if {![string is integer -strict $n] || $n < 0} {
            error "number of $what must be a whole number of 0 or more, got '$n'"
        }
    }

    # How this template was made, recorded at the top for reference
    set cmd "$::prog -init [file tail $file_name]"
    if {$comb}       { append cmd " -comb" }
    if {$n_in != 1}  { append cmd " -i $n_in" }
    if {$n_out != 1} { append cmd " -o $n_out" }

    set kind [expr {$comb ? "combinational (no clocks)" : "clocked"}]
    set tail [file tail $file_name]

    set clocks_section ""
    if {!$comb} {
        set clocks_section {
    // Clocks: "name": period in ns (decimals allowed, e.g. 12.5).
    // Each clock is added as a 1-bit input automatically, so don't list it
    // under "inputs" as well. The testbench gets one clock generator per clock.
    // Add more clocks as "name": period pairs, separated by commas.
    "clocks": {
        "clk": 10
    },
}
    }

    set text [string map [list \
        @CMD@    $cmd \
        @PROG@   $::prog \
        @ADJUST@ [expr {$comb ? "widths, types and parameters" : "widths, types, parameters and clocks"}] \
        @KIND@   $kind \
        @TAIL@   $tail \
        @CLOCKS@ $clocks_section \
        @INPUTS@  [init_ports_block input  $n_in] \
        @OUTPUTS@ [init_ports_block output $n_out] \
    ] {// vscaff config template: @KIND@ design
// Created with: @CMD@
//
// 1. Replace every "<placeholder>" below (-config refuses to run until you do).
// 2. Adjust @ADJUST@ as needed.
// 3. Generate the design and testbench:  @PROG@ -config @TAIL@
//
// Comments like these are allowed anywhere, and a trailing comma after the
// last item in a list is fine, so you can delete entries freely.
{
    // Module name: letters, digits and _, not starting with a digit.
    "module": "<module_name>",

    // Where to write the design: a directory (e.g. "../rtl") or a full
    // .v/.sv file path. Relative paths are relative to THIS config file.
    // Delete this line to write the design to the current directory.
    "design_path": "<path/to/design_dir>",

    // Where to write the testbench: a directory or a full .v/.sv file path.
    // If you give a file name, it also becomes the testbench module name.
    // Delete this line to put the testbench next to the design.
    "tb_path": "<path/to/tb_dir>",

    // Generate a testbench too? true or false.
    "generate_tb": true,

    // Parameters: "NAME": default value. The value is copied into the
    // Verilog as-is, so literals like "8'hFF" work. A parameter name can be
    // used as a port width, e.g. "width": "WIDTH". Use {} for no parameters.
    "parameters": {
        "WIDTH": 8
    },
@CLOCKS@
    "ports": {
        // Inputs, one { ... } per port:
        //   "name"   port name (required)
        //   "width"  1 = single bit; N = [N-1:0]; a parameter name such as
        //            "WIDTH" = [WIDTH-1:0]; or an explicit range like "7:0"
        //   "type"   inputs can only be "wire" (or leave the field out)
        // Shorthand: a plain string like "rst_n" is a 1-bit input.
        // Names with rst/reset are driven as resets in the testbench
        // (rst_n, wr_rst_n = active-low; rst, reset = active-high).
        @INPUTS@,

        // Outputs: same fields as inputs, but "type" can be "wire" or "reg".
        // Use "reg" for outputs you assign inside an always block.
        @OUTPUTS@
    }
}}]

    check_writable [list $file_name] $force
    write_output $file_name $text

    puts "Generated config template: $file_name"
    puts "Next: replace the <placeholders>, then run:  $::prog -config $file_name"
}
