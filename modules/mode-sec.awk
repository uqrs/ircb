#
# `mode-sec.awk` is a security module that keeps an indexed cache of every user
# in a channel, along with their channel mode (+q, +a, +o, +h, +v, etc.)
#
# this module is optional, and may be employed by other modules (such as `db-interface.awk`).
#
BEGIN {
	#
	# the modesec_Lookup array contains sub-arrays for each individual channel.
	# each of these individual channel-arrays contain key-value pairs in the form of
	# modesec_Lookup["#channel"]["nick"] = "r", where `r` is one of ~, &, @, %, + or " ".
	#
	array(modesec_Lookup);

	#
	# the modesec_Ranks array contains key-value pairs denoting numerical
	# representation of various ranks. This way, to tell whether user A's rank
	# is higher than user B's rank, one can do `modesec_Rank[a_rank] > modesec_Rank[b_rank]`
	#
	modesec_Ranks[" "]=0;
	modesec_Ranks["+"]=1;
	modesec_Ranks["%"]=2;
	modesec_Ranks["@"]=3;
	modesec_Ranks["&"]=4;
	modesec_Ranks["~"]=5;

	#
	# modesec_Temp: see comment on `353` vs. `366` below.
	#
	array(modesec_Temp);
}

#
# begin populating modesec_Temp["#channel"] user-rank pairs.
## you might need to modify which of the input records these functions use to identify the channel and such.
#
function modesec_Stage(		Individuals,namestring) {
	namestring=substr(cut($0,6),2);

	split(namestring,Individuals," ");

	for ( i in Individuals ) {
		if ( Individuals[i] ~ /^[~&@%+]/ ) {
			modesec_Temp[$5 " " substr(Individuals[i],2)]=substr(Individuals[i],1,1);
		} else {
			modesec_Temp[$5 " " Individuals[i]]=" ";
		}
	}
}

#
# move everything from modesec_Temp["#channel"] over to modesec_Lookup["#channel"],
# nuking the former in the process.
#
# `Channel` must be a `modesec_Temp["#channel"]` array.
#
function modesec_Commit() {
	for ( i in modesec_Lookup ) {
		if ( i ~ ("^" $4 " ") ) {
			delete modesec_Lookup[i];
		}
	}

	for ( i in modesec_Temp ) {
		modesec_Lookup[i] = modesec_Temp[i];
	}

	delete modesec_Temp;
}

#
# copy over permissions if they change their nick.
#
function modesec_Nick(	A) {
	for ( i in modesec_Lookup ) {
		if ( i ~ (" " USER "$") ) {
			split(i,A," ");
			modesec_Lookup[A[1] " " substr($3,2)] = modesec_Lookup[i];
			delete modesec_Lookup[i];
		}
	}
}

#
#
#
function modesec_Quit() {
	for ( i in modesec_Lookup ) {
		if ( i ~ (" " USER "$") ) {
			delete modesec_Lookup[i];
		}
	}
}

#
# when a `353` response for channel `#n` hits ircb, then ircb will populate `modesec_Temp["#n"]` with entries for each name, similar to
# how `modesec_Lookup` works.
# when a `366` response hits ircb, then it will copy/"commit" everything from `modesec_Temp["#n"]` to `modesec_Lookup["#n"]`.
## you might need to modify the response codes to match NAMES and END-OF-NAMES.
($2 == "353") {
	modesec_Stage()
}

($2 == "366") {
	modesec_Commit();
}

#
# look, ok. MODE is a fucking pain in the ass to handle. I'm not going to fucking bother at this point.
# for now it just re-requests NAMES.
#
($2 == "MODE") {
	send("NAMES " $3);
}

#
# remove a user's entry from the channel if they leave.
#
($2 == "PART") {
	delete modesec_Lookup[$3 " " USER];
}

#
# copy over permissions if they change their nick.
#
($2 == "NICK") {
	modesec_Nick();
}

#
# add a non-ranked entry in the lookup table if someone joins.
#
($2 == "JOIN") {
	modesec_Lookup[substr($3,2) " " USER]=" ";
}

#
# iterate through every channel, and remove entries for the user if they exist.
#
($2 == "QUIT") {
	modesec_Quit();
}
