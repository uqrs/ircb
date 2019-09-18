# url detection and title printing
BEGIN {
	URL_TITLEPIPE = "sed -nE 's_.*<title>(.*)</title>.*_\\1_p'"
	URL_CURLOPTS = "-L"

	url_Msg["err"] = "PRIVMSG %s :[%s] fatal: invalid or malformed URL."
	url_Msg["out"] = "PRIVMSG %s :[%s] %s"
}

function url_identify(url,    c, t) {
	split("", Output)

	c = sprintf("%s %s | %s",
		curl_compose(url), "-L", URL_TITLEPIPE)

	lsys(c, Output)

	return Output[1]
}

function url_Url(msg,    success)
{
	success = match(msg, /https?:\/\/[^ ]+/)
	while (success != 0) {

		t = url_identify(substr(msg, RSTART, RLENGTH))

		if (t == "")
			send(sprintf(url_Msg["err"],
				$3, "url => detect"))
		else
			send(sprintf(url_Msg["out"],
				$3, "url => detect", t))

		msg = substr(msg, RSTART + RLENGTH + 1)
		success = match(msg, /https?:\/\/[^ ]+/)
	}
}

(/https?:\/\/.+/) {
	url_Url($0)
}
