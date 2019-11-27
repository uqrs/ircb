# modules/boot.awk
# will attempt to authenticate with nickserv using `cfg/boot_nspass` as password.
# will send each line in `boot_Commands` to the server after authentication success/failure
#
BEGIN {
	split("", boot_Commands)

	#boot_Commands[1]="JOIN #channel"
	#boot_Commands[2]="PRIVMSG #channel :ircb v1.0 // http://github.com/uqrs"

	boot_passfile = "cfg/boot_nspass"

	BOOT_SUCCESS = 0
	BOOT_NOPASSFILE = 1
}
# if cfg/boot_nspass exists, authenticate with nickserv on joining
function boot_Nickserv (    pass){
    if ((getline pass < boot_passfile)>0) {
        ## modify nickserv authentication command if needed.
        send("PRIVMSG nickserv :identify " pass)
	close(boot_passfile)
	return BOOT_SUCCESS
    }

    # `cfg/boot_nspass` does not exist
    return BOOT_NOPASSFILE
}

function boot_Send(){
    for (i = 1; i <= length(boot_Commands); i++)
        send(boot_Commands[i])
}

## some ircds may not use 376 as end-of-motd
($2 == "376") || ($2 == "422") {
	if (boot_Nickserv() == BOOT_NOPASSFILE)
		boot_Send()
}
## some nickserv instances may send a different response
(tolower(USER) == "nickserv") && (tolower($0) ~ /password accepted/) {
	boot_Send()
}

