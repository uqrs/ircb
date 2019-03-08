#
# execute on a successful join (nickserv acknowledge)
#
BEGIN {
### set your nickserv password
#   mnsboot_authcmd="PRIVMSG nickserv :identify my_password"
### uncomment and modify as needed
#   mnsboot_Cmd[0]="JOIN #mychannel";
#   mnsboot_Cmd[1]="PRIVMSG #mychannel :ircb v1.0 // http://github.com/uqrs/ircb";
}

## some ircds may not use end-of-motd, who knows. modify if necessary.
$2 == "376" {
    send(mnsboot_authcmd);
}

## change to suit your network's nickserv behaviour
($1 ~ /^:NickServ!/) && (tolower($0) ~ /password accepted/) {
    for (mnsboot_line in mnsboot_Cmd) {send(mnsboot_Cmd[mnsboot_line]);};
    delete mnsboot_Cmd;
}

