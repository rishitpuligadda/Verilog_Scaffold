# lib/utils.tcl - shared helpers used by the flag handlers and templates

# Written at the top of every generated file. The design and the testbench
# must use the same timescale, so it is defined once here.
set ::TIMESCALE {`timescale 1ns / 1ps}

# Reserved words that cannot be used as module, port or parameter names.
set ::VERILOG_KEYWORDS {
    always and assign automatic begin buf case casex casez cell config deassign
    default defparam design disable edge else end endcase endconfig endfunction
    endgenerate endmodule endprimitive endspecify endtable endtask event for force
    forever fork function generate genvar if ifnone initial inout input instance
    integer join large liblist library localparam macromodule medium module nand
    negedge nmos nor not notif0 notif1 or output parameter pmos posedge primitive
    pull0 pull1 pulldown pullup real realtime reg release repeat rnmos rpmos rtran
    scalared signed small specify specparam strong0 strong1 supply0 supply1 table
    task time tran tri tri0 tri1 triand trior trireg unsigned use vectored wait
    wand weak0 weak1 while wire wor xnor xor
    bit byte int logic longint shortint
}

# Strip the common leading indentation from a block of text.
proc outdent {text} {
    set text  [string map {"\r" ""} $text]
    set lines [split [string trimright [string trimleft $text "\n"]] "\n"]

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

proc is_verilog_ident {name} {
    return [regexp {^[A-Za-z_][A-Za-z0-9_$]*$} $name]
}

# Raise a clear error if NAME is not a legal Verilog identifier.
proc check_ident {what name} {
    if {$name eq ""} {
        error "$what name is empty"
    }
    if {![is_verilog_ident $name]} {
        error "invalid $what name '$name': must start with a letter or underscore\
               and contain only letters, digits, _ or \$"
    }
    if {$name in $::VERILOG_KEYWORDS} {
        error "invalid $what name '$name': it is a reserved Verilog keyword"
    }
}

# Length of the longest string in a list (0 for an empty list).
proc max_len {strings} {
    set max 0
    foreach s $strings {
        set len [string length $s]
        if {$len > $max} { set max $len }
    }
    return $max
}

# Format a number for Verilog: 50.0 -> 50, 12.5 -> 12.5
proc fmt_num {n} {
    if {$n == int($n)} {
        return [expr {int($n)}]
    }
    return $n
}

# Refuse to clobber existing files unless forced. Checks every path before
# anything is written, so a run never leaves half its output behind.
proc check_writable {paths force} {
    if {$force} return
    foreach p $paths {
        if {[file exists $p]} {
            error "'$p' already exists (use -force to overwrite)"
        }
    }
}

# Write CONTENT to PATH, creating the parent directory if needed.
proc write_output {path content} {
    set dir [file dirname $path]
    if {![file isdirectory $dir]} {
        file mkdir $dir
    }
    set fp [open $path w]
    try {
        puts $fp $content
    } finally {
        close $fp
    }
}
