#
# the database interfacer provides a handful of higher-level functions.
# these functions accept more advanced query/update interfacing, and return singular strings for use in user-facing output.
# REQUIRES either db.awk or alt/db-ed.awk
#
# FLAGS (GENERAL)
#     -Q [n]  perform a database query (default: show entry `n`);
#     -S      perform a database update
#   DATABASE QUERY OPTIONS (use with -Q)
#       -s [f]  perform a database-search for field 'f'. 'f' may be one of
#               'name', 'owner', 'edited_by', 'creation', 'last_edited'.
#
#       -r [n]  return result 'n'
#       -E      use extended regular expressions when searching.
#
#       -i [n]  print information on entry `n`
#     DATABASE CONTENT MODIFICATION
#       -w [n]    overwrite entry 'n'
#       -a [n]    append to entry 'n'
#       -p [n]    prepend to entry 'n'
#       -s [n]    perform a find-and-replace on entry 'n'
#     DATABASE CONTENT MODIFICATION EXTRA (use with -Sw, -Sa, -Sp, -Ss)
#       -O [n]    overwrite database owner
#       -T [n]    overwrite creation date
#     DATABASE META MODIFICATION
#       -c [n]    change permissions for entry `n`
#       -C [n]    change ownership of entry `n`
#
BEGIN {
	#
	# databases are flat files that store actual information.
	#

	db_Persist["remember"]="./data/db/remember-db";

	#
	# `db_Use` specifies which database a given channel should use.
	#

	db_Use["#cat-n"]="remember";

	#
	# `dbinterface_Authority` specifies which the "authority" channel for a database.
	# the database authority channel is the channel from which e user-modes such
	# as ~, &, @, %, + etc. are looked up.
	#

	db_Authority["remember"]="#cat-n";

	#
	# message/response templates
	#
	dbinterface_Template["err_opts"]   ="PRIVMSG %s :[%s] fatal: erroneous options received. [2> %s]";
	dbinterface_Template["conflict"]   ="PRIVMSG %s :[%s] fatal: conflicting options `%s` and `%s` specified.";
	dbinterface_Template["neither"]    ="PRIVMSG %s :[%s] fatal: one of %s is required.";
	dbinterface_Template["neither_c"]  ="PRIVMSG %s :[%s] fatal: one of %s is required in conjunction with `%s`.";
	dbinterface_Template["invalid"]    ="PRIVMSG %s :[%s] fatal: invalid operation: `%s` does not apply to `%s`.";
	dbinterface_Template["no-entry"]   ="PRIVMSG %s :[%s] fatal: must specify an entry to display info on.";
	dbinterface_Template["not-found"]  ="PRIVMSG %s :[%s] fatal: no such entry '%s' in database `%s`.";
	dbinterface_Template["no-db"]      ="PRIVMSG %s :[%s] fatal: no database allocated for channel '%s'.";
	dbinterface_Template["result-info"]="PRIVMSG %s :[%s] \x02Info on \x0F%s\x02 from \x0F%s \x02-- Owned by: \x0F%s; Last modified by: \x0F%s\x02 -- Created at: \x0F%s\x02; Last modified at: \x0F%s\x02 -- Permissions: %s;"
	dbinterface_Template["result-show"]="PRIVMSG %s :[%s] %s %s";
}

#
# top-level function: check the input option string, and
# call the appropriate function.
#
function dbinterface_Db(input,		success,argstring,Options) {
	#
	# make sure a database is allocated
	#
	if (!($3 in db_Use)) { 
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

	success=getopt_Getopt("-QSrEiIwapsOTcC",argstring,Options);

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
			if (Options[0] == "-Q") {
			###
			# PERFORM A QUERY OPERATION (-Q)
			###
				#
				# filter/blacklist out operations that do not apply to `-Q`
				#
				success=getopt_Uncompatible(Options,"wapOTcC");
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
				if (Options[0] == "-s") { dbinterface_Query_search(Options) }
				else                    { dbinterface_Query_info(Options)   };
			} else {
			###
			# PERFORM A SYNC OPERATION (-S)
			###
				#
				# filter/blacklist out operations that do not apply to `-S`
				#
				success=getopt_Uncompatible(Options,"rEi");
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
				if (Options[0] == "-w")      { dbinterface_Sync_write(Options)  }
				else if (Options[0] == "-a") { dbinterface_Sync_append(Options) }
				else if (Options[0] == "-s") { dbinterface_Sync_sed(Options)    }
				else if (Options[0] == "-p") { dbinterface_Sync_prepend(Options)}
			}
		}
	}
}

function dbinterface_Query_search(Options){send("PRIVMSG " $3 " :invoked `dbinterface_Query_search()`");}

#
# db_info retrieves information on a given database entry, and then displays it.
#
function dbinterface_Query_info(Options,		Results,Parts,line,db,success,created_at,modified_at,searchfor) {
	#
	# ensure the user actually specified an argument
	#
	if ((Options["--"] == "") && (Options["-i"] == "")) {
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
	if (Options["--"]) {searchfor=Options["--"]}
	else               {searchfor=Options["-i"]}
	db=db_Use[$3];
	success=db_Search(db,db_Field["entryname"],searchfor,2,Results);

	#
	# if success isn't `0`, then no results were found.
	#
	if (success==1) {
		send(							\
			sprintf(					\
				dbinterface_Template["not-found"],	\
				$3,					\
				"db => query-info",			\
				searchfor,				\
				db					\
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
				"db => query",				\
				Parts[1],				\
				db,					\
				Parts[3],				\
				Parts[4],				\
				created_at,				\
				modified_at,				\
				Parts[2]				\
			)						\
		)

	}
}

function dbinterface_Query_show(Options,	Parts,Results,line,success,searchfor) {
	if ((Options["--"]=="") && (Options["-Q"]=="")) {
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
	if (Options["--"]) {searchfor=Options["--"]}
	else               {searchfor=Options["-Q"]}
	array(Results);
	db=db_Use[$3];
	success=db_Search(db,db_Field["entryname"],searchfor,2,Results);

	if (success==1) {
		send(							\
			sprintf(					\
				dbinterface_Template["not-found"],	\
				$3,					\
				"db => query-show",			\
				searchfor,				\
				db					\
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

function dbinterface_Sync_write(Options)  {send("PRIVMSG " $3 " :invoked `dbinterface_Sync_write()`");}
function dbinterface_Sync_append(Options) {send("PRIVMSG " $3 " :invoked `dbinterface_Sync_append()`");}
function dbinterface_Sync_sed(Options)    {send("PRIVMSG " $3 " :invoked `dbinterface_Sync_sed()`");};
function dbinterface_Sync_prepend(Options){send("PRIVMSG " $3 " :invoked `dbinterface_Sync_prepend()`");}

#
# reference: db_Get(db,line)      				[1=err]
#            db_Dissect(line,Arr) 				[1=less than 7 fields]
#            db_Search(db,field,search,mode,Matches)		[1=none found]
#            db_Update(db,line,user,new)			[1=line doesn't exist]
#            db_Add(db,entry,owner,contents) 
# db_Field["entryname", "permissions", "owner", "editedby", "creationdate", "lastedited", "contents"];
#           1            2              3        4           5               6             7
#
($2 == "PRIVMSG") && ($4 ~ /^::db$/) {
	dbinterface_Db($0);
}
