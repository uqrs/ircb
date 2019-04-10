#
# the database interfacer provides a handful of higher-level functions.
# these functions accept more advanced query/update interfacing, and return singular strings for use in user-facing output.
# REQUIRES either db.awk or alt/db-ed.awk
#
# FLAGS (GENERAL)
#     -Q   perform a database query
#     -S   perform a database update
#   DATABASE QUERY OPTIONS (use with -Q)
#       -s [f]  perform a database-search for field 'f'. 'f' may be one of
#               'name', 'owner', 'edited_by', 'creation', 'last_edited'.
#
#       -r [n]  return result 'n'
#       -E      use extended regular expressions when searching.
#
#       -i      print information on an entry
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
	# allocate ourselves a database.
	#
	db_Persist["remember"]="./data/db/remember-db";

	#
	# message/response templates
	#
	dbinterface_Template["err_opts"]  ="PRIVMSG %s :[db] fatal: erroneous options received [2> %s]";
	dbinterface_Template["conflict"]  ="PRIVMSG %s :[db => getopt] fatal: conflicting options `%s` and `%s` specified."
	dbinterface_Template["neither"]   ="PRIVMSG %s :[db => getopt] fatal: one of %s is required." 
	dbinterface_Template["neither_c"] ="PRIVMSG %s :[db => getopt] fatal: one of %s is required in conjunction with `%s`.";
	dbinterface_Template["invalid"]   ="PRIVMSG %s :[db => getopt] fatal: invalid operation: `%s` does not apply to `%s`"
}

#
# top-level function: check the input option string, and
# call the appropriate function.
#
function dbinterface_Db(input,		success,argstring,Options) {
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
					# neither search nor info query was performed. Complain
					#
					send(							\
						sprintf(					\
							dbinterface_Template["neither_c"],	\
							$3,					\
							"`-s` or `-i`",				\
							"-Q"					\
						)						\
					);

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
							Options[0],				\
							Options[-1]				\
						)						\
					)

					return 3;
				}
				#
				# no more conflicts. We're done, boys.
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
function dbinterface_Query_info(Options)  {send("PRIVMSG " $3 " :invoked `dbinterface_Query_info()`");}
function dbinterface_Sync_write(Options)  {send("PRIVMSG " $3 " :invoked `dbinterface_Sync_write()`");}
function dbinterface_Sync_append(Options) {send("PRIVMSG " $3 " :invoked `dbinterface_Sync_append()`");}
function dbinterface_Sync_sed(Options)    {send("PRIVMSG " $3 " :invoked `dbinterface_Sync_sed()`");};
function dbinterface_Sync_prepend(Options){send("PRIVMSG " $3 " :invoked `dbinterface_Sync_prepend()`");}

function dbinterface_Sec_owner(Options)   {}
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
