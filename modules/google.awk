# google API interfacer
# REQUIRES `jq` to be installed
# REQUIRES `curl.awk`
#
# FLAGS (GENERAL)
#    -S [q]   regular search query
#    -I [q]   query for images
BEGIN {
	# api keyfile
	google_apikey = "./cfg/google_apikey"
	google_cx_id = "CHANGE_THIS"

	GOOGLE_SEARCH_URL = "https://www.googleapis.com/customsearch/v1"

	GOOGLE_JQ_RESULT = ".items[0] | [.title, .link, .snippet][]"

	# map search output lines to fields
	GOOGLEF_TITLE = 1
	GOOGLEF_LINK = 2
	GOOGLEF_SNIPPET = 3

	# erroneous exit codes
	GOOGLE_NORESULTS = -1

	# options
	GOOGLEOPT_SEARCH = "S"
	GOOGLEOPT_VIDEO = "I"

	google_Msg["noquery"] = "PRIVMSG %s :[%s] fatal: must specify a search query."
	google_Msg["result"] = "PRIVMSG %s :[%s] %s \x02-\x0F %s\x02 -\x0F %s"
	google_Msg["noresults"] = "PRIVMSG %s :[%s] fatal: no results for query '%s'"
}

function google_search(q,    apikey, Curl_data, Curl_headers, r, l) {
	split("", Curl_data)
	split("", Curl_headers)

	getline apikey <google_apikey
	close(google_apikey)

	Curl_data["key"] = apikey
	Curl_data["q" ] = q
	Curl_data["cx"] = google_cx_id

	Curl_headers["accept"] = "application/json"

	r = sh(curl_compose(GOOGLE_SEARCH_URL, Curl_headers, Curl_data) " | tr '\\n' ' '")
	l = sh(sprintf("jq '.items | length' <<<'%s'", san(r)))

	if (l == 0)
		return GOOGLE_NORESULTS
	else
		return r
}

function google_Getopt(Options, args,    status) {
	status = getopt_Getopt(args, "S,I", Options)

	if (status == GETOPT_BADQUOTE) {
		send(sprintf(getopt_Msg["badquote"],
		     $3, "google => getopt", Options[0]))
		return status

	} else if (status != GETOPT_SUCCESS) {
		send(sprintf(getopt_Msg["invalid"],
		     $3, "google => getopt", Options[-1]))
		return status
	}

	status = getopt_Either(Options, "SI")

	if (status == GETOPT_COLLISION) {
		send(sprintf(getopt_Msg["collision"],
		     $3, "google => getopt", Options[0], Options[-1]))
		return status

	} else if (Options[STDOPT] == GETOPT_EMPTY) {
		send(sprintf(google_Msg["noquery"],
		     $3, "google => getopt"))
		return GETOPT_NOARG

	} else if (status == GETOPT_NEITHER || GOOGLEOPT_SEARCH in Options) {
		return GOOGLEOPT_SEARCH

	} else if (GOOGLEOPT_IMAGE in Options) {
		return GOOGLEOPT_IMAGE
	}
}

($2 == "PRIVMSG") && ($4 ~ /^::g(oogle)?$/) {
	split("", Options)
	r = google_Getopt(Options, cut($0, 5))

	if (r == GOOGLEOPT_SEARCH) {
		r = google_search(Options[STDOPT])

		if (r == GOOGLE_NORESULTS) {
			send(sprintf(google_Msg["noresults"],
			     $3, "google => search", Options[STDOPT]))
		} else {
			split("", R)
			lsh(sprintf("jq -r '%s' <<<'%s'", san(GOOGLE_JQ_RESULT), san(r)), R)

			send(sprintf(google_Msg["result"],
				$3, "google => search", R[GOOGLEF_LINK], R[GOOGLEF_TITLE], R[GOOGLEF_SNIPPET]))

		}
	} else if (r == GOOGLEOPT_IMAGE) {
		send(sprintf("PRIVMSG %s :[%s] To be implemented.",
		     $3, "google => image"))
	}

	r = ""
}
