###
# 'database' manager; used to store entries of arbitrary length.
#
# THIS IS THE `ED`-DEPENDENT VERSION; it has mild performance advantages while removing the file-I/O overhead.
#                                     for the non-ed version, use the standard `db.awk`
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
BEGIN {
	#
	# db_Persist is a publically editable array that binds names to files.
	# e.g. db_Persist["my_db"]="./data/db/my_db"
	#
	array(db_Persist);
}
function db_Get(db,line,		c,l){
	#
	# retrieve line # 'line' from the database file
	#
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
function db_Dissect(entry,Arr){
	split(entry,Arr,"\x1E");
}

#
# db_Search will scour a database for a line where field `field` has value `value`
# it populates the given array `Matches` with line numbers.
#
# `mode` may be 0 for a regular word-search, 2 for exact matching, or 1 for a regex search.
# `invert` may be 0 for a non-matching, or 1 for matching.
#
# returns: `0` if at least one match was found
#          `1` otherwise.
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
# 	`new`  is the new entry supposed to be shoved into the database. 
#
# Aside from these two parameters, db_Update() will also update the edit date.
# This function does not add new entries, it only updates existing ones.
#
function db_Update(db,line,new,		l,date,tempfile){
	array(Parts);
	date=sys("date +%s");

	l=db_Get(db,line);
	if ( l == "" ) { return 1 };

	sys(												\
		sprintf(										\
			"echo '%d\nc\n%s\n.\nw\nQ' | ed - '%s'",					\
			line,										\
			san(new),									\
			db										\
		)											\
	)

	return 0;
}
#
# db_Add will allocate a new entry into the database file.
# It accepts a few arguments:
#	`db`       as the database the new entry should be stored in.
#	`new`      as the new entry to be written to the database.
function db_Add(db,new){
	print new >> db;close(db);

	return 0;
}
