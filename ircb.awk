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
function send (mesg)                      {print (mesg "\r\n");fflush();}                                       # send message
function sys  (call,     	out)      {call | getline out;close(call);return out;}                          # system call wrapper
function lsys (call,Out,	out)      {while ((call | getline out)>0){Out[length(Out)+1]=out};close(call);} # system call wrapper but it does multiple lines
function array(Arr)                       {split("",Arr);}                                                      # create new array
function san  (string,  	 out)     {out=string;gsub(/'/,"'\\''",out);return out} #"                      # sanitise string for use in system calls
function rsan (string,           out)     {out=string;gsub(/[\$\^\\\.\[\]\{\}\*\?\+]/,"\\\\&",out);return out}
#
# function: retrieve fields x to y
#
function cut (string,begin,end,        out,Arr) {
    split(string,Arr);
    (end != 0) || (end=length(Arr));

    for (begin;begin<=end;begin++){
        out=(out Arr[begin] FS);
    };

    return out;
}
#
# function: same as `cut` but accept an already-split array.
#
function acut(Arr,begin,end,		out) {
    (end != 0) || (end=length(Arr));

    for (begin;begin<=end;begin++){
        out=(out Arr[begin] FS);
    };

    return out;
}

#
# variables needed to connect to irc
#
BEGIN {
    ircb_nick="ircb";
    ircb_user="ircb";
    ircb_rnam="irc-bot";

    send("NICK " ircb_nick);
    send("USER " ircb_user " * 0 :" ircb_rnam);
}

#
# destroy all ^Fs and ^J's.
#
{gsub(/[\r\n]+/,"")};

#
# store the recipient in a different, globally-accessible variable
#
{match($1,/^:([^!]+)!/);USER=substr($1,2,RLENGTH-2);}

#
# respond to pings normally
#
$1 == "PING" {
    send("PONG " substr($2,2));
}

#
# if a user is DMing us, spoof the channel form our own nick to the users' nick
#
($3 == ircb_nick) && ($2 == "PRIVMSG") {
    $3=USER;
}

#
# create a loopback circuit: anything ircb sends to itself
#
(USER == ircb_nick) && ($2 == "PRIVMSG") {
	$0=substr(cut($0,4),2);
	# recalculate the USER variable
	match($1,/^:([^!]+)!/);
	USER=substr($1,2,RLENGTH-2);
}
#
# handle us changing our own nick
#
(USER == ircb_nick) && ($2 == "NICK") {
	ircb_nick=substr($3,2);
}
