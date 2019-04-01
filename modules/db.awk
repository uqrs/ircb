###
# 'database' manager; used to let users store information on certain topics
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
  db_Persist["site199"]="./data/db/site199"

  #
  # reference table for fields by name
  #
  db_Field["entryname"]   =1;
  db_Field["permissions"] =2;
  db_Field["owner"]       =3;
  db_Field["editedby"]    =4;
  db_Field["creationdate"]=5;
  db_Field["lastedited"]  =6;
  db_field["contents"]    =7;
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
		if (++c==line){return l}
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
# `mode` may be 0 for a regular word-search, or 1 for a regex search.
#
# returns a '1' if no matches were found. '0' otherwise.
#
function db_Search(db,field,search,mode,Matches,		Parts,line,count){
	array(Parts);

	#
	# if mode is `0`, perform a regular full-word search.
	#
	if ( mode == 0 ) {
		while ((getline l < db_Persist[db]) > 0){
			count++;
			db_Dissect(l,Parts);

			if (Parts[field] ~ (" " rsan(search))) {Matches[length(Matches)+1]=count;}
		}
	#
	# otherwise, perform a regex search
	#
	} else {
		while ((getline l < db_Persist[db]) > 0) {
			count++;

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
function db_Update(db,line,user,new,		Parts,l,count,date,tempfile){
	array(Parts);
	date=sys("date +%s");
	tempfile=("/tmp/ircb-db-" rand()*1000000);

	#
	# keep reading lines from the database file, copying them over to a temporary file
	# when we hit our target line `line`, we modify it.
	#
	while ((getline l < db_Persist[db]) > 0) {
		#
		# we've hit our match. modify it.
		#
		if (++count==line){
			db_Dissect(l,Parts);

			#
			# assemble a new line:
			#
			l=sprintf(						\
				"%s\x1E%s\x1E%s\x1E%s\x1E%s\x1E%s\x1E %s ",	\
				Parts[1],					\
				Parts[2],					\
				Parts[3],					\
				user    ,					\
				Parts[5],					\
				date    ,					\
				new						\
			)
		}
		#
		# write our new line to the temporary file.
		#
		print l >> tempfile;
	}
	close(db_Persist[db]);
	close(tempfile);
	#
	# finally, move our file over to the database location:
	#
	sys(                                            \
	    sprintf(                                    \
			"mv '%s' '%s' 2>/dev/null",	\
			tempfile,			\
			db_Persist[db]			\
		)					\
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
