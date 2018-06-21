#! /bin/bash

VERSION="1.0.0"

#######################
### BEFIN FUNCTIONS ###
#######################

#### Variable Gathering Functions ####

function fn_url_vars {
   read -p "Enter the URL That you need to have monitored: " URL
   if [[ $( echo $URL | grep -ci "^HTTP" ) -eq 0 ]]; then
      DOMAIN=$URL
      URL="http://""$URL"
   else
      DOMAIN=$( echo $URL | sed -e "s/^[Hh][Tt][Tt][Pp][Ss]*:\/\///" )
   fi
   if [[ $( echo $URL | grep -c "https://" ) -gt 0 ]]; then
      IP_PORT="443"
      SERVER_STRING=$URL
   else
      IP_PORT="80"
      SERVER_STRING=$DOMAIN
   fi

   echo
   echo "When checking that URL, what string of characters will this script be searching for?"
   echo "(The search is done using 'egrep -c \"\$CHECK_STRING\"'. It's up to you to compensate"
   read -p "for any weirdness that might result.): " CHECK_STRING

   echo
   echo "Enter the IP Address that this URL should be monitored on. (Or just press enter"
   echo "to have the IP resolved via DNS) (NOTE: this feature requires curl 7.21.3"
   read -p "or later. If that version is not present, any input here will be ignored.): " IP_ADDRESS
   curl --resolve google.com:80:127.0.0.1 http://google.com > /dev/null 2>&1
   STATUS=$?
   if [[ $STATUS == 2 || -z $IP_ADDRESS || $( echo $IP_ADDRESS | grep -c "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$" ) = 0 ]]; then
      IP_ADDRESS=false
   else
      SERVER_STRING="$SERVER_STRING at $IP_ADDRESS"
   fi
   DOMAIN="$( echo $DOMAIN | sed 's/^\([^/]*\).*$/\1/' )"

   fn_email_address

   fn_url_confirm
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_ping_vars {
   read -p "Enter the domain or IP that you wish to ping: " DOMAIN
   DOMAIN=$( echo $DOMAIN | sed -e "s/^[Hh][Tt][Tt][Pp][Ss]*:\/\///" )
   DOMAIN="$( echo $DOMAIN | sed 's/^\([^/]*\).*$/\1/' )"
   if [[ $( echo $DOMAIN | egrep "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$" | wc -l ) -eq 0 ]]; then
      IP_ADDRESS=$( dig +short $DOMAIN | tail -n1 )
      if [[ $( echo $IP_ADDRESS | egrep -c "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$" ) -eq 0 ]]; then
         echo "Error: Domain $DOMAIN does not resolve. Exiting."
         exit
      fi
      SERVER_STRING="$DOMAIN ($IP_ADDRESS)"
   else
      IP_ADDRESS=$DOMAIN
      SERVER_STRING=$IP_ADDRESS
   fi
   
   fn_email_address

   fn_ping_confirm
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_dns_vars {
   read -p "Enter the IP or domain of the DNS server that you want to watch: " DOMAIN
   DOMAIN=$( echo $DOMAIN | sed -e "s/^[Hh][Tt][Tt][Pp][Ss]*:\/\///" )
   DOMAIN="$( echo $DOMAIN | sed 's/^\([^/]*\).*$/\1/' )"
   if [[ $( echo $DOMAIN | egrep "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$" | wc -l ) -eq 0 ]]; then
      IP_ADDRESS=$( dig +short $DOMAIN | tail -n1 )
      if [[ $( echo $IP_ADDRESS | egrep -c "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$" ) -eq 0 ]]; then
         echo "Error: Domain $DOMAIN does not resolve. Exiting."
         exit
      fi
      SERVER_STRING="$DOMAIN ($IP_ADDRESS)"
   else
      IP_ADDRESS=$DOMAIN
      SERVER_STRING=$IP_ADDRESS
   fi

   echo
   read -p "Enter the domain that you wish to query for: " DOMAIN
   
   fn_email_address

   fn_dns_confirm
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_email_address {
   echo
   echo "Enter the number of seconds the script should wait before performing each iterative check."
   read -p "(Or just press enter for the default of 10 seconds): " WAIT_SECONDS
   if [[ -z $WAIT_SECONDS || $( echo $WAIT_SECONDS | grep -c "[^0-9]" ) -eq 1 ]]; then
      WAIT_SECONDS=10
   fi
   echo
   echo "Enter the e-mail address that you want changes in status sent to."
   read -p "(Or just press enter to have no e-mail messages sent): " EMAIL_ADDRESS
   if [[ $( echo $EMAIL_ADDRESS | grep -c "[^@][^@]*@[^.]*\..*" ) -eq 0 ]]; then
      EMAIL_ADDRESS=false
      MAIL_DELAY=1
   else
      echo
      echo "Enter the number of consecutive failures or successes that should occur before an e-mail"
      read -p "message is sent (default 1; to never send a message, 0): " MAIL_DELAY
      if [[ -z $MAIL_DELAY || $( echo $MAIL_DELAY | grep -c "[^0-9]" ) -eq 1 ]]; then
         MAIL_DELAY=1
      fi
   fi
}

#### Confirmation Functions ####

function fn_ping_confirm {
   echo "I will begin monitoring the following:"
   echo "---Domain / IP to ping: $SERVER_STRING"
   NEW_JOB="$( date +%s )""_$RANDOM"
   echo "--ping" > "$WORKINGDIR""$NEW_JOB"
   fn_mutual_confirm
   mv -f "$WORKINGDIR""$NEW_JOB" "$WORKINGDIR""new/$NEW_JOB"
}

function fn_dns_confirm {
   echo "I will begin monitoring the following:"
   echo "---Domain / IP to query: $SERVER_STRING"
   SERVER_STRING="$DOMAIN @$SERVER_STRING"
   echo "---Domain to query for: $DOMAIN"
   NEW_JOB="$( date +%s )""_$RANDOM"
   echo "--dns" > "$WORKINGDIR""$NEW_JOB"
   fn_mutual_confirm
   mv -f "$WORKINGDIR""$NEW_JOB" "$WORKINGDIR""new/$NEW_JOB"
}

function fn_url_confirm {
   echo "I will begin monitoring the following:"
   echo "---URL to monitor: $URL"
   if [[ $IP_ADDRESS != false ]]; then
      echo "---IP Address to check against: $IP_ADDRESS"
   fi
   echo "---Port number: $IP_PORT"
   echo "---String that must be present to result in a success: \"$CHECK_STRING\""
   NEW_JOB="$( date +%s )""_$RANDOM"
   echo "--url" > "$WORKINGDIR""$NEW_JOB"
   fn_mutual_confirm
   echo "$URL" >> "$WORKINGDIR""$NEW_JOB"
   echo "$IP_PORT" >> "$WORKINGDIR""$NEW_JOB"
   echo "$CHECK_STRING" >> "$WORKINGDIR""$NEW_JOB"
   mv -f "$WORKINGDIR""$NEW_JOB" "$WORKINGDIR""new/$NEW_JOB"
}

function fn_mutual_confirm {
   echo "---Seconds to wait before initiating each new check: $WAIT_SECONDS"
   if [[ $EMAIL_ADDRESS = false ]]; then
      echo "---No e-mail allerts will be sent."
   else
      echo "---E-mail address to which allerts will be sent: $EMAIL_ADDRESS"
      echo "---Consecutive failures or successes before an e-mail will be sent: $MAIL_DELAY"
   fi
   echo
   read -p "Is this correct? (Y/n):" CHECK_CORRECT
   if [[ $( echo $CHECK_CORRECT | grep -c "^[Nn]" ) -eq 1 ]]; then
      rm -f "$WORKINGDIR""$NEW_JOB"
      echo "Exiting."
      exit
   fi
   echo "$WAIT_SECONDS" >> "$WORKINGDIR""$NEW_JOB"
   echo "$EMAIL_ADDRESS" >> "$WORKINGDIR""$NEW_JOB"
   echo "$MAIL_DELAY" >> "$WORKINGDIR""$NEW_JOB"
   echo "$DOMAIN" >> "$WORKINGDIR""$NEW_JOB"
   echo "$IP_ADDRESS" >> "$WORKINGDIR""$NEW_JOB"
   echo "$SERVER_STRING" >> "$WORKINGDIR""$NEW_JOB"
}

#### Child Functions ####

function fn_child {
   sleep 1
   trap fn_child_exit SIGINT SIGTERM SIGKILL
   MY_PID=$$
   MASTER_PID=$( cat "$WORKINGDIR"xmonitor.pid )
   START_TIME=$( date +%s )
   TOTAL_CHECKS=0
   TOTAL_HITS=0
   LAST_STATUS="none"
   LAST_HIT="never"
   LAST_MISS="never"
   HIT_MAIL=false
   MISS_MAIL=false      
   NUM_HITS_EMAIL=0
   NUM_MISSES_EMAIL=0
   OPERATION=$( sed -n "1 p" "$WORKINGDIR""$MY_PID""/params" )
   fn_child_vars
   if [[ $OPERATION == "--url" ]]; then
      fn_url_child
   elif [[ $OPERATION == "--ping" ]]; then
      fn_ping_child
   elif [[ $OPERATION == "--dns" ]]; then
      fn_dns_child
   fi
}

function fn_child_vars {
   WAIT_SECONDS=$( sed -n "2 p" "$WORKINGDIR""$MY_PID""/params" )
   EMAIL_ADDRESS=$( sed -n "3 p" "$WORKINGDIR""$MY_PID""/params" )
   MAIL_DELAY=$( sed -n "4 p" "$WORKINGDIR""$MY_PID""/params" )
   DOMAIN=$( sed -n "5 p" "$WORKINGDIR""$MY_PID""/params" )
   IP_ADDRESS=$( sed -n "6 p" "$WORKINGDIR""$MY_PID""/params" )
   SERVER_STRING=$( sed -n "7 p" "$WORKINGDIR""$MY_PID""/params" )
   if [[ $OPERATION == "--url" ]]; then
      URL=$( sed -n "8 p" "$WORKINGDIR""$MY_PID""/params" )
      IP_PORT=$( sed -n "9 p" "$WORKINGDIR""$MY_PID""/params" )
      CHECK_STRING=$( sed -n "10 p" "$WORKINGDIR""$MY_PID""/params" )
   fi
}

function fn_url_child {
   URL_OR_PING="URL"
   while [[ 1 == 1 ]]; do
      DATE=$( date +%m"/"%d" "%H":"%M":"%S )
      if [[ $IP_ADDRESS == false ]]; then
         SITE=$( curl -L -m 10 $URL 2> /dev/null | egrep -c "$CHECK_STRING" )
         if [[ "$SITE" -ne 0 ]]; then
            fn_hit
         else
            fn_miss
         fi
      elif [[ $IP_ADDRESS != false ]]; then
         SITE=$( curl -L -m 10 --resolve $DOMAIN:$IP_PORT:$IP_ADDRESS $URL 2> /dev/null | egrep -c "$CHECK_STRING" )
         if [[ "$SITE" -ne 0 ]]; then
            fn_hit
         else
            fn_miss
         fi
      fi
      fn_child_checks
   done
}

function fn_ping_child {
   URL_OR_PING="Ping of"
   while [[ 1 == 1 ]]; do
      DATE=$( date +%m"/"%d" "%H":"%M":"%S )
      PING_RESULT=$( ping -W2 -c1 $DOMAIN 2> /dev/null | grep "icmp_[rs]eq" )
      WATCH=$( echo $PING_RESULT | grep -c "icmp_[rs]eq" )
      if [[ $WATCH -ne 0 ]]; then
         fn_hit
      else
         fn_miss
      fi
      fn_child_checks
   done
}

function fn_dns_child {
   URL_OR_PING="DNS for"
   while [[ 1 == 1 ]]; do
      DATE=$( date +%m"/"%d" "%H":"%M":"%S )
      QUERY_RESULT=$( dig +tries=1 $DOMAIN @$IP_ADDRESS 2> /dev/null | grep -c "ANSWER SECTION" )
      if [[ $QUERY_RESULT -ne 0 ]]; then
         fn_hit
      else
         fn_miss
      fi
      fn_child_checks
   done
}

function fn_child_checks {
   if [[ -f "$WORKINGDIR""$MY_PID"/reload ]]; then
      rm -f "$WORKINGDIR""$MY_PID"/reload
      fn_child_vars
      echo "$( date ) - [$MY_PID] - Reloaded parameters for $URL_OR_PING $SERVER_STRING." >> $LOG
      echo "***Reloaded parameters for $URL_OR_PING $SERVER_STRING.***"
   fi
   if [[ -f "$WORKINGDIR""$MY_PID"/die ]]; then
      fn_child_exit
   fi
   sleep $WAIT_SECONDS
}

function fn_child_exit {
   echo "$( date ) - [$MY_PID] - Stopped watching $URL_OR_PING $SERVER_STRING: Running for $RUN_TIME seconds. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate." >> $LOG
   rm -rf "$WORKINGDIR""$MY_PID"
   exit
}

#### Hit and Miss Functions ####

function fn_hit {
   RUN_TIME=$(( $( date +%s ) - $START_TIME ))
   TOTAL_CHECKS=$(( $TOTAL_CHECKS + 1 ))
   TOTAL_HITS=$(( $TOTAL_HITS + 1 ))
   PERCENT_HITS=$( echo "scale=2; $TOTAL_HITS * 100 / $TOTAL_CHECKS" | bc )
   if [[ $LAST_MISS == "never" ]]; then
      LAST_MISS_STRING="never"
      if [[ $LAST_HIT == "never" ]]; then
         HIT_MAIL=true
      fi
   else
      LAST_MISS_STRING="$(( $LAST_HIT - $LAST_MISS )) seconds ago"
   fi
   LAST_HIT=$( date +%s )
   NUM_HITS_EMAIL=$(( $NUM_HITS_EMAIL + 1 ))

   VERBOSITY=$( cat "$WORKINGDIR"verbosity 2> /dev/null )
   if [[ $VERBOSITY == "verbose" ]]; then
      REPORT="$DATE - [$MY_PID] - $URL_OR_PING $SERVER_STRING: Succeeded! - Checking for $RUN_TIME seconds. Last failed check: $LAST_MISS_STRING. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate."
   else
      REPORT="$DATE - $URL_OR_PING $SERVER_STRING: Succeeded!"
   fi
   if [[ $( ps aux | grep "$MASTER_PID.*xmonitor.sh" | grep -vc " 0:00 grep " ) -eq 0 ]]; then
      fn_child_exit
   fi
   if [[ $LAST_STATUS == "hit" ]]; then
      if [[ $VERBOSITY != "change" && $VERBOSITY != "none" ]]; then
         echo "$REPORT"
      fi
      HIT_CHECKS=$(( $HIT_CHECKS + 1 ))
      if [[ $LAST_MISS != "never" ]]; then
         fn_hit_email
      fi
   elif [[ $LAST_STATUS == "none" ]]; then
      if [[ $VERBOSITY != "none" ]]; then
         echo -e "\e[1;32m""$REPORT""\e[00m"
      fi
      echo "$( date ) - [$MY_PID] - Initial status for $URL_OR_PING $SERVER_STRING: Check succeeded!" >> $LOG
      HIT_CHECKS=1
   else
      if [[ $VERBOSITY != "none" ]]; then
         echo -e "\e[1;32m""$REPORT""\e[00m"
      fi
      echo "$( date ) - [$MY_PID] - Status changed for $URL_OR_PING $SERVER_STRING: Check succeeded after $MISS_CHECKS failed checks!" >> $LOG
      HIT_CHECKS=1
      fn_hit_email
   fi
   LAST_STATUS="hit"
}

function fn_miss {
   RUN_TIME=$(( $( date +%s ) - $START_TIME ))
   TOTAL_CHECKS=$(( $TOTAL_CHECKS + 1 ))
   PERCENT_HITS=$( echo "scale=2; $TOTAL_HITS * 100 / $TOTAL_CHECKS" | bc )
   if [[ $LAST_HIT == "never" ]]; then
      LAST_HIT_STRING="never"
      if [[ $LAST_MISS == "never" ]]; then
         MISS_MAIL=true
      fi
   else
      LAST_HIT_STRING="$(( $LAST_MISS - $LAST_HIT )) seconds ago"
   fi
   LAST_MISS=$( date +%s )
   NUM_MISSES_EMAIL=$(( $NUM_MISSES_EMAIL + 1 ))

   VERBOSITY=$( cat "$WORKINGDIR"verbosity 2> /dev/null )
   if [[ $VERBOSITY == "verbose" ]]; then
      REPORT="$DATE - [$MY_PID] - $URL_OR_PING $SERVER_STRING: Failed! - Checking for $RUN_TIME seconds. Last successful check: $LAST_HIT_STRING. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate."
   else
      REPORT="$DATE - $URL_OR_PING $SERVER_STRING: Failed!"
   fi
   if [[ $( ps aux | grep "$MASTER_PID.*xmonitor.sh" | grep -vc " 0:00 grep " ) -eq 0 ]]; then
      fn_child_exit
   fi
   if [[ $LAST_STATUS == "miss" ]]; then
      if [[ $VERBOSITY != "change" && $VERBOSITY != "none" ]]; then
         echo -e "\e[1;33m""$REPORT""\e[00m"
      fi
      MISS_CHECKS=$(( $MISS_CHECKS + 1 ))
      if [[ $LAST_HIT != "never" ]]; then
         fn_miss_email
      fi
   elif [[ $LAST_STATUS == "none" ]]; then
      if [[ $VERBOSITY != "none" ]]; then
         echo -e "\e[1;31m""$REPORT""\e[00m"
      fi
      echo "$( date ) - [$MY_PID] - Initial status for $URL_OR_PING $SERVER_STRING: Check failed!" >> $LOG
      MISS_CHECKS=1
   else
      if [[ $VERBOSITY != "none" ]]; then
         echo -e "\e[1;31m""$REPORT""\e[00m"
      fi
      echo "$( date ) - [$MY_PID] - Status changed for $URL_OR_PING $SERVER_STRING: Check failed after $HIT_CHECKS successful checks!" >> $LOG
      MISS_CHECKS=1
      fn_miss_email
   fi
   LAST_STATUS="miss"
}

function fn_hit_email {
   if [[ $HIT_CHECKS -eq $MAIL_DELAY && $EMAIL_ADDRESS != false && $MISS_MAIL == true ]]; then
      echo -e "$( date ) - Xmonitor - $URL_OR_PING $SERVER_STRING - Status changed: Appears to be succeeding again.\n\nYou're recieving this message to inform you that $MAIL_DELAY consecutive check(s) against $URL_OR_PING $SERVER_STRING have succeeded, thus meeting your threshold for being alerted. Since the previous e-mail was sent (Or if none have been sent, since checks against this server were started) there have been a total of $NUM_HITS_EMAIL successful checks, and $NUM_MISSES_EMAIL failed checks.\n\nChecks have been running for $RUN_TIME seconds. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate." | mail -s "$URL_OR_PING $SERVER_STRING - Check PASSED!" $EMAIL_ADDRESS
      echo "$( date ) - [$MY_PID] - $URL_OR_PING $SERVER_STRING: Success e-mail sent" >> $LOG
      HIT_MAIL=true
      MISS_MAIL=false
      NUM_HITS_EMAIL=0
      NUM_MISSES_EMAIL=0
   fi
}

function fn_miss_email {
   if [[ $MISS_CHECKS -eq $MAIL_DELAY && $EMAIL_ADDRESS != false && $HIT_MAIL == true ]]; then
      echo -e "$( date ) - Xmonitor - $URL_OR_PING $SERVER_STRING - Status changed: Appears to be failing.\n\nYou're recieving this message to inform you that $MAIL_DELAY consecutive check(s) against $URL_OR_PING $SERVER_STRING have failed, thus meeting your threshold for being alerted. Since the previous e-mail was sent (Or if none have been sent, since checks against this server were started) there have been a total of $NUM_HITS_EMAIL successful checks, and $NUM_MISSES_EMAIL failed checks.\n\nChecks have been running for $RUN_TIME seconds. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate." | mail -s "$URL_OR_PING $SERVER_STRING - Check FAILED!" $EMAIL_ADDRESS
      echo "$( date ) - [$MY_PID] - $URL_OR_PING $SERVER_STRING: Failure e-mail sent" >> $LOG
      HIT_MAIL=false
      MISS_MAIL=true
      NUM_HITS_EMAIL=0
      NUM_MISSES_EMAIL=0
   fi
}

#### Master Functions ####

function fn_master {
   if [[ $RUNNING_STATE != "master" ]]; then
      echo "Master process already present. Exiting"
      exit
   fi
   trap fn_master_exit SIGINT SIGTERM SIGKILL
   VERBOSITY=$( cat "$WORKINGDIR"verbosity )
   while [[ 1 == 1 ]]; do
      if [[ $( ls -1 "$WORKINGDIR""new/" | wc -l ) -gt 0 ]]; then
         for i in $( ls -1 "$WORKINGDIR""new/" ); do
            SERVER_STRING="$( sed -n "7 p" "$WORKINGDIR""new/$i" )"
            OPERATION=$( sed -n "1 p" "$WORKINGDIR""new/$i" )
            if [[ $OPERATION == "--url" ]]; then
               SERVER_STRING="URL $SERVER_STRING"
            elif [[ $OPERATION == "--ping" ]]; then
               SERVER_STRING="PING $SERVER_STRING"
            elif [[ $OPERATION == "--dns" ]]; then
               SERVER_STRING="DNS $SERVER_STRING"
            fi
            # the server string doesn't need to be present, but it makes ps more readable.
            "$PROGRAMDIR"xmonitor.sh $SERVER_STRING &
            CHILD_PID=$!
            mkdir -p "$WORKINGDIR""$CHILD_PID"
            mv "$WORKINGDIR""new/$i" "$WORKINGDIR""$CHILD_PID""/params"
         done
      fi
      for i in $( find $WORKINGDIR -type d ); do
         CHILD_PID=$( basename $i )
         if [[ $( echo $CHILD_PID | grep -vc [^0-9] ) -eq 1 ]]; then
            if [[ $( ps aux | grep "$CHILD_PID.*xmonitor.sh" | grep -vc " 0:00 grep " ) -eq 0 ]]; then
               echo "$( date ) - [$CHILD_PID] - $( sed -n "1 p" "$WORKINGDIR""$CHILD_PID/params" 2> /dev/null | sed "s/^--//" ) $( sed -n "7 p" "$WORKINGDIR""$CHILD_PID/params" 2> /dev/null ) - CHILD process was found dead." >> $LOG
               rm -rf "$WORKINGDIR""$CHILD_PID"
            fi
         fi
      done
      if [[ ! -f "$WORKINGDIR"verbosity ]]; then
         echo $VERBOSITY > "$WORKINGDIR"verbosity
      elif [[ $( cat "$WORKINGDIR"verbosity ) != $VERBOSITY ]]; then
         VERBOSITY=$( cat "$WORKINGDIR"verbosity )
         echo "***Verbosity is now set as \"$VERBOSITY\"***"
      fi
      if [[ -f "$WORKINGDIR"die ]]; then
         fn_master_exit
      fi
      sleep 2
   done
}

function fn_master_exit {
   if [[ ! -f "$WORKINGDIR"die ]]; then
      echo "none" > "$WORKINGDIR"verbosity
      echo "Options:"
      echo
      echo "  1) Kill the master process and all child processes."
      echo "  2) Back up the data for the child processes so that they'll start again next time Xmonitor is run, then kill the master process and all child processes."
      echo
      read -p "How would you like to proceed? " OPTION_NUM
      if [[ $OPTION_NUM == "2" ]]; then
         touch "$WORKINGDIR"save
      fi
   fi
   if [[ -f "$WORKINGDIR"save ]]; then
      rm -f "$WORKINGDIR"save
      for i in $( find "$WORKINGDIR" -type d ); do 
         CHILD_PID=$( basename $i )
         if [[ $( echo $CHILD_PID | grep -vc [^0-9] ) -eq 1 ]]; then 
            cp -a $i/params "$WORKINGDIR"new/$CHILD_PID.txt
         fi
      done
   fi
   rm -f "$WORKINGDIR"xmonitor.pid "$WORKINGDIR"verbosity "$WORKINGDIR"die
   exit
}

#### Other Functions ####

function fn_verbosity {
   if [[ -z $VERBOSITY ]]; then
      OLD_VERBOSITY=$( cat "$WORKINGDIR"verbosity 2> /dev/null )
      if [[ -z $OLD_VERBOSITY ]]; then
         echo "Verbosity is not currently set"
      else
         echo "Verbosity is currently set to \"$OLD_VERBOSITY\"."
      fi
      read -p "Enter the new verbosity (standard / verbose / change / none): " VERBOSITY
   fi
   if [[ $( echo "$VERBOSITY" | egrep -c "standard|verbose|change|none" ) -eq 0 ]]; then
      echo "Invalid input. Exiting"
      exit
   fi
   
   if [[ $VERBOSITY == "standard" ]]; then
      echo "standard" > "$WORKINGDIR"verbosity
      echo "Verbosity is now set to \"standard\"."
   elif [[ $VERBOSITY == "verbose" ]]; then
      echo "verbose" > "$WORKINGDIR"verbosity
      echo "Verbosity is now set to \"verbose\" - additional statistical information will now be printed with each check."
   elif [[ $VERBOSITY == "change" ]]; then
      echo "change" > "$WORKINGDIR"verbosity
      echo "Verbosity is now set to \"change\" - only changes in status will be output to screen."
   elif [[ $VERBOSITY == "none" ]]; then
      echo "none" > "$WORKINGDIR"verbosity
      echo "Verbosity is now set to \"none\" - nothing will be output to screen."
   fi
}

function fn_modify {
   if [[ $RUNNING_STATE == "master" ]]; then
      echo "No current xmonitor processes. Exiting"
      exit
   fi
   echo "List of currently running xmonitor processes:"
   echo
   CHILD_NUMBER="0"
   aCHILD_PID[0]="none"
   for i in $( find $WORKINGDIR -type d ); do
      CHILD_PID=$( basename $i )
      if [[ $( echo $CHILD_PID | grep -vc [^0-9] ) -eq 1 ]]; then
         CHILD_NUMBER=$(( $CHILD_NUMBER + 1 ))
         echo "  $CHILD_NUMBER) $( sed -n "1 p" "$WORKINGDIR""$CHILD_PID/params" | sed "s/^--//" ) $( sed -n "7 p" "$WORKINGDIR""$CHILD_PID/params" )"
         aCHILD_PID[$CHILD_NUMBER]="$CHILD_PID"
      fi
   done
   CHILD_NUMBER=$(( $CHILD_NUMBER + 1 ))
   echo "  $CHILD_NUMBER) Master Process"
   aCHILD_PID[$CHILD_NUMBER]="master"
   echo
   read -p "Which process do you want to modify? " CHILD_NUMBER
   if [[ $CHILD_NUMBER == "0" || $( echo $CHILD_NUMBER| grep -vc "[^0-9]" ) -eq 0 ]]; then
      echo "Invalid Option. Exiting."
      exit
   fi
   CHILD_PID=${aCHILD_PID[$CHILD_NUMBER]}
   if [[ -z $CHILD_PID ]]; then
      echo "Invalid Option. Exiting."
      exit
   fi
   if [[ $CHILD_PID == "master" ]]; then
      echo -e "Options:\n"
      echo "  1) Exit out of the master process."
      echo "  2) First back-up the child processes so that they'll run immediately when xmonitor is next started, then exit out of the master process."
      echo "  3) Exit out of this menu."
      echo
      read -p "Choose an option from the above list: " OPTION_NUM
      if [[ $OPTION_NUM == "1" ]]; then
         touch "$WORKINGDIR"die
      elif [[ $OPTION_NUM == "2" ]]; then
         touch "$WORKINGDIR"save
         touch "$WORKINGDIR"die
      else
         echo "Exiting."
         exit
      fi
   else
      echo "$( sed -n "7 p" "$WORKINGDIR""$CHILD_PID/params" ):"
      echo
      echo "  1) Kill this process."
      echo "  2) Change the delay between checks from \"$( sed -n "2 p" "$WORKINGDIR""$CHILD_PID/params" )\" seconds."
      echo "  3) Change e-mail address from \"$( sed -n "3 p" "$WORKINGDIR""$CHILD_PID/params" )\"."
      echo "  4) Change the number of consecutive failures or successes before an e-mail is sent from \"$( sed -n "4 p" "$WORKINGDIR""$CHILD_PID/params" )\""
      echo "  5) Change the title of the job as it's reported by the child process. (Currently \"$( sed -n "7 p" "$WORKINGDIR""$CHILD_PID/params" )\")"
      echo "  6) Exit out of this menu."
      echo
      read -p "Chose an option from the above list: " OPTION_NUM
      if [[ $OPTION_NUM == "1" ]]; then
         touch "$WORKINGDIR""$CHILD_PID/die"
         echo "Process will exit out shortly."
      elif [[ $OPTION_NUM == "2" ]]; then
         read -p "Enter the number of seconds the script should wait before performing each iterative check: " WAIT_SECONDS
         if [[ -z $WAIT_SECONDS || $( echo $WAIT_SECONDS | grep -c "[^0-9]" ) -eq 1 ]]; then
            echo "Input must be a number. Exiting"
            exit
         fi
         sed -i "2 c$WAIT_SECONDS" "$WORKINGDIR""$CHILD_PID/params"
         touch "$WORKINGDIR""$CHILD_PID/reload"
         echo "Wait Seconds has been updated."
      elif [[ $OPTION_NUM == "3" ]]; then
         echo "Enter the e-mail address that you want changes in status sent to."
         read -p "(Or just press enter to have no e-mail messages sent): " EMAIL_ADDRESS
         if [[ ! -z $EMAIL_ADDRESS && $( echo $EMAIL_ADDRESS | grep -c "[^@][^@]*@[^.]*\..*" ) -eq 0 ]]; then
            echo "E-mail address does not appear to be valid. Exiting"
            exit
         elif [[ -z $EMAIL_ADDRESS ]]; then
            EMAIL_ADDRESS=false
         fi
         sed -i "3 c$EMAIL_ADDRESS" "$WORKINGDIR""$CHILD_PID/params"
         touch "$WORKINGDIR""$CHILD_PID/reload"
         echo "E-mail address has been updated."
      elif [[ $OPTION_NUM == "4" ]]; then
         echo "Enter the number of consecutive failures or successes that should occur before an e-mail"
         read -p "message is sent (default 1; to never send a message, 0): " MAIL_DELAY
         if [[ -z $MAIL_DELAY || $( echo $MAIL_DELAY | grep -c "[^0-9]" ) -eq 1 ]]; then
            echo "Input must be a number. Exiting"
            exit
         fi
         sed -i "4 c$MAIL_DELAY" "$WORKINGDIR""$CHILD_PID/params"
         touch "$WORKINGDIR""$CHILD_PID/reload"
         echo "Mail delay has been updated."
      elif [[ $OPTION_NUM == "5" ]]; then
         read -p "Enter a new identifying string to associate with this check: " SERVER_STRING
         sed -i "7 c$SERVER_STRING" "$WORKINGDIR""$CHILD_PID/params"
         touch "$WORKINGDIR""$CHILD_PID/reload"
         echo "THe server string has been updated."
      else
         echo "Exiting"
      fi
   fi
}

function fn_options {
   echo
   echo "Available Options:"
   echo
   echo "  1) Monitor a URL."
   echo "  2) Monitor ping on a server."
   echo "  3) Monitor DNS services on a server."
   echo "  4) Print help information."
   echo "  5) Print version information."
   if [[ $RUNNING_STATE == "master" ]]; then
      echo "  6) Spawn a master process without designating anything to monitor."
   elif [[ $RUNNING_STATE == "control" ]]; then
      echo "  6) Modify child processes or the master process."
      echo "  7) Change the output verbosity of child processes."
   fi
   echo
   read -p "How would you like to proceed? " OPTION_NUM

   if [[ $OPTION_NUM == "1" ]]; then
      fn_url_vars
   elif [[ $OPTION_NUM == "2" ]]; then
      fn_ping_vars
   elif [[ $OPTION_NUM == "3" ]]; then
      fn_dns_vars
   elif [[ $OPTION_NUM == "4" ]]; then
      fn_help
   elif [[ $OPTION_NUM == "5" ]]; then
      fn_version
   elif [[ $OPTION_NUM == "6" && $RUNNING_STATE == "master" ]]; then
      fn_master
   elif [[ $OPTION_NUM == "6" && $RUNNING_STATE == "control" ]]; then
      fn_modify
   elif [[ $OPTION_NUM == "7" && $RUNNING_STATE == "control" ]]; then
      fn_verbosity
   else
      echo "Invalid option. Exiting."
      exit
   fi
}

#### Help and Version Functions ####

function fn_help {
cat << 'EOF' > /dev/stdout


Xmonitor - A script to organize and consolidate the monitoring of multiple servers. With Xmonitor you can run checks against multiple servers simultaneously, starting new jobs and stopping old ones as needed without interfering with any that are currently running. All output from the checks goes to a single terminal window, allowing you to keep an eye on multiple things going on at once.

Usage:

./xmonitor.sh
     Prompts you on how you want to proceed, allowing you to choose from options similar to those presented by the descriptions below.

./xmonitor.sh [--url|--ping|--dns]
     1) Leaves a prompt telling the master process to spawn a child process to either a) in the case of --url, check a site's contents for a string of characters b) in the case of --ping, ping a site and check for a response c) in the case of --dns, dig against a nameserver and check for a valid response.
     2) If there is no currently running master process, it goes on to declare itself the master process and spawn child processes accordingly.

./xmonitor.sh [--url|--ping|--dns] --control
     Same as above, except that even if no master process is running, it does not declare itself the master process, but rather exits immediately after leaving the prompt for a child process to be spawned.

./xmonitor.sh [-u|-p|-d]
     Same as --url, --ping, and --dns

./xmonitor.sh --master
     Immediately designates itself as the master process. If any prompts are waiting, it spawns child processes as they describe, it then checks periodically for new prompts and spawns processes accordingly. If the master process ends, all child processes it has spawned will end as well.

./xmonitor.sh --verbosity [standard|verbose|change|none]
     Changes the verbosity level of the output of the child processes. Standard: Outputs whether any specific check has succeeded or failed. Verbose: In addition to the information given from the standard output, also indicates how long checks for that job have been running, how many have been run, and the percentage of successful checks. Change: Only outputs text on the first failure after any number of successes, or the first success after any number of failures. None: Child processes output no text.
     For all modes fo verbosity (except "none", of course) text output is color coded as follows: Green - The first check that has succeeded after any number of failed checks. White - a check that has succeeded when the previous check was also successful. Red - the first check that has failed after any number of successful checks. Yellow - a check that has failed when the previous check was also a failure.

./xmonitor.sh [--verbosity|-v]
     Same as above, except you're prompted for what verbosity you want xmonitor's child processes to be set at

./xmonitor.sh [--modify|-m]
     Prompts you with a list of currently running child processes and allows you to change how frequently their checks occur and how they send e-mail allerts, or kill them off if they're no longer desired.

./xmonitor.sh [--help|-h]
     Displays this dialogue

./xmonitor.sh --version
     Displays changes over the various versions.

NOTE: Regarding e-mail alerts!
     Xmonitor sends e-mail messages using the "mail" binary (usually located in /usr/bin/mail). In order for this to work as expected, you will likely need to modify the ~/.mailrc file with credentials for a valid e-mail account, otherwise the messages that are sent will likely get rejected.

NOTE: Regarding "echo -e" and pipe!
     In order to skip through the process of setting up a check, it's possible to use "eche -e" to pipe the variables into the script. This allows you to easily convey the settings that you have in place in a style that can easily be copied / pasted. EXAMPLE: 

       echo -e "sporks5000.com/index.html\nKeep in mind that\n50.28.76.15\n10\nacwilliams@liquidweb.com\n1\n" | ./xmonitor.sh --url

     This can be coupled with "--control" and "--master" in order to start up multiple processes at once:

       echo -e "glanky.com\nHotGoss Theme</a> by\n67.227.182.247\n10\nacwilliams@liquidweb.com\n2\n" | ./xmonitor.sh --url --control
       echo -e "glanky.com\nHotGoss Theme</a> by\n67.227.182.249\n10\nacwilliams@liquidweb.com\n2\n" | ./xmonitor.sh --url --control
       ./xmonitor.sh --master

NOTE: Regarding the log file!
     Xmonitor keeps a log file titled "xmonitor.log" in the same directory in which the script is located. This file is used to log when checks are started and stopped, and when ever there is a change in status on any of the checks.

NOTE: Regarding url checks and specifying an IP!
     Xmonitor allows you to specify an IP from which to pull a URL, rather than allowing DNS to resolve the domain name to an IP address. This is very useful in situations where you're attempting to monitor multiple servers within a load balanced setup. Unfortunately, the ability for curl to do this was only added in version 7.21.3. While that version is now more than two years old, it still has not made it into the standard repositories for some systems (CentOS 5 and 6, for example). Xmonitor checks if the functionality is present. If not, any IP addresses entered for URL checks will be ignored.

EOF
#"'do
exit
}

function fn_version {
echo "Current Version: $VERSION"
cat << 'EOF' > /dev/stdout

Version Notes:
Future Versions -
     Option to output the piped string

1.0.0 -
     Implimented master, child, and control functionality
     url, ping, and dns monitoring
     basic functionality for --modify
     --help text is concise and informative
     e-mail messages can be sent after a certain number of hits or a certain number of misses.
     When running without any arguents, prompt intelligently for what needs to be done.
     --modify allows you to kill the master process
     Option to backup current child processes so that they will run next time xmonitor is started, then kill the master process.
EOF
#'do
exit
}

###################
## END FUNCTIONS ##
###################

# Specify the working directory; create it if not present; specify the log file
PROGRAMDIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROGRAMDIR="$( echo "$PROGRAMDIR" | sed "s/\([^/]\)$/\1\//" )"
#"
WORKINGDIR="$PROGRAMDIR"".xmonitor/"
mkdir -p "$WORKINGDIR"
mkdir -p "$WORKINGDIR""new/"

LOG="$WORKINGDIR""../xmonitor.log"

# Determine the running state
if [[ -f "$WORKINGDIR"xmonitor.pid && $( ps aux | grep "$( cat "$WORKINGDIR"xmonitor.pid 2> /dev/null ).*xmonitor.sh" | grep -vc " 0:00 grep " ) -gt 0 ]]; then
   if [[ $PPID == $( cat "$WORKINGDIR"xmonitor.pid 2> /dev/null ) ]]; then
      RUNNING_STATE="child"
      fn_child
   else
      RUNNING_STATE="control"
   fi
else
   RUNNING_STATE="master"
   echo $$ > "$WORKINGDIR"xmonitor.pid
   if [[ ! -f "$WORKINGDIR"verbosity ]]; then
      echo "standard" > "$WORKINGDIR"verbosity
   fi
fi

if [[ $2 == "--control" ]]; then
   RUNNING_STATE="control"
fi

# Second group of options that requires $WORKINGDIR and / or $STATE information.
if [[ $1 == "--version" ]]; then
   fn_version
   exit
elif [[ $1 == "--help" || $1 == "-h" ]]; then
   fn_help
   exit
elif [[ $1 == "--modify" || $1 == "-m" ]]; then
   fn_modify
elif [[ $1 == "--verbosity" || $1 == "-v" ]]; then
   VERBOSITY=$2
   fn_verbosity
elif [[ $1 == "--ping" || $1 == "-p" ]]; then
   fn_ping_vars
elif [[ $1 == "--url" || $1 == "-u" ]]; then
   fn_url_vars
elif [[ $1 == "--dns" || $1 == "-d" ]]; then
   fn_dns_vars
elif [[ $1 == "--master" ]]; then
   fn_master
elif [[ -z $1 ]]; then
   fn_options
fi
