#
# execute on a successful join (end of MOTD)
#
BEGIN {
### uncomment and modify as needed
    boot_cmd[0]="JOIN #mychannel";
    boot_cmd[1]="PRIVMSG #mychannel :ircb v1.0";
}

## some ircds may not use end-of-motd, who knows. modify if necessary.
$5 == "376" {
    for (boot in boot_cmd) {send(boot_cmd[boot]);};
    delete boot_cmd;
}