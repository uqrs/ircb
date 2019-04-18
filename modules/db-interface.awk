#
# the database interfacer provides a handful of higher-level functions.
# these functions accept more advanced query/update interfacing, and return singular strings for use in user-facing output.
# REQUIRES either db.awk or alt/db-ed.awk
#
# Database contents are stored as:
# [entryname]\x1E[permissions]\x1E[owner]\x1E[editedby]\x1E[creationdate]\x1E[lastedited]\x1E[contents]\n
# [entryname] is the name of the entry itself.
# [permissions] is a string of 14 characters that stores read-write permissions for every irc-rank from none to ~
#               the layout is:
#                o   ~   &   @   %   +   n
#               [rw][rw][rw][rw][rw][rw][rw]
# where `o` denotes `owner`, and `n` denotes `none`.
# note that not every module that uses databases requires this(!) It is just a feature that is essential for
# certain modules that make use of `db.awk`
#
# [owner] is the nickname string of the individual who first allocated this entry
# [editedby] is the nickname string of the individual who last modified this entry
# [creationdate] is epoch describing when the entry was first allocated
# [lastedited] is epoch describing when the entry was last modified
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
#
#       -i        print information on entry
#     DATABASE CONTENT MODIFICATION
#       -w        overwrite entry
#       -a        append to entry
#       -p        prepend to entry
#       -s        perform a find-and-replace on entry
#     DATABASE CONTENT MODIFICATION EXTRA (use with -Sw, -Sa, -Sp, -Ss)
#       -O        overwrite database owner
#       -T        overwrite creation date
#     DATABASE META MODIFICATION
#       -c        change permissions for entry
#       -C        change ownership of entry
#
BEGIN {
	#
	# databases are flat files that store actual information.
	#
	db_Persist["remember"]="./data/db/remember-db";

	#
	# `dbinterface_Use` specifies which database a given channel should use.
	#
	dbinterface_Use["#cat-n"]="remember";

	#
	# dbinterface_color specifies whether output is formatted using colours.
	#
	dbinterface_color=1;

	#
	# `dbinterface_Authority` specifies which the "authority" channel for a database.
	# the database authority channel is the channel from which e user-modes such
	# as ~, &, @, %, + etc. are looked up.
	#
	db_Authority["remember"]="#cat-n";
	
	#
	# reference table for fields 
	#
	db_Field["label"]	=1;
	db_Field["perms"]	=2;
	db_Field["owner"]	=3;
	db_Field["edited_by"]	=4;
	db_Field["created"]	=5;
	db_Field["modified"]	=6;
	db_Field["contents"]	=7;

	#
	# message/response templates
	#
	# TODO: standardise the naming of these.
	#
	dbinterface_Template["err_opts"] ="PRIVMSG %s :[%s] fatal: erroneous options received. [2> %s]";
	dbinterface_Template["conflict"] ="PRIVMSG %s :[%s] fatal: conflicting options `%s` and `%s` specified.";
	dbinterface_Template["neither"]  ="PRIVMSG %s :[%s] fatal: one of %s is required.";
	dbinterface_Template["neither_c"]="PRIVMSG %s :[%s] fatal: one of %s is required in conjunction with `%s`.";
	dbinterface_Template["invalid"]  ="PRIVMSG %s :[%s] fatal: invalid operation: `%s` does not apply to `%s`.";
	dbinterface_Template["no-entry"] ="PRIVMSG %s :[%s] fatal: must specify an entry to display info on.";
	dbinterface_Template["not-found"]="PRIVMSG %s :[%s] fatal: no such entry '%s' in database `%s`.";
	dbinterface_Template["no-db"]    ="PRIVMSG %s :[%s] fatal: no database allocated for channel '%s'.";
	dbinterface_Template["result-info"]	="PRIVMSG %s :[%s] \x02Info on \x0F%s\x02 from \x0F%s \x02-- Owned by: \x0F%s\x02; Last modified by: \x0F%s\x02 -- Created at: \x0F%s; \x02Last modified at: \x0F%s\x02 -- Permissions: \x0F%s;"
	dbinterface_Template["result-show"]="PRIVMSG %s :[%s] %s %s";
	dbinterface_Template["search-result-show"]="PRIVMSG %s :[%s][%d/%d] %s %s";
	dbinterface_Template["no-number"]="PRIVMSG %s :[%s] fatal: option `%s` requires an argument.";
	dbinterface_Template["no-query"] ="PRIVMSG %s :[%s] fatal: no search query specified.";
	dbinterface_Template["no-matches"]="PRIVMSG %s :[%s] fatal: no results for query '%s'.";
	dbinterface_Template["search-results"]="PRIVMSG %s :[%s][%d/%d] Results: %s"
	dbinterface_Template["invalid-field"]="PRIVMSG %s :[%s] fatal: argument to `-f` must be one of 'label', 'perms', 'owner', 'edited_by', 'created', 'modified', 'contents'.";
	dbinterface_Template["no-write"]="PRIVMSG %s :[%s] fatal: no content supplied for write operation.";
	dbinterface_Template["no-write-entry"]="PRIVMSG %s :[%s] fatal: no entry specified to write to.";
	dbinterface_Template["write-success"]="PRIVMSG %s :[%s] Write to entry '%s' successful (%s:%s + %s @ %s)";
	dbinterface_Template["update-success"]="PRIVMSG %s :[%s] Entry '%s' updated successfully (%s:%s + %s @ %s)";
	dbinterface_Template["substitute-usage"]="PRIVMSG %s :[%s] Usage: `:db -Ss s/target/replacement/`"
}

#
# top-level function: check the input option string, and
# call the appropriate function.
#
function dbinterface_Db(input,		success,argstring,Options) {
	#
	# make sure a database is allocated
	#
	if (!($3 in dbinterface_Use)) { 
		send(						\
			sprintf(				\
				dbinterface_Template["no-db"],	\
				$3,				\
				"db => query-info",		\
				$3				\
			)					\
		)

		return 2;
	}
	#
	# parse the options
	#
	array(Options);
	argstring=cut(input,5);

	success=getopt_Getopt(argstring,"Q,S,p:,r:,f:,F,E,i,w:,a:,p:,s:,O,T,c,C",Options);

	#
	# if the option-parsing failed, throw an error. 
	#
	if (success == 1) {
		send(										\
			sprintf(								\
				dbinterface_Template["err_opts"],				\
				$3,								\
				"db => getopt",							\
				Options[0]							\
			)									\
		);
	#
	# begin deciphering what we are to do, throwing errors if we
	# end up with bogus flag arguments/combinations.
	#
	} else {
		success=getopt_Either(Options,"QS");

		if (success==1) {
			#
			# neither option was found
			#
			send(							\
				sprintf(					\
					dbinterface_Template["neither"],	\
					$3,					\
					"db => getopt",				\
					"`-Q` or `-S`"				\
				)						\
			)

		} else
		if (success==2) {
			#
			# conflicting options were found
			#
			send(							\
				sprintf(					\
					dbinterface_Template["conflict"],	\
					$3,					\
					"db => getopt",				\
					Options[0],				\
					Options[-1]				\
				)						\
			)
		} else
		{
			#
			# continue regular execution
			#
			if (Options[0] == "Q") {
			###
			# PERFORM A QUERY OPERATION (-Q)
			###
				#
				# filter/blacklist out operations that do not apply to `-Q`
				#
				success=getopt_Uncompatible(Options,"waOTcC");
				if (success==1) {
					#
					# incompatible options found; complain
					#
					send(							\
						sprintf(					\
							dbinterface_Template["invalid"],	\
							$3,					\
							"db => getopt",				\
							Options[0],				\
							"-Q"					\
						)						\
					);

					return 1;
				}
				#
				# look for one of `-s` or `-i`
				#
				success=getopt_Either(Options,"si");

				if (success == 1) {
					#
					# neither search nor info query was performed. Default to
					# showing the contents of the tell.
					#
					dbinterface_Query_show(Options);
					return 0;
				} else
				if (success == 2) {
					#
					# a conflict was found. Complain.
					#
					send(							\
						sprintf(					\
							dbinterface_Template["conflict"],	\
							$3,					\
							"db => getopt",				\
							Options[0],				\
							Options[-1]				\
						)						\
					)

					return 3;
				}
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
				success=getopt_Uncompatible(Options,"rEFif");
				if (success==1) {
					#
					# incompatible options found; complain
					#
					send(							\
						sprintf(					\
							dbinterface_Template["invalid"],	\
							$3,					\
							"db => getopt",				\
							Options[0],				\
							"-Q"					\
						)						\
					);

					return 1;
				}
				#
				# look for one of `-w`, `-a`, `-s`, or `-p`
				#
				success=getopt_Either(Options,"wasp");

				if (success == 1) {
					#
					# none of these were speficied. Complain.
					#
					send(							\
						sprintf(					\
							dbinterface_Template["neither_c"],	\
							$3,					\
							"db => getopt",				\
							"`-w`, `-a`, `-s`, or `-p`",		\
							"-S"					\
						)						\
					)

					return 2;
				} else
				if (success == 2) {
					#
					# a conflict was found. Complain.
					#
					send(							\
						sprintf(					\
							dbinterface_Template["conflict"],	\
							$3,					\
							"db => getopt",				\
							Options[0],				\
							Options[-1]				\
						)						\
					)

					return 3;
				}
				#
				# no more conflicts. 
				#
				dbinterface_Sync_write(Options);
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
	if (Options["--"] == "") {
		send(							\
			sprintf(					\
				dbinterface_Template["no-entry"],	\
				$3,					\
				"db => query-info"			\
			)						\
		)

		return 1;
	}
	#
	# perform the search
	#
	array(Results);
	db=db_Persist[dbinterface_Use[$3]];
	success=db_Search(db,db_Field["label"],Options["--"],2,Results);

	#
	# if success isn't `0`, then no results were found.
	#
	if (success==1) {
		send(							\
			sprintf(					\
				dbinterface_Template["not-found"],	\
				$3,					\
				"db => query-info",			\
				Options["--"],				\
				dbinterface_Use[$3]			\
			)						\
		)

		return 3;
	} else {
		#
		# display found result.
		#
		array(Parts);
		line=db_Get(db,Results[1]);
		db_Dissect(line,Parts);

		created_at=sys("date -d '@" Parts[5] "'");
		modified_at=sys("date -d '@" Parts[6] "'");
		send(							\
			sprintf(					\
				dbinterface_Template["result-info"],	\
				$3,					\
				"db => query-info",			\
				Parts[1],				\
				dbinterface_Use[$3],			\
				Parts[3],				\
				Parts[4],				\
				created_at,				\
				modified_at,				\
				Parts[2]				\
			)						\
		)

	}
}

function dbinterface_Query_show(Options,	Parts,Results,line,success) {
	if ((Options["--"]=="")) {
		send(							\
			sprintf(					\
				dbinterface_Template["no-entry"],	\
				$3,					\
				"db => query-show"			\
			)						\
		)
		return 1;
	}

	#
	# perform a search for the given database entry
	#
	array(Results);
	db=db_Persist[dbinterface_Use[$3]];
	success=db_Search(db,db_Field["label"],Options["--"],2,Results);

	if (success==1) {
		send(							\
			sprintf(					\
				dbinterface_Template["not-found"],	\
				$3,					\
				"db => query-show",			\
				Options["--"],				\
				dbinterface_Use[$3]			\
			)						\
		)
		return 2;
	}

	#
	# get the actual line itself and display it.
	#
	line=db_Get(db,Results[1]);
	db_Dissect(line,Parts);

	send(								\
		sprintf(						\
			dbinterface_Template["result-show"],		\
			$3,						\
			"db => query-show",				\
			Parts[1],					\
			Parts[7]					\
		)							\
	)
}

function dbinterface_Query_search(Options,		success,mode,Results,Parts,db,page,maxpage,out,line,use_field) {
	if ((Options["--"]=="")) {
		send(							\
			sprintf(					\
				dbinterface_Template["no-query"],	\
				$3,					\
				"db => query-search"			\
			)						\
		)

		return 1;
	}

	#
	# see if we have either `-E` or `-F`
	#
	success=getopt_Either(Options,"EF");

	if (success==2) {
		#
		# both flags were specified, complain.
		#
		send(							\
			sprintf(					\
				dbinterface_Template["conflict"],	\
				$3,					\
				"db => query-search",			\
				"-E",					\
				"-F"					\
			)						\
		)

		return 2;	
	}

	if (Options[0] == "E")  {mode=1}
	else                    {mode=0};

	success=getopt_Either(Options,"pr");

	if (success==2) {
		#
		# both flags were specified, complain.
		#
		send(							\
			sprintf(					\
				dbinterface_Template["conflict"],	\
				$3,					\
				"db => query-search",			\
				"-p",					\
				"-r"					\
			)						\
		)

		return 3;
	} else if (success==1) {
		Options["p"]=1;
		Options[0]="p";
	}

	if (Options[Options[0]]=="") {
		#
		# no argument for page-result was specified. Complain.
		#
		send(							\
			sprintf(					\
				dbinterface_Template["no-number"],	\
				$3,					\
				"db => query-search",			\
				Options[0]				\
			)						\
		)

		return 4;
	}

	if ("f" in Options) {
		if (!(Options["f"] in db_Field)) {
			send(							\
				sprintf(					\
					dbinterface_Template["invalid-field"],	\
					$3,					\
					"db => query-search"			\
				)						\
			)

			return 5;
		} 
	} else {
		Options["f"]="contents";
	}

	#
	# arguments figured out. Begin searching
	#
	array(Results);
	db=db_Persist[dbinterface_Use[$3]];
	use_field=db_Field[Options["f"]];
	success=db_Search(db,use_field,Options["--"],mode,Results);

	if (success==1) {
		#
		# no results found. complain.
		#
		send(							\
			sprintf(					\
				dbinterface_Template["no-matches"],	\
				$3,					\
				"db => query-search",			\
				Options["--"]				\
			)						\
		)

		return 5;
	}

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
			success=db_Get(db,Results[i]);
			if (success!=1) {
				out=out cut(success,1,1,"\x1E",", ");
			}
		}

		sub(/, $/,"",out)
		send(							\
			sprintf(					\
				dbinterface_Template["search-results"],	\
				$3,					\
				"db => query-search",			\
				page,					\
				maxpage,				\
				out					\
			)						\
		)
	} else {
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
		line=db_Get(db,Results[result]);
		db_Dissect(line,Parts);

		#
		# add colour-coding/formatting to which part of the string was matched.
		# recycle our previous `mode` variable:
		#
		if (dbinterface_color == 1) {
			if (mode==0) {
				match(Parts[use_field],rsan(Options["--"]))
			} else if (mode==1) {
				match(Parts[use_field],rsan(Options["--"]))
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

		send(								\
			sprintf(						\
				dbinterface_Template["search-result-show"],	\
				$3,						\
				"db => query-show",				\
				result,						\
				length(Results),				\
				Parts[1],					\
				Parts[7]					\
			)							\
		)
	}
}

function dbinterface_Sync_write(Options,	Current,Parts,old,date,new,what,op,Sub,sep)  {
	if      ("w" in Options) {what="w";op="write"}
	else if ("a" in Options) {what="a";op="append"}
	else if ("s" in Options) {what="s";op="substitute"}
	else if ("p" in Options) {what="p";op="prepend"}

	if ((Options[what]=="")) {
		#
		# no label specified to write to
		#
		send(							\
			sprintf(					\
			     dbinterface_Template["no-write-entry"],	\
			     $3,					\
			     "db => sync-" op				\
			)						\
		);

		return 1;
	}
	if ((Options["--"] == "")) {
		#
		# no write content specified. Complain.
		#
		send(							\
			sprintf(					\
				dbinterface_Template["no-write"],	\
				$3,					\
				"db => sync-" op			\
			)						\
		)

		return 2;
	};

	#
	# attempt a search to see if an entry with this label already exists.
	# call the appropriate function.
	#
	db=db_Persist[dbinterface_Use[$3]];
	array(Current);
	date=sys("date +%s");

	success=dbinterface_Exists(db,Options[what],Current);

	if (success==0) {
		#
		# entry exists. Update it.
		#
		old=db_Get(db,Current[1]);
		db_Dissect(old,Parts);

		Parts[db_Field["modified"]]=date;
		Parts[db_Field["edited_by"]]=USER;

		if      ( what == "w" ) {Parts[db_Field["contents"]]=Options["--"]}
		else if ( what == "a" ) {Parts[db_Field["contents"]]=Parts[db_Field["contents"]] " " Options["--"]}
		else if ( what == "p" ) {Parts[db_Field["contents"]]=Options["--"] " " Parts[db_Field["contents"]]}
		else if ( what == "s" ) {
			sub(/^ +/,"",Options["--"]);
			sub(/ +$/,"",Options["--"]);

			sep=substr(Options["--"],2,1);
			split(Options["--"],Sub,sep);

			if ( (Options["--"] !~ /^s./) || (length(Sub) != 4)) {
				send(								\
					sprintf(						\
						dbinterface_Template["substitute-usage"],	\
						$3,						\
						"db => sync-update/" op				\
					)							\
				)
				return 1;
			}

			gsub(Sub[2],Sub[3],Parts[db_Field["contents"]]);

		}

		gsub(/ +/," ",Parts[db_Field["contents"]]);
		db_Update(db,Current[1],acut(Parts,1,7,"\x1E"));

		send(							\
			sprintf(					\
				dbinterface_Template["update-success"],	\
				$3,					\
				"db => sync-update/" op,		\
				Parts[db_Field["label"]],		\
				Parts[db_Field["owner"]],		\
				USER,					\
				Parts[db_Field["perms"]],		\
				date					\
			)						\
		)
	} else {
		#
		# entry doesn't exist. Write a new one.
		#
		new=sprintf(						\
			"%s\x1E%s\x1E%s\x1E%s\x1E%s\x1E%s\x1E%s",	\
			Options[what],					\
			"rwrwrw",					\
			USER,						\
			USER,						\
			date,						\
			date,						\
			Options["--"]					\
		)

		# TODO: actually do something with `success`.
		success=db_Add(db,new);

		send(							\
			sprintf(					\
				dbinterface_Template["write-success"],	\
				$3,					\
				"db => sync-write",	 		\
				Options[what],				\
				USER,					\
				USER,					\
				"rwrwrw",				\
				date					\
			)						\
		)
	}
}

#
# The way all write operations performed by dbinterface are performed occurs like this:
#	dbinterface_Exists() checks to see whether an entry with label `l` already exists.
#		If one does exist (success=0) then `dbinterface_Update()` is used.
#		If none exists (success=1) then `dbinterface_Write()` is used.
#
# `dbinterface_Exists()` makes a call to `db_Search()` to see whether an entry with a given
# label already exists. If it does, it returns `0`. Else, `1`.
function dbinterface_Exists(db,label,Throw) {
	return db_Search(db,1,label,2,Throw);
};

#
# reference: db_Get(db,line)      				[1=err]
#            db_Dissect(line,Arr) 				[1=less than 7 fields]
#            db_Search(db,field,search,mode,Matches)		[1=none found]
#            db_Update(db,line,new)				[1=line doesn't exist]
#            db_Add(db,entry,owner,contents) 
# db_Field["label", "perms", "owner", "edited_by", "created", "edited", "contents"];
#           1        2        3        4            5          6         7
#

($2 == "PRIVMSG") && ($4 ~ /^::db$/) {
	dbinterface_Db($0);
}
