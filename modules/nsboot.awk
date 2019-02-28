#
# execute on a successful join (nickserv acknowledge)
#
BEGIN {
### set your nickserv password
    nsboot_authcmd="PRIVMSG nickserv :identify NSPASSWORD_HERE"
### uncomment and modify as needed
    nsboot_cmd[0]="JOIN #mychannel";
    nsboot_cmd[1]="PRIVMSG #mychannel :ircb v1.0";
}

## some ircds may not use end-of-motd, who knows. modify if necessary.
$5 == "376" {
    send(nsboot_authcmd);
}

(tolower($1) == "nickserv") && (tolower($0) ~ /password accepted/) {
  for (boot in nsboot_cmd) {send(nsboot_cmd[boot]);};
    delete nsboot_cmd;
}

