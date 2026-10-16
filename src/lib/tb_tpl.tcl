# lib/tb_tpl.tcl

proc tb_template {mod_name fp} {
    set raw {
        module @MOD_NAME@;

            initial begin

                #100 $finish;
            end
        endmodule
    }

    set clean [outdent $raw]
    set tb [string map [list @MOD_NAME@ $mod_name] $clean]
    puts $fp $tb
}
