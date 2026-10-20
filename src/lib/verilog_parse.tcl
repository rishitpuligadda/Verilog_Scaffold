# lib/verilog_parse.tcl - find a module in a Verilog file and read its interface
#
# parse_module_interface <file> <module> returns a dict:
#   params  list of {name default}      (overridable parameters only)
#   ports   list of {dir range name}    in declaration order, e.g. {input {[7:0]} data}
#
# Handles ANSI headers  (module m #(parameter W = 8) (input [W-1:0] a, ...);)
# and non-ANSI headers  (module m (a, b); input a; output [3:0] b; ...).
# Comments are ignored and `directive lines (`timescale, `define, `ifdef, ...)
# are skipped; ports inside `ifdef blocks are all included.

# Remove comments (keeping newlines, so line numbers stay valid) and
# compiler-directive lines. String literals are swapped for tokens
# ("@@S0@@", ...) so nothing inside them is mistaken for code; the
# originals are kept in ::vp_strings for vp_unstring.
proc vp_clean {text} {
    set ::vp_strings {}
    set text [string map {"\r" ""} $text]
    set out ""
    set n [string length $text]
    set i 0
    while {$i < $n} {
        set c [string index $text $i]
        if {$c eq "\""} {
            set j [expr {$i + 1}]
            while {$j < $n} {
                set d [string index $text $j]
                if {$d eq "\\"} { incr j 2; continue }
                if {$d eq "\"" || $d eq "\n"} break
                incr j
            }
            set tok "@@S[expr {[llength $::vp_strings] / 2}]@@"
            lappend ::vp_strings $tok [string range $text $i $j]
            append out $tok
            set i [expr {$j + 1}]
            continue
        }
        set two [string range $text $i [expr {$i + 1}]]
        if {$two eq "//"} {
            set end [string first "\n" $text $i]
            if {$end < 0} { set end $n }
            set i $end
            continue
        }
        if {$two eq "/*"} {
            set end [string first "*/" $text [expr {$i + 2}]]
            if {$end < 0} { set end [expr {$n - 2}] }
            # keep the newlines of the comment
            append out [regsub -all {[^\n]} [string range $text $i [expr {$end + 1}]] ""]
            set i [expr {$end + 2}]
            continue
        }
        append out $c
        incr i
    }
    regsub -all -line {^[ \t]*`.*$} $out "" out
    return $out
}

# Put the original string literals back into a piece of cleaned text
proc vp_unstring {text} {
    return [string map $::vp_strings $text]
}

# Index of the bracket matching the one at OPEN, or -1
proc vp_match {text open} {
    set depth 0
    set n [string length $text]
    for {set i $open} {$i < $n} {incr i} {
        switch -- [string index $text $i] {
            "(" - "\[" - "\{" { incr depth }
            ")" - "\]" - "\}" {
                incr depth -1
                if {$depth == 0} { return $i }
            }
        }
    }
    return -1
}

# Split on commas that are not inside (), [] or {}
proc vp_split {text} {
    set items {}
    set depth 0
    set cur ""
    foreach c [split $text ""] {
        switch -- $c {
            "(" - "\[" - "\{" { incr depth }
            ")" - "\]" - "\}" { incr depth -1 }
            "," {
                if {$depth == 0} {
                    lappend items [string trim $cur]
                    set cur ""
                    continue
                }
            }
        }
        append cur $c
    }
    lappend items [string trim $cur]
    return [lmap it $items {if {$it eq ""} continue; set it}]
}

# Split "lhs = rhs" at the first top-level '='; returns {lhs rhs}
proc vp_split_eq {text} {
    set depth 0
    set n [string length $text]
    for {set i 0} {$i < $n} {incr i} {
        set c [string index $text $i]
        switch -- $c {
            "(" - "\[" - "\{" { incr depth }
            ")" - "\]" - "\}" { incr depth -1 }
            "=" {
                if {$depth == 0} {
                    return [list [string trim [string range $text 0 [expr {$i - 1}]]] \
                                 [string trim [string range $text [expr {$i + 1}] end]]]
                }
            }
        }
    }
    return [list [string trim $text] ""]
}

# Split one declaration item into {decl name}: "input wire [7:0] a [0:3]"
# -> {{input wire [7:0]} a}. Trailing unpacked dimensions are dropped.
proc vp_decl_name {item} {
    set item [lindex [vp_split_eq $item] 0]
    regsub {(\s*\[[^\]]*\])+\s*$} $item "" item
    if {![regexp -indices {[A-Za-z_][A-Za-z0-9_$]*\s*$} $item where]} {
        return ""
    }
    set start [lindex $where 0]
    return [list [string trim [string range $item 0 [expr {$start - 1}]]] \
                 [string trim [string range $item $start end]]]
}

# The packed range(s) in a declaration, with spaces removed: "[W - 1:0]" -> "[W-1:0]"
proc vp_range {decl} {
    return [string map {" " "" "\t" "" "\n" ""} [join [regexp -all -inline {\[[^\]]*\]} $decl] ""]]
}

# Line number of character index IDX in TEXT
proc vp_line {text idx} {
    return [expr {[regexp -all "\n" [string range $text 0 $idx]] + 1}]
}

# Names of every module defined in the (cleaned) text
proc vp_module_names {text} {
    set names {}
    foreach {- name} [regexp -all -inline {\m(?:macro)?module\s+(?:(?:automatic|static)\s+)?([A-Za-z_][A-Za-z0-9_$]*)} $text] {
        lappend names $name
    }
    return $names
}

proc parse_module_interface {file module} {
    if {![file readable $file]} {
        error "file not found or not readable: $file"
    }
    set fp [open $file r]
    set text [vp_clean [read $fp]]
    close $fp

    # 1. Find "module <name>"
    set start -1
    set pos 0
    while {[regexp -start $pos -indices {\m(?:macro)?module\s+(?:(?:automatic|static)\s+)?([A-Za-z_][A-Za-z0-9_$]*)} $text all grp]} {
        if {[string range $text {*}$grp] eq $module} {
            set start [expr {[lindex $grp 1] + 1}]
            break
        }
        set pos [expr {[lindex $all 1] + 1}]
    }
    if {$start < 0} {
        set found [vp_module_names $text]
        if {[llength $found] == 0} {
            error "module '$module' not found in $file (the file defines no modules)"
        }
        error "module '$module' not found in $file (it defines: [join $found {, }])"
    }
    set mod_line [vp_line $text $start]

    # 2. Optional parameter list #( ... )
    set i $start
    set rest [string range $text $i end]
    set param_text ""
    set has_param_list 0
    if {[regexp -indices {^\s*#\s*\(} $rest m]} {
        set open [expr {$i + [lindex $m 1]}]
        set close [vp_match $text $open]
        if {$close < 0} {
            error "$file line $mod_line: unbalanced parentheses in the parameter list of '$module'"
        }
        set param_text [string range $text [expr {$open + 1}] [expr {$close - 1}]]
        set has_param_list 1
        set i [expr {$close + 1}]
        set rest [string range $text $i end]
    }

    # 3. Port list ( ... ) and the terminating ';'
    set port_text ""
    if {[regexp -indices {^\s*\(} $rest m]} {
        set open [expr {$i + [lindex $m 1]}]
        set close [vp_match $text $open]
        if {$close < 0} {
            error "$file line $mod_line: unbalanced parentheses in the port list of '$module'"
        }
        set port_text [string range $text [expr {$open + 1}] [expr {$close - 1}]]
        set i [expr {$close + 1}]
        set rest [string range $text $i end]
    }
    if {![regexp -indices {^\s*;} $rest m]} {
        error "$file line $mod_line: could not read the header of module '$module'"
    }
    set body_start [expr {$i + [lindex $m 1] + 1}]
    if {[regexp -start $body_start -indices {\mendmodule\M} $text em]} {
        set body [string range $text $body_start [expr {[lindex $em 0] - 1}]]
    } else {
        set body [string range $text $body_start end]
    }

    # 4. Parameters
    set params {}
    if {$has_param_list} {
        set kind "parameter"
        foreach item [vp_split $param_text] {
            if {[regexp {^\s*(parameter|localparam)\M\s*(.*)$} $item -> kind item]} {}
            if {$kind eq "localparam"} continue
            lassign [vp_split_eq $item] lhs default
            if {[regexp {([A-Za-z_][A-Za-z0-9_$]*)\s*$} $lhs -> pname]} {
                lappend params [list $pname [vp_unstring $default]]
            }
        }
    } else {
        # Without #( ), body-level "parameter" declarations can be overridden
        foreach {- stmt} [regexp -all -inline {\mparameter\M([^;]*);} $body] {
            foreach item [vp_split $stmt] {
                lassign [vp_split_eq $item] lhs default
                if {[regexp {([A-Za-z_][A-Za-z0-9_$]*)\s*$} $lhs -> pname]} {
                    lappend params [list $pname [vp_unstring $default]]
                }
            }
        }
    }

    # 5. Ports
    set items [vp_split $port_text]
    set ports {}
    set ansi [regexp {\m(input|output|inout)\M} $port_text]

    if {$ansi} {
        set dir ""
        set range ""
        foreach item $items {
            set dn [vp_decl_name $item]
            if {$dn eq ""} {
                error "$file line $mod_line: could not read port declaration '$item' of '$module'"
            }
            lassign $dn decl name
            if {[regexp {^(input|output|inout)\M} $decl -> d]} {
                set dir   $d
                set range [vp_range $decl]
            } elseif {$decl ne ""} {
                # e.g. a SystemVerilog interface port "bus_if.master bus"
                set dir   $decl
                set range ""
            }
            # a bare name ("input [7:0] a, b") repeats the previous declaration
            lappend ports [list $dir $range $name]
        }
    } else {
        # Non-ANSI: the header lists names; directions are declared in the body
        set decls [dict create]
        foreach {- d stmt} [regexp -all -inline {\m(input|output|inout)\M([^;]*);} $body] {
            set range ""
            set first 1
            foreach item [vp_split $stmt] {
                set dn [vp_decl_name $item]
                if {$dn eq ""} continue
                lassign $dn decl name
                if {$first || $decl ne ""} {
                    set range [vp_range $decl]
                    set first 0
                }
                dict set decls $name [list $d $range]
            }
        }
        foreach item $items {
            if {![regexp {^[A-Za-z_][A-Za-z0-9_$]*$} $item]} {
                error "$file line $mod_line: unsupported port expression '$item' in '$module'"
            }
            if {[dict exists $decls $item]} {
                lassign [dict get $decls $item] d r
            } else {
                set d ""
                set r ""
            }
            lappend ports [list $d $r $item]
        }
    }

    return [dict create params $params ports $ports]
}
