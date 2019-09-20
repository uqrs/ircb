# DEPENDS ON: whois-sec.awk
function whois_session_show(who,who_p,expires_in){
	if (length($5) != 0)
		who_p = $5
	else 
		who_p = USER

	who = tolower(who_p)

	if (whois_Whois(who, $0, "get-session", $3) == WHOIS_IDENTIFIED) {
		expires_in = (whois_Db[who]) - sys("date +%s")
		send("PRIVMSG " $3 " :[get-session => whois-session] User '" who_p "' is identified (SESSION_ENDS=" whois_Db[who] ") (expires in: " expires_in ")")
	} else {
		return WHOIS_UNIDENTIFIED
	}
};

($2 == "PRIVMSG") && ($4 ~ /^:@S/) {
	if (whois_session_show() == WHOIS_UNIDENTIFIED) {
		next
	}
}

($2 == "PRIVMSG") && ($4 ~ /^:@E/) {
	if (whois_Whois(USER, $0, "expire-session", $3) == WHOIS_IDENTIFIED) {
		whois_expire(USER);
		send("PRIVMSG " $3 " :[expire-session => whois-session] Successfully expired '" USER "'s session.")
	} else {
		next
	}
}
