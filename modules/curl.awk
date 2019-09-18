BEGIN {
	curl_bin = "curl"
	curl_flags = "-s"

	CURL_ERROR = 1
	CURL_SUCCESS = 0
}

function curl_compose (url, Headers, Data)
{
	c = sprintf("%s -G %s --request GET --url '%s'",
		curl_bin, curl_flags, san(url), pipe)

	for (h in Headers) {
		if (Headers[h] != "")
			c = (c " --header '" h ": " san(Headers[h]) "'")
		else
			c = (c " --header '" san(Headers[h]) "'")

	}

	for (d in Data) {
		if (Data[d] != "")
			c = (c " --data-urlencode '" d "=" san(Data[d]) "'")
		else
			c = (c " --data-urlencode '" san(Data[d]) "'")
	}

	return c
}

function curl_Get (Output, url, Headers, Data)
{
	lsys(curl_compose(url, Headers, Data), Output)

	if (length(Output) == 0)
		return CURL_ERROR
	else
		return CURL_SUCCESS
}
