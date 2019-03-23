###
# memoserv clone for networks that dont have memoserv
#
BEGIN {
  ### the file in which tells should be permanently stored
  tell_persist="./data/tell"
  #
  # messages are stored in this file using:
  #   [recipient] [sender] [date] [message]\n
  #

  #
  # generate a cache table that stores the amount of messages each individual has queued
  #   tell_Cache[user] = number;
  #
  array(tell_Cache);

  #
  # cache every tell found in the tellfile
  #
  tell_initcache();
}

###
# function: add a user to the cache
#
function tell_cache(user){
   tell_Cache[user]=sys(sprintf("awk '$1 == \"%s\"' < '%s' | wc -l",user,tell_persist));
}

###
# function: initialise cache for all users
#
function tell_initcache(		user,Arr){
   array(Arr);

   lsys(                                             \
     sprintf("cut -d ' ' -f 1 <'%s' | sort | uniq",san(tell_persist)), \
     Arr                                             \
   )

   for (user in Arr) {
      tell_cache(Arr[user]);
   }
}

###
# function: clear a user from the cache
#
function tell_clearcache(user){
   delete tell_Cache[user];
}

###!!
# Function: add a tell to the cache
#    invoked by: `tell`
###
function tell_Add(		message){
   # 
   # variable initialisation
   #
   message=cut($0,6);

   #
   # store the actual tell into a file
   #
   printf("%s %s %s %s\n",$5,USER,sys("date +%s"),message) >> tell_persist; close(tell_persist);

   #
   # print confirmation that the tell was queued
   #
   send(                                                                         \
     sprintf(                                                                    \
       "PRIVMSG %s :[%s => %s][@%s] Message of length (%s) queued successfully", \
       $3,                                                                       \
       USER,                                                                     \
       $5,                                                                       \
       sys("date +%s"),                                                          \
       length(message)                                                           \
     )                                                                           \
   )

   #
   # add the user to the cache
   #
   tell_cache($5);
}

###!!
# Function: send all tells queued for a user.
#    invoked by: `showtells`
function tell_Get(		tell,Tells,Parts,ys,ds,hs,ms,ss){
   #
   # remove the recipient's name from the cache
   #
   tell_clearcache(USER);

   #
   # collect all tells queued for this user into array Tells;
   #
   lsys(                                                                          \
       sprintf("sed -Ei '/^%s /I { w /dev/stdout\nd }' '%s'",USER,tell_persist),  \
       Tells                                                                      \
   );

   #
   # send all of them back to back;
   #
   for ( tell in Tells ) {
     split(Tells[tell],Parts," ");

     #
     # calculate the time since this message was sent in a human-readable format.
     #
     ss=(int(sys("date +%s") - int(Parts[3])));
     ys=(ss-(   ss%31557600))/31557600;           ss=(ss-(ys*31557600));
     ds=(ss-((  ss%31557600)%86400))/86400;       ss=(ss-(ds*86400));
     hs=(ss-((( ss%31557600)%86400)%3600))/3600;  ss=(ss-(hs*3600));
     ms=(ss-((((ss%31557600)%86400)%3600)%60))/60;

     send(                                                      \
      sprintf(                                                  \
        "PRIVMSG %s :[%s => %s][%4dy %3dd %2dh %2dm ago] %s",   \
        Parts[1],                                               \
        Parts[2],                                               \
        Parts[1],                                               \
        ys,                                                     \
        ds,                                                     \
        hs,                                                     \
        ms,                                                     \
        acut(Parts,4)                                           \
      )                                                         \
     );
   };
}

# # #
# command: store a tell for someone
#
($2 == "PRIVMSG") && ($4 ~ /^::(t|tell)$/) {
   if(!length($5)){send("PRIVMSG " $3 " :Usage: tell [recipient] [message]");}
   else           {tell_Add();}
}

# # #
# command: retrieve and send all pending messages for this user.
#
($2 == "PRIVMSG") && ($4 ~ /^::(showtells)$/) {tell_Get()};
# # #
# retrieve the amount of pending messages for this person.
#
($2 == "PRIVMSG") && (USER in tell_Cache) {
   #
   # inform them
   #
   send(                                                                                    \
     sprintf("PRIVMSG %s :You have %d messages in your inbox.",USER,tell_Cache[USER])       \
   )

   #
   # remove the recipient's entry from the cache
   #
   tell_clearcache(USER);
}

END {close(tell_persist);}