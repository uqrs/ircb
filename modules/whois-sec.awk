# whoisec determines whether someone has identified using services
#
# whois_Db[nickname] = expiry_epoch
#
# if an entry in whois_Db is expired or doesn't exist, start dialogue with nickserv
#
# whoisec makes use of the peculiar loopback circuit to put commands "on hold" while
# ircb waits for a WHOIS command.
#
# If a user has no valid session:
#   put IRC message in whois_Loop => call WHOIS:
#     => if WHOIS says user is identified: send whois_Loop command to loopback circuit, create session for user
#     => not identified: truncate Loopback message and display an error
BEGIN {
	# What MODE character does the server use to identify registered users?
	whoisec_mode = "r"

	# session length?
	whoisec_sessionlength = 300

	split("",whois_Db)

	# buffers for re-executing commands & recognising unidentified users
	split("",whois_Loop)
	split("",whois_Cont)
	split("",whois_Chan)
	split("",whois_Extr)

	WHOIS_IDENTIFIED = 0
	WHOIS_UNIDENTIFIED = 1
	WHOIS_RACE = 3
	WHOIS_VALIDSESSION = 0
	WHOIS_EXPIREDSESSION = 2
}

function whois_Whois(who, loop_msg, context, channel, extra_notif){
	who = tolower(who)

	if (whois_validsession(who) == WHOIS_VALIDSESSION) {
		whois_Db[who] = int(sys("date +%s")) + whoisec_sessionlength
		return WHOIS_IDENTIFIED
	} else {
		if (who in whois_Loop) {
			return WHOIS_RACE
		} else {
			# invalid/no session
			whois_Loop[who] = loop_msg
			whois_Cont[who] = context
			whois_Chan[who] = channel
			whois_Extr[who] = extra_notif

			send("WHOIS " who)

			return WHOIS_UNIDENTIFIED
		}
	}
}

function whois_validsession(who){
	if (!(who in whois_Db)) {
		return WHOIS_UNIDENTIFIED
	} else if (int(sys("date +%s")) >= whois_Db[who]) {
		delete whois_Db[who]
		return WHOIS_EXPIREDSESSION
	} else {
		return WHOIS_VALIDSESSION 
	}
}

function whois_verify(who,    status) {
	who = tolower(who)

	if (who in whois_Db) {
		send("PRIVMSG " ircb_nick " :" whois_Loop[who])
		status = WHOIS_IDENTIFIED
	} else {
		send("PRIVMSG " whois_Chan[who] " :[" whois_Cont[who] " => whois-sec] fatal: user '" $4 "' has not authenticated with services " whois_Extr[who])
		status = WHOIS_UNIDENTIFIED
	}
	delete whois_Chan[who]
	delete whois_Cont[who]
	delete whois_Loop[who]
	delete whois_Extr[who]

	return status
}

function whois_expire(who) {
	delete whois_Db[tolower(who)]
}

## expect:
## END OF WHOIS = 318 
## IS IDENTIFIED FOR NICK = 307
($2 == "307") {
	whois_Db[tolower($4)] = int(sys("date +%s")) + whoisec_sessionlength
}

# END-OF-WHOIS
($2 == "318") {
	whois_verify($4)
}

($2 == "NICK") {
	whois_expire(USER)
}
($2 == "PART") {
	whois_expire(USER)
}
($2 == "QUIT") {
	whois_expire(USER)
}
