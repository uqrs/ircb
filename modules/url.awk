# url detection and title printing
BEGIN {
	URL_TITLEPIPE = "sed -nE 's_.*<title>(.*)</title>.*_\\1_p'"

	url_maxsize = 10485760 # 10MiB

	url_tmpdir = "/tmp/"

	url_Msg["notitle"] = "PRIVMSG %s :[%s] No title."
	url_Msg["out"] = "PRIVMSG %s :[%s] %s"
	url_Msg["large"] = "PRIVMSG %s :[%s] Page of content type %s exceeds maximum allowed size (%s > %s)"
	url_Msg["info"] = "PRIVMSG %s :[%s] %s"

	srand()
}

function url_htmltitle(url,    c, t) {
	split("", Output)

	c = sprintf("%s %s | %s",
		curl_compose(url), "-L", URL_TITLEPIPE)

	lsys(c, Output)

	return Output[1]
}

function url_headers(url, Output,    c, t, i, loc) {
	split("", Output)

	c = sprintf("%s %s",
	  	curl_compose(url), "-IL")

	lsys(c, Output)

	if (length(Output) == 0)
		return CURL_ERROR

	for (i in Output) {
		loc = index(Output[i]," ")
		Output[tolower(substr(Output[i],1,loc-1))] = tolower(substr(Output[i],loc+1))
		gsub(/[\n\r]/, "", Output[tolower(substr(Output[i],1,loc-1))])
	}

	return CURL_SUCCESS
}

function url_Url(msg,    success, t, L, f, c, i, url)
{
	success = match(msg, /https?:\/\/[^ ]+/)
	while (success != 0) {
		url = substr(msg, RSTART, RLENGTH)
		url_headers(url, L)

		if (int(L["content-length:"]) > url_maxsize) {
			send(sprintf(url_Msg["large"],
			     $3, "url => detect", L["content-type:"], L["content-length:"], url_maxsize))
		} else if (L["content-type:"] ~ /text\/html/) {
			t = url_htmltitle(url)

			if (t == "")
				send(sprintf(url_Msg["notitle"],
					$3, "url => detect"))
			else
				send(sprintf(url_Msg["out"],
					$3, "url => detect", t))
		} else {
			f = url_tmpdir "ircb-" int(rand()*1000000)

			i = sys(sprintf("%s %s && file %s",
			    curl_compose(url), " -L --output " f, f))

			send(sprintf(url_Msg["info"],
			     $3, "url => detect", cut(i,2)))

			sys(sprintf("rm %s", f))
		}

		msg = substr(msg, RSTART + RLENGTH + 1)
		success = match(msg, /https?:\/\/[^ ]+/)
	}
}

($2 == "PRIVMSG") && ($0 ~ /https?:\/\/.+/) {
	url_Url($0)
}
