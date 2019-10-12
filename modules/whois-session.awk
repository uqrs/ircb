# DEPENDS ON: whois-sec.awk
function whois_session_show(    who, expires_in) {
	if (length($5) != 0)
		who = tolower($5)
	else
		who = tolower(USER)

	if (whois_Whois(who) == WHOIS_IDENTIFIED) {
		expires_in = (whois_Session[who]) - sh("date +%s")

		send(sprintf("PRIVMSG %s :[get-session => whois-session] User '%s' is identified (SESSION_ENDS=%d) (expires in: %s)",
			$3, who, whois_Session[who], expires_in))

	} else {
		send(sprintf("PRIVMSG %s :[whois-session => session-show] fatal: user '%s' has not authenticated with services.",
		     $3, who))
	}
}

($2 == "PRIVMSG") && ($4 ~ /^:@S/) {
	whois_session_show()
}

($2 == "PRIVMSG") && ($4 ~ /^:@E/) {
	if (whois_Whois(USER) == WHOIS_IDENTIFIED) {
		whois_expire(USER)
		send(sprintf("PRIVMSG %s :[whois-session => session-expire] Successfully expired '%s's session.",
		     $3, USER))
	} else {
		send(sprintf("PRIVMSG %s :[whois-session => session-expire] fatal: user '%s' has not authenticated with services.",
		     $3, USER))
	}
}
