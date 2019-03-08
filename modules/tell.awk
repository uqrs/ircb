#
# memoserv clone for networks that dont have memoserv
#
BEGIN {
  ### the file in which tells should be permanently stored
  mtell_persist="./data/tell"

  #
  # messages are stored in this file using:
  #   recipient\x1Esender\x1Edate\x1Emessage
  #

  #
  # command templates where we can later slot variables into.
  #
  mtell_RETRIEVE=sprintf("sed -Ei '/^%s\x1E/I { w /dev/stdout\nd }' '%s'","%s",san(mtell_persist));
  mtell_PENDING=sprintf("grep '^%s\x1E' '%s' | wc -l","%s",san(mtell_persist));

  #
  # make a cache string of every user who has a message queued for them.
  # this would mean we don't have to grep for a user everytime they send a message.
  #
  mtell_cache=(" " sys(                                                                            \
    sprintf("cut -d $(echo -e '\x1E') -f 1 < '%s' | sort | uniq | tr '\n' ' '",san(mtell_persist)) \
  ) " ");
}

#
# command: store a tell for someone
#
($1 ~ /^#/) && ($6 ~ /^:(t|tell)$/) {
   if(!length($8)){send("PRIVMSG " $1 " :Usage: tell [recipient] [message]");next;}

   #
   # Construct the required message string:
   #
   mtell_date=sys("date +%s");
   mtell_message=$0;sub(/^[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +/,"",mtell_message);
   gsub("\x1E","",mtell_message);
   printf("%s\x1E%s\x1E%s\x1E%s\n",$7,$5,mtell_date,mtell_message) >> mtell_persist;fflush();

   #
   # add the recipient's name to the cache if it's not already in there
   #
   (mtell_cache !~ (" " $7 " ")) && (mtell_cache=(mtell_cache $7 " "));
}

#
# command: retrieve and send all pending messages for this user.
#
($1 ~ /^#/) && ($6 ~ /^:(showtells)$/) {
   #
   # collect all the tells in array mtell_Tells;
   #
   arr(mtell_Tells);
   lsys(                                          \
     sprintf(mtell_RETRIEVE,$5),mtell_Tells       \
   );

   #
   # send all of them back to back;
   #
   for ( mtell_tell in mtell_Tells ) {
     split(mtell_Tells[mtell_tell],mtell_Tellparts,"\x1E");

     mtell_secondssince=(int(sys("date +%s") - int(mtell_Tellparts[3])));
     mtell_yearssince  =(mtell_secondssince-(   mtell_secondssince%31557600))/31557600;           mtell_secondssince=(mtell_secondssince-(mtell_yearssince*31557600));
     mtell_dayssince   =(mtell_secondssince-((  mtell_secondssince%31557600)%86400))/86400;       mtell_secondssince=(mtell_secondssince-(mtell_dayssince*86400));
     mtell_hourssince  =(mtell_secondssince-((( mtell_secondssince%31557600)%86400)%3600))/3600;  mtell_secondssince=(mtell_secondssince-(mtell_hourssince*3600));
     mtell_minutessince=(mtell_secondssince-((((mtell_secondssince%31557600)%86400)%3600)%60))/60;

     send(                                                      \
      sprintf(                                                  \
        "PRIVMSG %s :[%s => %s][%4dy %3dd %2dh %2dm ago] %s",   \
        $5,                                                     \
        mtell_Tellparts[2],                                     \
        mtell_Tellparts[1],                                     \
        mtell_yearssince,                                       \
        mtell_dayssince,                                        \
        mtell_hourssince,                                       \
        mtell_minutessince,                                     \
        mtell_Tellparts[4]                                      \
      )                                                         \
     );
   };

   delete mtell_Tells;
}

#
# retrieve the amount of pending messages for this person.
#
($1 ~ /^#/) && (mtell_cache ~ (" " $5 " ")) {
   #
   # remove the recipient's name from the cache
   #
   sub(" " $5 " "," ",mtell_cache);

   #
   # get the amount of pending tells
   #
   mtell_pending=sys(                        \
     sprintf(mtell_PENDING,$5)               \
   )

   #
   # inform them
   #
   send(                                                                            \
     sprintf("PRIVMSG %s :You have %d messages in your inbox.",$5,mtell_pending)    \
   )
}


END {
   close(tell_persist);
}