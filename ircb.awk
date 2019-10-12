#
# ircb.awk
#
# non-overengineered irc bot. accepts irc messages from stdin
#
# individual irc "modules" can be included with -f
#
# sample invocation:
#   netcat my.network.net 6667 < irc/in | awk -f ircb.awk -f modules/my_module.awk> irc/in
#
# hints:
#  - irc logger: /bin/tee
#
# rules:
#  - for local variables, functions must be used. local variables must be
#    declared by introducing a two-tab gap inbetween intended arguments and the
#    local variables. the variable's name must begin with a capital letter if 
#    it's an array.
#
#  - global variables for use by modules must be preceded with the module's
#    name (e.g. `boot_commands` for the `boot.awk` module)
#  - a distinction is made between 'top-level functions' and 'normal functions'
#     * top-level functions are capitalised, and are called by a regular awk
#       statement (e.g. `boot_Nickserv`)
#  - check for function conflicts with grep. you're smart,  you can figure it out
#  - comments starting with '##' indicate the presence of ircd-weirdness, 
#    where you might need to modify some code.
#  - comments starting with '###' indicate there are config variables nearby
#    that need to be changed
#     * hint: `grep -r '###' modules/`
#  - no gnuisms (call me out on github if i put any in)
#
# for user-facing IRC output, use the following grammar:
#	[CONTEXT] WHAT: MESSAGE [ADDITIONS]
#
#	CONTEXT is a description of the general stack of calls performed.
#	        e.g. say the `db` module is making a `sync` operation, CONTEXT would 
#               indicate: [db => sync]. these may chain infinitely, so if `sync`
#               is calling `whois-sec`, CONTEXT would indicate
#               [db => sync => whois-sec], etc.
#
#	WHAT is an optional, short description of the operations' status.
#            is may, for example, say `warn`, `fatal`, `success`, etc.
#
#       MESSAGE is the meat of the information for the user. go wild.
#
#       ADDITIONS is extra information.
#                 QUOTING SHELL OUTPUT: `[2> this is stderr stuff]`
#                 INDICATING IRCB BEHAVIOUR: `(some_option=yes/no)`
#
# this grammar needn't be adhered to strictly, but it provides a good starting
# point for cohesiveness between modules.
#
# faq:
# Q: "i want to change the command prefixes for my modules (from ":" to "!")
# A: sed -Ei 's_^\$4\s*~\s*/\^:._\$4 ~ /^:' modules/*
#
# for help and support with irc, read: https://tools.ietf.org/html/rfc2812
# for help and support with awk, read: awk(1)
BEGIN {
    # useful constants for sys() and lsys()
    SH_WATCHDOG = "(PID=$!; sleep %d; kill \"$PID\" &>/dev/null) &"

    # TODO: hacky, configuration is not respected.
    ircb_nick = "ircb"
    ircb_user = "ircb"
    ircb_realname = "irc-bot"

    send("NICK " ircb_nick)
    send("USER " ircb_user " * 0 :" ircb_realname)
}


function send(msg) {
	print (msg "\r\n")
	fflush()
}

function sh(syscall,    stdout) {
	syscall | getline stdout
	close(syscall)
	return stdout
}

function lsh(syscall, Lines,    stdout) {
	while ((syscall | getline stdout) > 0) {
		Lines[length(Lines)+1] = stdout
	}
	close(syscall)
	return Lines[1]
}

function watchdog(s) {
	return sprintf(SH_WATCHDOG, s)
}

# sanitise shell strings
function san(string) {
	gsub(/'/, "'\\''", string)
	return string
}

# sanitise regular expressions
function rsan(string) {
	gsub(/[\$\^\\\.\[\]\{\}\*\?\+]/, "\\\\&", string)
	return string
}

# assemble a substring from fields `begin` to `end`
function cut(string, begin, end, delim, out_delim,    subs, Array) {
    if (delim == "")
	    delim = FS
    if (out_delim == "")
	    out_delim = delim

    split(string, Array, delim)
    if (!end)
	    end = length(Array)

    for (begin; begin <= end; begin++) {
        subs = (subs Array[begin] out_delim)
    }

    return subs
}

# assemble substring from fields `begin` to `end` using array `Array`
function acut(Array, begin, end, out_delim,    subs) {
    if (!end)
	    end = length(Array)
    if (out_delim == "")
	    out_delim = FS

    for (begin; begin <= end; begin++){
        subs = (subs Array[begin] out_delim)
    }

    return subs
}

function loop(m) {
	send(sprintf("PRIVMSG %s :%s",
	     ircb_nick, m))
}

{
    gsub(/[\r\n]+/, "")
}

($1 == "PING") {
    send("PONG " substr($2, 2))
}

# USER is nick of the user who sent the command, if appliccable.
{
    match($1, /^:([^!]+)!/)
    USER = substr($1, 2, RLENGTH-2)
}


# for private correspondence, $3 will be changed from our own nick to the sender's nick
($3 == ircb_nick) && ($2 == "PRIVMSG") {
    $3 = USER
}

# PRIVMSG's received by ourselves are re-interpreted as commands.
(USER == ircb_nick) && ($2 == "PRIVMSG") {
	$0 = substr(cut($0, 4), 2)

	match($1, /^:([^!]+)!/)
	USER = substr($1, 2, RLENGTH-2)
}

# update after self-nick changes
(USER == ircb_nick) && ($2 == "NICK") {
	ircb_nick = substr($3, 2)
}
