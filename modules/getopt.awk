#
# `input` is the option string that is to be parsed.
# `accept` is a string that describes the list of accepted flags in the form of:
#    [flag][:],
#    where an optional `:` denotes that this flag accepts arguments.
#    if there is no `:`, then every argument specified after this flag will
#    automatically be deferred to `--` (stdarg).
#
# return values: `1` on invalid flag (Out[0] = the invalid flag).
#                `2` on single `-` (TODO: have this treated as an argument).
#                `3` on unterminated string (Out[0] = the option this invalid string was for).
#                `0` on no errors
#
function getopt_Getopt(input,accept,Out,	POSITION,OPT_ARR,REMAINDER,CHAR,CURRENT_OPT,OPT_END,OPT_ACCEPT_TEMP,OPT_ACCEPT,TERMINATOR,TERMINATOR_LOC,CURRENT_ARG) {
	POSITION=1;
	REMAINDER=(input " ");
	CURRENT_OPT="--"
	CHAR;
	array(OPT_ARR);
	array(Out);

	#
	# parse the 'accept' arguments into an array so that:
	#    OPT_ACCEPT[<option>] = <: or ' '>
	#
	split(accept,OPT_ACCEPT_TEMP,",");
	for ( i in OPT_ACCEPT_TEMP ) {
		OPT_ACCEPT[substr(OPT_ACCEPT_TEMP[i],1,1)]=substr(OPT_ACCEPT_TEMP[i],2,1);
	}
	delete OPT_ACCEPT_TEMP;

	while ( REMAINDER != "" ) {
		#
		# the plan is to parse REMAINDER from left-to-right
		# after we parse something significant (an option, an argument, etc)
		# we truncate the already-parsed portion of REMAINDER and continue
		# until REMAINDER is completely empty.
		#
		# This means that the first character in REMAINDER will always be
		# either a:
		#    - : it's a flag.
		#    " : it's a string.
		# other: it's an unquoted argument
		#
		# When a `-` is encountered, all of the characters
		# that follow will be individually interpreted as
		# individual options. If the final character in
		# this string accepts arguments (OPT_ACCEPT[flag] = ":") then
		# the `CURRENT_OPT` argument is set to the value of `flag`.
		# otherwise, it is set to `--` (stdarg) by default.
		#
		# When a quote or other non-whitespace character is encountered,
		# everything between the current character and TERMINATOR is
		# interpreted as an option.
		#
		# TERMINATOR is either:
		# - a single, unescaped whitespace character (` `) (unquoted argument)
		# - a single, unescaped double-quote (`"`)         (double-quoted string)
		# - a single apostrophe (`'`)                      (single-quoted string)
		#
		# In the process of looking for an unescaped TERMINATOR, this function will:
		# - Look for a TERMINATOR somewhere.
		# - Look to see whether a group of backslashes occur in front of the TERMINATOR.
		# - Check to see if the number of backslashes are even (not escaped) or odd (escaped).
		#   - If even: commit the fully-parsed option to CURRENT_OPT.
		#   - If odd: store the partially-parsed option in `CURRENT_ARG` and skip ahead
		#             looking for another TERMINATOR, repeating the process.
		#
		match(REMAINDER,/[^ ]/);

		POSITION=RSTART;
		CHAR=substr(REMAINDER,RSTART,1);

		if ( CHAR == "-" ) {
			#
			# it's an option.
			#
			# find where the next whitespace occurs.
			#
			OPT_END=index(REMAINDER," ");
			if ( (RSTART + 1) == OPT_END ) {
				#
				# just a lone `-` with no options behind it.
				#
				return 2;
			} else {
				#
				# get the list of options and go through these one-by-one.
				#
				split(						\
					substr(REMAINDER,RSTART+1,OPT_END-2),	\
					OPT_ARR,				\
					""					\
				)

				for ( OPT=1 ; OPT <= length(OPT_ARR) ; OPT++ ) {
					if ( !(OPT_ARR[OPT] in OPT_ACCEPT) ) {
						#
						# option is not accepted; throw a fit:
						#
						Out[0]=OPT_ARR[OPT];
						return 1;
					} else {
						Out[OPT_ARR[OPT]]="";
						if ( OPT_ACCEPT[OPT_ARR[OPT]] == ":" ) {
							CURRENT_OPT=OPT_ARR[OPT];
						} else {
							CURRENT_OPT="--";
						}
					}
				}
				REMAINDER=substr(REMAINDER,OPT_END);
				sub(/^ +/,"",REMAINDER);
			}
		} else {
			if ( CHAR == "\"" )     { TERMINATOR="\""}
			else if ( CHAR == "'" ) { TERMINATOR="'" }
			else                    { REMAINDER=(" " REMAINDER); TERMINATOR=" " }
			REMAINDER=substr(REMAINDER,2);
			TERMINATOR_LOC=index(REMAINDER,TERMINATOR);

			#
			# return pre-emptively if no matching quotes were found.
			#
			if (TERMINATOR_LOC == 0 ) {Out[0]=CURRENT_OPT;return 3;}

			#
			# keep looking for backslashes until we find no more
			#
			while ( index(REMAINDER,"\\") != 0 ) {
				match(REMAINDER,/\\+/);
				#
				# check to see: is the amount of bacskslashes even or uneven?
				#
				CURRENT_ARG=(CURRENT_ARG substr(REMAINDER,1,RSTART+RLENGTH))
				sub("\\\\" TERMINATOR "$",TERMINATOR,CURRENT_ARG);
				REMAINDER=substr(REMAINDER,RSTART+RLENGTH+1);
				TERMINATOR_LOC=index(REMAINDER,TERMINATOR);

				if ( (RLENGTH % 2 != 0) && (RSTART+RLENGTH == TERMINATOR_LOC) ) {
					# if odd: that's an unescaped backslash. Keep looking
					# for more backslashes.
					#
					# if no terminator was found, we have an error:
					# no matching close-brace found.
					#
					if ( TERMINATOR_LOC == 0 ) {Out[0]=CURRENT_OPT;return 3;}
				}
			}
			Out[CURRENT_OPT]=Out[CURRENT_OPT] " " CURRENT_ARG substr(REMAINDER,1,TERMINATOR_LOC-1);
			CURRENT_ARG="";
			CURRENT_OPT="--";
			REMAINDER=substr(REMAINDER,TERMINATOR_LOC+1);
		}
	}
	#
	# clean up all the options: deal with backslashes and leading spaces.
	#
	for ( i in Out ) {
		gsub("\\\\\\\\","\\",Out[i]);
		sub(/ *$/,"",Out[i]);
		sub(/^ */,"",Out[i]);
	};

	return 0;
}
#
# scour through Options, checking to make sure only one flag specified in `which` is present.
# `which` is just `QRS` for ensuring only one of -Q, -R or -S is supplied.
#
# returns: `0` on one-found  (Options[0] = the found flag)
#          `1` on none-found (Options[0] = "")
#          `2` on collission (Options[0] = first found flag; Options[-1] = second found flag;)
#
function getopt_Either(Options,which,		found) {
	#
	# turn `which` into a regex
	#
	which="[" rsan(which) "]";

	for ( i in Options ) {
		if (i ~ which) {
			if (found){
				#
				# collission found!
				#
				Options[0] =found;
				Options[-1]=i;
				return 2;
			}
			#
			# found a flag
			#
			else {found=i};
		}
	}
	#
	# exit code
	#
	if (found) {Options[0]=found;return 0;} 
	else       {return 1;}
}

#
# go through `Options`, returning an error if any of the flags in `which` are found.
#
# returns: `0` on none-found (Options[0] = "");
#          `1` on one-found  (Options[0] = the found flag);
#
function getopt_Uncompatible(Options,which) {
	#
	# turn `which` into a regex.
	#
	which="[" rsan(which) "]";

	for ( i in Options ) {
		if (i ~ which) {
			#
			# found a blacklisted flag!
			#
			Options[0]=i;
			return 1;
		}
	}
	#
	# no blacklisted flags found...
	#
	return 0;
}
