#
# execute on a successful join (end of MOTD)
#
BEGIN {
### uncomment and modify as needed
#   mboot__Cmd[0]="JOIN #mychannel";
#   mboot__Cmd[1]="PRIVMSG #mychannel :ircb v1.0";
}

## some ircds may not use end-of-motd, who knows. modify if necessary.
$5 == "376" {
    for (mboot_line in mboot_Cmd) {send(mboot_Cmd[mboot_line]);};
    delete mboot_Cmd;
}