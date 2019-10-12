# `bc` bindings
#
# FLAGS (GENERAL)
#    -s     force POSIX behaviour (GNU/bc only)
#    -l     define the standard math library
#
BEGIN {
	# for those who use GNU/bc:
	#BC_OPTS = "l,s"
	BC_OPTS = "l"

	BCOPT_MATHLIB = "l"
	BCOPT_POSIX = "s"

	bc_Msg["opt-err"] = "PRIVMSG %s :[%s] fatal: erroneous options received. [2> %s]"
	bs_Msg["opt-no-query"] = "PRIVMSG %s :[%s] fatal: must specify a valid expression."
	bc_Msg["noout"] = "PRIVMSG %s :[%s] fatal: no output (killed by watchdog?)"
	bc_Msg["output"] = "PRIVMSG %s :[%s] %s"
}


function bc_Bc(input,    Options, opts, o) {
	split("", Options)

	s = getopt_Getopt(input, BC_OPTS, Options)

	if (s == GETOPT_INVALID) {
		send(sprintf(bc_Msg["opt-err"],
		     $3, "bc => getopt", Options[0]))
		return
	}

	if (Options[STDOPT] == "") {
		send(sprintf(bc_Msg["opt-no-query"],
		     $3, "bc => getopt"))
		return
	}

	if (BCOPT_MATHLIB in Options)
		opts = opts " -l"
	if (BCOPT_POSIX in Options)
		opts = opts " -s"

	o = sh(sprintf("bc %s <<<'scale=20; %s' 2>&1 & %s",
		opts, san(Options[STDOPT]), watchdog(1)))

	if (o == "") {
		send(sprintf(bc_Msg["noout"],
		     $3, "bc => expr"))
	} else {
		send(sprintf(bc_Msg["output"],
		     $3, "bc => expr", o))
	}
}

($2 == "PRIVMSG") && ($4 ~ /^::bc$/) {
	bc_Bc(cut($0, 5))
}
