# whoisec determines whether someone has identified using services
#
# whois_Session[nickname] = expiry_epoch
#
# if an entry in whois_Session is expired or doesn't exist, start dialogue with nickserv
#
# whoisec makes use of the peculiar loopback circuit to put commands "on hold" while
# ircb waits for a WHOIS command.
#
# If a user has no valid session:
#   put IRC message in whois_Loop => call WHOIS:
#     => if WHOIS says user is identified: send whois_Loop command to loopback circuit, create session for user
#     => not identified: truncate Loopback message and display an error
BEGIN {
	# config vars
	whois_sessionlength = 300

	# global module vars
	split("", whois_Session)

	# macros
	WHOIS_IDENTIFIED = 0
	WHOIS_UNIDENTIFIED = 1
	WHOIS_VALIDSESSION = 0
	WHOIS_EXPIREDSESSION = 2
}

function whois_Whois(who,    old, i, B) {
	who = tolower(who)

	if (whois_session(who) == WHOIS_VALIDSESSION) {
		whois_Session[who] = int(sys("date +%s")) + whois_sessionlength
		return WHOIS_IDENTIFIED

	} else {
		send("WHOIS " who)

		old = $0
		split("", B)

		## 'end of whois' = 318
		## 'is identified for this nick' = 307
		do {
			getline

			if ($2 !~ /^(311|319|312|671|317|318)$/)
				B[length(B)+1] = $0

			if ($2 == "307")
				whois_Session[tolower($4)] = int(sys("date +%s")) + whois_sessionlength

			sys("sleep 1")

		} while ($2 != "318")

		$0 = old

		for (i = 1; i <= length(B); i++)
			loop(B[i])

		return whois_session(who)
	}
}

function whois_session(who) {
	if (!(who in whois_Session)) {
		return WHOIS_UNIDENTIFIED

	} else if (int(sys("date +%s")) >= whois_Session[who]) {
		delete whois_Session[who]
		return WHOIS_EXPIREDSESSION

	} else {
		return WHOIS_VALIDSESSION

	}
}

function whois_verify(who,    status) {
	who = tolower(who)

	if (who in whois_Session) {
		send("PRIVMSG " ircb_nick " :" whois_Loop[who])
		status = WHOIS_IDENTIFIED

	} else {
		status = WHOIS_UNIDENTIFIED
	}

	delete whois_Chan[who]
	delete whois_Cont[who]
	delete whois_Loop[who]
	delete whois_Extr[who]

	return status
}

function whois_expire(who) {
	delete whois_Session[tolower(who)]
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
