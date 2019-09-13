# `modules/db.awk`
# store, retrieve and search for arbitrary lines in a file (""database"")
#
# "fields" in a databse are delimited using `\x1E` (record separator)
# rows in a database are delimited by NL
#
# TODO: add support for specifying different delimiters
#
# individual entries are identified by line number.
BEGIN {
	# exit codes
	DB_SUCCESS = 0

	DB_OUTOFRANGE = -1

	DB_NORESULTS = -1
	DB_BADMODE = -2

	DB_FIXED = 0
	DB_REGEX = 1
	DB_EXACT = 2

	DB_NORMAL = 1
	DB_INVERT = 0
}

function db_Get (dbf, target,    c, line) {
	while ((getline line < dbf) > 0) {
		if (++c == target) {
			close(dbf)
			return line
		}
	}

	close(dbf)
	return DB_OUTOFRANGE
}

function db_Dissect (line, Fields) {
	return split(line, Fields, "\x1E");
}

# db_Search looks for lines where the given field matches the search criteria.
# the line numbers of matching are deposited into `Matches`
#
# `mode` may be:
#    DB_FIXED - for fixed-string searching
#    DB_EXACT - for exact string matching
#    DB_REGEX - for regular expression search
#
# `invert` may be:
#    DB_NORMAL - for regular search
#    DB_INVERT - look for non-matching strings
#
# returns:
#    DB_SUCCESS - at least one match found
#    DB_NORESULTS - no matches found
function db_Search(dbf, field, query, mode, invert, Matches,    Fields, line, i) {
	split("", Fields)

	if (invert == "")
		invert = DB_NORMAL

	if (mode == DB_FIXED) {
		while ((getline line < dbf) > 0) {
			i++
			db_Dissect(line, Fields)
			if ((tolower(Fields[field]) ~ tolower(rsan(query))) == invert) {
				Matches[length(Matches)+1] = i
			}
		}
	} else if (mode == DB_EXACT) {
		while ((getline line < dbf) > 0) {
			i++
			db_Dissect(line, Fields)
			if ((tolower(Fields[field]) == tolower(query)) == invert) {
				Matches[length(Matches)+1] = i
			}
		}
	} else if (mode == DB_REGEX) {
		while ((getline line < dbf) > 0) {
			i++
			db_Dissect(l, Fields)

			if ((tolower(Fields[field]) ~ tolower(query)) == invert) {
				Matches[length(Matches)+1] = i
			}
		}
	} else {
		return DB_BADMODE
	}

	close(dbf)

	if (length(Matches) == 0)
		return DB_NORESULTS 
	else
		return DB_SUCCESS
}

# db_Update replaces the target line with string `new`
function db_Update(dbf, target, new,    line, count, tmpf) {
	tmpf = ("/tmp/ircb-db-" rand()*1000000)

	while ((getline line < dbf) > 0) {
		if (++count == target) {
			line = new
		}

		print line >> tmpf;
	}
	close(dbf)
	close(tmpf)

	return sys(sprintf("mv '%s' '%s' 2>/dev/null", tmpf, dbf))
}

function db_Add(dbf, new) {
	print new >> dbf
	close(dbf)

	return DB_SUCCESS
}

# using a similar tactic to db_Update, remove a line from the db.
function db_Remove(dbf, target,    c, line, tmpf) {
	tmpf = ("/tmp/ircb-db-" rand()*1000000);

	while ((getline line < dbf) > 0) {
		if (++c != target) {
			print line >> tmpf
		}
	}
	close(dbf)
	close(tmpf)

	return sys(sprintf("mv '%s' '%s' 2>/dev/null", tmpf, dbf))
}
