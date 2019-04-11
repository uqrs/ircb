###
# 'database' manager; used to let users store information on certain topics
#
# THIS IS THE `ED`-DEPENDENT VERSION; it has mild performance advantages while removing the file-I/O overhead.
#                                     for the non-ed version, use the standard `db.awk`
#
# Channels may be bound to database files. One file has entries stored as:
#
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
BEGIN {
  ### the files in which entries should be permanently stored for each database.
  db_Persist["my_database"]="./data/db/mydb"

  #
  # reference table for fields by name
  #
  db_Field["entryname"]   =1;
  db_Field["permissions"] =2;
  db_Field["owner"]       =3;
  db_Field["editedby"]    =4;
  db_Field["creationdate"]=5;
  db_Field["lastedited"]  =6;
  db_Field["contents"]    =7;
}

#
# the db_Get function will retrieve the database entry for line `line`. The line will automatically
# be dissected and inserted into Arr
#
function db_Get(db,line,		c,l){
	#
	# retrieve line # 'line' from the database file
	#
	while ((getline l < db_Persist[db]) > 0) {
		if (++c==line){close(db_Persist[db]);return l}
	}
	#
	# if 'l' was not returned, then that means no line was found. 
	#
	close(db_Persist[db]);
}

#
# db_Dissect will take an individual entry line and dissect it into array Arr.
#
function db_Dissect(line,Arr){
	split(line,Arr,"\x1E");

	#
	# there should be at least 7 fields. If any are missing, then we have a dud.
	#
	if (!(7 in Arr)) {return 1;}
	else             {return 0;}
}

#
# db_Search will scour a database for a line where field `field` has value `value`
# it populates the given array `Matches` with line numbers.
#
# `mode` may be 0 for a regular word-search, 2 for exact matching, or 1 for a regex search.
#
# returns a '1' if no matches were found. '0' otherwise.
#
function db_Search(db,field,search,mode,Matches,		Parts,line,count){
	array(Parts);array(Matches);
	#
	# if mode is `0`, perform a regular search.
	#
	if ( mode == 0 ) {
		while ((getline l < db_Persist[db]) > 0){
			count++;
			db_Dissect(l,Parts);

			if (Parts[field] ~ (rsan(search))) {Matches[length(Matches)+1]=count;}
		}
	} else
	#
	# if mode is `2`, perform an exact match.
	#
	if ( mode == 2 ) {
		while ((getline l < db_Persist[db]) > 0){
			count++;
			db_Dissect(l,Parts);

			if (Parts[field] == (rsan(search))) {Matches[length(Matches)+1]=count;}
		}
	#
	# otherwise, perform a regex search
	#
	} else {
		while ((getline l < db_Persist[db]) > 0) {
			count++;
			db_Dissect(l,Parts);

			if (Parts[field] ~ search) {Matches[length(Matches)+1]=count;}
		}
	}

	close(db_Persist[db]);
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
# 	`new`  is the new string to be slotted into the entry (field 7)
#	`user` is the nickname of the individual who is making the write operation. (field 4)
#
# Aside from these two parameters, db_Update() will also update the edit date.
# This function does not add new entries, it only updates existing ones.
#
function db_Update(db,line,user,new,		Parts,l,date,tempfile){
	array(Parts);
	date=sys("date +%s");

	l=db_Get(db,line);
	if ( l == "" ) { return 1 };
	db_Dissect(l,Parts);

	sys(												\
		sprintf(										\
			"echo '%d\nc\n%s\x1E%s\x1E%s\x1E%s\x1E%s\x1E%s\x1E %s \n.\nw\nQ' | ed - '%s'",	\
			line,										\
			Parts[1],									\
			Parts[2],									\
			Parts[3],									\
			san(user),									\
			Parts[5],									\
			date,										\
			san(new),									\
			db_Persist[db]									\
		)											\
	)

	return 0;
}
#
# db_Add will allocate a new entry into the database file.
# It accepts a few arguments:
#	`db`       as the database the new entry should be stored in.
#	`entry`    as the name of the new database entry
#	`owner`    as the individual who is allocating the entry
#	`contents` as the actual contents that need to be written
#
# db_Add will infer editedby, creationdate and lastedited.
function db_Add(db,entry,owner,contents){
	date=sys("date +%s");

	# TODO: add arg for standard permissions to be written into
	printf("%s\x1E%s\x1E%s\x1E%s\x1E%s\x1E%s\x1E %s \n",	\
	     entry,						\
	     "rwrwrw",						\
	     owner,						\
	     owner,						\
	     date,						\
	     date,						\
	     contents						\
	) >> db_Persist[db];close(db_Persist[db]);

	return 0;
}
