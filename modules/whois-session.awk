#
# DEPENDS ON: whois-sec.awk
#
# user session management tools.
#
function whois_Session() {
	# add other session-management tools here...
	whois_session_show()
}

function whois_session_show(		who,who_p,expires_in){
	if (length($5)>0) {who_p=$5;}
	else              {who_p=USER;}
	who=tolower(who_p)

	if ( whois_Whois(who,$0,"get-session",$3) == 0 ) {
		expires_in=((whois_Db[who]) - sys("date +%s"));
		send("PRIVMSG " $3 " :[get-session => whois-session] User '" who_p "' is identified (SESSION_ENDS=" whois_Db[who] ") (expires in: " expires_in ")");
	}
};

#
# top-level command
#
($2 == "PRIVMSG") && ($4 ~ /^:(@S|:session)/) {
	whois_Session();
}