# url detection and title printing
BEGIN {
	URL_TITLEPIPE = "sed -nE 's_.*<title>(.*)</title>.*_\\1_p'"

	url_maxsize = 10485760 # 10MiB

	url_tmpdir = "/tmp/"

	url_Msg["notitle"] = "PRIVMSG %s :[%s] No title."
	url_Msg["out"] = "PRIVMSG %s :[%s] %s"
	url_Msg["large"] = "PRIVMSG %s :[%s] Page of content type %s exceeds maximum allowed size (%s > %s)"
	url_Msg["info"] = "PRIVMSG %s :[%s] %s"

	# &amp; is handled separately since using & as a second argument to (g)sub
	# substitutes the entire character code back in.
	url_Codes["&quot;"] = 34
	url_Codes["&nbsp;"] = 160
	url_Codes["&apos;"] = 39
	url_Codes["&lt;"] = 60
	url_Codes["&gt;"] = 62

	srand()
}

function url_htmltitle(url,    c, t, a, C, d, i, Output) {
	split("", Output)

	c = sprintf("%s %s | %s",
		curl_compose(url), "-L", URL_TITLEPIPE)
	lsh(c, Output)


	a = Output[1]

	if (a) {
		split("", C)

		match(a, /&(#[0-9]+|[a-zA-Z]+);/)

		while (RSTART != 0) {
			d = substr(a, RSTART, RLENGTH)

			if (d in url_Codes)
				C[d] = url_Codes[d]
			else
				C[d] = int(substr(d, 3, length(d) - 3))

			a = substr(a, RSTART + RLENGTH + 1)
			match(a, /&(#[0-9]+|[a-zA-Z]+);/)
		}
	}


	gsub(/&amp;/, "\\&", Output[1]) # special case; see url_Codes[]

	for (i in C)
		gsub(i, sprintf("%c", C[i]), Output[1])

	return Output[1]
}

function url_headers(url, Output,    c, t, i, loc) {
	split("", Output)

	c = sprintf("%s %s",
	  	curl_compose(url), "-IL")

	lsh(c, Output)

	if (length(Output) == 0)
		return CURL_ERROR

	for (i in Output) {
		loc = index(Output[i]," ")
		Output[tolower(substr(Output[i],1,loc-1))] = tolower(substr(Output[i],loc+1))
		gsub(/[\n\r]/, "", Output[tolower(substr(Output[i],1,loc-1))])
	}

	return CURL_SUCCESS
}

function url_Url(msg,    success, t, L, f, c, i, url, rs, rl)
{
	success = match(msg, /https?:\/\/[^ ]+/)
	rs = RSTART
	rl = RLENGTH

	while (success != 0) {
		split("", L)
		url = substr(msg, rs, rl)
		url_headers(url, L)

		if (length(L) != 0) {
			if (int(L["content-length:"]) > url_maxsize) {
				send(sprintf(url_Msg["large"],
				     $3, "url => detect", L["content-type:"], L["content-length:"], url_maxsize))

			} else if (L["content-type:"] ~ /text\/html/) {
				t = url_htmltitle(url)

				if (t == "") {
					send(sprintf(url_Msg["notitle"],
						$3, "url => detect"))
				} else {
					send(sprintf(url_Msg["out"],
						$3, "url => detect", t))
			}

			} else {
				f = url_tmpdir "ircb-" int(rand()*1000000)

				i = sh(sprintf("%s %s && file %s",
				    curl_compose(url), " -L --output " f, f))

				send(sprintf(url_Msg["info"],
				     $3, "url => detect", cut(i,2)))

				sh(sprintf("rm %s", f))
			}
		}

		msg = substr(msg, rs + rl + 1)
		success = match(msg, /https?:\/\/[^ ]+/)
		rs = RSTART
		rl = RLENGTH
	}
}

($2 == "PRIVMSG") && ($0 ~ /https?:\/\/.+/) {
	url_Url($0)
}
