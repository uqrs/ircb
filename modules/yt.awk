# youtube API interfacer
# REQUIRES `jq` to be installed
# REQUIRES `curl.awk`
#
# FLAGS (GENERAL)
#    -V [q]   query for video
#    -C [q]   query for channels
BEGIN {
	# api keyfile
	yt_apikey = "./cfg/yt_apikey"

	YT_SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"
	YT_VIDEO_URL = "https://www.googleapis.com/youtube/v3/videos"
	YT_CHANNEL_URL = "https://www.googleapis.com/youtube/v3/channels"

	YT_JQ_INFO = ".items[0] | [.id, .snippet.channelTitle, .snippet.title, .contentDetails.duration, .statistics.viewCount, .statistics.likeCount, .statistics.dislikeCount][]"
	YT_JQ_ID = ".items[0].id.videoId"
	YT_JQ_CHANNEL_ID = ".items[0].id.channelId"
	YT_JQ_CHANNEL = ".items[0] | [.id, .snippet.title, .snippet.customUrl, .statistics.subscriberCount, .statistics.viewCount, .statistics.videoCount][]"

	# map jq output lines to fields
	# videos
	YTF_ID = 1
	YTF_CHANNEL = 2
	YTF_TITLE = 3
	YTF_DURATION = 4
	YTF_VIEWS = 5
	YTF_LIKES = 6
	YTF_DISLIKES = 7

	# channels
	YTF_ID = 1
	YTF_CHANNEL = 2
	YTF_URL = 3
	YTF_SUBSCRIBERS = 4
	YTF_VIEWS = 5
	YTF_VIDEOS = 6

	YT_VIDEO = 1
	YT_CHANNEL = 2

	YT_NORESULTS = -1

	YT_PAGESIZE = 10

	YTOPT_VIDEO = "V"
	YTOPT_CHANNEL = "C"

	yt_Msg["noquery"] = "PRIVMSG %s :[%s] fatal: must specify a search query."
	yt_Msg["noresults"] = "PRIVMSG %s :[%s] No results for query '%s'"
	yt_Msg["result"] = "PRIVMSG %s :[%s] %s\x02 - length:\x0F %s\x02 -\x0F %s\x02 views -\x0F %s↑ %s↓ - uploaded by\x02 %s\x02 -\x0F https://youtu.be/%s "
	yt_Msg["channel"] = "PRIVMSG %s :[%s] %s\x02 -\x0F %s\x02 videos,\x0F %s\x02 subscribers,\x0F %s views\x02 -\x0F https://youtube.com/%s "
}

function yt_comma(s) {
	return sh(sprintf("rev <<<'%s' | sed -E 's/(.{3})/\\1,/g; s/,$//' | rev", san(s)))
}

function yt_search(q, t, n,   apikey, Curl_data, Curl_headers, r, l) {
	split("", Curl_data)
	split("", Curl_headers)

	getline apikey <yt_apikey
	close(yt_apikey)

	if (!t)
		t = "video"
	if (!n)
		n = 1

	Curl_data["part"] = "snippet"
	Curl_data["order"] = "relevance"
	Curl_data["type"] = t
	Curl_data["maxResults"] = n
	Curl_data["key"] = apikey
	Curl_data["q"] = q

	Curl_headers["accept"] = "application/json"

	r = sh(curl_compose(YT_SEARCH_URL, Curl_headers, Curl_data) " | tr '\\n' ' '")
	l = sh(sprintf("jq '.items | length' <<<'%s'", san(r)))

	if (l == 0)
		return YT_NORESULTS
	else
		return r
}

function yt_video(id,    apikey, Curl_data, Curl_headers, r, l) {
	split("", Curl_data)
	split("", Curl_headers)

	getline apikey <yt_apikey
	close(yt_apikey)

	Curl_data["id"] = id
	Curl_data["part"] = "statistics,contentDetails,snippet"
	Curl_data["key"] = apikey
	Curl_headers["accept"] = "application/json"

	r = sh(curl_compose(YT_VIDEO_URL, Curl_headers, Curl_data) " | tr '\\n' ' '")
	l = sh(sprintf("jq '.items | length' <<<'%s'", san(r)))

	if (l == 0)
		return YT_NORESULTS
	else
		return r
}

function yt_channel(id,    apikey, Curl_data, Curl_headers, r, l) {
	split("", Curl_data)
	split("", Curl_headers)

	getline apikey <yt_apikey
	close(yt_apikey)

	Curl_data["id"] = id
	Curl_data["part"] = "snippet,statistics"
	Curl_data["key"] = apikey
	Curl_headers["accept"] = "application/json"

	r = sh(curl_compose(YT_CHANNEL_URL, Curl_headers, Curl_data) " | tr '\\n' ' '")
	l = sh(sprintf("jq '.items | length' <<<'%s'", san(r)))

	if (l == 0)
		return YT_NORESULTS
	else
		return r
}

function yt_Getopt(Options, args,    status) {
	status = getopt_Getopt(args, "V,C", Options)

	if (status == GETOPT_BADQUOTE) {
		send(sprintf(getopt_Msg["badquote"],
		     $3, "yt => getopt", Options[0]))
		return status

	} else if (status != GETOPT_SUCCESS) {
		send(sprintf(getopt_Msg["invalid"],
		     $3, "yt => getopt", Options[-1]))
		return status
	}

	status = getopt_Either(Options, "VC")

	if (status == GETOPT_COLLISION) {
		send(sprintf(getopt_Msg["collision"],
		     $3, "yt => getopt", Options[0], Options[-1]))
		return status

	} else if (Options[STDOPT] == GETOPT_EMPTY) {
		send(sprintf(yt_Msg["noquery"],
		     $3, "yt => getopt"))
		return GETOPT_NOARG

	} else if (status == GETOPT_NEITHER || YTOPT_VIDEO in Options) {
		return YT_VIDEO

	} else if (YTOPT_CHANNEL in Options) {
		return YT_CHANNEL
	}
}

($2 == "PRIVMSG") && ($4 ~ /^::yt?$/) {
	split("", Options)
	r = yt_Getopt(Options, cut($0, 5))

	if (r == YT_VIDEO) {
		r = yt_search(Options[STDOPT], "video", 1)

		if (r == YT_NORESULTS) {
			send(sprintf(yt_Msg["noresults"],
			     $3, "yt => search", Options[STDOPT]))
		} else {
			id = sh(sprintf("jq -r '%s' <<<'%s'", san(YT_JQ_ID), san(r)))
			r = yt_video(id)

			split("", V)
			lsh(sprintf("jq -r '%s' <<<'%s'", san(YT_JQ_INFO), san(r)), V)

			V[YTF_DURATION] = tolower(substr(V[YTF_DURATION], 3))
			V[YTF_VIEWS] = yt_comma(V[YTF_VIEWS])
			V[YTF_LIKES] = yt_comma(V[YTF_LIKES])
			V[YTF_DISLIKES] = yt_comma(V[YTF_DISLIKES])

			send(sprintf(yt_Msg["result"],
				$3, "yt => search", V[YTF_TITLE], V[YTF_DURATION], V[YTF_VIEWS], V[YTF_LIKES], V[YTF_DISLIKES], V[YTF_CHANNEL], V[YTF_ID]))
		}
	} else if (r == YT_CHANNEL) {
		r = yt_search(Options[STDOPT], "channel", 1)

		if (r == YT_NORESULTS) {
			send(sprintf(yt_Msg["noresults"],
			     $3, "yt => search", Options[STDOPT]))
		} else {
			id = sh(sprintf("jq -r '%s' <<<'%s'", san(YT_JQ_CHANNEL_ID), san(r)))
			r = yt_channel(id)

			split("", V)
			lsh(sprintf("jq -r '%s' <<<'%s'", san(YT_JQ_CHANNEL), san(r)), V)

			V[YTF_VIEWS] = yt_comma(V[YTF_VIEWS])
			V[YTF_SUBSCRIBERS] = yt_comma(V[YTF_SUBSCRIBERS])
			V[YTF_VIDEOS] = yt_comma(V[YTF_VIDEOS])

			if (V[YTF_URL] == "null")
				V[YTF_URL] = ("channel/" V[YTF_ID])

			send(sprintf(yt_Msg["channel"],
			     $3, "yt => search", V[YTF_CHANNEL], V[YTF_VIDEOS], V[YTF_SUBSCRIBERS], V[YTF_VIEWS], V[YTF_URL]))
		}
	}

	r = ""; id = "";
}
