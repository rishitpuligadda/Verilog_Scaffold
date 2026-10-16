# lib/design_tpl.tcl

proc design_template {mod_name fp {inputs {}} {outputs {}}} {
    # 1. Build the comma-separated port declarations
    set port_lines {}

    foreach out $outputs {
        lappend port_lines "    output $out"
    }
    foreach in $inputs {
        lappend port_lines "    input  $in"
    }

    # Join lines with a trailing comma on every port except the last
    set port_block [join $port_lines ",\n"]

    # If ports exist, add a newline before and after for clean spacing
    if {$port_block ne ""} {
        set port_block "\n$port_block\n"
    }

    # 2. Assemble module template using placeholders
    set raw {
        module @MOD_NAME@ (@PORTS@);

        endmodule
    }

    set clean [outdent $raw]
    set design [string map [list @MOD_NAME@ $mod_name @PORTS@ $port_block] $clean]

    puts $fp $design
}
