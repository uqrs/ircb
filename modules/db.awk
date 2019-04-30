###
# 'database' manager; used to store entries of arbitrary length.
#
# the db_Get function will retrieve the database entry for line `line`. The line will automatically
# be dissected and inserted into Arr
#
# the db_Get function will retrieve the database entry for line `line`. The line will automatically
# be dissected and inserted into Arr
#
# conventions:
#	every function except for `db_Dissect` accepts `db` as its first argument.
#	`db` here is one of the values from `db_Persist` (i.e. a path).
#
#	`line` always refers to a line number in a given database file.
#	to discover the number for a line based on a field, use `db_Search()`.
#
# returns: `l` the retrieved line on success.
#          `1` if no line was found.
#
function db_Get(db,line,		c,l){
	while ((getline l < db) > 0) {
		if (++c==line){close(db);return l}
	}
	#
	# if 'l' was not returned, then that means no line was found. 
	#
	close(db);
	return 1;
}

#
# db_Dissect will take an individual entry line and dissect it into array Arr.
#
function db_Dissect(line,Arr){
	split(line,Arr,"\x1E");

	return 0;
}

#
# db_Search will scour a database for a line where field `field` has value `value`
# it populates the given array `Matches` with line numbers.
#
# `mode` may be 0 for a regular word-search, 1 for a regex search, or 2 for exact-matching.
# `invert` may be 1 for non-matching, or 0 for matching.
#
# returns: `0` if at least one match was found
#          `1` if none were found
#
function db_Search(db,field,search,mode,invert,Matches,		Parts,line,count){
	array(Parts);

	invert || (invert=0);
	#
	# if mode is `0`, perform a regular search.
	#
	if ( mode == 0 ) {
		while ((getline l < db) > 0){
			count++;
			db_Dissect(l,Parts);
			if ((tolower(Parts[field]) ~ tolower(rsan(search))) == !invert) {Matches[length(Matches)+1]=count;}
		}
	} else
	#
	# else, if it's `2`, perform a word-match
	#
	if ( mode == 2) {
		while ((getline l < db) > 0){
			count++
			db_Dissect(l,Parts);
			if ((tolower(Parts[field]) == tolower(search)) == !invert) {Matches[length(Matches)+1]=count;}
		}
	#
	# otherwise, perform a regex search
	#
	} else {
		while ((getline l < db) > 0) {
			count++;
			db_Dissect(l,Parts);

			if ((tolower(Parts[field]) ~ tolower(search)) == !invert) {Matches[length(Matches)+1]=count;}
		}
	}

	close(db);
	#
	# if no matches were found, return an erroneous exit status.
	#
	if (length(Matches) == 0) {return 1}
	else                      {return 0};
}

#
# db_Update will modify the entry for line `l`.
# It accepts a few arguments:
#	`db`   is the database in question to be edited
#	`line` is the line in question that should be updated.
#	`new`  is the new, full database entry that should be written in the place of the previous.
#
# Aside from these two parameters, db_Update() will also update the edit date.
# This function does not add new entries, it only updates existing ones.
#
function db_Update(db,line,new,		Parts,l,count,date,tempfile){
	array(Parts);
	date=sys("date +%s");
	tempfile=("/tmp/ircb-db-" rand()*1000000);

	#
	# keep reading lines from the database file, copying them over to a temporary file
	# when we hit our target line `line`, we modify it.
	#
	while ((getline l < db) > 0) {
		#
		# we've hit our match. modify it.
		#
		if (++count==line){
			l=new;
		}
		#
		# write our new line to the temporary file.
		#
		print l >> tempfile;
	}
	close(db);
	close(tempfile);
	#
	# finally, overwrite the old database.
	#
	sys(                                            \
	    sprintf(                                    \
			"mv '%s' '%s' 2>/dev/null",	\
			tempfile,			\
			db				\
		)					\
	)

	return 0;
}

#
# db_Add will allocate a new entry into the database file.
# It accepts a few arguments:
#	`db`		as the database the new entry should be stored in.
#	`new`		as the new entry to be written to the database.
function db_Add(db,new){
	print new >> db ; close(db);

	return 0;
}

#
# db_Remove will remove a line from the database file.
# It accepts a few arguments:
#	`db`		as the database the entry should be removed from.
#	`line`		as the line in question to be removed.
#
function db_Remove(db,line,	c,l){
	date=sys("date +%s");
	tempfile=("/tmp/ircb-db-" rand()*1000000);
	#
	# keep reading lines from the database file, copying them over to a temporary file
	# when we hit our target line `line`, we skip without writing it.
	#
	while ((getline l < db) > 0) {
		#
		# as long as we're not hitting our match, keep writing.
		#
		if (++count!=line){
			#
			# write our new line to the temporary file.
			#
			print l >> tempfile;
		}
	}
	close(db);
	close(tempfile);
	#
	# finally, overwrite the old database.
	#
	sys(                                            \
	    sprintf(                                    \
			"mv '%s' '%s' 2>/dev/null",	\
			tempfile,			\
			db				\
		)					\
	)

	return 0;
}
