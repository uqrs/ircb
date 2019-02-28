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
#  - awk has no notion of local variables. preface your identifies with the name of your plugin
#  - check for function conflicts with grep. you're smart,  you can figure it out
#  - comments starting with '##' indicate the presence of ircd-weirdness, where you might need to modify some code.
#  - comments starting with '###' indicate there are config variables nearby that need to be changed
#    hint: `grep -r '###' modules/`
function send(m) {print (sic_cmd m);fflush();}

BEGIN {
     ### pick sane defaults (hint: use -v)
     sic_cmd || (sic_cmd=":");
}

END{
    close(sic_in);
}