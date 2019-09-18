# arch-linux package searcher for official repos
# REQUIRES `jq` to be installed
# REQUIRES `curl.awk`
#
# FLAGS (GENERAL)
#   -Q      query name or description (default)
#   -N      query description only
#   -D      query description only
#
#   -R [r]  comma-delimited list of repositories to search (-R only)
#   -a [a]  architecture (x86_64, i686, any)
#   -m [m]  maintainer
#   -f      flagged
#
#   -r [n]  display result 'n'
#   -p [n]  display a list of results from 'n*10' to 'n*10+10'
BEGIN {
	ALPS_URL = "https://www.archlinux.org/packages/search/json/"
	ALPS_JQ_RESULT = ".results[%d] | .pkgname + \" \" + .pkgver + \"-\" + .pkgrel + \" (\" + .arch + \") from \" + .repo + \": \" + .pkgdesc + \" (\" + .url + \")\""
	ALPS_JQ_PAGE = "[ .results[%d:%d][].pkgname ] | join(\", \")"

	ALPS_PAGESIZE = 10

	ALPSOPT_QUERY = "Q"
	ALPSOPT_NAME = "N"
	ALPSOPT_DESCRIPTION = "D"

	ALPSOPT_REPO = "R"
	ALPSOPT_ARCH = "a"
	ALPSOPT_MAINTAINER = "m"
	ALPSOPT_FLAGGED = "f"

	ALPSOPT_PAGE = "p"
	ALPSOPT_RESULT = "r"

	alps_Msg["opt-err"] = "PRIVMSG %s :[%s] fatal: erroneous options received."
	alps_Msg["opt-conflict"] = "PRIVMSG %s :[%s] fatal: conflicting options `%s` and `%s` specified."
	alps_Msg["opt-ns-query"] = "PRIVMSG %s :[%s] fatal: must specify a search query."
	alps_Msg["opt-resultltz"] = "PRIVMSG %s :[%s] fatal: specified result '%d' out of bounds [n < 1]."
	alps_Msg["opt-pageltz"] = "PRIVMSG %s :[%s] fatal: specified page '%d' out of bounds [n < 1]."
	alps_Msg["opt-nan"] = "PRIVMSG %s :[%s] fatal: Option `%s` expected a number, got '%s' instead."
	alps_Msg["no-results"] = "PRIVMSG %s :[%s] No results for query '%s'"
	alps_Msg["result"] = "PRIVMSG %s :[%s][%d/%d] %s"
	alps_Msg["page"] = "PRIVMSG %s :[%s][%d/%d] %s"
}

function alps_Search(input,    Options, argstring, success, Curl_data, Curl_headers, Output, nresults, result, mode, rmode, lstart, lend) {
	split("",Curl_data)
	split("",Curl_headers)
	split("",Output)


	split("",Options)
	argstring = cut(input, 5)

	success = getopt_Getopt(argstring, "Q,N,D,R:,a:,m:,f,r:,p:", Options)

	if (success != GETOPT_SUCCESS) {
		send(sprintf(alps_Msg["opt-err"],
		     $3, "alps => getopt", Options[0]))
		return
	} else {
		success = getopt_Either(Options, "QND")
		if (success == GETOPT_COLLISION) {
			send(sprintf(alps_Msg["opt-conflict"],
			     $3, "alps => getopt", "-" Options[0], "-" Options[-1]))
			return
		} else if (success == GETOPT_NEITHER || ALPSOPT_QUERY in Options)
			mode = "q"
		else if (ALPSOPT_NAME in Options)
			mode = "name"
		else if (ALPSOPT_DESC in Options)
			mode = "desc"
	}

	success = getopt_Either(Options, "pr")

	if (success == GETOPT_COLLISION) {
		send(sprintf(alps_Msg["opt-conflict"],
		     $3, "alps => getopt", "-" Options[0], "-" Options[-1]))
		return
	} else if (success == GETOPT_NEITHER) {
		Options[ALPSOPT_RESULT] = 1
	}

	if (Options[STDOPT] == GETOPT_EMPTY) {
		send(sprintf(alps_Msg["opt-ns-query"],
		     $3, "alps => search"))
		return
	}



	Curl_data[mode] = Options[STDOPT]
	if (ALPSOPT_REPO in Options)
		Curl_data["repo"] = Options[ALPSOPT_REPO]
	if (ALPSOPT_ARCH in Options)
		Curl_data["arch"] = Options[ALPSOPT_ARCH]
	if (ALPSOPT_MAINTAINER in Options)
		Curl_data["maintainer"] = Options[ALPSOPT_MAINTAINER]

	if (ALPSOPT_FLAGGED in Options)
		Curl_data["flagged"] = "Flagged"

	Curl_headers["accept"] = "application/json"

	curl_Get(Output, ALPS_URL, Curl_headers, Curl_data)



	nresults = sys(sprintf("jq '.results | length' <<<'%s'",
	    san(Output[1])))

	if (nresults == 0) {
		send(sprintf(alps_Msg["no-results"],
		     $3, "alps => search", Options[STDOPT]))
		return
	}

	if (ALPSOPT_RESULT in Options) {
		if (Options[ALPSOPT_RESULT] !~ /^[0-9]+$/) {
			send(sprintf(alps_Msg["opt-nan"],
			     $3, "alps => getopt", "-" ALPSOPT_RESULT, Options[ALPSOPT_RESULT]))
			return
		} else if (Options[ALPSOPT_RESULT] < 1) {
			send(sprintf(alps_Msg["opt-resultltz"],
				$3, "alps => getopt", Options[ALPSOPT_RESULT]))
			return
		} else if (Options[ALPSOPT_RESULT] > nresults) {
			Options[ALPSOPT_RESULT] = nresults
		}

		result = sys(sprintf("jq '%s' <<<'%s'",
			sprintf(ALPS_JQ_RESULT, Options[ALPSOPT_RESULT]-1), san(Output[1])))

		result = substr(result, 2, length(result)-2)

		send(sprintf(alps_Msg["result"],
			$3, "alps => search", Options[ALPSOPT_RESULT], nresults, result))


	} else if (ALPSOPT_PAGE in Options) {
		if (Options[ALPSOPT_PAGE] !~ /^[0-9]+$/) {
			send(sprintf(alps_Msg["opt-nan"],
			     $3, "alps => getopt", "-" ALPSOPT_PAGE, Options[ALPSOPT_PAGE]))
			return
		} else if (Options[ALPSOPT_PAGE] < 1) {
			send(sprintf(alps_Msg["opt-pageltz"],
			     $3, "alps => getopt", Options[ALPSOPT_PAGE]))
			return
		} else if (((Options[ALPSOPT_PAGE]-1) * ALPS_PAGESIZE) > nresults) {
			Options[ALPSOPT_PAGE] = int(nresults/ALPS_PAGESIZE)+1
		}

		lstart = ((Options[ALPSOPT_PAGE]-1) * ALPS_PAGESIZE)
		lend = lstart + ALPS_PAGESIZE

		result = sys(sprintf("jq '%s' <<<'%s'",
		       sprintf(ALPS_JQ_PAGE, lstart, lend), san(Output[1])))

		result = substr(result, 2, length(result)-2)

		send(sprintf(alps_Msg["page"],
		     $3, "alps => search", Options[ALPSOPT_PAGE], int(nresults/ALPS_PAGESIZE)+1, result))
	}
}

($2 == "PRIVMSG") && ($4 ~ /^::alps$/) {
	alps_Search($0)
}
