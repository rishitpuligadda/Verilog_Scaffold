# lib/utils.tcl

proc outdent {text} {
    set lines [split [string trimright [string trimleft $text "\r\n"]] "\n"]

    set min_indent -1
    foreach line $lines {
        if {[string trim $line] eq ""} continue
        regexp {^(\s*)} $line -> indent
        set len [string length $indent]
        if {$min_indent == -1 || $len < $min_indent} {
            set min_indent $len
        }
    }

    if {$min_indent <= 0} {
        return [join $lines "\n"]
    }

    set result {}
    foreach line $lines {
        lappend result [string range $line $min_indent end]
    }
    return [join $result "\n"]
}
