#
# the database interfacer provides a handful of higher-level functions.
# these functions accept more advanced query/update interfacing, and return singular strings for use in user-facing output.
# REQUIRES either db.awk or alt/db-ed.awk
#
# Database contents are stored as:
# [label]\x1E[perms]\x1E[owner]\x1E[edited_by]\x1E[created]\x1E[modified]\x1E[contents]\n
# [label] is the name of the entry itself.
# [perms] is a string of 14 characters that stores read-write permissions for every irc-rank from none to ~
#               the layout is:
#                ~    &    @    %    +    " "
#               [rw-][rw-][rw-][rw-][rw-][rw-]
#         where 'r' = read
#               'w' = write
#               '-' = reserved for potential future features.
#
# [owner] is the nickname string of the individual who first allocated this entry
# [edited_by] is the nickname string of the individual who last modified this entry
# [created] is epoch describing when the entry was first allocated
# [modified] is epoch describing when the entry was last modified
# [contents] is a NL-terminated string of characters depicting the actual contents of this entry.
#
# FLAGS (GENERAL)
#     -Q      perform a database query (default: show entry)
#     -S      perform a database update
#   DATABASE QUERY OPTIONS (use with -Q)
#       -s      perform a database-search.
#
#	-p [n]  show result page 'n'
#       -r [n]  return result 'n'
#
#	-f [f]  search based on field 'f'
#
#       -E      use extended regular expressions when searching.
#	-F      use fixed strings when searching (default).
#	-v      invert search (show non-matching).
#
#       -i        print information on entry
#     DATABASE CONTENT MODIFICATION (use with -S)
#       -w        overwrite entry
#       -a        append to entry
#       -r        perform a find-and-replace on entry
#       -p        prepend to entry
#     DATABASE META MODIFICATION (use with -S)
#       -c        change permissions for entry
#       -C        change ownership of entry
#
# SECURITY
#  db-interface makes use of a joint nickserv-security and mode-security implementation
#  using these security features REQUIRES both `whois-sec.awk` and `mode-sec.awk`.
#
#  security features are automatically enabled for a database if this database
#  has an authority channel assigned to it in the `dbinterface_Authority` array. 
#
# TODO
#   - Standardise error codes; make it so that each function returns a given error code for similar issues.
#     e.g. a "no such entry exist" code will always be -2, etc.
#   - Clean the getopt parsing up even more and find some kind of structure for error-message printing.
BEGIN {
	#
	# databases are flat files that store actual information.
	#

	#db_Persist["remember"]="./data/db/remember-db";

	#
	# `dbinterface_Use` specifies which database a given channel should use.
	#

	#dbinterface_Use["#channel"]="remember";

	#
	# dbinterface_color specifies whether output is formatted using colours.
	#
	dbinterface_color=1;

	#
	# `dbinterface_Authority` specifies which the "authority" channel for a database.
	# the database authority channel is the channel from which e user-modes such
	# as ~, &, @, %, + etc. are looked up.
	#
	#dbinterface_Authority["remember"]="#channel";

	#
	# `dbinterface_Mask` specifies the default permissions for a newly allocated entry.
	#
	dbinterface_Mask["remember"]="rw-rw-rw-r--r--r--";
	
	#
	# reference table for fields 
	#
	dbinterface_Field["label"]	=1;
	dbinterface_Field["perms"]	=2;
	dbinterface_Field["owner"]	=3;
	dbinterface_Field["edited_by"]	=4;
	dbinterface_Field["created"]	=5;
	dbinterface_Field["modified"]	=6;
	dbinterface_Field["contents"]	=7;

	#
	# message/response templates
	#
	dbinterface_Template["no-db"]    ="PRIVMSG %s :[%s] fatal: no database allocated for channel '%s'.";

	#
	# errors for invalid options
	#
	dbinterface_Template["opt-err"]        ="PRIVMSG %s :[%s] fatal: erroneous options received. [2> %s]";
	dbinterface_Template["opt-conflict"]   ="PRIVMSG %s :[%s] fatal: conflicting options `%s` and `%s` specified.";
	dbinterface_Template["opt-neither"]    ="PRIVMSG %s :[%s] fatal: one of %s is required.";
	dbinterface_Template["opt-neither-c"]  ="PRIVMSG %s :[%s] fatal: one of %s is required in conjunction with `%s`.";
	dbinterface_Template["opt-invalid"]    ="PRIVMSG %s :[%s] fatal: invalid operation: `%s` does not apply to `%s`.";
	dbinterface_Template["opt-ns-entry"]   ="PRIVMSG %s :[%s] fatal: must specify an entry to display info on.";
	dbinterface_Template["opt-noarg"]      ="PRIVMSG %s :[%s] fatal: option `%s` requires an argument.";
	dbinterface_Template["opt-no-query"]   ="PRIVMSG %s :[%s] fatal: no search query specified.";
	dbinterface_Template["opt-bogus-field"]="PRIVMSG %s :[%s] fatal: argument to `-f` must be one of 'label', 'perms', 'owner', 'edited_by', 'created', 'modified', 'contents'.";
	dbinterface_Template["opt-no-write"]   ="PRIVMSG %s :[%s] fatal: no content supplied for write operation.";
	dbinterface_Template["opt-write-entry"]="PRIVMSG %s :[%s] fatal: no entry specified to write to.";
	dbinterface_Template["opt-chmod-entry"]="PRIVMSG %s :[%s] fatal: no entry specified to work on.";
	dbinterface_Template["opt-no-perms"]   ="PRIVMSG %s :[%s] fatal: must specify new permission strings.";
	#
	# non-error results
	#
	dbinterface_Template["query-no-results"] ="PRIVMSG %s :[%s] fatal: no results for query '%s' in database `%s`.";
	dbinterface_Template["query-not-found"]  ="PRIVMSG %s :[%s] fatal: no such entry '%s' in database `%s`.";
	dbinterface_Template["query-info"]       ="PRIVMSG %s :[%s] \x02Info on \x0F%s\x02 from \x0F%s \x02-- Owned by: \x0F%s\x02; Last modified by: \x0F%s\x02 -- Created at: \x0F%s; \x02Last modified at: \x0F%s\x02 -- Permissions: \x0F%s;"
	dbinterface_Template["query-show"]       ="PRIVMSG %s :[%s] %s %s";
	dbinterface_Template["query-search-show"]="PRIVMSG %s :[%s][%d/%d] %s %s";
	dbinterface_Template["query-search-page"]="PRIVMSG %s :[%s][%d/%d] Results: %s"
	dbinterface_Template["write-success"]    ="PRIVMSG %s :[%s] Write to entry '%s' successful (%s:%s + %s @ %s)";
	dbinterface_Template["update-success"]   ="PRIVMSG %s :[%s] Entry '%s' updated successfully (%s:%s + %s @ %s)";
	dbinterface_Template["substitute-usage"] ="PRIVMSG %s :[%s] Usage: `:db -Ss s/target/replacement/`";
	dbinterface_Template["chmod-usage"]      ="PRIVMSG %s :[%s] Usage: `[~&@%%+n]:[r-][w-][x-][ [~&@%%+n]:[r-][w-][x-] [...]]`";
	dbinterface_Template["chmod-success"]    ="PRIVMSG %s :[%s] Successfully modified permissions for entry `%s` (now: %s)";
	#
	# denied permissions
	#
	dbinterface_Template["perm-no-read"]     ="PRIVMSG %s :[%s] fatal: user `%s` is not authorized to read entry `%s` (%s:%s)";
	dbinterface_Template["perm-no-write"]    ="PRIVMSG %s :[%s] fatal: user `%s` is not authorized to modify entry `%s` (%s:%s)";
	dbinterface_Template["perm-no-chmod"]    ="PRIVMSG %s :[%s] fatal: user `%s` is not authorized to modify permissions for rank `%s` for entry `%s` (%s > %s)";
}

#
# top-level function: check the input option string, and
# call the appropriate function.
#
function dbinterface_Db(input,		success,argstring,Optionsi,secure) {
	#
	# make sure a database is allocated
	#
	if (!($3 in dbinterface_Use)) { send( sprintf( dbinterface_Template["no-db"],	\
		$3,			\
		"db => query-info",	\
		$3			\
	) ); return -1 }

	#
	# check to see whether this database has an authority channel
	# assigned for it. If so, set `secure` to 1.
	#
	if (dbinterface_Use[$3] in dbinterface_Authority) {
		#
		# If we're doing anything secure, make sure the user is identified.
		#
		secure=1;

		if ( whois_Whois(USER,$0,"db-interface",$3,"(authority for " dbinterface_Use[$3] ": " $3 ")") == 1 ) {
			return -2;
		}
	}
	else { secure=0; }

	#
	# parse the options
	#
	array(Options);
	argstring=cut(input,5);

	success=getopt_Getopt(argstring,"Q,S,p:,r:,f:,F,E,i,w:,a:,p:,s,O,T,c:,C:,v",Options);

	#
	# if the option-parsing failed, throw an error. 
	#
	if (success == 1) { send( sprintf( dbinterface_Template["opt-err"], \
		$3,		\
		"db => getopt",	\
		Options[0]	\
	) ); return -3; }
	#
	# begin deciphering what we are to do, throwing errors if we
	# end up with bogus flag arguments/combinations.
	#
	else {
		success=getopt_Either(Options,"QS");

		#
		# neither option was found
		#
		if (success==1) { send( sprintf( dbinterface_Template["opt-neither"], \
			$3,		\
			"db => getopt",	\
			"`-Q` or `-S`"	\
		) ); return -4 } 
		#
		# conflicting options were found
		#
		else if (success==2) { send( sprintf( dbinterface_Template["opt-conflict"], \
			$3,		\
			"db => getopt",	\
			"-" Options[0],	\
			"-" Options[-1]	\
		) ); return -5 } 
		#
		# continue regular execution
		#
		else {
			if (Options[0] == "Q") {
			###
			# PERFORM A QUERY OPERATION (-Q)
			###
				#
				# filter/blacklist out operations that do not apply to `-Q`
				#
				success=getopt_Uncompatible(Options,"waOTcC");

				#
				# incompatible options found; complain
				#
				if (success==1) { send(	sprintf( dbinterface_Template["opt-invalid"], \
					$3,		\
					"db => getopt",	\
					"-" Options[0],	\
					"-Q"		\
				) ); return -6 }
				#
				# look for one of `-s` or `-i`
				#
				success=getopt_Either(Options,"si");

				#
				# neither search nor info query was performed. Default to
				# showing the contents of the tell.
				#
				if (success == 1) {
					dbinterface_Query_show(Options);
					return 0;
				}
				#
				# a conflict was found. Complain.
				#
				else if (success == 2) { send( sprintf(	dbinterface_Template["opt-conflict"], \
					$3,		\
					"db => getopt",	\
					"-" Options[0],	\
					"-" Options[-1]	\
				) ); return -7 }
				#
				# no more conflicts/bogus flags. We can begin command execution.
				#
				if (Options[0] == "s")  { dbinterface_Query_search(Options) }
				else                    { dbinterface_Query_info(Options)   };
			} else {
			###
			# PERFORM A SYNC OPERATION (-S)
			###
				#
				# filter/blacklist out operations that do not apply to `-S`
				#
				success=getopt_Uncompatible(Options,"EFifv");

				#
				# incompatible options found; complain
				#
				if (success==1) { send( sprintf( dbinterface_Template["opt-invalid"], \
					$3,					\
					"db => getopt",				\
					"-" Options[0],				\
					"-S"					\
				) ); return -8 }
				#
				# look for one of `-w`, `-a`, `-r`, or `-p`
				#
				success=getopt_Either(Options,"warpcC");

				#
				# none of these were speficied. Complain.
				#
				if (success == 1) { send( sprintf( dbinterface_Template["opt-neither-c"], \
					$3,					\
					"db => getopt",				\
					"`-w`, `-a`, `-r`, `-p`, `-c` or `-C`",	\
					"-S"					\
				) ); return -9 }
				#
				# a conflict was found. Complain.
				#
				else if (success == 2) { send( sprintf( dbinterface_Template["opt-conflict"], \
					$3,		\
					"db => getopt",	\
					"-" Options[0],	\
					"-" Options[-1]	\
				) ); return -10 }
				#
				# no more conflicts. 
				#
				if ( "c" in Options ) { dbinterface_Sync_chmod(Options) }
				else                  { dbinterface_Sync_write(Options) }
			}
		}
	}
}


#
# db_info retrieves information on a given database entry, and then displays it.
#
function dbinterface_Query_info(Options,		Results,Parts,line,db,success,created_at,modified_at) {
	#
	# ensure the user actually specified an argument
	#
	if (Options["--"] == "") { send( sprintf( dbinterface_Template["opt-ns-entry"],	\
		$3,			\
		"db => query-info"	\
	) ); return -1 }
	#
	# perform the search
	#
	array(Results);
	db=dbinterface_Use[$3];
	success=db_Search(db_Persist[db],dbinterface_Field["label"],Options["--"],2,0,Results);

	#
	# if success isn't `0`, then no results were found.
	#
	if (success==1) { send( sprintf( dbinterface_Template["query-not-found"], \
				$3,			\
				"db => query-info",	\
				Options["--"],		\
				db			\
	) ); return -2 }
	#
	# continue regular execution
	#
	array(Parts);
	line=db_Get(db_Persist[db],Results[1]);
	db_Dissect(line,Parts);

	#
	# if security for this channel is enabled, check permissions.
	#
	if (db in dbinterface_Authority) {
		success=dbinterface_Resolveperms(db,Parts,"r");

		#
		# user is not permitted to read.
		#
		if ( success == 1 ) { send( sprintf( dbinterface_Template["perm-no-read"], \
			$3,							\
			"db => query-info",					\
			USER,							\
			Options["--"],						\
			modesec_Lookup[dbinterface_Authority[db] " " USER],	\
			Parts[dbinterface_Field["perms"]]			\
		) ); return -3 }
	}

	created_at=sys("date -d '@" Parts[5] "'");
	modified_at=sys("date -d '@" Parts[6] "'");
	send( sprintf( dbinterface_Template["query-info"], \
		$3,			\
		"db => query-info",	\
		Parts[1],		\
		db,			\
		Parts[3],		\
		Parts[4],		\
		created_at,		\
		modified_at,		\
		Parts[2]		\
	) );

	return 0;
}

function dbinterface_Query_show(Options,	Parts,Results,line,success) {
	if ((Options["--"]=="")) { send( sprintf( dbinterface_Template["opt-ns-entry"], \
		$3,			\
		"db => query-show"	\
	) ); return -1 }

	#
	# perform a search for the given database entry
	#
	array(Results);
	db=dbinterface_Use[$3];
	success=db_Search(db_Persist[db],dbinterface_Field["label"],Options["--"],2,0,Results);

	#
	# no results found...
	#
	if (success==1) { send( sprintf( dbinterface_Template["query-not-found"], \
				$3,			\
				"db => query-show",	\
				Options["--"],		\
				db			\
	) ); return -2 }

	#
	# get the line in question
	# 
	line=db_Get(db_Persist[db],Results[1]);
	db_Dissect(line,Parts);

	#
	# if security for this channel is enabled, check permissions.
	#
	if (db in dbinterface_Authority) {
		success=dbinterface_Resolveperms(db,Parts,"r");
		#
		# user is not permitted to read.
		#
		if ( success == 1 ) { send( sprintf( dbinterface_Template["perm-no-read"], 	\
			$3,							\
			"db => query-search",					\
			USER,							\
			Parts[dbinterface_Field["label"]],			\
			modesec_Lookup[dbinterface_Authority[db] " " USER],	\
			Parts[dbinterface_Field["perms"]]			\
		) ); return -3 }
	}

	#
	# actually display it
	#
	send( sprintf( dbinterface_Template["query-show"], \
		$3,			\
		"db => query-show",	\
		Parts[1],		\
		Parts[7]		\
	) );

	return 0;
}

function dbinterface_Query_search(Options,		success,mode,Results,Parts,db,page,maxpage,out,line,use_field,invert) {
	if ((Options["--"]=="")) { send( sprintf( dbinterface_Template["opt-no-query"], \
		$3,			\
		"db => query-search"	\
	) ); return -1 }

	#
	# see if we have either `-E` or `-F`
	#
	success=getopt_Either(Options,"EF");

	#
	# both flags were specified, complain.
	#
	if (success==2) { send( sprintf( dbinterface_Template["opt-conflict"], \
		$3,			\
		"db => query-search",	\
		"-" Options[0],		\
		"-" Options[-1]		\
	) ); return -2 }

	if (Options[0] == "E")  {mode=1}
	else                    {mode=0};

	success=getopt_Either(Options,"pr");

	#
	# both flags were specified, complain.
	#
	if (success==2) { send( sprintf( dbinterface_Template["opt-conflict"], \
		$3,			\
		"db => query-search",	\
		"-" Options[0],		\
		"-" Options[-1]		\
	) ); return -3 }
	#
	# otherwise, default to `-p 1`
	#
	else if (success==1) {
		Options["p"]=1;
		Options[0]="p";
	}

	#
	# no argument for page-result was specified. Complain.
	#
	if (Options[Options[0]]=="") { send( sprintf( dbinterface_Template["opt-noarg"], \
		$3,			\
		"db => query-search",	\
		Options[0]		\
	) ); return -4 }

	if ("f" in Options) {
		if (!(Options["f"] in dbinterface_Field)) { send( sprintf( dbinterface_Template["opt-bogus-field"], \
			$3,			\
			"db => query-search"	\
		) ); return -5 }
	} else {
		Options["f"]="contents";
	}

	if ("v" in Options) { invert=1 }
	else                { invert=0 };
	#
	#
	#

	#
	# arguments figured out. Begin searching
	#
	array(Results);
	db=dbinterface_Use[$3];
	use_field=dbinterface_Field[Options["f"]];
	success=db_Search(db_Persist[db],use_field,Options["--"],mode,invert,Results);

	#
	# no results found. complain.
	#
	if (success==1) { send( sprintf( dbinterface_Template["query-no-results"], \
		$3,			\
		"db => query-search",	\
		Options["--"],		\
		db			\
	) ); return -6 }

	if (Options[0]=="p") {
		#
		# `-p` specified; show pages with results
		#
		page=int(Options["p"]);
		maxpage=(((length(Results) - (length(Results)%10))/10)+1)


 		if ( page > maxpage ) {
			#
			# if the page number is higher than the amount of options we have,
			# then just set `page` to the highest possible number.
			#
			page=maxpage;
		}

		#
		# assemble our output string.
		#
		for (i = ((page-1)*10)+1 ; i<= (page*10) ; i++ ) {
			success=db_Get(db_Persist[db],Results[i]);
			if (success!=1) {
				out=out cut(success,1,1,"\x1E",", ");
			}
		}

		sub(/, $/,"",out)
		send( sprintf( dbinterface_Template["query-search-page"], \
			$3,			\
			"db => query-search",	\
			page,			\
			maxpage,		\
			out			\
		) ); return 0 }
	else {
		#
		# `-r` specified; show result number `n`.
		#
		result=int(Options["r"]);

		if ( result > length(Results) ) {
			#
			# if the result number if higher than the amount of results
			# found, then just set `result` to the highest possible result.
			#
			result=length(Results);
		}

		#
		# assemble our output string
		#
		line=db_Get(db_Persist[db],Results[result]);
		db_Dissect(line,Parts);

		#
		# if security for this channel is enabled, check permissions.
		#
		if (db in dbinterface_Authority) {
			success=dbinterface_Resolveperms(db,Parts,"r");
			#
			# user is not permitted to read.
			#
			if ( success == 1 ) { send( sprintf( dbinterface_Template["perm-no-read"], 	\
						$3,							\
						"db => query-search",					\
						USER,							\
						Parts[dbinterface_Field["label"]],			\
						modesec_Lookup[dbinterface_Authority[db] " " USER],	\
						Parts[dbinterface_Field["perms"]]			\
			) ); return -7 }
		}

		#
		# add colour-coding/formatting to which part of the string was matched.
		# recycle our previous `mode` variable:
		#
		if (dbinterface_color == 1) {
			if (mode==0) {
				match(tolower(Parts[use_field]),tolower(rsan(Options["--"])))
			} else if (mode==1) {
				match(tolower(Parts[use_field]),tolower(rsan(Options["--"])))
			} else {
				RSTART=1; RLENGTH=length(Parts[use_field]);
			}
			Parts[use_field]=sprintf(			\
				"%s%s%d%s%s%s%s",			\
				substr(Parts[use_field],1,RSTART-1),	\
				"\x03",					\
				4,					\
				"\x02",					\
				substr(Parts[use_field],RSTART,RLENGTH),\
				"\x0f",					\
				substr(Parts[use_field],RSTART+RLENGTH) \
			);
		}

		send( sprintf( dbinterface_Template["query-search-show"], \
			$3,			\
			"db => query-show",	\
			result,			\
			length(Results),	\
			Parts[1],		\
			Parts[7]		\
		) ); return 0
	}
}

function dbinterface_Sync_write(Options,	Current,Parts,old,date,new,what,op,Sub,sep)  {
	if      ("w" in Options) {what="w";op="write"}
	else if ("a" in Options) {what="a";op="append"}
	else if ("r" in Options) {what="r";op="replace"}
	else if ("p" in Options) {what="p";op="prepend"}

	#
	# no label specified to write to
	#
	if ((Options[what]=="")) { send( sprintf( dbinterface_Template["opt-write-entry"], \
		$3,		\
		"db => sync-" op	\
	) ); return -1 }
	#
	# no write content specified. Complain.
	#
	else if ((Options["--"] == "")) { send( sprintf( dbinterface_Template["opt-no-write"], \
		$3,			\
		"db => sync-" op	\
	) ); return -2 }
	#
	# attempt a search to see if an entry with this label already exists.
	# call the appropriate function.
	#
	db=dbinterface_Use[$3];
	array(Current);
	date=sys("date +%s");

	success=dbinterface_Exists(db_Persist[db],Options[what],Current);

	if (success==0) {
		#
		# entry exists. Update it.
		#
		old=db_Get(db_Persist[db],Current[1]);
		db_Dissect(old,Parts);

		Parts[dbinterface_Field["modified"]]=date;
		Parts[dbinterface_Field["edited_by"]]=USER;

		#
		# if security for this channel is enabled, check permissions.
		#
		if (db in dbinterface_Authority) {
			success=dbinterface_Resolveperms(db,Parts,"w");
			#
			# user is not permitted to write.
			#
			if ( success == 1 ) { send( sprintf( dbinterface_Template["perm-no-write"], \
				$3,							\
				"db => sync-update/" op,				\
				USER,							\
				Parts[dbinterface_Field["label"]],			\
				modesec_Lookup[dbinterface_Authority[db] " " USER],	\
				Parts[dbinterface_Field["perms"]]			\
			) ); return -3 }
		}
		if      ( what == "w" ) {Parts[dbinterface_Field["contents"]]=Options["--"]}
		else if ( what == "a" ) {Parts[dbinterface_Field["contents"]]=Parts[dbinterface_Field["contents"]] " " Options["--"]}
		else if ( what == "p" ) {Parts[dbinterface_Field["contents"]]=Options["--"] " " Parts[dbinterface_Field["contents"]]}
		else if ( what == "r" ) {
			sub(/^ +/,"",Options["--"]);
			sub(/ +$/,"",Options["--"]);

			sep=substr(Options["--"],2,1);
			split(Options["--"],Sub,sep);

			#
			# invalid usage of `s/`, lecture the user.
			#
			if ( (Options["--"] !~ /^s./) || (length(Sub) != 4)) { send( sprintf( dbinterface_Template["substitute-usage"], \
				$3,			\
				"db => sync-update/" op	\
			) ); return -4 }

			gsub(Sub[2],Sub[3],Parts[dbinterface_Field["contents"]]);

		}

		gsub(/ +/," ",Parts[dbinterface_Field["contents"]]);
		db_Update(db_Persist[db],Current[1],acut(Parts,1,7,"\x1E"));

		send( sprintf( dbinterface_Template["update-success"], \
			$3,					\
			"db => sync-update/" op,		\
			Parts[dbinterface_Field["label"]],	\
			Parts[dbinterface_Field["owner"]],	\
			USER,					\
			Parts[dbinterface_Field["perms"]],	\
			date					\
		) );
	} else {
		#
		# entry doesn't exist. Write a new one.
		#
		new=sprintf(						\
			"%s\x1E%s\x1E%s\x1E%s\x1E%s\x1E%s\x1E%s",	\
			Options[what],					\
			dbinterface_Mask[db],				\
			USER,						\
			USER,						\
			date,						\
			date,						\
			Options["--"]					\
		)

		# TODO: actually do something with `success`.
		success=db_Add(db_Persist[db],new);

		send( sprintf( dbinterface_Template["write-success"], \
				$3,			\
				"db => sync-write",	\
				Options[what],		\
				USER,			\
				USER,			\
				dbinterface_Mask[db],	\
				date			\
		) );
	}
}

function dbinterface_Sync_chmod(Options,	Modstrings,Modparts,effective_rank,results,success,db,use_field,line,Parts,perms) {
	#
	# no label specified to work on.
	#
	if ((Options["c"]=="")) { send( sprintf( dbinterface_Template["opt-chmod-entry"], \
		$3,		\
		"db => chmod"	\
	) ); return -1 }
	#
	# no write content specified. Complain.
	#
	else if ((Options["--"] == "")) { send( sprintf( dbinterface_Template["opt-no-perms"], \
		$3,		\
		"db => chmod"	\
	) ); return -2 }

	#
	# lookup the entry in question and throw errors if needed:
	#
	array(Results);
	db=dbinterface_Use[$3];
	success=db_Search(db_Persist[db],dbinterface_Field["label"],Options["c"],2,0,Results);

	if ( success == 1 ) { send( sprintf( dbinterface_Template["query-not-found"], \
		$3,		\
		"db => chmod",	\
		Options["c"],	\
		db		\
	) ); return -5 }
	#
	# the stdopt arg must be a sequence of characters in the form of:
	#  R:[r-][w-][x-][\x20R2:[r-][w-][x-] [...]
	# where `R` corresponds to one of the ranks found in `modesec_Ranks`
	#
	array(Modstring);
	split(Options["--"],Modstrings);

	#
	# check to see that the user hasn't butchered the syntax and check
	# to see whether the user is allowed to modify the permissions at all
	# (may only modify permissions below their own rank).
	#
	# note that the `n = ~ if user is owner` substitution is not made.
	#

	#
	# store the caller's effective rank for cross-referencing
	#
	effective_rank=modesec_Lookup[dbinterface_Authority[db] " " USER];

	#
	# this loop intends to catch syntax errors and illegal modifications
	#
	for ( i in Modstrings ) {
		#
		# check syntax:
		#
		if ( Modstrings[i] !~ /^[~&@%\+n]:[r\-][w\-][x\-]$/ ) { send( sprintf( dbinterface_Template["chmod-usage"], \
			$3,		\
			"db => chmod"	\
		) ); return -3 }

		#
		# check whether user is permitted to modify:
		#
		if ( modesec_Ranks[substr(Modstrings[i],1,1)] < modesec_Ranks[effective_rank] ) { send( sprintf( dbinterface_Template["perm-no-chmod"], \
			$3,				\
			"db => chmod",			\
			USER,				\
			substr(Modstrings[i],1,1),	\
			Options["c"],			\
			substr(Modstrings[i],1,1),	\
			effective_rank			\
		) ); return -4 }
	}

	#
	# begin retrieving the line and apply changes to the
	# permissions string.
	#
	line=db_Get(db_Persist[db],Results[1]);
	db_Dissect(line,Parts);

	for ( i in Modstrings ) {
		split(Modstrings[i],Modparts,":");

		perms=Parts[dbinterface_Field["perms"]];
		Parts[dbinterface_Field["perms"]]=(				\
			substr(perms,1,modesec_Ranks[Modparts[1]]*3)		\
			Modparts[2]						\
			substr(perms,(modesec_Ranks[Modparts[1]]+1)*3+1)	\
		)
	}

	#
	# perform a database update to apply new permissions.
	#
	db_Update(db_Persist[db],Results[1],acut(Parts,1,7,"\x1E"));

	send( sprintf( dbinterface_Template["chmod-success"], \
		$3,					\
		"db => chmod",				\
		Options["c"],				\
		Parts[dbinterface_Field["perms"]]	\
	) );

	return 0;
}
#
# The way all write operations performed by dbinterface are performed occurs like this:
#	dbinterface_Exists() checks to see whether an entry with label `l` already exists.
#		If one does exist (success=0) then `dbinterface_Update()` is used.
#		If none exists (success=1) then `dbinterface_Write()` is used.
#
# `dbinterface_Exists()` makes a call to `db_Search()` to see whether an entry with a given
# label already exists. If it does, it returns `0`. Else, `1`.
function dbinterface_Exists(db_file,label,Throw) {
	return db_Search(db_file,1,label,2,0,Throw);
};

#
# `dbinterface_Resolveperms` has only one job: it takes a single database entry 'Parts'
# (a dissected entry, as one might expect from `db_Dissect()` and checks to see whether the
# called is permitted to perform operation `perm`.
#
# This function requires an allocated entry in `dbinterface_Authority` (dbinterface_Authority[db] != "")
#
function dbinterface_Resolveperms(db,Parts,perm,	effective_rank) {
	#
	# `effective_rank` is either:
	#	- '~' if USER is the owner of this entry
	#	- the rank assigned to the user in db_Lookup
	#
	if ( Parts[dbinterface_Field["owner"]] == USER ) {
		effective_rank="~";
	} else {
		effective_rank=modesec_Lookup[dbinterface_Authority[db] " " USER];
	}

	allocated_perms=substr(Parts[dbinterface_Field["perms"]],(modesec_Ranks[effective_rank] * 3)+1,3);
	return (!(allocated_perms ~ perm));
}

($2 == "PRIVMSG") && ($4 ~ /^::db$/) {
	dbinterface_Db($0);
}
