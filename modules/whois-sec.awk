#
# whoisec is used to identify registered users by WHOIS-ing them and receiving their MODE.
# use ONLY to identify users for commands(!)
#
BEGIN {
	# What MODE character does the server use to identify registered users?
	whoisec_mode="r";

	# Default session length?
	whoisec_sessionlength=300;

	# whois database for caching
	array(whois_Db);

	# buffers for re-executing commands & recognising unidentified users
	array(whois_Call);
	array(whois_Cont);
	array(whois_Envi);
	array(whois_Extr);
}

#
# top-level function; "is the user identified?"
# needs: username (USER), command ($0), context (module name), environment (channel) and extra (extra info);
#
function whois_Whois(who,command,context,environment,extra){
	# we identify users case-insensitively
	who=tolower(who);

	# if the user is indeed identified for this nickname
	if ( whois_validsession(who) == 0 ) {
		whois_Db[who]=int(sys("date +%s"))+whoisec_sessionlength;
		# return a '0' to show that the user is identified.
		return 0;
	} else {
		if ( who in whois_Call ) {
			# race condition triggered; ignore new command.
			return 1;
		}
		# this user is not identified.
		# cache their command into whois_Re and whois_Un;
		whois_Call[who]=command;
		whois_Cont[who]=context;
		whois_Envi[who]=environment;
		whois_Extr[who]=extra;

		# execute WHOIS command:
		send("WHOIS " who);

		return 1;
	}
}

#
# verify if the user session is still valid
#
function whois_validsession(who){
	if ((who in whois_Db) == 0) {
		# user is not identified
		return 1;
	} else if ( int(sys("date +%s")) >= (whois_Db[who])  ) {
		delete whois_Db[who];
		# user's session has expired
		return 2;
	} else {
		# user is identified
		return 0;
	}
}
#
# request WHOIS info from the user and cache this
#
function whois_getwhois(who){
	send("WHOIS " who);
}

function whois_verify(who) {
	who=tolower(who);

	if (who in whois_Db) {
		# the user is identified. re-execute their command.
		send("PRIVMSG " ircb_nick " :" whois_Call[who]);
	} else {
		# the user wasn't identified. send a 'sorry bruv' message
		send("PRIVMSG " whois_Envi[who] " :[" whois_Cont[who] " => whois-sec] fatal: user '" $4 "' has not authenticated with services " whois_Extr[who]);
	}
	delete whois_Envi[who];
	delete whois_Cont[who];
	delete whois_Call[who];
	delete whois_Extr[who];
}

#
# immediately  expire a users' session.
#
function whois_expire(who) {
	delete whois_Db[tolower(who)];
}

#
# catch "whois" response that shows the user is identified.
## you may need to modify this entire block; your ircd may not use `307` to show that a user was identified.
## you may even need to completely modify this script to use MODE instead of WHOIS.
## expecting: END OF WHOIS = 318; IS IDENTIFIED FOR NICK = 307
## MODIFY THESE OR WRITE A DIFFERENT IMPLEMENTATION(!)
#
($2 == "307") {
	# the user who is identified is stored in `$4`	
	# given the fact that a user has just been identified; we're renewing their session
	whois_Db[tolower($4)]=(int(sys("date +%s")) + whoisec_sessionlength);
}

# 
# end of whois; moment of truth: are they identified or not?
#
($2 == "318") {
	whois_verify($4);
}

#
# automatically expire a user's session when:
#   - they change nicks
#   - they leave a channel
#   - they quit from irc
#
($2 == "NICK") {whois_expire(USER);}
($2 == "PART") {whois_expire(USER);}
($2 == "QUIT") {whois_expire(USER);}
