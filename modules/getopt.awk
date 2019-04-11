###
# primitive `getopt` wrapper.
# takes three arguments:
#   `options` as a direct argument to `-o` for `getopt`
#   `optstring` as the string to parse.
#   `Fill` as the table to which the parsed arguments should be stored.
#
function getopt_Getopt(options,optstring,Fill,		getopt_out,Parse,i,current_opt,current_arg) {
	getopt_out=sys(							\
		sprintf(						\
			"getopt -u -o '%s' -- $(echo '%s') 2>&1",	\
			san(options),					\
			san(optstring)					\
		)							\
	);

	#
	# getopt prepends a space to non-erroneous outputs.
	# use this to detect whether an error has occurred.
	#
	if (getopt_out !~ /^ /) {
		#
		# an error occurred, invalid flag.
		#
		Fill[0]=getopt_out;
		return 1;
	} else {
		#
		# no errors occurred, begin parsing getopt output.
		#
		# begin parsing arguments in a uh... hacky manner. Forgive me.
		#
		split(getopt_out,Parse);

		#
		# the default opt string is `--`
		#
		current_opt="--";
		current_arg=" ";

		#
		# dunno why, but i can't get awk to traverse the array
		# sequentially using `for i in Parse`.
		#
		for ( i=1; i<=length(Parse); i++ ) {
			#
			# if it's an option:
			#
			if ( Parse[i] ~ /^-/ ) {
				Fill[current_opt]=(Fill[current_opt] "");
				current_opt=Parse[i];
			} else {
				Fill[current_opt]=(Fill[current_opt] Parse[i] " ");
				current_opt="--";
			}
		}
		#
		# take care of trailing spaces.
		#
		for ( i in Fill ) {
			gsub(/ $/,"",Fill[i]);
		}

		return 0;
	}
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
	which="-[" rsan(which) "]";

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
	which="-[" rsan(which) "]";

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
