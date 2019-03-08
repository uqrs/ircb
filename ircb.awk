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
#  - awk has no notion of local variables. variable format is: [fm][name]_[varname] (fsys_call for function 'sys'. mtell_persist for module 'tell')
#    the [varname] must begin with a capital letter if it's an array.
#  - check for function conflicts with grep. you're smart,  you can figure it out
#  - comments starting with '##' indicate the presence of ircd-weirdness, where you might need to modify some code.
#  - comments starting with '###' indicate there are config variables nearby that need to be changed
#    hint: `grep -r '###' modules/`
#
# faq:
# Q: "i want to change the command prefixes for my modules (from ":" to "!")
# A: sed -Ei 's_^\$4\s*~\s*/\^:._\$4 ~ /^:' modules/*
function send(fsend_mesg)                     {print (fsend_mesg "\r\n");fflush();}
function sys (fsys_call)                      {fsys_call | getline fsys_out;close(fsys_call);return fsys_out;}
function lsys(fsys_call,fsys_Out)             {while ((fsys_call | getline fsys_out)>0){fsys_Out[length(fsys_Out)+1]=fsys_out}close(fsys_call);}
function arr (farr_arr)                       {split("",farr_arr);}
function san (fsan_string)                    {fsan_out=fsan_string;gsub(/'/,"'\\''",fsan_out);return fsan_out} #"
function cut (fcut_str,fcut_fields,fcut_delim){fcut_delim || (fcut_delim=" ");return sys(sprintf("cut -f '%s' -d '%s' <<< '%s'",san(fcut_fields),san(fcut_delim),san(fcut_str)))}
function user(fuser_str)                      {fuser_str || (fuser_str=$0);match(fuser_str,/^:([^!]+)!/);return substr(fuser_str,2,RLENGTH-2);}

BEGIN {
    ircb_nick="ircb";
    ircb_user="ircb";
    ircb_rnam="irc-bot";

    send("NICK " ircb_nick);
    send("USER " ircb_user " * 0 :" ircb_rnam);
}

#
# destroy all ctrl+f's or ctrl+m's.
#
{gsub(/[\r\n]+/,"")};

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
    $3=user();
}

