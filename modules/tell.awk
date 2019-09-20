# memoserv clone for networks that dont have memoserv
# OPTIONALLY requires whois-sec.awk
BEGIN {
	tell_persist = "./data/tell"
	# messages are stored in this file using:
	#   [recipient] [sender] [date] [message]\n

	# use whois-sec to identify recipients and senders?
	tell_secure = "yes"

	# cache the amount of tells someone has stored
	#   tell_Cache[user] = number
	split("", tell_Cache)

	tell_initcache()
}

function tell_cache(user) {
	tell_Cache[user] = sys(sprintf("awk '$1 == \"%s\"' < '%s' | wc -l", user, tell_persist))
}

function tell_initcache(    user, Output) {
	split("", Output)

	lsys(sprintf("cut -d ' ' -f 1 <'%s' | sort | uniq",
	     san(tell_persist)), Output)

	for (user in Output)
		tell_cache(Output[user])
}

function tell_clearcache(user) {
	delete tell_Cache[user]
}

function tell_Add(    message){
	message = cut($0, 6)

	printf("%s %s %s %s\n", $5, USER, sys("date +%s"), message) >> tell_persist
	close(tell_persist)

	send(sprintf("PRIVMSG %s :[tell][%s => %s][@%s] Message of length (%s) queued successfully",
		$3, USER, $5, sys("date +%s"), length(message)))

	tell_cache($5)
}

function tell_Sendall(		tell, Tells, Parts, ys, ds, hs, ms, ss){
	tell_clearcache(USER)
	split("",Tells)

	lsys(sprintf( \
	     "sed -Ei '/^%s /I { w /dev/stdout\nd }' '%s'", USER, tell_persist), Tells)

	if (Tells[1] == "")
		return

	for (tell in Tells) {
		split(Tells[tell], Parts, " ")

		# yeah uhhh fuck me
		ss=(int(sys("date +%s") - int(Parts[3])))
		ys=(ss-(ss%31557600))/31557600
		ss=(ss-(ys*31557600))
		ds=(ss-((ss%31557600)%86400))/86400
		ss=(ss-(ds*86400))
		hs=(ss-(((ss%31557600)%86400)%3600))/3600
		ss=(ss-(hs*3600))
		ms=(ss-((((ss%31557600)%86400)%3600)%60))/60

		send(sprintf("PRIVMSG %s :[%s => %s][%4dy %3dd %2dh %2dm ago] %s",
			Parts[1], Parts[2], Parts[1], ys, ds, hs, ms, acut(Parts, 4)))
	}
}

($2 == "PRIVMSG") && ($4 ~ /^::(t|tell)$/) {
	if (length($6) == 0) {
		send("PRIVMSG " $3 " :[tell] Usage: tell [recipient] [message]")
	} else if (tell_secure == "yes") {
		if (whois_Whois(USER, $0, "tell => send", $3, "(tell_secure=yes)") == WHOIS_IDENTIFIED) {
			tell_Add()
		} else {
			next
		}
	} else {
		tell_Add()
	}
}

($2 == "PRIVMSG") && ($4 ~ /^::(showtells)$/) {
	if (tell_secure == "yes") {
		if (whois_Whois(USER,$0,"tell => get",$3,"(tell_secure=yes)") == WHOIS_IDENTIFIED) {
			tell_Sendall()
		} else {
			next	
		}
	} else {
		tell_Sendall()
	}
}

($2 == "PRIVMSG") && (USER in tell_Cache) {
	send(sprintf("PRIVMSG %s :[tell] You have %d messages in your inbox.",
	     USER, tell_Cache[USER]))

	tell_clearcache(USER)
}

END {
	close(tell_persist)
}
