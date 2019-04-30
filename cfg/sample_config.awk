#
# sample configuration file for ircb.
# for information on the individual variables, see their respective files.
#
BEGIN {
	#
	# essential ircb variables:
	#
	## ircb_nick="ircb";
	## ircb_user="ircb";
	## ircb_rnam="irc-bot";

	#
	# variables pertaining to:
	#   - boot.awk
	#
	## boot_Commands[1] = "JOIN #channel";
	## boot_Commands[2] = "PRIVMSG #channel :ircb v1.0 // http://github.com/uqrs/ircb

	# variables pertaining to:
	#   - tell.awk
	#
	## tell_persist="./data/tell";
	## tell_secure="yes";

	#
	# variables pertaining to:
	#   - db.awk or alt/db-ed.awk
	#   - db-interface.awk
	#
	#
	# database declarations
	#
	## db_Persist["remember"]            = "./data/db/remember-db";

	#
	# dbinterface setup
	#
	## dbinterface_Use["#channel"]       = "remember";
	## dbinterface_Authority["remember"] = "#channel";
	## dbinterface_Mask["remember"]      = "rw-rw-rw-rw-r--r--";
	##
	## dbinterface_color=1;

}
