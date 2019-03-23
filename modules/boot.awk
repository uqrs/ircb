#
# attempt to:
#   - authenticate to nickserv using an authentication command in cfg/boot_nspass
#   - execute each individual command found in cfg/boot_cmd after nickserv gives an acknowledge
#

#
# if cfg/boot_nspass exists, authenticate with nickserv on joining
#
function boot_nickserv(		pass,success){
    success=0;
    if ((getline pass < "cfg/boot_nspass")>0) {
        ## modify nickserv authentication command if needed.
        send("PRIVMSG nickserv :identify " pass);
        success=1;
    }; close("cfg/boot_nspass");

    return success;
}

#
# execute list of commands found in cfg/boot_commands
#
function boot_commands(		command){
    while ((getline command < "cfg/boot_commands")>0) { 
        send(command);
    }; close("cfg/boot_commands");
}

## some ircds may not use end-of-motd, who knows. modify if necessary.
($2 == "376")                                               {boot_nickserv() || boot_commands()}

## some nickserv instances may use a different string; modify if necessary.
($1 ~ /^:NickServ!/) && (tolower($0) ~ /password accepted/) {boot_commands()}

