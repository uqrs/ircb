#
# `mode-sec.awk` is a security module that keeps an indexed cache of every user
# in a channel, along with their channel mode (+q, +a, +o, +h, +v, etc.)
#
# this module is optional, and may be employed by other modules (such as `db-interface.awk`).
#
BEGIN {
	# modesec_Lookup["#channel" "nick"] = "r", where `r` is one of ~, &, @, %, + or " ".
	split("", modesec_Lookup);

	# to check whether b_rank is higher then a_rank:
	# `modesec_Rank[a_rank] < modesec_Rank[b_rank]`
	# `n` stands in for "no rank"
	#
	# modesec will rebuild this table if a `PREFIX` capability is delivered by the server.
	modesec_Ranks["n"] = 2;
	modesec_Ranks["+"] = 1;
	modesec_Ranks["@"] = 0;
	modesec_Ranklist = "@+";

	# modesec_Temp: see comment on `353` vs. `366` below.
	split("", modesec_Temp);
}

# populate modesec_Temp using $0 (353 response)
## you might need to modify which of the input records these functions use to identify the channel and such.
function modesec_Stage(    Individuals, namestring) {
	namestring = substr(cut($0, 6), 2);

	split(namestring, Individuals, " ");

	for (i in Individuals) {
		if (Individuals[i] ~ "^[" modesec_Ranklist "]") {
			modesec_Temp[$5 " " substr(Individuals[i],2)] = substr(Individuals[i], 1, 1);
		} else {
			modesec_Temp[$5 " " Individuals[i]] = "n"
		}
	}
}

# move modesec_Temp's contents to modesec_Lookup (called after a 366 response)
function modesec_Commit() {
	for (i in modesec_Lookup) {
		if (i ~ ("^" $4 " ")) {
			delete modesec_Lookup[i];
		}
	}

	for (i in modesec_Temp) {
		modesec_Lookup[i] = modesec_Temp[i];
	}

	delete modesec_Temp;
}

function modesec_Nick(    U) {
	for (i in modesec_Lookup ) {
		if (i ~ (" " USER "$")) {
			split(i, U, " ");
			modesec_Lookup[U[1] " " substr($3, 2)] = modesec_Lookup[i]
			delete modesec_Lookup[i]
		}
	}
}

function modesec_Quit() {
	for (i in modesec_Lookup) {
		if (i ~ (" " USER "$")) {
			delete modesec_Lookup[i]
		}
	}
}

function modesec_Createranks (ranks) {
	delete modesec_Ranks

	modesec_Ranklist = substr(ranks, index(ranks,")"i) + 1)

	for (c = length(modesec_Ranklist); c > 0; c--) {
		modesec_Ranks[substr(modesec_Ranklist, c, 1)] = (c-1)
	}

	modesec_Ranks["n"] = length(modesec_Ranks);
}

# parse server-caps for a 'PREFIX' capability in order to rebuild modesec_Ranks
($2 == "005") {
	if (match($0,/PREFIX=\([^) ]+\)[^ ]+/) != 0) {
		modesec_Createranks(substr($0, RSTART, RLENGTH))
	}
}

## you might need to modify the response codes to match NAMES (353) and END-OF-NAMES (366)
($2 == "353") {
	modesec_Stage()
}

($2 == "366") {
	modesec_Commit()
}

($2 == "MODE") {
	send("NAMES " $3)
}

($2 == "PART") {
	delete modesec_Lookup[$3 " " USER]
}

($2 == "NICK") {
	modesec_Nick()
}

($2 == "JOIN") {
	modesec_Lookup[substr($3,2) " " USER]=" "
}

($2 == "QUIT") {
	modesec_Quit()
}
