#
# attempt to:
#   - authenticate to nickserv using an authentication command in cfg/boot_nspass
#   - execute each individual command found in `boot_Commands` after nickserv gives an acknowledge
#
BEGIN {
	#
	# fill this array with commands to be sent on-join.
	#
	array(boot_Commands);

	#boot_Commands[1]="JOIN #channel";
	#boot_Commands[2]="PRIVMSG #channel :ircb v1.0 // http://github.com/uqrs"
}
#
# if cfg/boot_nspass exists, authenticate with nickserv on joining
#
# returns: `1` on missing boot_nspass file.
#          `0` on no error.
#
#
function boot_Nickserv(		pass,success){
    if ((getline pass < "cfg/boot_nspass")>0) {
        ## modify nickserv authentication command if needed.
        send("PRIVMSG nickserv :identify " pass);
	close("cfg/boot_nspass");
	return 0;
    };

    return 1;
}

#
# execute list all commands. 
#
function boot_Sendcommands(){
	for ( i=1 ; i<=length(boot_Commands) ; i++ ) {
		send(boot_Commands[i]);
	}
}

## some ircds may not use end-of-motd, who knows. modify if necessary.
($2 == "376")                                               {(!boot_Nickserv()) || boot_Sendcommands()}
## some nickserv instances may use a different string; modify if necessary.
($1 ~ /^:NickServ!/) && (tolower($0) ~ /password accepted/) {boot_Sendcommands()}

