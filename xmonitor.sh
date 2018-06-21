#! /bin/bash

VERSION="1.1.0"

#######################
### BEGIN FUNCTIONS ###
#######################

#### Variable Gathering Functions ####

function fn_url_vars {
   # When a URL monitoring task is selected from the menu, it will run through this function in order to acquire the necessary variables.
   read -p "Enter the URL That you need to have monitored: " SERVER
   if [[ -z $SERVER ]]; then
      echo "A URL must be supplied. Exiting."
      exit
   fi
   fn_parse_server
   DOMAIN=$DOMAINa
   IP_PORT=$IP_PORTa
   URL=$URLa

   echo
   echo "When checking that URL, what string of characters will this script be searching for?"
   echo "(The search is done using 'egrep -c \"\$CHECK_STRING\"'. It's up to you to compensate"
   read -p "for any weirdness that might result.): " CHECK_STRING

   echo
   echo "Enter the IP Address that this URL should be monitored on. (Or just press enter"
   echo "to have the IP resolved via DNS) (NOTE: this feature requires curl 7.21.3"
   read -p "or later. If that version is not present, any input here will be ignored.): " SERVER
   if [[ ! -z $SERVER ]]; then
      fn_parse_server
      IP_ADDRESS=$IP_ADDRESSa
      curl --resolve google.com:80:127.0.0.1 http://google.com > /dev/null 2>&1
      STATUS=$?
   fi
   if [[ $STATUS == 2 || -z $SERVER || $IP_ADDRESS == false ]]; then
      IP_ADDRESS=false
      SERVER_STRING=$URL
   else
      SERVER_STRING="$URL at $IP_ADDRESS"
   fi

   fn_email_address

   fn_url_confirm
   # If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_ping_vars {
   # When a ping monitoring task is selected from the menu, it will run through this function in order to acquire the necessary variables.
   read -p "Enter the domain or IP that you wish to ping: " SERVER
   if [[ -z $SERVER ]]; then
      echo "A domain or IP must be supplied. Exiting."
      exit
   fi
   fn_parse_server
   IP_ADDRESS=$IP_ADDRESSa
   DOMAIN=$DOMAINa
   if [[ $IP_ADDRESS == false ]]; then
      echo "Error: Domain $DOMAIN does not resolve. Exiting."
      exit
   fi
   if [[ $DOMAIN == $IP_ADDRESS ]]; then
      SERVER_STRING=$IP_ADDRESS
   else
      SERVER_STRING="$DOMAIN ($IP_ADDRESS)"
   fi
   
   fn_email_address

   fn_ping_confirm
   # If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_dns_vars {
   # When a DNS monitoring task is selected from the menu, it will run through this function in order to acquire the necessary variables.
   read -p "Enter the IP or domain of the DNS server that you want to watch: " SERVER
   fn_parse_server
   SERVER_STRING=$DOMAINa
   IP_ADDRESS=$IP_ADDRESSa
   if [[ $IP_ADDRESS == false ]]; then
      echo "Error: Domain $DOMAIN does not resolve. Exiting."
      exit
   fi

   echo
   read -p "Enter the domain that you wish to query for: " DOMAIN
   SERVER_STRING="$DOMAIN @$SERVER_STRING"
   
   fn_email_address

   fn_dns_confirm
   # If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_email_address {
   # When functions are run from the meno, the come here to gather the $WAIT_SECONDS $EMAIL_ADDRESS and $MAIL_DELAY variables.
   echo
   echo "Enter the number of seconds the script should wait before performing each iterative check."
   read -p "(Or just press enter for the default of $( cat "$WORKINGDIR"wait_seconds ) seconds): " WAIT_SECONDS
   if [[ -z $WAIT_SECONDS || $( echo $WAIT_SECONDS | grep -c "[^0-9]" ) -eq 1 ]]; then
      WAIT_SECONDS="$( cat "$WORKINGDIR"wait_seconds )"
   fi
   echo
   echo "Enter the e-mail address that you want changes in status sent to."
   if [[ -z $( cat "$WORKINGDIR"email_address ) ]]; then
      read -p "(Or just press enter to have no e-mail messages sent): " EMAIL_ADDRESS
   else
      read -p "(Or just press enter to have it default to $( cat "$WORKINGDIR"email_address )): " EMAIL_ADDRESS
   fi
   if [[ $( echo $EMAIL_ADDRESS | grep -c "[^@][^@]*@[^.]*\..*" ) -eq 0 ]]; then
      EMAIL_ADDRESS="$( cat "$WORKINGDIR"email_address )"
      MAIL_DELAY="$( cat "$WORKINGDIR"mail_delay )"
   else
      echo
      echo "Enter the number of consecutive failures or successes that should occur before an e-mail"
      read -p "message is sent (default $( cat "$WORKINGDIR"mail_delay ); to never send a message, 0): " MAIL_DELAY
      if [[ -z $MAIL_DELAY || $( echo $MAIL_DELAY | grep -c "[^0-9]" ) -eq 1 ]]; then
         MAIL_DELAY="$( cat "$WORKINGDIR"mail_delay )"
      fi
   fi
}

function fn_parse_server {
   # given a URL, Domain name, or IP address, this parses those out into the variables $URL, $DOMAIN $IP_ADDRESS, and $IP_PORT.
   if [[ $( echo $SERVER | grep -ci "^HTTP" ) -eq 0 ]]; then
      DOMAINa=$SERVER
      URLa=$SERVER
      IP_PORTa="80"
   else
      # get rid of "http(s)" at the veginning of the domain name
      DOMAINa=$( echo $SERVER | sed -e "s/^[Hh][Tt][Tt][Pp][Ss]*:\/\///" )
      if [[ $( echo $SERVER | grep -ci "^HTTPS" ) -eq 0 ]]; then
         URLa=$SERVER
         IP_PORTa="443"
      else
         URLa=$( echo $SERVER | sed -e "s/^[Hh][Tt][Tt][Pp]:\/\///" )
         IP_PORTa="80"
      fi
   fi
   # get rid of the slash and anything else that follows the domain name
   DOMAINa="$( echo $DOMAINa | sed 's/^\([^/]*\).*$/\1/' )"
   # check if it's an IP.
   if [[ $( echo $DOMAINa | egrep "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$" | wc -l ) -eq 0 ]]; then
      IP_ADDRESSa=$( dig +short $DOMAINa | tail -n1 )
      if [[ $( echo $IP_ADDRESSa | egrep -c "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$" ) -eq 0 ]]; then
         IP_ADDRESSa=false
      fi
   else
      IP_ADDRESSa=$DOMAINa
   fi
}

#### Variable Command Line Functions ####

function fn_url_cl {
   # When a URL monitoring job is run from the command line, this parses out the commandline variables...
   if [[ -z $CHECK_STRING ]]; then
      echo "It is required that you specify a check string using \"--string\" followed by a string in quotes that will be searched for when checking a URL. Exiting."
      exit
   elif [[ ! -z $URL && ! -z $DNS_DOMAIN && $URL != $DNS_DOMAIN ]]; then
      echo "Please specify either a URL or a domain, not both. Exiting."
      exit
   elif [[ ! -z $IP_ADDRESS ]]; then
      SERVER=$IP_ADDRESS
      fn_parse_server
      IP_ADDRESS=$IP_ADDRESSa
      curl --resolve google.com:80:127.0.0.1 http://google.com > /dev/null 2>&1
      STATUS=$?
      if [[ $STATUS == 2 ]]; then
         echo "In order to specify an IP address, this script requires that you have curl version 7.21.3 or later. Exiting."
         exit
      elif [[ $IP_ADDRESS == false ]]; then
         echo "Not a valid IP address. Exiting."
         exit
      fi
   fi
   if [[ -z $URL && ! -z $DNS_DOMAIN ]]; then
      URL=$DNS_DOMAIN
   fi
   # ...and then makes sure that those variables are correctly assigned.
   SERVER=$URL
   fn_parse_server
   DOMAIN=$DOMAINa
   IP_PORT=$IP_PORTa
   URL=$URLa

   if [[ -z $IP_ADDRESS ]]; then
      IP_ADDRESS=false
      SERVER_STRING=$URL
   else
      SERVER_STRING="$URL at $IP_ADDRESS"
   fi

   fn_email_cl

   fn_cl_confirm
   # If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_ping_cl {
   # When a Ping monitoring job is run from the command line, this parses out the commandline variables...
   if [[ -z $DOMAIN && -z $IP_ADDRESS && -z $DNS_DOMAIN ]]; then
      echo "You must specify an IP address or domain to ping, either as an argument after the \"--ip\" flag, the \"--domain\" flag or after the \"--ping\" flag itself. Exiting."
      exit
   elif [[ ! -z $DOMAIN && ! -z $IP_ADDRESS && $DOMAIN != $IP_ADDRESS ]]; then
      echo "Please specify the IP address / domain name only once. Exiting."
      exit
   elif [[ ! -z $DOMAIN && ! -z $DNS_DOMAIN && $DOMAIN != $DNS_DOMAIN ]]; then
      echo "Please specify the IP address / domain name only once. Exiting."
      exit
   elif [[ ! -z $DNS_DOMAIN && ! -z $IP_ADDRESS && $DNS_DOMAIN != $IP_ADDRESS ]]; then
      echo "Please specify the IP address / domain name only once. Exiting."
      exit
   elif [[ ! -z $CHECK_STRING ]]; then
      echo "You should not specify a check string when using \"--ping\". Exiting."
      exit
   fi
   if [[ -z $DOMAIN && ! -z $DNS_DOMAIN ]]; then
      DOMAIN=$DNS_DOMAIN
   elif [[ -z $DOMAIN && ! -z $IP_ADDRESS ]]; then
      DOMAIN=$IP_ADDRESS
   fi
   # ...and then makes sure that those variables are correctly assigned.
   SERVER=$DOMAIN
   fn_parse_server
   IP_ADDRESS=$IP_ADDRESSa
   DOMAIN=$DOMAINa
   if [[ $IP_ADDRESS == false ]]; then
      echo "Error: Domain $DOMAIN does not resolve. Exiting."
      exit
   fi
   if [[ $DOMAIN == $IP_ADDRESS ]]; then
      SERVER_STRING=$IP_ADDRESS
   else
      SERVER_STRING="$DOMAIN ($IP_ADDRESS)"
   fi
   
   fn_email_cl

   fn_cl_confirm
   # If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_dns_cl {
   # When a DNS monitoring job is run from the command line, this parses out the commandline variables...
   if [[ ! -z $IP_ADDRESS && ! -z $DOMAIN && $DOMAIN != $IP_ADDRESS ]]; then
      echo "Please specify the IP address / domain name of the server you're checking against only once. Exiting."
      exit
   elif [[ -z $IP_ADDRESS && -z $DOMAIN ]]; then
      echo "Please specify the IP address / domain name of the server you're checking against, either as an argument directly after the \"--ip\" flag, of after the \"--dns\" flag itself. Exiting."
      exit
   elif [[ -z $DNS_DOMAIN ]]; then
      echo "Please specify a domain name that has a zone file on the server to check for as an argument after the \"--domain\" flag. Exiting."
      exit
   elif [[ ! -z $CHECK_STRING ]]; then
      echo "You should not specify a check string when using \"--dns\". Exiting."
      exit
   fi
   if [[ -z $DOMAIN && ! -z $IP_ADDRESS ]]; then
      DOMAIN=$IP_ADDRESS
   fi
   # ...and then makes sure that those variables are correctly assigned.
   SERVER=$DOMAIN
   fn_parse_server
   SERVER_STRING=$DOMAINa
   IP_ADDRESS=$IP_ADDRESSa
   if [[ $IP_ADDRESS == false ]]; then
      echo "Error: Domain $DOMAIN does not resolve. Exiting."
      exit
   fi
   DOMAIN=$DNS_DOMAIN
   SERVER_STRING="$DOMAIN @$SERVER_STRING"
   fn_email_cl

   fn_cl_confirm
   # If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_email_cl {
   # This function parses out the command line information for e-mail address
   if [[ -z $WAIT_SECONDS || $( echo $WAIT_SECONDS | grep -c "[^0-9]" ) -eq 1 ]]; then
      WAIT_SECONDS="$( cat "$WORKINGDIR"wait_seconds )"
   fi
   if [[ $( echo $EMAIL_ADDRESS | grep -c "[^@][^@]*@[^.]*\..*" ) -eq 0 ]]; then
      EMAIL_ADDRESS="$( cat "$WORKINGDIR"email_address )"
      MAIL_DELAY="$( cat "$WORKINGDIR"mail_delay )"
   else
      if [[ -z $MAIL_DELAY || $( echo $MAIL_DELAY | grep -c "[^0-9]" ) -eq 1 ]]; then
         MAIL_DELAY="$( cat "$WORKINGDIR"mail_delay )"
      fi
   fi
}

#### Confirmation Functions ####

function fn_ping_confirm {
   # When run from the menu, this confirms the settings for a Ping job.
   echo "I will begin monitoring the following:"
   echo "---Domain / IP to ping: $SERVER_STRING"
   NEW_JOB="$( date +%s )""_$RANDOM"
   echo "--ping" > "$WORKINGDIR""$NEW_JOB"
   fn_mutual_confirm
   mv -f "$WORKINGDIR""$NEW_JOB" "$WORKINGDIR""new/$NEW_JOB"
}

function fn_dns_confirm {
   # When run from the menu, this confirms the settings for a DNS job.
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
   # When run from the menu, this confirms the settings for a URL job.
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
   # There are additional variables for URL based jobs. Those are input into the params file here.
   echo "$URL" >> "$WORKINGDIR""$NEW_JOB"
   echo "$IP_PORT" >> "$WORKINGDIR""$NEW_JOB"
   echo "$CHECK_STRING" >> "$WORKINGDIR""$NEW_JOB"
   mv -f "$WORKINGDIR""$NEW_JOB" "$WORKINGDIR""new/$NEW_JOB"
}

function fn_mutual_confirm {
   # Confirms the remainder of the veriables from a menu-assigned task...
   echo "---Seconds to wait before initiating each new check: $WAIT_SECONDS"
   if [[ -z $EMAIL_ADDRESS ]]; then
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
   # ...and then inputs those variables into the params file so that the child process can read them.
   echo "$WAIT_SECONDS" >> "$WORKINGDIR""$NEW_JOB"
   echo "$EMAIL_ADDRESS" >> "$WORKINGDIR""$NEW_JOB"
   echo "$MAIL_DELAY" >> "$WORKINGDIR""$NEW_JOB"
   echo "$DOMAIN" >> "$WORKINGDIR""$NEW_JOB"
   echo "$IP_ADDRESS" >> "$WORKINGDIR""$NEW_JOB"
   echo "$SERVER_STRING" >> "$WORKINGDIR""$NEW_JOB"
}

function fn_cl_confirm {
   # This takes the variables from a job started from the command line, and then places them in the params file in order for a child process to read them.
   NEW_JOB="$( date +%s )""_$RANDOM"
   if [[ $RUN_TYPE == "--url" || $RUN_TYPE == "-u" ]]; then
      echo "--url" > "$WORKINGDIR""$NEW_JOB"
   elif [[ $RUN_TYPE == "--ping" || $RUN_TYPE == "-p" ]]; then
      echo "--ping" > "$WORKINGDIR""$NEW_JOB"
   elif [[ $RUN_TYPE == "--dns" || $RUN_TYPE == "-d" ]]; then
      echo "--dns" > "$WORKINGDIR""$NEW_JOB"
   fi
   echo "$WAIT_SECONDS" >> "$WORKINGDIR""$NEW_JOB"
   echo "$EMAIL_ADDRESS" >> "$WORKINGDIR""$NEW_JOB"
   echo "$MAIL_DELAY" >> "$WORKINGDIR""$NEW_JOB"
   echo "$DOMAIN" >> "$WORKINGDIR""$NEW_JOB"
   echo "$IP_ADDRESS" >> "$WORKINGDIR""$NEW_JOB"
   echo "$SERVER_STRING" >> "$WORKINGDIR""$NEW_JOB"
   if [[ $RUN_TYPE == "--url" || $RUN_TYPE == "-u" ]]; then
      echo "$URL" >> "$WORKINGDIR""$NEW_JOB"
      echo "$IP_PORT" >> "$WORKINGDIR""$NEW_JOB"
      echo "$CHECK_STRING" >> "$WORKINGDIR""$NEW_JOB"
   fi
   mv -f "$WORKINGDIR""$NEW_JOB" "$WORKINGDIR""new/$NEW_JOB"
}

#### Child Functions ####

function fn_child {
   # The opening part of a child process!
   # Wait to make sure that the params file is in place.
   sleep 1
   # Make sure that the child processes are not exited out of o'er hastily.
   trap fn_child_exit SIGINT SIGTERM SIGKILL
   # Define the variables that will be used over the life of the child process
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
   # Pull the necessary variables for the child process from the params file.
   # This function is run at the beginning of a child process, and each time a file named "reload" is found in it's directory.
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
   #The basic loop for a URL monitoring process.
   URL_OR_PING="URL"
   while [[ 1 == 1 ]]; do
      DATE=$( date +%m"/"%d" "%H":"%M":"%S )
      if [[ $IP_ADDRESS == false ]]; then
         # If an IP address was specified, and the correct version of curl is present
         SITE=$( curl -L -m 10 $URL 2> /dev/null | egrep -c "$CHECK_STRING" )
         if [[ "$SITE" -ne 0 ]]; then
            fn_hit
         else
            fn_miss
         fi
      elif [[ $IP_ADDRESS != false ]]; then
         # If no IP address was specified
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
   # The basic loop for a ping monitoring process
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
   # The basic loop for a DNS monitoring process
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
   # Is there a file in place telling the child process to reload its params file, or to die?
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
   # When a child process exits, it needs to cleam up after itself and log the fact that it has exited.
   echo "$( date ) - [$MY_PID] - Stopped watching $URL_OR_PING $SERVER_STRING: Running for $RUN_TIME seconds. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate." >> $LOG
   rm -rf "$WORKINGDIR""$MY_PID"
   exit
}

#### Hit and Miss Functions ####

function fn_hit {
   # This is run every time a monitoring process has a successful check
   # gather variables for use ni reporting, both to the log file and to e-mail.
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
   #Determine how verbose Xmonitor is set to be and prepare the message accordingly.
   VERBOSITY=$( cat "$WORKINGDIR"verbosity 2> /dev/null )
   if [[ $VERBOSITY == "verbose" ]]; then
      REPORT="$DATE - [$MY_PID] - $URL_OR_PING $SERVER_STRING: Succeeded! - Checking for $RUN_TIME seconds. Last failed check: $LAST_MISS_STRING. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate."
   else
      REPORT="$DATE - $URL_OR_PING $SERVER_STRING: Succeeded!"
   fi
   # Check to see if the parent is still in palce
   if [[ $( ps aux | grep "$MASTER_PID.*xmonitor.sh" | grep -vc " 0:00 grep " ) -eq 0 ]]; then
      fn_child_exit
   fi
   # If the last check was also successful
   if [[ $LAST_STATUS == "hit" ]]; then
      if [[ $VERBOSITY != "change" && $VERBOSITY != "none" && $VERBOSITY != "none2" ]]; then
         echo "$REPORT"
      fi
      HIT_CHECKS=$(( $HIT_CHECKS + 1 ))
      if [[ $LAST_MISS != "never" ]]; then
         fn_hit_email
      fi
   # If there was no last check
   elif [[ $LAST_STATUS == "none" ]]; then
      if [[ $VERBOSITY != "none" && $VERBOSITY != "none2" ]]; then
         echo -e "\e[1;32m""$REPORT""\e[00m"
      fi
      echo "$( date ) - [$MY_PID] - Initial status for $URL_OR_PING $SERVER_STRING: Check succeeded!" >> $LOG
      HIT_CHECKS=1
   # If the last check failed
   else
      if [[ $VERBOSITY != "none" && $VERBOSITY != "none2" ]]; then
         echo -e "\e[1;32m""$REPORT""\e[00m"
      fi
      echo "$( date ) - [$MY_PID] - Status changed for $URL_OR_PING $SERVER_STRING: Check succeeded after $MISS_CHECKS failed checks!" >> $LOG
      HIT_CHECKS=1
      fn_hit_email
   fi
   LAST_STATUS="hit"
}

function fn_miss {
   # This is run every time a monitoring process has a failed check
   # gather variables for use in reporting, both to the log file and to e-mail.
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
   # determine what the verbosity is set to and prepare the message accordingly.
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
      # If the last check was also a miss
      if [[ $VERBOSITY != "change" && $VERBOSITY != "none" && $VERBOSITY != "none2" ]]; then
         echo -e "\e[1;33m""$REPORT""\e[00m"
      fi
      MISS_CHECKS=$(( $MISS_CHECKS + 1 ))
      if [[ $LAST_HIT != "never" ]]; then
         fn_miss_email
      fi
   elif [[ $LAST_STATUS == "none" ]]; then
      # If there was no last check
      if [[ $VERBOSITY != "none" && $VERBOSITY != "none2" ]]; then
         echo -e "\e[1;31m""$REPORT""\e[00m"
      fi
      echo "$( date ) - [$MY_PID] - Initial status for $URL_OR_PING $SERVER_STRING: Check failed!" >> $LOG
      MISS_CHECKS=1
   else
      # If the last check was a hit.
      if [[ $VERBOSITY != "none" && $VERBOSITY != "none2" ]]; then
         echo -e "\e[1;31m""$REPORT""\e[00m"
      fi
      echo "$( date ) - [$MY_PID] - Status changed for $URL_OR_PING $SERVER_STRING: Check failed after $HIT_CHECKS successful checks!" >> $LOG
      MISS_CHECKS=1
      fn_miss_email
   fi
   LAST_STATUS="miss"
}

function fn_hit_email {
   # Determines if a success e-mail needs to be sent and, if so, sends that e-mail.
   if [[ $HIT_CHECKS -eq $MAIL_DELAY && ! -z $EMAIL_ADDRESS && $MISS_MAIL == true ]]; then
      echo -e "$( date ) - Xmonitor - $URL_OR_PING $SERVER_STRING - Status changed: Appears to be succeeding again.\n\nYou're recieving this message to inform you that $MAIL_DELAY consecutive check(s) against $URL_OR_PING $SERVER_STRING have succeeded, thus meeting your threshold for being alerted. Since the previous e-mail was sent (Or if none have been sent, since checks against this server were started) there have been a total of $NUM_HITS_EMAIL successful checks, and $NUM_MISSES_EMAIL failed checks.\n\nChecks have been running for $RUN_TIME seconds. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate.\n\nLogs related to this check;\n\n$( tail -n $( echo $(( $( wc -l $LOG | cut -d " " -f1 ) - $( grep -n "\[$MY_PID\] - Initial" $LOG | tail -n1 | cut -d ":" -f1 ) + 5 )) ) $LOG | grep "\[$MY_PID\]" )" | mail -s "$URL_OR_PING $SERVER_STRING - Check PASSED!" $EMAIL_ADDRESS && echo "$( date ) - [$MY_PID] - $URL_OR_PING $SERVER_STRING: Success e-mail sent" >> $LOG &
      # set the variables that prepare for the next message to be sent.
      HIT_MAIL=true
      MISS_MAIL=false
      NUM_HITS_EMAIL=0
      NUM_MISSES_EMAIL=0
   fi
}

function fn_miss_email {
   # Determines if a failure e-mail needs to be sent and, if so, sends that e-mail.
   if [[ $MISS_CHECKS -eq $MAIL_DELAY && ! -z $EMAIL_ADDRESS && $HIT_MAIL == true ]]; then
      echo -e "$( date ) - Xmonitor - $URL_OR_PING $SERVER_STRING - Status changed: Appears to be failing.\n\nYou're recieving this message to inform you that $MAIL_DELAY consecutive check(s) against $URL_OR_PING $SERVER_STRING have failed, thus meeting your threshold for being alerted. Since the previous e-mail was sent (Or if none have been sent, since checks against this server were started) there have been a total of $NUM_HITS_EMAIL successful checks, and $NUM_MISSES_EMAIL failed checks.\n\nChecks have been running for $RUN_TIME seconds. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate.\n\nLogs related to this check;\n\n$( tail -n $( echo $(( $( wc -l $LOG | cut -d " " -f1 ) - $( grep -n "\[$MY_PID\] - Initial" $LOG | tail -n1 | cut -d ":" -f1 ) + 5 )) ) $LOG | grep "\[$MY_PID\]" )" | mail -s "$URL_OR_PING $SERVER_STRING - Check FAILED!" $EMAIL_ADDRESS && echo "$( date ) - [$MY_PID] - $URL_OR_PING $SERVER_STRING: Failure e-mail sent" >> $LOG &
      # set the variables that prepare for the next message to be sent.
      HIT_MAIL=false
      MISS_MAIL=true
      NUM_HITS_EMAIL=0
      NUM_MISSES_EMAIL=0
   fi
}

#### Master Functions ####

function fn_master {
   # This is the loop for the master function.
   if [[ $RUNNING_STATE != "master" ]]; then
      echo "Master process already present. Exiting"
      exit
   fi
   trap fn_master_exit SIGINT SIGTERM SIGKILL
   VERBOSITY=$( cat "$WORKINGDIR"verbosity )
   while [[ 1 == 1 ]]; do
      # Check if there are any new files within the new/ directory. Assume that they're params files for new jobs
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
            # Note - the server string doesn't need to be present, but it makes ps more readable.
            # Launch the child process
            "$PROGRAMDIR"xmonitor.sh $SERVER_STRING &
            # create the child's wirectory and move the params file there.
            CHILD_PID=$!
            mkdir -p "$WORKINGDIR""$CHILD_PID"
            mv "$WORKINGDIR""new/$i" "$WORKINGDIR""$CHILD_PID""/params"
         done
      fi
      # go through the directories for child processes. Make sure that each one is associated with a running child process. If not, clean up after it.
      for i in $( find $WORKINGDIR -type d ); do
         CHILD_PID=$( basename $i )
         if [[ $( echo $CHILD_PID | grep -vc [^0-9] ) -eq 1 ]]; then
            if [[ $( ps aux | grep "$CHILD_PID.*xmonitor.sh" | grep -vc " 0:00 grep " ) -eq 0 ]]; then
               echo "$( date ) - [$CHILD_PID] - $( sed -n "1 p" "$WORKINGDIR""$CHILD_PID/params" 2> /dev/null | sed "s/^--//" ) $( sed -n "7 p" "$WORKINGDIR""$CHILD_PID/params" 2> /dev/null ) - CHILD process was found dead." >> $LOG
               rm -rf "$WORKINGDIR""$CHILD_PID"
            fi
         fi
      done
      # Has verbosity changed? If so, announce this fact!
      if [[ ! -f "$WORKINGDIR"verbosity ]]; then
         echo $VERBOSITY > "$WORKINGDIR"verbosity
      elif [[ $( cat "$WORKINGDIR"verbosity ) != $VERBOSITY ]]; then
         VERBOSITY=$( cat "$WORKINGDIR"verbosity )
         echo "***Verbosity is now set as \"$VERBOSITY\"***"
      fi
      # Is there a file named "die" in the worknig directory? If so, end the master process.
      if [[ -f "$WORKINGDIR"die ]]; then
         fn_master_exit
      fi
      sleep 2
   done
}

function fn_master_exit {
   # these steps are run after the master process has recieved a signal that it needs to die.
   if [[ ! -f "$WORKINGDIR"die ]]; then
      # If the "die" file is not present, it was CTRL-C'd from the command line. Prompt if the child processes should be saved.
      if [[ -f "$WORKINGDIR"verbosity  ]]; then
         VERBOSITY=$( cat "$WORKINGDIR"verbosity )
      else
         VERBOSITY="standard"
      fi
      # Set verbosity to "none2". This is only ever set here. If upon starting, it's found set to "none2", we know that this process was exited out of before completion and that the verbosity setting is therefore wrong. This allows us to retain verbosity information across sessions without having to worry that it's been misset by an aborted exit.
      echo "none2" > "$WORKINGDIR"verbosity
      echo "Options:"
      echo
      echo "  1) Kill the master process and all child processes."
      echo "  2) Back up the data for the child processes so that they'll start again next time Xmonitor is run, then kill the master process and all child processes."
      echo
      read -p "How would you like to proceed? " OPTION_NUM
      if [[ $OPTION_NUM == "2" ]]; then
         touch "$WORKINGDIR"save
      fi
      echo $VERBOSITY > "$WORKINGDIR"verbosity
   fi
   # Is there a file in the working directory naemd "save"? If so, let's backup the current jobs.
   if [[ -f "$WORKINGDIR"save ]]; then
      rm -f "$WORKINGDIR"save
      for i in $( find "$WORKINGDIR" -type d ); do 
         CHILD_PID=$( basename $i )
         if [[ $( echo $CHILD_PID | grep -vc [^0-9] ) -eq 1 ]]; then 
            cp -a $i/params "$WORKINGDIR"new/$CHILD_PID.txt
         fi
      done
   fi
   rm -f "$WORKINGDIR"xmonitor.pid "$WORKINGDIR"die
   exit
}

#### Other Functions ####

function fn_verbosity {
   # This is the menu front-end for determining verbosity.
   OLD_VERBOSITY=$( cat "$WORKINGDIR"verbosity 2> /dev/null )
   if [[ -z $OLD_VERBOSITY ]]; then
      echo "Verbosity is not currently set"
   else
      echo "Verbosity is currently set to \"$OLD_VERBOSITY\"."
   fi
   echo
   echo "  1) Standard: A description of the server and whether the check passed or failed."
   echo "  2) Verbose: As standard, but with additional statistical information."
   echo "  3) Change: As standard, but only outputs when the status of the check is different than of the previous check."
   echo "  4) None: Nothing is output."
   echo
   read -p "What would you like the new verbosity to be? " OPTION
   if [[ $( echo "$OPTION" | egrep -vc "^0-9" ) -eq 0 || $OPTION -gt 4 ]]; then
      echo "Invalid input. Exiting"
      exit
   fi
   if [[ $OPTION == "1" ]]; then
      VERBOSITY="standard"
   elif [[ $OPTION == "2" ]]; then
      VERBOSITY="verbose"
   elif [[ $OPTION == "3" ]]; then
      VERBOSITY="change"
   elif [[ $OPTION == "4" ]]; then
      VERBOSITY="none"
   fi
   fn_verbosity_assign
}

function fn_verbosity_assign {
   # This process handles the back-end of assigning verbosity.
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
   # This is the menu front-end for modifying child processes.
   if [[ $RUNNING_STATE == "master" ]]; then
      echo "No current xmonitor processes. Exiting"
      exit
   fi
   echo "List of currently running xmonitor processes:"
   echo
   CHILD_NUMBER="0"
   aCHILD_PID[0]="none"
   # List the current xmonitor processes.
   for i in $( find $WORKINGDIR -type d ); do
      CHILD_PID=$( basename $i )
      if [[ $( echo $CHILD_PID | grep -vc [^0-9] ) -eq 1 ]]; then
         CHILD_NUMBER=$(( $CHILD_NUMBER + 1 ))
         echo "  $CHILD_NUMBER) [$CHILD_PID] - $( sed -n "1 p" "$WORKINGDIR""$CHILD_PID/params" | sed "s/^--//" ) $( sed -n "7 p" "$WORKINGDIR""$CHILD_PID/params" )"
         aCHILD_PID[$CHILD_NUMBER]="$CHILD_PID"
      fi
   done
   if [[ $IS_LIST == true ]]; then
      echo
      exit
   fi
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
      # sub-menu for if the master process is selected.
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
      # Sub-menu for if a child process is selected.
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
            EMAIL_ADDRESS=""
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
         echo "The server string has been updated."
      else
         echo "Exiting"
      fi
   fi
}

function fn_options {
   # this is the menu front end that's accessed when xmonitor is run with no flags
   echo
   echo "Available Options:"
   echo
   echo "  1) Monitor a URL."
   echo "  2) Monitor ping on a server."
   echo "  3) Monitor DNS services on a server."
   echo "  4) Print help information."
   echo "  5) Print version information."
   echo "  6) Change default values."
   if [[ $RUNNING_STATE == "master" ]]; then
      echo "  7) Spawn a master process without designating anything to monitor."
   elif [[ $RUNNING_STATE == "control" ]]; then
      echo "  7) Modify child processes or the master process."
      echo "  8) Change the output verbosity of child processes."
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
   elif [[ $OPTION_NUM == "6" ]]; then
      fn_defaults
   elif [[ $OPTION_NUM == "7" && $RUNNING_STATE == "master" ]]; then
      fn_master
   elif [[ $OPTION_NUM == "7" && $RUNNING_STATE == "control" ]]; then
      fn_modify
   elif [[ $OPTION_NUM == "8" && $RUNNING_STATE == "control" ]]; then
      fn_verbosity
   else
      echo "Invalid option. Exiting."
      exit
   fi
}

function fn_defaults {
   echo
   echo "From this menu, you can set a default value for the following things:"
   echo
   echo "  1) E-mail address"
   echo "  2) Number of seconds between iterative checks"
   echo "  3) Number of consecutive failed or successful checks before an e-mail is sent"
   echo
   read -p "Which would you like to set? " OPTION_NUM
   if [[ $OPTION_NUM == "1" ]]; then
      echo
      echo "Current default e-mail address is: \"$( cat "$WORKINGDIR"email_address )\"."
      read -p "Enter the new default e-mail address: " EMAIL_ADDRESS
      "$PROGRAMDIR"xmonitor.sh --default --mail $EMAIL_ADDRESS
   elif [[ $OPTION_NUM == "2" ]]; then
      echo
      echo "Current default number of seconds is: \"$( cat "$WORKINGDIR"wait_seconds )\"."
      read -p "Enter the new default number of seconds: " WAIT_SECONDS
      "$PROGRAMDIR"xmonitor.sh --default --seconds $WAIT_SECONDS
   elif [[ $OPTION_NUM == "3" ]]; then
      echo
      echo "Current default number of checks is: \"$( cat "$WORKINGDIR"mail_delay )\"."
      read -p "Enter the new default number of checks: " MAIL_DELAY
      "$PROGRAMDIR"xmonitor.sh --default --mail-delay $MAIL_DELAY
   fi
}

function fn_set_defaults {
   # This function is run when using the --default flag in order to set default values.
   if [[ ! -z $EMAIL_ADDRESS ]]; then
      echo "$EMAIL_ADDRESS" > "$WORKINGDIR"email_address
      echo "Default e-mail address set to $EMAIL_ADDRESS."
   fi
   if [[ ! -z $WAIT_SECONDS ]]; then
      echo "$WAIT_SECONDS" > "$WORKINGDIR"wait_seconds
      echo "Default seconds between iterative checks set to $WAIT_SECONDS."
   fi
   if [[ ! -z $MAIL_DELAY ]]; then
      echo "$MAIL_DELAY" > "$WORKINGDIR"mail_delay
      echo "Default consecutive failed or successful checks before an e-mail is sent set to $MAIL_DELAY."
   fi
}

#### Help and Version Functions ####

function fn_help {
cat << 'EOF' > /dev/stdout

Xmonitor - A script to organize and consolidate the monitoring of multiple servers. With Xmonitor you can run checks against multiple servers simultaneously, starting new jobs and stopping old ones as needed without interfering with any that are currently running. All output from the checks goes to a single terminal window, allowing you to keep an eye on multiple things going on at once.


USAGE:

./xmonitor.sh (Followed by no arguments or flags)
     Prompts you on how you want to proceed, allowing you to choose from options similar to those presented by the descriptions below.


ADDITIONAL USAGE:

./xmonitor.sh [--url (or -u)|--ping (or -p)|--dns (or -d)] (followed by other flags)
     1) Leaves a prompt telling the master process to spawn a child process to either a) in the case of --url, check a site's contents for a string of characters b) in the case of --ping, ping a site and check for a response c) in the case of --dns, dig against a nameserver and check for a valid response.
     2) If there is no currently running master process, it goes on to declare itself the master process and spawn child processes accordingly.
     NOTE: For more information on the additional arguments and flags that can be used here, run ./xmonitor --help-flags

./xmonitor.sh --modify (or -m)
     Prompts you with a list of currently running child processes and allows you to change how frequently their checks occur and how they send e-mail allerts, or kill them off if they're no longer desired.

./xmonitor.sh --help or (-h)
     Displays this dialogue.

./xmonitor.sh --help-flags
     Outputs help information with specific descriptions of all of the command line flags.

./xmonitor.sh --version
     Displays changes over the various versions.

./xmonitor.sh --kill (--save)
     Kills off the Xmonitor master process, which in turn prompts any child processes to exit as well. Optionally, you can use the "--save" flag in conjunction with "--kill" to save all of the current running child processes so that they will be restarted automaticaly when xmonitor is next launched.


ADDITIONAL ADDITIONAL USAGE:

Run ./xmonitor --help-flags for further information.


OTHER NOTES:

Note: Regarding e-mail alerts!
     Xmonitor sends e-mail messages using the "mail" binary (usually located in /usr/bin/mail). In order for this to work as expected, you will likely need to modify the ~/.mailrc file with credentials for a valid e-mail account, otherwise the messages that are sent will likely get rejected.

Note: Regarding the log file!
     Xmonitor keeps a log file titled "xmonitor.log" in the same directory in which the script is located. This file is used to log when checks are started and stopped, and when ever there is a change in status on any of the checks.

Note: Regarding url checks and specifying an IP!
     Xmonitor allows you to specify an IP from which to pull a URL, rather than allowing DNS to resolve the domain name to an IP address. This is very useful in situations where you're attempting to monitor multiple servers within a load balanced setup. Unfortunately, the ability for curl to do this was only added in version 7.21.3. While that version is now more than two years old, it still has not made it into the standard repositories for some systems (CentOS 5 and 6, for example). Xmonitor checks if the functionality is present. If not, any IP addresses entered for URL checks will be ignored.

Note: Regarding text color!
     Text output is color coded as follows: Green - The first check that has succeeded after any number of failed checks. White - a check that has succeeded when the previous check was also successful. Red - the first check that has failed after any number of successful checks. Yellow - a check that has failed when the previous check was also a failure.

EOF
#"'do
exit
}

function fn_help_flags {
cat << 'EOF' > /dev/stdout

FLAGS FOR CREATING A NEW MONITORING JOB:

--dns (server), --ping (server), --url (url)

     Specifies what type of check is being created. Each of these should be followed by the domain name, IP address, or URL that is being monitored.

--control

     Designates the process as a control process - I.E. it just lays out the specifics of a child process and puts them in place for the master process to spawn, but even if there is not currently a master process, it does not designate itself master and spawn the process that's been specified.

--domain (domain name)

     If used with "--dns" specifies the domain name that you're querying the DNS server for. This is not a necessary flag when using "--url" or "--ping", but it can be used if you did not specify the URL, IP address, or domain after the "--url" or "--ping" flags. But why would you do that?

--ip (IP address)

     When used with "--url" this flag is used to specify that IP address of the server that you're running the check against. Without this flag, a DNS query is used to determine what IP the site needs to be pulled from. "--ip" is perfect for situations where multiple load balanced servers need to be monitored at once. When used with "--ping" or "--dns" this flag can be used to specify the IP address if not already specified after the "--ping" or "--dns" flags.

--mail (e-mail address)

     Specifies the e-mail address to which alerts regarding changes in status should be sent.

--mail-delay (number)

     Specifies the number of failed or successful chacks that need to occur in a row before an e-mail message is sent. The default is to send a message after each check that has a different result than the previous one, however for some monitoring jobs, this can be tedious and unnecessary. Setting this to "0" prevents e-mail allerts from being sent.

--seconds (number)

     Specifies the number of seconds after a check has completed to begin a new check. The default is 10 seconds.

--string

     When used with "--url", this specifies the string that the contents of the curl'd page will be searched for in order to confirm that it is loading correctly. Under optimal circumstances, this string should be something dynamically generated via php code that pulls information from a database - thus no matter if it's apache, mysql, or php that's failing, a change in status will be detected. Attempting to use this flag with "--ping or "--dns" will throw an error.


OTHER FLAGS:

--default

     Allows you to specify a default for "--mail", "--seconds", or "--mail-delay" (or any combination thereof) that will be assumed if ythey are not specified.

--help

     Displays the basic help information.

--help-flags
 
     Outputs the help information specific to command line flags.

--kill

     Used to terminate the master Xmonitor process, which in turn prompts any child processes to exit as well. This can be used in conjunction with the "--save" flag.
     
--master

     Immediately designates itself as the master process. If any prompts are waiting, it spawns child processes as they describe, it then checks periodically for new prompts and spawns processes accordingly. If the master process ends, all child processes it has spawned will end as well.

--modify

     Prompts you with a list of currently running child processes and allows you to change how frequently their checks occur and how they send e-mail allerts, or kill them off if they're no longer desired.

--save

     Used in conjunction with the "--kill" flag. Prompts Xmonitor to save all of the current running child processes before exiting so that they will be restarted automaticaly when xmonitor is next launched.

--verbosity

     Changes the verbosity level of the output of the child processes. Standard: Outputs whether any specific check has succeeded or failed. Verbose: In addition to the information given from the standard output, also indicates how long checks for that job have been running, how many have been run, and the percentage of successful checks. Change: Only outputs text on the first failure after any number of successes, or the first success after any number of failures. None: Child processes output no text.

--version

     Outputs information regarding the changes over the various versions.

EOF
#'"do
exit
}

function fn_version {
echo "Current Version: $VERSION"
cat << 'EOF' > /dev/stdout

Version Notes:
Future Versions -
     no current plans

1.1.0 -
     Added far more robust command line arguments
     Added the ability to parse those command line arguments
     Added a function that parses out any URL into a URL, IP address, domain, and port.
     Better descriptions of the verbosity settings in the menu
     Updated the help information and added a help option specifically for flags.
     Allowed for setting default e-mail address, wait_seconds, and mail_delay through "--default"
     E-mail messages are sent as a background process so that the script won't hang if mail isn't configured.

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

LOG="$WORKINGDIR""../xmonitor.log"

# Determine the running state
if [[ -f "$WORKINGDIR"xmonitor.pid && $( ps aux | grep "$( cat "$WORKINGDIR"xmonitor.pid 2> /dev/null ).*xmonitor.sh" | grep -vc " 0:00 grep " ) -gt 0 ]]; then
   if [[ $PPID == $( cat "$WORKINGDIR"xmonitor.pid 2> /dev/null ) ]]; then
      # Child processes monitor one thing only they are spawned only by the master process and when the master process is no longer present, they die.
      RUNNING_STATE="child"
      fn_child
   else
      # Control processes set up the parameters for new child processes and then exit.
      RUNNING_STATE="control"
   fi
else
   # The master process (which typically starts out functioning as a control process) waits to see if there are waiting jobs present in the "new/" directory, and then spawns child processes for them.
   RUNNING_STATE="master"
   # Create some necessary configuration files and directories
   mkdir -p "$WORKINGDIR""new/"
   echo $$ > "$WORKINGDIR"xmonitor.pid
   if [[ ! -f "$WORKINGDIR"verbosity || $( cat "$WORKINGDIR"verbosity ) == "none2" ]]; then
      echo "standard" > "$WORKINGDIR"verbosity
   fi
   if [[ ! -f "$WORKINGDIR"email_address ]]; then
      echo "" > "$WORKINGDIR"email_address
   fi
   if [[ ! -f "$WORKINGDIR"wait_seconds ]]; then
      echo "10" > "$WORKINGDIR"wait_seconds
   fi
   if [[ ! -f "$WORKINGDIR"mail_delay ]]; then
      echo "1" > "$WORKINGDIR"mail_delay
   fi
fi

# Turn the command line arguments into an array.
CL_ARGUMENTS=( "$@" )

# For each command line argument, determine what needs to be done.
for (( c=0; c<=$(( $# - 1 )); c++ )); do
   arg="${CL_ARGUMENTS[$c]}"
   if [[ $( echo $arg | egrep -c "^(--(url|dns|list|default|ping|master|version|help|help-flags|modify|verbosity|kill)|[^-]*-[hmvpud])$" ) -gt 0 ]]; then
      # These flags indicate a specific action for the script to take. Two actinos cannot be taken at once.
      if [[ ! -z $RUN_TYPE ]]; then
         # If another of these actions has already been specified, end.
         echo "Cannot use \"$RUN_TYPE\" and \"$arg\" simultaneously. Exiting."
         exit
      fi
      RUN_TYPE=$arg
      if [[ $( echo ${CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^-" ) -eq 0 ]]; then
         if [[ $arg == "--url" || $arg == "-u" ]]; then
            c=$(( $c + 1 ))
            URL="${CL_ARGUMENTS[$c]}"
         elif [[ $arg == "--dns" || $arg == "-d" || $arg == "--ping" || $arg == "-p" ]]; then
            c=$(( $c + 1 ))
            DOMAIN="${CL_ARGUMENTS[$c]}"
         elif [[ $arg == "--verbosity" || $arg == "-v" ]]; then
            c=$(( $c + 1 ))
            VERBOSITY="${CL_ARGUMENTS[$c]}"
         elif [[ $arg == "--kill" ]]; then
            c=$(( $c + 1 ))
            CHILD_PID="${CL_ARGUMENTS[$c]}"
         fi
      fi
   # All other flags modify or contribute to one of the above actions.
   elif [[ $arg == "--control" ]]; then
      RUNNING_STATE="control"
   elif [[ $arg == "--save" ]]; then
      SAVE_JOBS=true
   elif [[ $arg == "--mail" ]]; then
      if [[ $( echo ${CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^[^@][^@]*@[^.]*\..*$" ) -eq 1 ]]; then
         c=$(( $c + 1 ))
         EMAIL_ADDRESS="${CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--mail\" needs to be followed by an e-mail address. Exiting"
         exit
      fi
   elif [[ $arg == "--seconds" ]]; then
      if [[ $( echo ${CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^[[:digit:]][[:digit:]]*$" ) -eq 1 ]]; then
         c=$(( $c + 1 ))
         WAIT_SECONDS="${CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--seconds\" needs to be followed by a number of seconds. Exiting"
         exit
      fi
   elif [[ $arg == "--mail-delay" ]]; then
      if [[ $( echo ${CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^[[:digit:]][[:digit:]]*$" ) -eq 1 ]]; then
         c=$(( $c + 1 ))
         MAIL_DELAY="${CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--mail-delay\" needs to be followed by a number. Exiting"
         exit
      fi
   elif [[ $arg == "--ip" ]]; then
      if [[ $( echo ${CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^-" ) -eq 0 ]]; then
         # Specifically don't check if the value here is actually an IP address - fn_parse_server will take care of that. 
         c=$(( $c + 1 ))
         IP_ADDRESS="${CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--ip\" needs to be followed by an IP address. Exiting"
         exit
      fi
   elif [[ $arg == "--string" ]]; then
      if [[ $( echo ${CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^-" ) -eq 0 ]]; then
         c=$(( $c + 1 ))
         CHECK_STRING="${CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--string\" needs to be followed by a string (in quotes, if it contains spaces) for which the contents of the URL will be searched. Exiting"
         exit
      fi
   elif [[ $arg == "--domain" ]]; then
      if [[ $( echo ${CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^-" ) -eq 0 ]]; then
         c=$(( $c + 1 ))
         DNS_DOMAIN="${CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--domain\" needs to be followed by a domain name. Exiting"
         exit
      fi
   else
      if [[ $( echo $arg | grep -c "^-" ) -eq 1 ]]; then
         echo "There is no such flag \"$arg\". Exiting."
      else
         echo "I don't understand what flag the argument \"$arg\" is supposed to be associated with. Exiting."
      fi
      exit
   fi
   NUM_ARGUMENTS=$(( $NUM_ARGUMENTS + 1 ))
done

# Some of these flags need to be used alone.
if [[ $RUN_TYPE == "--master" || $RUN_TYPE == "--verbosity" || $RUN_TYPE == "-v" || $RUN_TYPE == "--version" || $RUN_TYPE == "--help-flags" || $RUN_TYPE == "--help" || $RUN_TYPE == "--modify" || $RUN_TYPE == "-h" || $RUN_TYPE == "-m" ]]; then
   if [[ $NUM_ARGUMENTS -gt 1 ]]; then
      echo "The flag \"$RUN_TYPE\" cannot be used with other flags. Exiting."
      exit
   fi
fi
# Tells the script where to go with the type of job that was selected.
if [[ $RUN_TYPE == "--url" || $RUN_TYPE == "-u" ]]; then
   fn_url_cl
elif [[ $RUN_TYPE == "--ping" || $RUN_TYPE == "-p" ]]; then
   fn_ping_cl
elif [[ $RUN_TYPE == "--dns" || $RUN_TYPE == "-d" ]]; then
   fn_dns_cl
elif [[ $RUN_TYPE == "--kill" ]]; then
   if [[ ! -z $CHILD_PID ]]; then
      if [[ ! -f  "$WORKINGDIR"$CHILD_PID/params ]]; then
         echo "Child ID provided does not exist."
         exit
      fi
      touch "$WORKINGDIR"$CHILD_PID/die
      echo "The child process will exit shortly."
      exit   
   elif [[ $SAVE_JOBS == true ]]; then
      if [[ $NUM_ARGUMENTS -gt 2 ]]; then
         echo "The \"--kill\" flag can only used a lone, with the \"--save\" flag, or in conjunction with the ID number of a child process. Exiting."
         exit
      fi
      touch "$WORKINGDIR"save
   else
      if [[ $NUM_ARGUMENTS -gt 1 ]]; then
         echo "The \"--kill\" flag can only used a lone, with the \"--save\" flag, or in conjunction with the ID number of a child process. Exiting."
         exit
      fi
   fi
   touch "$WORKINGDIR"die
   exit
elif [[ $RUN_TYPE == "--verbosity" || $RUN_TYPE == "-v" ]]; then
   if [[ -z $VERBOSITY ]]; then
      fn_verbosity
   else
      fn_verbosity_assign
   fi
elif [[ $RUN_TYPE == "--version" ]]; then
   fn_version
   exit
elif [[ $RUN_TYPE == "--help" || $1 == "-h" ]]; then
   fn_help
   exit
elif [[ $RUN_TYPE == "--help-flags" ]]; then
   fn_help_flags
   exit
elif [[ $RUN_TYPE == "--modify" || $1 == "-m" ]]; then
   fn_modify
elif [[ $RUN_TYPE == "--list" || $1 == "-l" ]]; then
   IS_LIST=true
   fn_modify
elif [[ $RUN_TYPE == "--master" ]]; then
   fn_master
elif [[ $RUN_TYPE == "--default" ]]; then
   fn_set_defaults
elif [[ -z $RUN_TYPE ]]; then
   if [[ $NUM_ARGUMENTS -ne 0 ]]; then
      echo "Some of the flags you used didn't make sense in context. Here's a menu instead."
   fi
   fn_options
fi
