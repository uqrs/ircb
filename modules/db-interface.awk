# the database interfacer provides a handful of higher-level functions.
# these functions accept more advanced query/update interfacing, and return singular strings for use in user-facing output.
# REQUIRES either db.awk or alt/db-ed.awk
#
# database contents are stored as:
# [label]\x1E[tag]\x1E[perms]\x1E[owner]\x1E[edited_by]\x1E[created]\x1E[modified]\x1E[contents]\n
# [label] is the name of the entry.
# [tag]   is a tag settable by users.
# [perms] contains the current permissions for a string
#               the layout is:
#                @    +    n
#               [rwd][rwd][rwd]
#         where 'r' = read
#               'w' = write
#               'd' = delete
#
# [owner] is who allocated the entry
# [edited_by] is who last modified it
# [created] is epoch describing when the entry was first allocated
# [modified] is epoch describing when the entry was last modified
# [contents] is a string containing the actual contents.
#
# FLAGS (GENERAL)
#     -Q      perform a database query (default: show entry)
#     -S      perform a database update
#     -R      perform a deletion
#   DATABASE QUERY OPTIONS (use with -Q)
#       -s      perform a database-search.
#       -i      print information on entry
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
#     DATABASE CONTENT MODIFICATION (use with -S)
#       -w      overwrite entry
#       -a      append to entry
#       -r      perform a find-and-replace on entry
#       -p      prepend to entry
#     DATABASE META MODIFICATION (use with -S)
#       -c      change permissions for entry
#       -C      change ownership of entry
#       -t      modify tag for certain entry
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
#   - Clean the getopt parsing up even more and find some kind of structure for error-message printing.
#
BEGIN {
	db_Persist["remember"]="./data/db/remember-db"

	# `dbinterface_Use` specifies which database a given channel should use.
	#dbinterface_Use["#channel"]="remember"

	# dbinterface_color specifies whether output is formatted using colours.
	dbinterface_color=1

	# `dbinterface_Authority` specifies which channels' usermodes should be used.
	#dbinterface_Authority["remember"]="#channel"

	# `dbinterface_Mask` specifies the default permissions for a newly allocated entry.
	## NOTICE: if your IRCd supports extended ranks (such as ~, &, %, etc.) then set your Mask
	##         to a sufficient length to accomodate these ranks(!)
	##        e.g. given PREFIX=(qoahv)~&@%+ you should set your mask to:
	##          "rwdrwdrw-rw-r--r--" or something similar to accomodate each individual value.
	##
	## It is also a good idea to perform the following should you reuse your db for a different server:
	##	awk 'BEGIN{FS="\x1E";OFS="\x1E"} {$2="new-perm-string";print}' <my-old-db > my-new-db
	#dbinterface_Mask["remember"]="rwdr--r--"

	# default mask to be fallen back upon should none be allocated
	dbinterface_Defaultmask="rw-r--r--"
	
	# reference table for fields 
	DBF_LABEL = 1
	DBF_TAG = 2
	DBF_PERMS = 3
	DBF_OWNER = 4
	DBF_EDITOR = 5
	DBF_CREATED  = 6
	DBF_MODIFIED = 7
	DBF_CONTENTS = 8

	# option names
	DBOPT_QUERY = "Q"
	DBOPT_SYNC = "S"
	DBOPT_REMOVE = "R"
	DBOPT_SEARCH = "s"
	DBOPT_PAGE = "p"
	DBOPT_RESULT = "r"
	DBOPT_FIELD = "f"
	DBOPT_REGEX = "E"
	DBOPT_FIXEDSEARCH = "F"
	DBOPT_INVERT = "v"
	DBOPT_INFO = "i"
	DBOPT_WRITE = "w"
	DBOPT_APPEND = "a"
	DBOPT_SED = "r"
	DBOPT_PREPEND = "p"
	DBOPT_CHMOD = "c"
	DBOPT_CHOWN = "C"
	DBOPT_TAG = "t"

	DBI_EXISTS = 0
	DBI_NONEXIST = 1

	# user-friendly names for fields
	dbinterface_Field["label"] = DBF_LABEL
	dbinterface_Field["tag"] = DBF_TAG
	dbinterface_Field["perms"] = DBF_PERMS
	dbinterface_Field["owner"] = DBF_OWNER
	dbinterface_Field["edited_by"] = DBF_EDITOR
	dbinterface_Field["created"] = DBF_CREATED
	dbinterface_Field["modified"] = DBF_MODIFIED
	dbinterface_Field["contents"] = DBF_CONTENTS

	# message/response templates
	dbinterface_Msg["no-db"] = "PRIVMSG %s :[%s] fatal: no database allocated for channel '%s'."

	# errors for invalid options
	dbinterface_Msg["opt-err"] = "PRIVMSG %s :[%s] fatal: erroneous options received. [2> %s]"
	dbinterface_Msg["opt-conflict"] = "PRIVMSG %s :[%s] fatal: conflicting options `%s` and `%s` specified."
	dbinterface_Msg["opt-neither"] = "PRIVMSG %s :[%s] fatal: one of %s is required."
	dbinterface_Msg["opt-neither-c"] = "PRIVMSG %s :[%s] fatal: one of %s is required in conjunction with `%s`."
	dbinterface_Msg["opt-invalid"] = "PRIVMSG %s :[%s] fatal: invalid operation: `%s` does not apply to `%s`."
	dbinterface_Msg["opt-ns-entry"] = "PRIVMSG %s :[%s] fatal: must specify an entry to display."
	dbinterface_Msg["opt-noarg"] = "PRIVMSG %s :[%s] fatal: option `%s` requires an argument."
	dbinterface_Msg["opt-no-query"] = "PRIVMSG %s :[%s] fatal: no search query specified."
	dbinterface_Msg["opt-bogus-field"] = "PRIVMSG %s :[%s] fatal: argument to `-f` must be one of 'label', 'tag', 'perms', 'owner', 'edited_by', 'created', 'modified', 'contents'."
	dbinterface_Msg["opt-no-write"] = "PRIVMSG %s :[%s] fatal: no content supplied for write operation."
	dbinterface_Msg["opt-write-entry"] = "PRIVMSG %s :[%s] fatal: no entry specified to write to."
	dbinterface_Msg["opt-work-entry"] = "PRIVMSG %s :[%s] fatal: no entry specified to work on."
	dbinterface_Msg["opt-remove-entry"] = "PRIVMSG %s :[%s] fatal: no entry specified to remove."
	dbinterface_Msg["opt-no-perms"] = "PRIVMSG %s :[%s] fatal: must specify new permission strings."
	dbinterface_Msg["opt-no-owner"] = "PRIVMSG %s :[%s] fatal: must specify a new owner."
	dbinterface_Msg["opt-no-tag"] = "PRIVMSG %s :[%s] fatal: must specify a new tag."

	# non-error results
	dbinterface_Msg["query-no-results"] = "PRIVMSG %s :[%s] fatal: no results for query '%s' in database `%s`."
	dbinterface_Msg["query-not-found"] = "PRIVMSG %s :[%s] fatal: no such entry '%s' in database `%s`."
	dbinterface_Msg["query-info"] = "PRIVMSG %s :[%s] \x02Info on\x0F %s\x02 from\x0F %s\x02 tagged as\x0F %s\x02 -- Owned by:\x0F %s\x02; Last modified by:\x0F %s\x02 -- Created at:\x0F %s\x02; Last modified at:\x0F %s\x02 -- Permissions:\x0F %s;"
	dbinterface_Msg["query-show"] = "PRIVMSG %s :[%s] %s %s"
	dbinterface_Msg["query-search-show"] = "PRIVMSG %s :[%s][%d/%d] %s %s"
	dbinterface_Msg["query-search-page"] = "PRIVMSG %s :[%s][%d/%d] Results: %s"
	dbinterface_Msg["write-success"] = "PRIVMSG %s :[%s] Write to entry '%s' successful (%s:%s + %s @ %s)"
	dbinterface_Msg["update-success"] = "PRIVMSG %s :[%s] Entry '%s' updated successfully (%s:%s + %s @ %s)"
	dbinterface_Msg["substitute-usage"] = "PRIVMSG %s :[%s] Usage: `:db -Ss s/target/replacement/`"
	dbinterface_Msg["chmod-usage"] = "PRIVMSG %s :[%s] Usage: `[~&@%%+n]+=[r-][w-][x-][ [~&@%%+n]+=[r-][w-][x-] [...]]`"
	dbinterface_Msg["chmod-success"] = "PRIVMSG %s :[%s] Successfully modified permissions for entry `%s` (now: %s)"
	dbinterface_Msg["chown-success"] = "PRIVMSG %s :[%s] Successfully transferred ownership of entry `%s` to `%s`."
	dbinterface_Msg["tag-success"] = "PRIVMSG %s :[%s] Successfully modified tag for entry `%s` (%s => %s)"
	dbinterface_Msg["tag-remove-success"] = "PRIVMSG %s :[%s] Successfully removed tag for entry `%s` (%s => %s)"
	dbinterface_Msg["remove-success"] = "PRIVMSG %s :[%s] Successfully removed entry `%s` from `%s`."

	# denied permissions
	dbinterface_Msg["perm-no-read"] = "PRIVMSG %s :[%s] fatal: user `%s` is not authorized to read entry `%s` (%s:%s)"
	dbinterface_Msg["perm-no-write"] = "PRIVMSG %s :[%s] fatal: user `%s` is not authorized to modify entry `%s` (%s:%s)"
	dbinterface_Msg["perm-no-chmod"] = "PRIVMSG %s :[%s] fatal: user `%s` is not authorized to modify permissions for rank `%s` for entry `%s` (%s >= %s)"
	dbinterface_Msg["perm-no-chown"] = "PRIVMSG %s :[%s] fatal: user `%s` is not authorized to transfer ownership of entry `%s`."
	dbinterface_Msg["perm-no-remove"] = "PRIVMSG %s :[%s] fatal: user `%s` is not authorized to remove entry `%s` (%s:%s)"
}

function dbinterface_Db(input,    success, argstring, Options, secure, db) {
	if (!($3 in dbinterface_Use)) {
		send(sprintf(dbinterface_Msg["no-db"],
		      $3, "db => query-info", $3))
		return -1
	}

	db = dbinterface_Use[$3]

	if (dbinterface_Use[$3] in dbinterface_Authority) {
		secure = 1
		if (whois_Whois(USER, $0, "db-interface", $3, "(authority for " db ": " $3 ")") == WHOIS_UNIDENTIFIED) {
			return -2
		}
	} else {
		secure = 0
	}

	split("", Options)
	argstring = cut(input, 5)

	success = getopt_Getopt(argstring, "Q,R,S,p:,r:,f:,F,E,i,w:,a:,p:,s,O,T,c:,C:,t:,v", Options)

	if (success != GETOPT_SUCCESS) {
		send(sprintf(dbinterface_Msg["opt-err"],
			$3, "db => getopt", Options[0]))
		return -3
	} else {
		success = getopt_Either(Options,"QRS")

		if (success == GETOPT_NEITHER) {
			send(sprintf(dbinterface_Msg["opt-neither"],
				$3, "db => getopt", "`-Q`, `-R` or `-S`"))
			return -4
		} else if (success == GETOPT_COLLISION) {
			send(sprintf(dbinterface_Msg["opt-conflict"],
				$3, "db => getopt", "-" Options[0], "-" Options[-1]))
			return -5
		} else {
			if (Options[0] == DBOPT_QUERY) {
				success = getopt_Incompatible(Options, "waOTcCt")

				if (success == GETOPT_INCOMPATIBLE) {
					send(sprintf(dbinterface_Msg["opt-invalid"],
						$3, "db => getopt", "-" Options[0], "-Q"))
					return -6
				}

				success = getopt_Either(Options, "si")

				if (success == GETOPT_NEITHER) {
					dbinterface_Query_show(Options)
					return 0
				} else if (success == GETOPT_COLLISION) {
					send(sprintf(dbinterface_Msg["opt-conflict"],
						$3, "db => getopt", "-" Options[0], "-" Options[-1]))
					return -7
				}

				if (Options[0] == DBOPT_SEARCH) {
					dbinterface_Query_search(Options)
				} else if (Options[0] == DBOPT_INFO) {
					dbinterface_Query_info(Options)
				}

			} else if (Options[0] == DBOPT_REMOVE) {
				success = getopt_Incompatible(Options, "QSsprfEFviwarpcCt")

				if (success == GETOPT_INCOMPATIBLE) {
					send(sprintf(dbinterface_Msg["opt-invalid"],
						$3, "db => getopt", "-" Options[0], "-R"))
					return -6
				} else {
					dbinterface_Remove(Options)
				}

			} else if (Options[0] = DBOPT_WRITE) {
				success = getopt_Incompatible(Options, "EFifv")

				if (success == GETOPT_INCOMPATIBLE) {
					send(sprintf(dbinterface_Msg["opt-invalid"],
						$3, "db => getopt", "-" Options[0], "-S"))
					return -6
				}

				success = getopt_Either(Options, "warpcCt")

				if (success == GETOPT_NEITHER) {
					send(sprintf(dbinterface_Msg["opt-neither-c"],
						$3, "db => getopt", "`-w`, `-a`, `-r`, `-p`, `-c`, `-C` or `-t`", "-S"))
					return -9
				} else if (success == GETOPT_COLLISION) {
					send(sprintf(dbinterface_Msg["opt-conflict"],
						$3, "db => getopt", "-" Options[0], "-" Options[-1]))
					return -10
				}

				if (DBOPT_CHMOD in Options)
					dbinterface_Sync_chmod(Options)
				else if (DBOPT_CHOWN in Options)
					dbinterface_Sync_chown(Options)
				else if (DBOPT_TAG in Options)
					dbinterface_Sync_tag(Options)
				else
					dbinterface_Sync_write(Options)
			}
		}
	}
}

# print and display metadata on a given database entry
function dbinterface_Query_info(Options,    Results, Fields, line, db, dbf, success, created_at, modified_at, tag) {
	if (Options[STDOPT] == GETOPT_EMPTY) {
		send(sprintf(dbinterface_Msg["opt-ns-entry"],
			$3, "db => query-info"))
		return -1
	}

	split("", Results)
	split("", Fields)
	db = dbinterface_Use[$3]
	dbf = db_Persist[db]

	success = db_Search(dbf, DBF_LABEL, Options[STDOPT], DB_EXACT, DB_NORMAL, Results)

	if (success == DB_NORESULTS) {
		send(sprintf(dbinterface_Msg["query-not-found"],
			$3, "db => query-info", Options[STDOPT], db))
		return -2
	}

	line = db_Get(dbf, Results[1])
	db_Dissect(line, Fields)

	if (db in dbinterface_Authority) {
		success = dbinterface_Resolveperms(db, Fields, "r")

		if (success == 1) {
			send(sprintf(dbinterface_Msg["perm-no-read"],
				$3, "db => query-info", USER, Options[STDOPT], modesec_Lookup[dbinterface_Authority[db] " " USER], Fields[DBF_PERMS]))
			return -3
		}
	}

	if (Fields[DBF_TAG] == "") 
		tag = "N/A"
	else
		tag = Fields[DBF_TAG]

	created_at = sys("date -d '@" Fields[DBF_CREATED] "'")
	modified_at = sys("date -d '@" Fields[DBF_MODIFIED] "'")
	send(sprintf(dbinterface_Msg["query-info"],
		$3, "db => query-info", Fields[DBF_LABEL], db, tag, Fields[DBF_OWNER],
		Fields[DBF_EDITOR], created_at, modified_at, Fields[DBF_PERMS]))

	return 0
}

# print the actual contents of the entry itself
function dbinterface_Query_show(Options,    Fields, Results, line, success, db, dbf) {
	if (Options[STDOPT] == "") {
		send(sprintf(dbinterface_Msg["opt-ns-entry"],
			$3, "db => query-show"))
		return -1
	}

	split("", Results)
	db = dbinterface_Use[$3]
	dbf = db_Persist[db]
	success = db_Search(dbf, DBF_LABEL, Options[STDOPT], DB_EXACT, DB_NORMAL, Results)

	if (success == DB_NORESULTS) {
		send(sprintf(dbinterface_Msg["query-not-found"],
			$3, "db => query-show", Options[STDOPT], db))
		return -2
	}

	line = db_Get(dbf, Results[1])
	db_Dissect(line, Fields)

	if (db in dbinterface_Authority) {
		success = dbinterface_Resolveperms(db, Fields, "r")

		if (success == 1) {
			send(sprintf(dbinterface_Msg["perm-no-read"],
				$3, "db => query-search", USER, Fields[DBF_FIELD], modesec_Lookup[dbinterface_Authority[db] " " USER], Fields[DBF_PERMS]))
			return -3
		}
	}

	send(sprintf(dbinterface_Msg["query-show"],
		$3, "db => query-show", Fields[DBF_LABEL], Fields[DBF_CONTENTS]))

	return 0
}

function dbinterface_Query_search(Options,    success, mode, Results, Fields, dbf, db, page, maxpage, out, line, use_field, invert) {
	if (Options[STDOPT] == GETOPT_EMPTY) {
		send(sprintf(dbinterface_Msg["opt-no-query"],
			$3, "db => query-search"))
		return -1
	}

	success = getopt_Either(Options,"EF")

	if (success == GETOPT_COLLISION) {
		send(sprintf(dbinterface_Msg["opt-conflict"],
			$3, "db => query-search", "-" Options[0], "-" Options[-1]))
		return -2
	}

	if (DBOPT_REGEX in Options)
		mode = DB_REGEX
	else
		mode = DB_FIXED

	success = getopt_Either(Options,"pr")

	if (success == GETOPT_COLLISION) {
		send(sprintf(dbinterface_Msg["opt-conflict"],
			$3, "db => query-search", "-" Options[0], "-" Options[-1]))
		return -3
	}

	else if (success == GETOPT_NEITHER) {
		Options[DBOPT_PAGE] = 1
		Options[0] = DBOPT_PAGE
	}

	if (Options[Options[0]] == GETOPT_EMPTY) {
		send(sprintf(dbinterface_Msg["opt-noarg"],
			$3, "db => query-search", Options[0]))
		return -4
	}

	if (DBOPT_FIELD in Options) {
		if (!(Options[DBOPT_FIELD] in dbinterface_Field)) {
			send(sprintf(dbinterface_Msg["opt-bogus-field"],
				$3, "db => query-search"))
			return -5
		}
	} else {
		Options[DBOPT_FIELD] = DBF_CONTENTS
	}

	if (DBOPT_INVERT in Options)
		invert = DB_INVERT
	else
		invert = DB_NORMAL

	split("", Results)
	db = dbinterface_Use[$3]
	dbf = db_Persist[db]
	use_field = dbinterface_Field[Options[DBOPT_FIELD]]
	success = db_Search(dbf, use_field, Options[STDOPT], mode, invert, Results)

	if (success == DB_NORESULTS) {
		send(sprintf(dbinterface_Msg["query-no-results"],
			$3, "db => query-search", Options[STDOPT], db))
		return -6
	}

	if (Options[0] == DBOPT_PAGE) {
		page = int(Options[DBOPT_PAGE])
		maxpage = (length(Results) - length(Results)%10)/10 + 1

 		if (page > maxpage)
			page = maxpage

		# assemble our output string.
		for (i = (page-1)*10 + 1; i <= page*10 ; i++ ) {
			success = db_Get(db_Persist[db],Results[i])
			if (success != DB_OUTOFRANGE) {
				out=out cut(success, 1, 1, "\x1E", ", ")
			}
		}

		sub(/, $/, "", out)
		send(sprintf(dbinterface_Msg["query-search-page"],
			$3, "db => query-search", page, maxpage, out))

		return 0
	} else if (Options[0] == DBOPT_RESULT) {
		result = int(Options[DBOPT_RESULT])

		if (result > length(Results))
			result = length(Results)

		line = db_Get(db_Persist[db], Results[result])
		db_Dissect(line, Fields)

		if (db in dbinterface_Authority) {
			success = dbinterface_Resolveperms(db,Fields,"r")

			if (success == 1) {
				send(sprintf(dbinterface_Msg["perm-no-read"],
					$3, "db => query-search", USER, Fields[DBF_LABEL],
					modesec_Lookup[dbinterface_Authority[db] " " USER], Fields[DBF_PERMS]))
				return -7
			}
		}

		# add colour-coding/formatting to which part of the string was matched.
		# also recycle our previous `mode` variable:
		if (dbinterface_color == 1) {
			if (mode == DB_FIXED) {
				match(tolower(Fields[use_field]), tolower(rsan(Options[STDOPT])))
			} else if (mode==1) {
				match(tolower(Fields[use_field]),tolower(rsan(Options[STDOPT])))
			} else {
				RSTART = 1
				RLENGTH = length(Fields[use_field])
			}
			Fields[use_field] = sprintf("%s%s%d%s%s%s%s",	 \
				substr(Fields[use_field], 1, RSTART-1),  \
				"\x03", 4, "\x02",			 \
				substr(Fields[use_field],RSTART,RLENGTH),\
				"\x0f",					 \
				substr(Fields[use_field],RSTART+RLENGTH) \
			)
		}

		send(sprintf(dbinterface_Msg["query-search-show"],
			$3, "db => query-show", result, length(Results), Fields[DBF_LABEL], Fields[DBF_CONTENTS]))

		return 0
	}
}

# perform any write operation on an already-existing entry, potentially updating older ones if they exist.
function dbinterface_Sync_write(Options,    Results, Fields, old, date, new, what, operation, Sub, separator, mask, dbf, db) {
	if (DBOPT_WRITE in Options) {
		what = DBOPT_WRITE
		op = "write"
	} else if (DBOPT_APPEND in Options) {
		what = DBOPT_APPEND
		op = "append"
	} else if (DBOPT_SED in Options) {
		what = DBOPT_SED
		op = "replace"
	} else if (DBOPT_PREPEND in Options) {
		what = DBOPT_PREPEND
		op = "prepend"
	}

	if (Options[what] == GETOPT_EMPTY) {
		send(sprintf(dbinterface_Msg["opt-write-entry"],
			$3, "db => sync-" op))
		return -1
	} else if ((Options[STDOPT] == GETOPT_EMPTY)) {
		send(sprintf(dbinterface_Msg["opt-no-write"],
			$3, "db => sync-" op))
		return -2
	}

	split("", Results)
	db = dbinterface_Use[$3]
	dbf = db_Persist[db]
	date = sys("date +%s")

	success = db_Search(dbf, DBF_LABEL, Options[what], DB_EXACT, DB_NORMAL, Results)

	if (success == DB_FOUND) {
		old = db_Get(dbf, Results[1])
		db_Dissect(old, Fields)

		Fields[DBF_MODIFIED] = date
		Fields[DBF_EDITOR] = USER

		if (db in dbinterface_Authority) {
			success = dbinterface_Resolveperms(db, Fields, DBOPT_WRITE)
			if (success == 1) {
				send(sprintf(dbinterface_Msg["perm-no-write"],
					$3, "db => sync-update/" op, USER, Fields[DBF_LABEL],
					modesec_Lookup[dbinterface_Authority[db] " " USER], Fields[DBF_PERMS]))
				return -3
			}
		}

		if (what == DBOPT_WRITE) {
			Fields[DBF_CONTENTS] = Options[STDOPT]
		} else if (what == DBOPT_APPEND) {
			Fields[DBF_CONTENTS] = Fields[DBF_CONTENTS] " " Options[STDOPT]
		} else if (what == DBOPT_PREPEND) {
			Fields[DBF_CONTENTS] = Options[STDOPT] " " Fields[DBF_CONTENTS]
		} else if (what == DBOPT_SED) {
			sub(/^ +/,"",Options[STDOPT])
			sub(/ +$/,"",Options[STDOPT])

			separator = substr(Options[STDOPT], 2, 1)
			split(Options[STDOPT], Sub, separator)

			if (Options[STDOPT] !~ /^s./ || length(Sub) != 4) {
				# invalid syntax
				send(sprintf(dbinterface_Msg["substitute-usage"],
					$3, "db => sync-update/" op))
				return -4
			}

			gsub(Sub[2], Sub[3], Fields[DBF_CONTENTS])
		}

		gsub(/ +/, " ", Fields[DBF_CONTENTS])
		db_Update(dbf, Results[1], acut(Fields,DBF_LABEL,DBF_CONTENTS, "\x1E"))

		send(sprintf(dbinterface_Msg["update-success"],
			$3, "db => sync-update/" op, Fields[DBF_LABEL], Fields[DBF_OWNER],
			USER, Fields[DBF_PERMS], date))

		return 0
	} else if (success == DB_NORESULTS) {
		if (db in dbinterface_Mask)
			mask = dbinterface_Mask[db]
		else
			mask = dbinterface_Defaultmask

		new = sprintf("%s\x1E%s\x1E%s\x1E%s\x1E%s\x1E%s\x1E%s\x1E%s",
			Options[what], "", mask, USER, USER, date, date, Options["--"])

		# TODO: actually do something with `success`.
		success = db_Add(dbf, new)

		send(sprintf(dbinterface_Msg["write-success"],
			$3, "db => sync-write", Options[what], USER, USER, mask, date))

		return 0
	}
}

function dbinterface_Sync_chmod(Options,    Modstrings, Modparts, effective_rank, results, success, db, dbf, use_field, line, Fields, perms) {
	if (Options[DBOPT_CHMOD] == GETOPT_EMPTY) {
		send(sprintf(dbinterface_Msg["opt-work-entry"],
			$3, "db => chmod"))
		return -1
	} else if (Options[STDOPT] == GETOPT_EMPTY) {
		send(sprintf(dbinterface_Msg["opt-no-perms"],
			$3, "db => chmod"))
		return -2
	}

	split("",Results)
	db = dbinterface_Use[$3]
	dbf = db_Persist[db]
	success = db_Search(dbf, DBF_LABEL, Options[DBOPT_CHMOD], DB_EXACT, DB_NORMAL, Results)

	if (success == DB_NORESULTS) {
		send(sprintf(dbinterface_Msg["query-not-found"],
			$3, "db => chmod", Options[DBOPT_CHMOD], db))
		return -5
	}
	# the stdopt arg must be a sequence of characters in the form of:
	#  R=[r-][w-][x-][ R2=[r-][w-][x-] [...]
	# where `R` is an arbitrary-length string containing characters found in `modesec_Ranks`
	split("", Modstrings)
	split(Options[STDOPT], Modstrings)

	effective_rank = modesec_Lookup[dbinterface_Authority[db] " " USER]

	for (i in Modstrings) {
		# check syntax
		if (Modstrings[i] !~ /^[~&@%\+n]+=[r\-][w\-][d\-]$/) {
			send(sprintf(dbinterface_Msg["chmod-usage"],
				$3, "db => chmod"))
			return -3
		}

		split(Modstrings[i], Modparts, "=")
		for (c=1 ; c<=length(Modparts[1]) ; c++) {
			if (modesec_Ranks[substr(Modparts[1],c,1)] <= modesec_Ranks[effective_rank] && (modesec_Ranks[effective_rank] != 0)) {
				# user is not permitted to modify this entry
				send(sprintf(dbinterface_Msg["perm-no-chmod"],
					$3, "db => chmod", USER, substr(Modstrings[i],1,1), Options["c"], substr(Modparts[1],c,1), effective_rank))
				return -4
			}
		}
	}

	line = db_Get(db_Persist[db],Results[1])
	db_Dissect(line,Fields)

	for (i in Modstrings) {
		# apply permissions
		split(Modstrings[i], Modparts, "=")

		for (c=1; c<=length(Modparts[1]); c++) {
			perms = Fields[DBF_PERMS]
			Fields[DBF_PERMS]=(                                                       \
				substr(perms,1,modesec_Ranks[substr(Modparts[1], c, 1)]*3)        \
				Modparts[2]                                                       \
				substr(perms,(modesec_Ranks[substr(Modparts[1], c, 1)]+1)*3 + 1)  \
			)
		}
	}

	# perform a database update to apply new permissions.
	db_Update(dbf, Results[1], acut(Fields, DBF_LABEL, DBF_CONTENTS, "\x1E"))

	send(sprintf(dbinterface_Msg["chmod-success"],
		$3, "db => chmod", Options[DBOPT_CHMOD], Fields[DBF_PERMS]))

	return 0
}

function dbinterface_Sync_chown(Options,    Results, db, Fields, line, success) {
	if (Options[DBOPT_CHOWN] == GETOPT_EMPTY) {
		send(sprintf(dbinterface_Msg["opt-work-entry"],
			$3, "db => chown"))
		return -1 
	}
	else if (Options[STDOPT] == GETOPT_EMPTY) {
		send(sprintf(dbinterface_Msg["opt-no-owner"],
			$3, "db => chown"))
		return -2
	}

	split("",Results)
	db = dbinterface_Use[$3]
	dbf = db_Persist[db]
	success = db_Search(dbf, DBF_LABEL, Options[DBOPT_CHOWN], DB_EXACT, DB_NORMAL, Results)

	if (success == DB_NORESULTS) {
		send(sprintf(dbinterface_Msg["query-not-found"],
			$3, "db => chown", Options[DBOPT_CHOWN], db))
		return -3
	}

	line = db_Get(dbf, Results[1])
	db_Dissect(line, Fields)

	if (USER != Fields[DBF_OWNER]) {
		send(sprintf(dbinterface_Msg["perm-no-chown"],
			$3, "db => chown", USER, Options[DBOPT_CHOWN]))
		return -4
	}

	Fields[DBF_OWNER] = Options[STDOPT]
	db_Update(dbf, Results[1],
		acut(Fields, DBF_LABEL, DBF_CONTENTS, "\x1E"))

	send(sprintf(dbinterface_Msg["chown-success"],
		$3, "db => chmod", Options[DBOPT_CHOWN], Fields[DBF_OWNER]))

	return 0
}

function dbinterface_Sync_tag (Options,    Results, db, Fields, line, success, previous) {
	if (Options[DBOPT_TAG] == GETOPT_EMPTY) {
		send(sprintf(dbinterface_Msg["opt-work-entry"],
			$3, "db => tag"))
		return -1
	}

	split("", Results)
	db = dbinterface_Use[$3]
	dbf = db_Persist[db]
	success=db_Search(dbf, DBF_LABEL, Options[DBOPT_TAG], DB_EXACT, DB_NORMAL, Results)

	if (success == DB_NORESULTS) {
		send(sprintf(dbinterface_Msg["query-not-found"],
			$3, "db => tag", Options[DBOPT_TAG], db))
		return -3
	}

	line = db_Get(dbf, Results[1])
	db_Dissect(line, Fields)

	if (db in dbinterface_Authority) {
		success = dbinterface_Resolveperms(db, Fields, "w")
		if (success == 1) {
			send(sprintf(dbinterface_Msg["perm-no-write"],
				$3, "db => tag", USER, Fields[DBF_LABEL],
				modesec_Lookup[dbinterface_Authority[db] " " USER], Fields[DBF_PERMS]))
			return -3
		}
	}

	if (Options[STDOPT] != GETOPT_EMPTY) {
		# modify tag
		if (Fields[DBF_TAG] == "")
			previous = "N/A"
		else
			previous = Fields[DBF_TAG]	

		Fields[DBF_TAG] = Options[STDOPT]
		db_Update(dbf,Results[1],
			acut(Fields, DBF_LABEL, DBF_CONTENTS, "\x1E"))

		send(sprintf(dbinterface_Msg["tag-success"],
			$3, "db => tag", Options[DBOPT_TAG], previous, Fields[DBF_TAG]))
	} else {
		# clear tag
		if (Fields[DBF_TAG] == "")
			previous="N/A"
		else
			previous = Fields[DBF_TAG]

		Fields[DBF_TAG] = ""

		db_Update(db_Persist[db], Results[1],
			acut(Fields, DBF_LABEL, DBF_CONTENTS, "\x1E"))

		send(sprintf(dbinterface_Msg["tag-remove-success"],
			$3, "db => tag", Options[DBOPT_TAG], previous, "N/A"))
	}
	return 0
}

function dbinterface_Remove(Options,	Results, db, success, line) {
	if (Options[STDOPT] == GETOPT_EMPTY) {
		send(sprintf(dbinterface_Msg["opt-remove-entry"],
			$3, "db => remove"))
		return -1
	}

	split("", Results)
	db = dbinterface_Use[$3]
	dbf = db_Persist[db]
	success = db_Search(dbf, DBF_LABEL, Options[STDOPT], DB_EXACT, DB_NORMAL, Results)

	if (success == GETOPT_NORESULTS) {
		send(sprintf(dbinterface_Msg["query-not-found"],
			$3, "db => remove", Options[STDOPT], db))
		return -3
	}

	line = db_Get(dbf, Results[1])
	db_Dissect(line, Fields)

	if (db in dbinterface_Authority) {
		success = dbinterface_Resolveperms(db,Fields,"d")
		if (success == 1) {
			send(sprintf(dbinterface_Msg["perm-no-remove"],
				$3, "db => remove", USER, Options[STDOPT], modesec_Lookup[dbinterface_Authority[db] " " USER], Fields[DBF_PERMS]))
			return -4
		}
	}

	db_Remove(dbf, Results[1])

	send(sprintf(dbinterface_Msg["remove-success"],
		$3, "db => remove", Options[STDOPT], db))

	return 0
}

# `dbinterface_Resolveperms` has only one job: it takes a single database entry 'Fields'
# (a dissected entry, as one might expect from `db_Dissect()` and checks to see whether the
# called is permitted to perform operation `perm`.
#
# This function requires an allocated entry in `dbinterface_Authority` (dbinterface_Authority[db] != "")
function dbinterface_Resolveperms(db,Fields,perm,	effective_rank) {
	# `effective_rank` is either:
	#	- '~' if USER is the owner of this entry
	#	- the rank assigned to the user in modesec_lookup
	if (Fields[DBF_OWNER] == USER) {
		effective_rank = "~"
	} else {
		effective_rank = modesec_Lookup[dbinterface_Authority[db] " " USER]
	}

	# retrieve a string slice from the "perms" field containing the permission triplet for this rank
	allocated_perms = substr(Fields[DBF_PERMS], modesec_Ranks[effective_rank]*3 + 1, 3)
	return (allocated_perms !~ perm)
}

($2 == "PRIVMSG") && ($4 ~ /^::db$/) {
	dbinterface_Db($0)
}
