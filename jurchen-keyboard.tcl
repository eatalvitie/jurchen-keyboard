#!/usr/bin/wish -f

wm title . "\u5973\u771F\u8A9E\u865B\u64EC\u9375\u76E4"

# Input code currently being processed, before conversion
set waiting ""

# Distance between end of waiting input and cursor on screen
# for moving within and changing waiting input before conversion
# -1 ... no waiting input
#  0 ... cursor after [string index $waiting end]
# positive integers ... cursor after [string index $waiting end-$cursordiff]
set cursordiff -1

# Suggested conversions, start blank
set previous {};   # previous suggestions, accessible through PgUp
set current {};    # current suggestions on display
set next {};       # next suggestions, accessible through PgDn

# Display settings
set max 5;         # number of suggested conversions shown at once
set none "\u2001";      # blank button (U+2001)

# Functionality
## write a stroke or component
proc insert char {
	global waiting cursordiff
	if {$cursordiff == -1} {set cursordiff 0}
	set waiting [string insert $waiting end-$cursordiff $char]
	.input.entry insert insert $char
	distribute [suggest $waiting]
	display
}

# find all characters whose input code starts with $pattern
# ordered manually in the conversion table
# (for shortest codes first need to sort data file)
proc suggest pattern {
	#if {$pattern eq ""} { return {} }
	# suggest never called with $pattern eq "".
	# however, if it were, finding all characters in data file
	# (this line commented) would arguably be correct
	global data
	return [lsearch -all -inline $data $pattern*]
}
proc distribute suggestions {
	global previous current next max
	if {$suggestions eq ""} {
		set previous ""
		set current ""
		set next ""
	} else {
		set previous ""
		set current [lrange $suggestions 0 [expr {$max-1}]]
		set next [lrange $suggestions $max end]
	}
}

## clear displayed suggestions
proc clear-display {} {
	global max none
	for {set i 0} {$i < $max} {incr i} {
		.choices.$i configure -text $none
		.choices.{$i}remaining configure -text ""
	}
}

# display suggested conversions and the remainder of their input codes
proc display {} {
	clear-display
	global max waiting previous current next
	for {set i 0} {$i < $max} {incr i} {
		set s [lindex $current $i]
		if {$s eq ""} { break } ;# end of suggestions reached
		.choices.$i configure -text [char-of $s]
		set remain [string range [code-of $s] [string length $waiting] end]
		if {$remain eq ""} {
			.choices.{$i}remaining configure -text \
				[expr {$i == 0 ? "<Space>" : [expr {$i+1}]}]
		} else {
			.choices.{$i}remaining configure -text [string range $remain 0 2]
		}
	}
	if {$previous eq ""} {
		.choices.left configure -state disabled
	} else {
		.choices.left configure -state normal
	}	
	if {$next eq ""} {
		.choices.right configure -state disabled
	} else {
		.choices.right configure -state normal
	}
}

# display next/previous available conversions
proc display-next count {
	global previous current next
	if {$next eq ""} { bell; return }
	set previous [concat $previous [lrange $current 0 [expr {$count-1}]]]
	set current [concat \
		[lrange $current $count end] \
		[lrange $next 0 [expr {$count-1}]]]
	set next [lrange $next $count end]
	display
}
proc display-previous count {
	global previous current next max
	if {$previous eq ""} { bell; return }
	# first page of suggestions should always be full
	# even if mixing moves of different size (arrow, pgup/dn)
	if {[llength $previous] < $max} {
		distribute [list {*}$previous {*}$current {*}$next]
	} else {
		set next [concat [lrange $current [expr {$max-$count}] end] $next]
		set current [concat \
			[lrange $previous end-[expr {$count-1}] end] \
			[lrange $current 0 [expr {$max-$count-1}]]]
		set previous [lrange $previous 0 end-$count]
	}
	display
}

# convert waiting cangjie input into the selected character
proc commit char {
	global waiting cursordiff
	# replace all of waiting input regardless of cursor position
	.input.entry delete [expr \
		{[.input.entry index insert] - [string length $waiting]+$cursordiff}] \
		[expr {[.input.entry index insert]+$cursordiff}]
	.input.entry insert insert $char
	set waiting {}
	set cursordiff -1
	distribute {}
	display
}

# commit numbered choice on display
# refuse to commit empty choice
proc commit-choice number {
	global current
	set c [char-of [lindex $current $number]]
	if {$c eq ""} { bell } else { commit $c }
}

# commit leftmost choice by default
proc commit-default {} {
	commit-choice 0
	return -code break
}

# delete waiting input, cancelling conversion
proc delete-waiting {} { commit "" }

# move cursor inside waiting input
# refuse to leave waiting input before commit
proc move-left {} {
	global waiting cursordiff
	if {$cursordiff == [string length $waiting]} { bell; return -code break }
	incr cursordiff
}
proc move-right {} {
	global cursordiff
	if {$cursordiff == 0} { bell; return -code break }
	incr cursordiff -1
}

# delete character before or after cursor in waiting input
# refuse to delete already committed input
# TODO: deleting an alphabetic character trims from $waiting
proc delete-before-cursor {} {
	global waiting cursordiff
	if {$cursordiff == [string length $waiting]} {
		bell
		return -code break
	} else {
		set waiting [string replace $waiting end-$cursordiff end-$cursordiff ""]
		distribute [suggest $waiting]
		display
	}
}
proc delete-after-cursor {} {
	global waiting cursordiff
	if {$cursordiff == 0} {
		bell
		return -code break
	} else {
		incr cursordiff -1
		set waiting [string replace $waiting end-$cursordiff end-$cursordiff ""]
		distribute [suggest $waiting]
		display
	}
}


# Keys for Jurchen cangjie keyboard with QWERTY mappings
set keys [list s "\uE5CD" d "\uE5DF" f "\uE0FB" j "\uE457" k "\uE348" l "\uE2FB"]

# Graphical interface
## font settings
font create tiny -family MenksoftJurchen -size 10
font create normal -family MenksoftJurchen -size 20
font create large -family MenksoftJurchen -size 40
#font create tiny -family {CCAMC Khitan & Jurchen Std} -size 10
#font create normal -family {CCAMC Khitan & Jurchen Std} -size 20
#font create large -family {CCAMC Khitan & Jurchen Std} -size 40

## input bar
grid [frame .input -borderwidth 10] -column 0 -row 0
grid [label .input.label -text "\u5165\u529B"]
grid [entry .input.entry -width 25 -relief sunken -background #ffffff \
	-font normal -textvariable entry] -column 1 -row 0 -columnspan 4 -padx 10

## buttons for suggested conversions
grid [frame .choices -borderwidth 10] -column 0 -row 1 -rowspan 2
grid [button .choices.left -height 2 -padx 2 \
	-state disabled -text "\u25C0" -command {display-previous 1}] \
	-column 0 -row 1
for {set i 0} {$i < $max} {incr i} {
	grid [button .choices.$i -font large \
		-text $none -command "commit-choice $i"] \
		-column [expr {$i+1}] -row 1
	grid [label .choices.{$i}remaining -font tiny \
		-text ""] -column [expr {$i+1}] -row 2
	if {$i == 9} {
		bind .input.entry <Key-0> {commit-choice 9; break}
		break
	} else {	
		bind .input.entry <Key-[expr {$i+1}]> "commit-choice $i; break"
	}
}
grid [button .choices.right -height 2 -padx 2 \
	-state disabled -text "\u25B6" -command {display-next 1}] \
	-column 11 -row 1

## keyboard
grid [labelframe .kbd -borderwidth 8 -text "\u9375\u76E4"] -row 3 -pady 5
set row 3
set column 0
foreach {key value} $keys {
	#if {$key == "a" || $key == "z"} { incr row; set column 0 }
	grid [button .kbd.$key -font normal -text $value \
		-command "insert $value"] -column $column -row $row
	bind .input.entry <$key> "insert $value; break"
	incr column
}

bind .input.entry <Key-space> {if {$waiting ne ""} { commit-default }}
bind .input.entry <Return>    {if {$waiting ne ""} { commit-default }}
bind .input.entry <KP_Enter>  {if {$waiting ne ""} { commit-default }}
bind .input.entry <Kanji>     {if {$waiting ne ""} { commit-default }}
bind .input.entry <Escape>    {if {$waiting ne ""} { delete-waiting }}
bind .input.entry <Left>      {if {$waiting ne ""} { move-left }}
bind .input.entry <Right>     {if {$waiting ne ""} { move-right }}
bind .input.entry <BackSpace> {if {$waiting ne ""} { delete-before-cursor }}
bind .input.entry <Delete>    {if {$waiting ne ""} { delete-after-cursor }}
bind .input.entry <Next>      {if {$waiting ne ""} { display-next $max }}
bind .input.entry <Prior>     {if {$waiting ne ""} { display-previous $max }}

focus .input.entry

### debug
#grid [frame .debug] -row 4
#grid [label .debug.cd -font tiny -text {$cursordiff:}] -row 4 -column 1
#grid [label .debug.cursordiff -font tiny \
#	-textvariable cursordiff] -column 2 -row 4
#grid [label .debug.wai -font tiny -text {$waiting:}] -row 4 -column 3
#grid [label .debug.waiting -font tiny \
#	-textvariable waiting] -column 4 -row 4
#grid [label .debug.ne -font tiny -text {$next:}] -row 5 -column 1
#grid [label .debug.next -font tiny \
#	-textvariable next] -column 2 -row 5
#grid [label .debug.cur -font tiny -text {$current:}] -row 6 -column 1
#grid [label .debug.current -font tiny \
#	-textvariable current] -column 2 -row 6
#grid [label .debug.pr -font tiny -text {$previous:}] -row 7 -column 1
#grid [label .debug.previous -font tiny \
#	-textvariable previous] -column 2 -row 7

# Utility functions

## insert substring $ins into string after index $pos
proc strinsert {str pos ins} {
	if {$pos eq "end-[string length $str]"} {
		return $ins$str
	} else {
		string replace $str $pos $pos [string index $str $pos]$ins
	}
}
namespace ensemble configure ::string -map \
	[dict merge [namespace ensemble configure string -map] {insert strinsert}]

## split conversion rules of the format code:char
proc code-of conversion { lindex [split $conversion :] 0 }
proc char-of conversion { lindex [split $conversion :] 1 }


# Start
## Load cangjie mappings from file
set f [open {jurchen}]
fconfigure $f -encoding utf-8
while {[gets $f line] > -1} {
	if {[regexp {(\S+)\s+(\S+)} $line -> code char]} {
		lappend data $code:$char
	}
}
close $f

clear-display

# TODO: clear (^bksp, ^del), select all (^a), undo, cursor
# try text instead of entry
# check if all chars in Menk in data file
# other fonts
# components
