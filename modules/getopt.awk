BEGIN {
	GETOPT_SUCCESS = 0
	GETOPT_INVALID = 1
	GETOPT_BADQUOTE = 2
	GETOPT_NEITHER = 1
	GETOPT_COLLISION = 2
	GETOPT_INCOMPATIBLE = 1

	STDOPT = "--"
	GETOPT_EMPTY = ""
}

function getopt_tokenise(input, T) {
	match(input, /\\*([^ "'\-\\]+|"|'|-+| +)/)

	while (RSTART) {
		T[length(T)+1] = substr(input, RSTART, RLENGTH)
		input = substr(input, RSTART + RLENGTH)

		match(input, /\\*([^ "'\-\\]+|"|'|-+| +)/)
	}
}

function getopt_Getopt(input, accept, Output,    term, i, T, F, o, escaped, copt, carg, lock, A_tmp, A, a) {
	split("", Output)

	split(accept, A_tmp, ",")

	for (a in A_tmp) {
		A[substr(A_tmp[a],1,1)] = substr(A_tmp[a],2,1)
	}

	input = (input " ")
	getopt_tokenise(input, T)
	copt = STDOPT

	for (i = 1; i <= length(T); i++) {
		match(T[i], /^\\+[^\\]/)
		if (RSTART == 0 || (RLENGTH-1) % 2 == 0) {
			escaped = 0
		} else {
			escaped = 1
			# \" => "
			# \- => -
			# etc.
			T[i] = substr(T[i], 1, RLENGTH - 2) substr(T[i], RSTART + RLENGTH - 1)
		}
		gsub(/\\\\/, "\\", T[i])

		if (T[i] !~ /[ "'-]/ || escaped) {
			carg = carg T[i]

		} else if (T[i] ~ /"/) {
			if (term == "\"")
				term = ""
			else if (term == "'")
				carg = carg T[i]
			else
				term = "\""

		} else if (T[i] ~ /'/) {
			if (term == "'")
				term = ""
			else if (term == "\"")
				carg = carg T[i]
			else
				term = "'"

		} else if (T[i] ~ /^\\*-/) {
			if (T[i] ~ /^\\*--$/ && !lock) {
				copt = STDOPT
				lock = 1
			} else if (lock || term || carg) {
				carg = carg T[i]
			} else {
				if (!(i+1 in T) || T[i+1] ~ /["' ]/) {
					carg = carg T[i]
				} else {
					# we handle the next token here instead of letting the rest of the loop handle it
					split(T[++i], F, "")

					Output[copt] = Output[copt] carg
					carg = ""

					for (o = 1; o <= length(F); o++) {
						Output[F[o]] = ""

						if (!(F[o] in A)) {
							Output[-1] = F[o]

							return GETOPT_INVALID
						} else if (A[F[o]] == ":") {
							copt = F[o]
						}
					}
				}
			}

		} else if (T[i] ~ /^ +$/) {
			if (term) {
				carg = carg T[i]
			} else if (!term && carg) {
				if (Output[copt] == "")
					Output[copt] = Output[copt] carg
				else
					Output[copt] = Output[copt] " " carg

				carg = ""
				copt = STDOPT
			}
		}
	}

	if (term)
		return GETOPT_BADQUOTE
	else
		return GETOPT_SUCCESS
}

function getopt_Either (Options, which,    found, i) {
	which = "[" rsan(which) "]"

	for (i in Options) {
		if (i ~ which) {
			if (found) {
				Options[0] = found
				Options[-1] = 1
				return GETOPT_COLLISION

			} else {
				found = i
			}
		}
	}

	if (found) {
		Options[0] = found
		return GETOPT_SUCCESS
	} else {
		return GETOPT_NEITHER
	}
}

function getopt_Incompatible (Options, which) {
	which = "[" rsan(which) "]"

	for (i in Options) {
		if (i ~ which) {
			Options[0] = i
			return GETOPT_INCOMPATIBLE
		}
	}

	return GETOPT_SUCCESS
}
