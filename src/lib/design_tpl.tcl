# lib/design_tpl.tcl

proc design_template {mod_name fp} {
    set raw {
        module $mod_name (

        );

        endmodule
    }

    set clean [outdent $raw]
    set design [subst -nocommands -nobackslashes $clean]
    puts $fp $design
}
