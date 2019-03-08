#
# ircb.awk
#
# non-overengineered irc bot. accepts messages from stdin.
#
# made to work with sic (https://tools.suckless.org/sic/)
#
# individual irc "modules" can be included with -f
#
# if you set a different command prefix for sic change `sic_cmd`
# the buffering is a tad shaky; run sic with unbuffered input stream.
#
# sample invocation:
#   stdbuf --input=0 ./sic -sic_args < irc/in | gawk -f ircb.awk -f modules/my_module.awk > irc/in
# sample invocation (+logging):
#   stdbuf --input=0 ./sic -sic_args < irc/in | tee /dev/stderr 2> irc/log | gawk -f ircb.awk -f modules/nsboot.awk > irc/in
#
# put either of these into a bootstrap .sh file, whatever floats your boat. 
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
# A: sed -Ei 's_^\$6\s*~\s*/\^._\$6 ~ /^!' modules/*
#
# hints for module writers:
# - is message? `$1 ~ /^#/`
# - $1 = channel; $2 = colon; $3 = date; $4 = time; $5 = sender; $6 - $NF = message;
# - $5's braces are removed. see below.
function send(fsend_mesg)        {print (msic_cmd fsend_mesg);fflush();}
function sys (fsys_call)         {fsys_call | getline fsys_out;close(fsys_call);return fsys_out;}
function lsys(fsys_call,fsys_Out){while ((fsys_call | getline fsys_out)>0){fsys_Out[length(fsys_Out)+1]=fsys_out}close(fsys_call);}
function arr (farr_arr)          {split("",farr_arr);}
function san (fsan_string)       {fsan_out=fsan_string;gsub(/'/,"'\\''",fsan_out);return fsan_out} #"

BEGIN{
     ### pick sane defaults (hint: use -v)
     msic_cmd || (msic_cmd=":");
}

#
# hack to get rid of those braces sic outputs
#
$1 ~ /^#/ {gsub(/[<>]/,"",$5);};

END{}