#! /bin/bash

VERSION="1.2.2"

#######################
### BEGIN FUNCTIONS ###
#######################

#### Functions that gather variables ####

function fn_url_vars {
   ### When a URL monitoring task is selected from the menu, it will run through this function in order to acquire the necessary variables.
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
   read -p  "to have the IP resolved via DNS): " SERVER
   if [[ ! -z $SERVER ]]; then
      fn_parse_server
      IP_ADDRESS=$IP_ADDRESSa
   fi
   if [[ -z $SERVER || $IP_ADDRESS == false ]]; then
      IP_ADDRESS=false
      SERVER_STRING=$URL
   else
      SERVER_STRING="$URL at $IP_ADDRESS"
   fi
   echo
   echo "Should the script use Google Chrome's useragent when trying to access the site?"
   read -p "(Anything other than \"y\" or \"yes\" will be interpreted as \"no\".): " v_USER_AGENT
   if [[ $v_USER_AGENT == "y" || $v_USER_AGENT == "yes" ]]; then
      v_USER_AGENT=true
   else
      v_USER_AGENT=false
   fi

   echo
   echo "How many seconds should the script wait for a response from the server (default"
   read -p "$( cat "$WORKINGDIR"curl_timeout ) seconds).: " v_CURL_TIMEOUT
   if [[ -z $v_CURL_TIMEOUT || $( echo $v_CURL_TIMEOUT | grep -c "[^0-9]" ) -eq 1 ]]; then
      v_CURL_TIMEOUT="$( cat "$WORKINGDIR"curl_timeout )"
   fi

   fn_email_address

   fn_url_confirm
   ### If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_ping_vars {
   ### When a ping monitoring task is selected from the menu, it will run through this function in order to acquire the necessary variables.
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
   ### If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_dns_vars {
   ### When a DNS monitoring task is selected from the menu, it will run through this function in order to acquire the necessary variables.
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
   ### If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_email_address {
   ### When functions are run from the menu, they come here to gather the $WAIT_SECONDS $EMAIL_ADDRESS and $MAIL_DELAY variables.
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
   echo
   echo "Enter a file for status information to be output to (or press enter for the default"
   read -p "of \"$v_OUTPUT\".): " v_OUTPUT
   if [[ -z $v_OUTPUT ]]; then
      $v_OUTPUT="/dev/stdout"
   else
      if [[ ${v_OUTPUT:0:1} != "/" ]]; then
         echo "Please ensure that this file is referenced by an absolute path. Exiting."
         exit
      fi
      touch "$v_OUTPUT" 2> /dev/null
      v_STATUS=$?
      if [[ ( ! -f "$v_OUTPUT" || ! -w "$v_OUTPUT" || $v_STATUS == 1 ) && "$v_OUTPUT" != "/dev/stdout" ]]; then
         echo "Please ensure that this file is already created, and has write permissions. Exiting."
         exit
      fi
   fi
}

function fn_parse_server {
   ### given a URL, Domain name, or IP address, this parses those out into the variables $URL, $DOMAIN, $IP_ADDRESS, and $IP_PORT.
   if [[ $( echo $SERVER | grep -ci "^HTTP" ) -eq 0 ]]; then
      DOMAINa=$SERVER
      URLa=$SERVER
      IP_PORTa="80"
   else
      ### get rid of "http(s)" at the beginning of the domain name
      DOMAINa=$( echo $SERVER | sed -e "s/^[Hh][Tt][Tt][Pp][Ss]*:\/\///" )
      if [[ $( echo $SERVER | grep -ci "^HTTPS" ) -eq 1 ]]; then
         URLa=$SERVER
         IP_PORTa="443"
      else
         URLa=$( echo $SERVER | sed -e "s/^[Hh][Tt][Tt][Pp]:\/\///" )
         IP_PORTa="80"
      fi
   fi
   ### get rid of the slash and anything else that follows the domain name
   DOMAINa="$( echo $DOMAINa | sed 's/^\([^/]*\).*$/\1/' )"
   ### check if it's an IP.
   if [[ $( echo $DOMAINa | egrep "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$" | wc -l ) -eq 0 ]]; then
      IP_ADDRESSa=$( dig +short $DOMAINa | tail -n1 )
      if [[ $( echo $IP_ADDRESSa | egrep -c "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$" ) -eq 0 ]]; then
         IP_ADDRESSa=false
      fi
   else
      IP_ADDRESSa=$DOMAINa
   fi
   ### If the port is specified in the URL, lets use that.
   if [[ $( echo $DOMAINa | grep -c ":" ) -eq 1 ]]; then
      IP_PORTa="$( echo $DOMAINa | cut -d ":" -f2 )"
      DOMAINa="$( echo $DOMAINa | cut -d ":" -f1 )"
   fi
}

#### Functions that gather variables from command line flags ####

function fn_url_cl {
   ### When a URL monitoring job is run from the command line, this parses out the commandline variables...
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
      if [[ $IP_ADDRESS == false ]]; then
         echo "Not a valid IP address. Exiting."
         exit
      fi
   fi
   if [[ -z $URL && ! -z $DNS_DOMAIN ]]; then
      URL=$DNS_DOMAIN
   fi
   ### ...and then makes sure that those variables are correctly assigned.
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
   ### If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_ping_cl {
   ### When a Ping monitoring job is run from the command line, this parses out the commandline variables...
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
   ### ...and then makes sure that those variables are correctly assigned.
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
   ### If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_dns_cl {
   ### When a DNS monitoring job is run from the command line, this parses out the commandline variables...
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
   ### ...and then makes sure that those variables are correctly assigned.
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
   ### If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_email_cl {
   ### This function parses out the command line information for e-mail address
   if [[ -z $WAIT_SECONDS || $( echo $WAIT_SECONDS | grep -c "[^0-9]" ) -eq 1 ]]; then
      WAIT_SECONDS="$( cat "$WORKINGDIR"wait_seconds )"
   fi
   if [[ -z $v_CURL_TIMEOUT || $( echo $v_CURL_TIMEOUT | grep -c "[^0-9]" ) -eq 1 ]]; then
      v_CURL_TIMEOUT="$( cat "$WORKINGDIR"curl_timeout )"
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
   ### When run from the menu, this confirms the settings for a Ping job.
   echo "I will begin monitoring the following:"
   echo "---Domain / IP to ping: $SERVER_STRING"
   NEW_JOB="$( date +%s )""_$RANDOM.job"
   echo "--ping" > "$WORKINGDIR""$NEW_JOB"
   fn_mutual_confirm
   mv -f "$WORKINGDIR""$NEW_JOB" "$WORKINGDIR""new/$NEW_JOB"
}

function fn_dns_confirm {
   ### When run from the menu, this confirms the settings for a DNS job.
   echo "I will begin monitoring the following:"
   echo "---Domain / IP to query: $SERVER_STRING"
   SERVER_STRING="$DOMAIN @$SERVER_STRING"
   echo "---Domain to query for: $DOMAIN"
   NEW_JOB="$( date +%s )""_$RANDOM.job"
   echo "--dns" > "$WORKINGDIR""$NEW_JOB"
   fn_mutual_confirm
   mv -f "$WORKINGDIR""$NEW_JOB" "$WORKINGDIR""new/$NEW_JOB"
}

function fn_url_confirm {
   ### When run from the menu, this confirms the settings for a URL job.
   echo "I will begin monitoring the following:"
   echo "---URL to monitor: $URL"
   if [[ $IP_ADDRESS != false ]]; then
      echo "---IP Address to check against: $IP_ADDRESS"
   fi
   echo "---Port number: $IP_PORT"
   echo "---String that must be present to result in a success: \"$CHECK_STRING\""
   NEW_JOB="$( date +%s )""_$RANDOM.job"
   echo "--url" > "$WORKINGDIR""$NEW_JOB"
   fn_mutual_confirm
   ### There are additional variables for URL based jobs. Those are input into the params file here.
   echo "URL:$URL" >> "$WORKINGDIR""$NEW_JOB"
   echo "Port:$IP_PORT" >> "$WORKINGDIR""$NEW_JOB"
   echo "Check String:$CHECK_STRING" >> "$WORKINGDIR""$NEW_JOB"
   echo "User Agent:$v_USER_AGENT" >> "$WORKINGDIR""$NEW_JOB"
   echo "Curl Timeout:$v_CURL_TIMEOUT" >> "$WORKINGDIR""$NEW_JOB"
   mv -f "$WORKINGDIR""$NEW_JOB" "$WORKINGDIR""new/$NEW_JOB"
}

function fn_mutual_confirm {
   ### Confirms the remainder of the veriables from a menu-assigned task...
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
   ### ...and then inputs those variables into the params file so that the child process can read them.
   echo "Wait Seconds:$WAIT_SECONDS" >> "$WORKINGDIR""$NEW_JOB"
   echo "Email Address:$EMAIL_ADDRESS" >> "$WORKINGDIR""$NEW_JOB"
   echo "Mail Delay:$MAIL_DELAY" >> "$WORKINGDIR""$NEW_JOB"
   echo "Domain:$DOMAIN" >> "$WORKINGDIR""$NEW_JOB"
   echo "IP Address:$IP_ADDRESS" >> "$WORKINGDIR""$NEW_JOB"
   echo "Server String:$SERVER_STRING" >> "$WORKINGDIR""$NEW_JOB"
   echo "Server String (Original)::$SERVER_STRING" >> "$WORKINGDIR""$NEW_JOB"
   echo "Output:$v_OUTPUT" >> "$WORKINGDIR""$NEW_JOB"
}

function fn_cl_confirm {
   ### This takes the variables from a job started from the command line, and then places them in the params file in order for a child process to read them.
   NEW_JOB="$( date +%s )""_$RANDOM.job"
   if [[ $RUN_TYPE == "--url" || $RUN_TYPE == "-u" ]]; then
      echo "--url" > "$WORKINGDIR""$NEW_JOB"
   elif [[ $RUN_TYPE == "--ping" || $RUN_TYPE == "-p" ]]; then
      echo "--ping" > "$WORKINGDIR""$NEW_JOB"
   elif [[ $RUN_TYPE == "--dns" || $RUN_TYPE == "-d" ]]; then
      echo "--dns" > "$WORKINGDIR""$NEW_JOB"
   fi
   echo "Wait Seconds:$WAIT_SECONDS" >> "$WORKINGDIR""$NEW_JOB"
   echo "Email Address:$EMAIL_ADDRESS" >> "$WORKINGDIR""$NEW_JOB"
   echo "Mail Delay:$MAIL_DELAY" >> "$WORKINGDIR""$NEW_JOB"
   echo "Domain:$DOMAIN" >> "$WORKINGDIR""$NEW_JOB"
   echo "IP Address:$IP_ADDRESS" >> "$WORKINGDIR""$NEW_JOB"
   echo "Server String:$SERVER_STRING" >> "$WORKINGDIR""$NEW_JOB"
   echo "Server String (Original):$SERVER_STRING" >> "$WORKINGDIR""$NEW_JOB"
   echo "Output:$v_OUTPUT" >> "$WORKINGDIR""$NEW_JOB"
   if [[ $RUN_TYPE == "--url" || $RUN_TYPE == "-u" ]]; then
      echo "URL:$URL" >> "$WORKINGDIR""$NEW_JOB"
      echo "Port:$IP_PORT" >> "$WORKINGDIR""$NEW_JOB"
      echo "Check String:$CHECK_STRING" >> "$WORKINGDIR""$NEW_JOB"
      echo "User Agent:$v_USER_AGENT" >> "$WORKINGDIR""$NEW_JOB"
      echo "Curl Timeout:$v_CURL_TIMEOUT" >> "$WORKINGDIR""$NEW_JOB"
   fi
   mv -f "$WORKINGDIR""$NEW_JOB" "$WORKINGDIR""new/$NEW_JOB"
}

#### Child Functions ####

function fn_child {
   ### The opening part of a child process!
   ### Wait to make sure that the params file is in place.
   sleep 1
   ### Make sure that the child processes are not exited out of o'er hastily.
   trap fn_child_exit SIGINT SIGTERM SIGKILL
   ### Define the variables that will be used over the life of the child process
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
   ### Pull the necessary variables for the child process from the params file.
   ### This function is run at the beginning of a child process, and each time a file named "reload" is found in it's directory.
   WAIT_SECONDS="$( egrep "^Wait Seconds:" "$WORKINGDIR""$MY_PID""/params" | tail -n1 | cut -d ":" -f2- )"
   EMAIL_ADDRESS="$( egrep "^Email Address:" "$WORKINGDIR""$MY_PID""/params" | tail -n1 | cut -d ":" -f2- )"
   MAIL_DELAY="$( egrep "^Mail Delay:" "$WORKINGDIR""$MY_PID""/params" | tail -n1 | cut -d ":" -f2- )"
   DOMAIN="$( egrep "^Domain:" "$WORKINGDIR""$MY_PID""/params" | tail -n1 | cut -d ":" -f2- )"
   IP_ADDRESS="$( egrep "^IP Address:" "$WORKINGDIR""$MY_PID""/params" | tail -n1 | cut -d ":" -f2- )"
   SERVER_STRING="$( egrep "^Server String:" "$WORKINGDIR""$MY_PID""/params" | tail -n1 | cut -d ":" -f2- )"
   ORIG_SERVER_STRING="$( egrep "^Server String \(Original\):" "$WORKINGDIR""$MY_PID""/params" | tail -n1 | cut -d ":" -f2- )"
   if [[ $OPERATION == "--url" ]]; then
      URL="$( egrep "^URL:" "$WORKINGDIR""$MY_PID""/params" | tail -n1 | cut -d ":" -f2- )"
      IP_PORT="$( egrep "^Port:" "$WORKINGDIR""$MY_PID""/params" | tail -n1 | cut -d ":" -f2- )"
      CHECK_STRING="$( egrep "^Check String:" "$WORKINGDIR""$MY_PID""/params" | tail -n1 | cut -d ":" -f2- )"
      v_USER_AGENT="$( egrep "^User Agent:" "$WORKINGDIR""$MY_PID""/params" | tail -n1 | cut -d ":" -f2- )"
      v_CURL_TIMEOUT="$( egrep "^Curl Timeout:" "$WORKINGDIR""$MY_PID""/params" | tail -n1 | cut -d ":" -f2- )"
      ### If there's an IP address, then the URL needs to have the domain replaced with the IP address and the port number.
      if [[ $IP_ADDRESS != "false" && $( echo $URL | egrep -c "^(http://|https://)*$DOMAIN:[0-9][0-9]*" ) -eq 1 ]]; then
         ### If it's specified with a port in the URL, lets make sure that it's the right port (according to the params file).
         URL="$( echo $URL | sed "s/$DOMAIN:[0-9][0-9]*/$IP_ADDRESS:$IP_PORT/" )"
      elif [[ $IP_ADDRESS != "false" ]]; then
         ### If it's not specified with the port in the URL, lets add the port.
         URL="$( echo $URL | sed "s/$DOMAIN/$IP_ADDRESS:$IP_PORT/" )"
      fi
      if [[ $v_USER_AGENT == true ]]; then
         v_USER_AGENT='Mozilla/5.0 (X11; Linux x86_64) Xmonitor/'"$VERSION"' AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.85 Safari/537.36'
      elif [[ $v_USER_AGENT == false ]]; then
         v_USER_AGENT='Xmonitor/'"$VERSION"' curl/'"$v_CURL_BIN_VERSION"
      fi
   fi
   v_OUTPUT2="$( egrep "^Output:" "$WORKINGDIR""$MY_PID""/params" | tail -n1 | cut -d ":" -f2- )"
   touch "$v_OUTPUT2" 2> /dev/null
   ### If the designated output file looks good, and is different than it was previously, log it.
   if [[ ! -z "$v_OUTPUT2" && "${v_OUTPUT2:0:1}" == "/" && ( -f "$v_OUTPUT2" || "$v_OUTPUT2" == "/dev/stdout" ) && -w "$v_OUTPUT2" && "$v_OUTPUT2" != "$v_OUTPUT" ]]; then
      echo "$( date ) - [$MY_PID] - Output for child process $MY_PID is being directed to $v_OUTPUT2" >> "$v_LOG"
      v_OUTPUT="$v_OUTPUT2"
   elif [[ -z "$v_OUTPUT2" && -z "$v_OUTPUT" ]]; then
      ### If there is no designated output file, and there was none previously, stdout will be fine.
      v_OUTPUT="/dev/stdout"
   fi
}

### Here's an example to test the logic being used for port numbers:
### URL="https://sporks5000.com:4670/index.php"; DOMAIN="sporks5000.com"; IP_PORT=8080; IP_ADDRESS="10.30.6.88"; if [[ $( echo $URL | egrep -c "^(http://|https://)*$DOMAIN:[0-9][0-9]*" ) -eq 1 ]]; then echo "curl $URL --header 'Host: $DOMAIN'" | sed "s/$DOMAIN:[0-9][0-9]*/$IP_ADDRESS:$IP_PORT/"; else echo "curl $URL --header 'Host: $DOMAIN'" | sed "s/$DOMAIN/$IP_ADDRESS:$IP_PORT/"; fi

function fn_url_child {
   ###The basic loop for a URL monitoring process.
   URL_OR_PING="URL"
   while [[ 1 == 1 ]]; do
      v_DATE3_LAST="$v_DATE3"
      v_DATE="$( date +%m"/"%d" "%H":"%M":"%S )"
      v_DATE2="$( date )"
      v_DATE3="$( date +%s )"
      if [[ -f "$WORKINGDIR""$MY_PID"/site_current.html ]]; then
         ### The only instalce where this isn't the case should be on the first run of the loop.
         mv -f "$WORKINGDIR""$MY_PID"/site_current.html "$WORKINGDIR""$MY_PID"/site_previous.html
      fi
      if [[ $IP_ADDRESS == false ]]; then
         ### If an IP address was specified, and the correct version of curl is present
         $v_CURL_BIN -kLsm $v_CURL_TIMEOUT $URL --header 'User-Agent: '"$v_USER_AGENT" 2> /dev/null > "$WORKINGDIR""$MY_PID"/site_current.html
         v_STATUS=$?
      elif [[ $IP_ADDRESS != false ]]; then
         ### If no IP address was specified
         $v_CURL_BIN -kLsm $v_CURL_TIMEOUT $URL --header "Host: $DOMAIN" --header 'User-Agent: '"$v_USER_AGENT" 2> /dev/null > "$WORKINGDIR""$MY_PID"/site_current.html
         v_STATUS=$?
      fi
      ### If the exit status of curl is 28, this means that the page timed out.
      if [[ $v_STATUS == 28 ]]; then
         echo "Curl return code: $v_STATUS (This means that the timeout was reached before the full page was returned.)" >> "$WORKINGDIR""$MY_PID"/site_current.html
      elif [[ $v_STATUS != 0 ]]; then
         echo "Curl return code: $v_STATUS" >> "$WORKINGDIR""$MY_PID"/site_current.html
      fi
      if [[ $( egrep -c "$CHECK_STRING" "$WORKINGDIR""$MY_PID"/site_current.html ) -ne 0 ]]; then
         fn_hit
      else
         fn_miss
      fi
      fn_child_checks
   done
}

function fn_ping_child {
   ### The basic loop for a ping monitoring process
   URL_OR_PING="Ping of"
   while [[ 1 == 1 ]]; do
      v_DATE="$( date +%m"/"%d" "%H":"%M":"%S )"
      v_DATE2="$( date )"
      v_DATE3="$( date +%s )"
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
   ### The basic loop for a DNS monitoring process
   URL_OR_PING="DNS for"
   while [[ 1 == 1 ]]; do
      v_DATE="$( date +%m"/"%d" "%H":"%M":"%S )"
      v_DATE2="$( date )"
      v_DATE3="$( date +%s )"
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
   ### Is there a file in place telling the child process to reload its params file, or to die?
   if [[ -f "$WORKINGDIR""$MY_PID"/reload ]]; then
      mv -f "$WORKINGDIR""$MY_PID"/reload "$WORKINGDIR""$MY_PID"/#reload
      fn_child_vars
      echo "$v_DATE2 - [$MY_PID] - Reloaded parameters for $URL_OR_PING $ORIG_SERVER_STRING." >> "$v_LOG"
      echo "$v_DATE2 - [$MY_PID] - Reloaded parameters for $URL_OR_PING $ORIG_SERVER_STRING." >> "$WORKINGDIR""$MY_PID"/log
      echo "***Reloaded parameters for $URL_OR_PING $SERVER_STRING.***"
   fi
   ### If there are more than 100 copies of the broken site, we only need to keep the last 100.
   if [[ $( ls -1 "$WORKINGDIR""$MY_PID"/ | grep -c "^site_" ) -gt 100 ]]; then
      rm -f "$WORKINGDIR""$MY_PID"/site_"$( ls -1t "$WORKINGDIR""$MY_PID"/ | grep "^site_" | tail -n1 | sed "s/site_//" )"
   fi
   ### If the domain or IP address shows up on the die list, this process can be killed.
   if [[ $( egrep -c "^[[:blank:]]*($DOMAIN|$IP_ADDRESS)[[:blank:]]*(#.*)*$" "$WORKINGDIR"die_list ) -gt 0 ]]; then
      echo "$( date ) - [$MY_PID] - Process ended due to data on the remote list. The line reads \"$( egrep "^[[:blank:]]*($DOMAIN|$IP_ADDRESS)[[:blank:]]*(#.*)*$" "$WORKINGDIR"die_list | head -n1 )\"." >> "$v_LOG"
      echo "$( date ) - [$MY_PID] - Process ended due to data on the remote list. The line reads \"$( egrep "^[[:blank:]]*($DOMAIN|$IP_ADDRESS)[[:blank:]]*(#.*)*$" "$WORKINGDIR"die_list | head -n1 )\"." >> "$WORKINGDIR""$MY_PID"/log
      touch "$WORKINGDIR""$MY_PID"/die
   fi
   if [[ -f "$WORKINGDIR""$MY_PID"/die ]]; then
      fn_child_exit
   fi
   sleep $WAIT_SECONDS
}

function fn_child_exit {
   ### When a child process exits, it needs to clean up after itself and log the fact that it has exited.
   echo "$v_DATE2 - [$MY_PID] - Stopped watching $URL_OR_PING $ORIG_SERVER_STRING: Running for $RUN_TIME seconds. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate." >> "$v_LOG"
   echo "$v_DATE2 - [$MY_PID] - Stopped watching $URL_OR_PING $ORIG_SERVER_STRING: Running for $RUN_TIME seconds. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate." >> "$WORKINGDIR""$MY_PID"/log
   ### Instead of deleting the directory, back it up temporarily.
   ### rm -rf "$WORKINGDIR""$MY_PID"
   if [[ -f "$WORKINGDIR""$MY_PID"/die ]]; then
      mv -f "$WORKINGDIR""$MY_PID"/die "$WORKINGDIR""$MY_PID"/#die
      mv "$WORKINGDIR""$MY_PID" "$WORKINGDIR""old_""$MY_PID""_""$v_DATE3"
   fi
   exit
}

#### Hit and Miss Functions ####

function fn_hit {
   ### This is run every time a monitoring process has a successful check
   ### gather variables for use in reporting, both to the log file and to e-mail.
   RUN_TIME=$(( $v_DATE3 - $START_TIME ))
   TOTAL_CHECKS=$(( $TOTAL_CHECKS + 1 ))
   TOTAL_HITS=$(( $TOTAL_HITS + 1 ))
   PERCENT_HITS=$( echo "scale=2; $TOTAL_HITS * 100 / $TOTAL_CHECKS" | bc )
   if [[ $LAST_MISS == "never" ]]; then
      LAST_MISS_STRING="never"
      if [[ $LAST_HIT == "never" ]]; then
         HIT_MAIL=true
      fi
   else
      LAST_MISS_STRING="$(( $v_DATE3 - $LAST_MISS )) seconds ago"
   fi
   LAST_HIT=$v_DATE3
   NUM_HITS_EMAIL=$(( $NUM_HITS_EMAIL + 1 ))
   ### Determine how verbose Xmonitor is set to be and prepare the message accordingly.
   if [[ "$WORKINGDIR""$MY_PID"/verbosity ]]; then
      VERBOSITY=$( cat "$WORKINGDIR""$MY_PID"/verbosity 2> /dev/null )
   else
      VERBOSITY=$( cat "$WORKINGDIR"verbosity 2> /dev/null )
   fi
   if [[ $VERBOSITY == "verbose" || -f "$WORKINGDIR""$MY_PID"/status ]]; then
      REPORT="$v_DATE - [$MY_PID] - $URL_OR_PING $SERVER_STRING: Succeeded! - Checking for $RUN_TIME seconds. Last failed check: $LAST_MISS_STRING. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate."
      if [[ -f "$WORKINGDIR""$MY_PID"/status ]]; then
         echo "$REPORT" > "$WORKINGDIR""$MY_PID"/status
         mv -f "$WORKINGDIR""$MY_PID"/status "$WORKINGDIR""$MY_PID/#status"
      fi
   else
      REPORT="$v_DATE - $URL_OR_PING $SERVER_STRING: Succeeded!"
   fi
   ### Check to see if the parent is still in palce
   if [[ $( ps aux | grep "$MASTER_PID.*xmonitor.sh" | grep -vc " 0:00 grep " ) -eq 0 ]]; then
      fn_child_exit
   fi
   ### If the last check was also successful
   if [[ $LAST_STATUS == "hit" ]]; then
      if [[ $VERBOSITY != "change" && $VERBOSITY != "none" && $VERBOSITY != "none2" ]]; then
         echo "$REPORT" >> "$v_OUTPUT"
      fi
      HIT_CHECKS=$(( $HIT_CHECKS + 1 ))
      if [[ $LAST_MISS != "never" ]]; then
         fn_hit_email
      fi
   ### If there was no last check
   elif [[ $LAST_STATUS == "none" ]]; then
      if [[ $VERBOSITY != "none" && $VERBOSITY != "none2" ]]; then
         echo -e "\e[1;32m""$REPORT""\e[00m" >> "$v_OUTPUT"
      fi
      echo "$v_DATE2 - [$MY_PID] - Initial status for $URL_OR_PING $ORIG_SERVER_STRING: Check succeeded!" >> "$v_LOG"
      echo "$v_DATE2 - [$MY_PID] - Initial status for $URL_OR_PING $ORIG_SERVER_STRING: Check succeeded!" >> "$WORKINGDIR""$MY_PID"/log
      HIT_CHECKS=1
   ### If the last check failed
   else
      if [[ $VERBOSITY != "none" && $VERBOSITY != "none2" ]]; then
         echo -e "\e[1;32m""$REPORT""\e[00m" >> "$v_OUTPUT"
      fi
      echo "$v_DATE2 - [$MY_PID] - Status changed for $URL_OR_PING $ORIG_SERVER_STRING: Check succeeded after $MISS_CHECKS failed checks!" >> "$v_LOG"
      echo "$v_DATE2 - [$MY_PID] - Status changed for $URL_OR_PING $ORIG_SERVER_STRING: Check succeeded after $MISS_CHECKS failed checks!" >> "$WORKINGDIR""$MY_PID"/log
      HIT_CHECKS=1
      fn_hit_email
   fi
   LAST_STATUS="hit"
}

function fn_miss {
   ### This is run every time a monitoring process has a failed check
   ### gather variables for use in reporting, both to the log file and to e-mail.
   RUN_TIME=$(( $v_DATE3 - $START_TIME ))
   TOTAL_CHECKS=$(( $TOTAL_CHECKS + 1 ))
   PERCENT_HITS=$( echo "scale=2; $TOTAL_HITS * 100 / $TOTAL_CHECKS" | bc )
   if [[ $LAST_HIT == "never" ]]; then
      LAST_HIT_STRING="never"
      if [[ $LAST_MISS == "never" ]]; then
         MISS_MAIL=true
      fi
   else
      LAST_HIT_STRING="$(( $v_DATE3 - $LAST_HIT )) seconds ago"
   fi
   LAST_MISS=$v_DATE3
   NUM_MISSES_EMAIL=$(( $NUM_MISSES_EMAIL + 1 ))
   ### determine what the verbosity is set to and prepare the message accordingly.
   if [[ "$WORKINGDIR""$MY_PID"/verbosity ]]; then
      VERBOSITY=$( cat "$WORKINGDIR""$MY_PID"/verbosity 2> /dev/null )
   else
      VERBOSITY=$( cat "$WORKINGDIR"verbosity 2> /dev/null )
   fi
   if [[ $VERBOSITY == "verbose" || -f "$WORKINGDIR""$MY_PID"/status ]]; then
      REPORT="$v_DATE - [$MY_PID] - $URL_OR_PING $SERVER_STRING: Failed! - Checking for $RUN_TIME seconds. Last successful check: $LAST_HIT_STRING. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate."
      if [[ -f "$WORKINGDIR""$MY_PID"/status ]]; then
         echo "$REPORT" > "$WORKINGDIR""$MY_PID"/status
         mv -f "$WORKINGDIR""$MY_PID"/status "$WORKINGDIR""$MY_PID"/#status
      fi
   else
      REPORT="$v_DATE - $URL_OR_PING $SERVER_STRING: Failed!"
   fi
   if [[ $( ps aux | grep "$MASTER_PID.*xmonitor.sh" | grep -vc " 0:00 grep " ) -eq 0 ]]; then
      fn_child_exit
   fi
   if [[ $LAST_STATUS == "miss" ]]; then
      ### If the last check was also a miss
      if [[ $VERBOSITY != "change" && $VERBOSITY != "none" && $VERBOSITY != "none2" ]]; then
         echo -e "\e[1;33m""$REPORT""\e[00m" >> "$v_OUTPUT"
      fi
      MISS_CHECKS=$(( $MISS_CHECKS + 1 ))
      if [[ $LAST_HIT != "never" ]]; then
         fn_miss_email
      fi
   elif [[ $LAST_STATUS == "none" ]]; then
      ### If there was no last check
      if [[ $VERBOSITY != "none" && $VERBOSITY != "none2" ]]; then
         echo -e "\e[1;31m""$REPORT""\e[00m" >> "$v_OUTPUT"
      fi
      echo "$v_DATE2 - [$MY_PID] - Initial status for $URL_OR_PING $ORIG_SERVER_STRING: Check failed!" >> "$v_LOG"
      echo "$v_DATE2 - [$MY_PID] - Initial status for $URL_OR_PING $ORIG_SERVER_STRING: Check failed!" >> "$WORKINGDIR""$MY_PID"/log
      MISS_CHECKS=1
   else
      ### If the last check was a hit.
      if [[ $VERBOSITY != "none" && $VERBOSITY != "none2" ]]; then
         echo -e "\e[1;31m""$REPORT""\e[00m" >> "$v_OUTPUT"
      fi
      ### The first failure after a hit should be the only instance where we need to save a copy of the site (if we're in URL mode).
      if [[ $URL_OR_PING == "URL" ]]; then
         cp -a "$WORKINGDIR""$MY_PID"/site_current.html "$WORKINGDIR""$MY_PID"/site_fail_"$v_DATE3".html
         cp -a "$WORKINGDIR""$MY_PID"/site_previous.html "$WORKINGDIR""$MY_PID"/site_success_"$v_DATE3_LAST".html
      fi
      echo "$v_DATE2 - [$MY_PID] - Status changed for $URL_OR_PING $ORIG_SERVER_STRING: Check failed after $HIT_CHECKS successful checks!" >> "$v_LOG"
      echo "$v_DATE2 - [$MY_PID] - Status changed for $URL_OR_PING $ORIG_SERVER_STRING: Check failed after $HIT_CHECKS successful checks!" >> "$WORKINGDIR""$MY_PID"/log
      MISS_CHECKS=1
      fn_miss_email
   fi
   LAST_STATUS="miss"
}

function fn_hit_email {
   ### Determines if a success e-mail needs to be sent and, if so, sends that e-mail.
   if [[ $HIT_CHECKS -eq $MAIL_DELAY && ! -z $EMAIL_ADDRESS && $MISS_MAIL == true ]]; then
      echo -e "$v_DATE2 - Xmonitor - $URL_OR_PING $SERVER_STRING - Status changed: Appears to be succeeding again.\n\nYou're recieving this message to inform you that $MAIL_DELAY consecutive check(s) against $URL_OR_PING $SERVER_STRING ($ORIG_SERVER_STRING) have succeeded, thus meeting your threshold for being alerted. Since the previous e-mail was sent (Or if none have been sent, since checks against this server were started) there have been a total of $NUM_HITS_EMAIL successful checks, and $NUM_MISSES_EMAIL failed checks.\n\nChecks have been running for $RUN_TIME seconds. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate.\n\nLogs related to this check;\n\n$( cat "$WORKINGDIR""$MY_PID"/log )" | mail -s "Xmonitor - $URL_OR_PING $SERVER_STRING - Check PASSED!" $EMAIL_ADDRESS && echo "$v_DATE2 - [$MY_PID] - $URL_OR_PING $ORIG_SERVER_STRING: Success e-mail sent" >> "$v_LOG" &
      ### set the variables that prepare for the next message to be sent.
      HIT_MAIL=true
      MISS_MAIL=false
      NUM_HITS_EMAIL=0
      NUM_MISSES_EMAIL=0
   fi
}

function fn_miss_email {
   ### Determines if a failure e-mail needs to be sent and, if so, sends that e-mail.
   if [[ $MISS_CHECKS -eq $MAIL_DELAY && ! -z $EMAIL_ADDRESS && $HIT_MAIL == true ]]; then
      echo -e "$v_DATE2 - Xmonitor - $URL_OR_PING $SERVER_STRING - Status changed: Appears to be failing.\n\nYou're recieving this message to inform you that $MAIL_DELAY consecutive check(s) against $URL_OR_PING $SERVER_STRING ($ORIG_SERVER_STRING) have failed, thus meeting your threshold for being alerted. Since the previous e-mail was sent (Or if none have been sent, since checks against this server were started) there have been a total of $NUM_HITS_EMAIL successful checks, and $NUM_MISSES_EMAIL failed checks.\n\nChecks have been running for $RUN_TIME seconds. $TOTAL_CHECKS checks completed. $PERCENT_HITS% success rate.\n\nLogs related to this check;\n\n$( cat "$WORKINGDIR""$MY_PID"/log )" | mail -s "Xmonitor - $URL_OR_PING $SERVER_STRING - Check FAILED!" $EMAIL_ADDRESS && echo "$v_DATE2 - [$MY_PID] - $URL_OR_PING $ORIG_SERVER_STRING: Failure e-mail sent" >> "$v_LOG" &
      ### set the variables that prepare for the next message to be sent.
      HIT_MAIL=false
      MISS_MAIL=true
      NUM_HITS_EMAIL=0
      NUM_MISSES_EMAIL=0
   fi
}

#### Master Functions ####

function fn_master {
   ### This is the loop for the master function.
   if [[ $RUNNING_STATE != "master" ]]; then
      echo "Master process already present. Exiting"
      exit
   fi
   ### try to prevent the master process from exiting unexpectedly.
   trap fn_master_exit SIGINT SIGTERM SIGKILL
   VERBOSITY=$( cat "$WORKINGDIR"verbosity )
   ### Get rid of the save file (if there is one).
   if [[ -f "$WORKINGDIR"save ]]; then
      rm -f "$WORKINGDIR"save
   fi
   v_TIMESTAMP_REMOTE_CHECK=0
   v_TIMESTAMP_LOCAL_CHECK=0
   $v_CURL_BIN -Lsm 10 http://72.52.228.74/xmonitor.txt --header "Host: tacobell.com" > "$WORKINGDIR"die_list
   while [[ 1 == 1 ]]; do
      ### Check to see what the current IP address is (thanks to VPN, this can change, so we need to check every half hour.
      if [[ $(( $( date +%s ) - 1800 )) -gt $v_TIMESTAMP_REMOTE_CHECK ]]; then
         v_TIMESTAMP_REMOTE_CHECK="$( date +%s )"
         v_LOCAL_IP="$( $v_CURL_BIN -Lsm 10 http://ip.liquidweb.com/ )"
         if [[ -z $v_LOCAL_IP ]]; then
            v_LOCAL_IP="Not_Found"
         fi
         ### Also, let's do getting rid of old processes here - there's no reason to do that every two seconds, and this already runs every half hour, so there's no need to create a separate timer for that.
         for v_OLD_CHILD in $( find "$WORKINGDIR" -maxdepth 1 -type d | rev | cut -d "/" -f1 | rev | grep "^old_[0-9][0-9]*_[0-9][0-9]*$" ); do
            if [[ $( echo $v_OLD_CHILD | grep -c "^old_[[:digit:]]*_[[:digit:]]*$" ) -eq 1 ]]; then
               if [[ $(( $( date +%s ) - $( echo $v_OLD_CHILD | cut -d "_" -f3 ) )) -gt 604800 ]]; then
                  ### 604800 seconds = seven days.
                  echo "$( date ) - [$( echo "$v_OLD_CHILD" | cut -d "_" -f2)] - $( sed -n "1 p" "$WORKINGDIR""$v_OLD_CHILD/params" 2> /dev/null | sed "s/^--//" ) $( egrep "^Server String:" "$WORKINGDIR""$v_OLD_CHILD""/params" | tail -n1 | cut -d ":" -f2- ) - Child process dead for seven days. Deleting backed up data." >> "$v_LOG"
                  rm -rf "$WORKINGDIR""$v_OLD_CHILD"
               fi
            fi
         done
      fi
      ### Check a remote list to see if xmonitor should be stopped
      if [[ $(( $( date +%s ) - 300 )) -gt $v_TIMESTAMP_REMOTE_CHECK ]]; then
         v_TIMESTAMP_REMOTE_CHECK="$( date +%s )"
         $v_CURL_BIN -Lsm 10 http://72.52.228.74/xmonitor.txt --header "Host: tacobell.com" > "$WORKINGDIR"die_list
         if [[ $( egrep -c "^[[:blank:]]*$v_LOCAL_IP[[:blank:]]*(#.*)*$" "$WORKINGDIR"die_list ) -gt 0 ]]; then
            touch "$WORKINGDIR"die
            touch "$WORKINGDIR"save
            echo "$( date ) - [$$] - Local IP found on remote list. The line reads \"$( egrep "^[[:blank:]]*$v_LOCAL_IP[[:blank:]]*(#.*)*$" "$WORKINGDIR"die_list | head -n1 )\". Process ended." >> "$v_LOG"
            fn_master_exit
         fi
      fi
      ### Check if there are any new files within the new/ directory. Assume that they're params files for new jobs
      if [[ $( ls -1 "$WORKINGDIR""new/" | wc -l ) -gt 0 ]]; then
         for i in $( ls -1 "$WORKINGDIR""new/" | grep "\.job$" ); do
            ### Find all files that are not marked as log files.
            SERVER_STRING="$( egrep "^Server String:" "$WORKINGDIR""new/$i" | tail -n1 | cut -d ":" -f2- )"
            OPERATION=$( sed -n "1 p" "$WORKINGDIR""new/$i" )
            if [[ $OPERATION == "--url" ]]; then
               SERVER_STRING="URL $SERVER_STRING"
               fn_spawn_child_process
            elif [[ $OPERATION == "--ping" ]]; then
               SERVER_STRING="PING $SERVER_STRING"
               fn_spawn_child_process
            elif [[ $OPERATION == "--dns" ]]; then
               SERVER_STRING="DNS $SERVER_STRING"
               fn_spawn_child_process
            fi
         done
         ### If there's anything else left in this directory, it is neither a job, nor a log file. Let's get rid of it.
         if [[ $( ls -1 "$WORKINGDIR""new/" | wc -l ) -gt 0 ]]; then
            rm -f "$WORKINGDIR"new/*
         fi
      fi
      ### go through the directories for child processes. Make sure that each one is associated with a running child process. If not....
      ### go through the directories for child processes. Make sure that each one is associated with a running child process. If not....
      for CHILD_PID in $( find "$WORKINGDIR" -maxdepth 1 -type d | rev | cut -d "/" -f1 | rev | grep "^[0-9][0-9]*$" ); do
         if [[ $( ps aux | grep "$CHILD_PID.*xmonitor.sh" | grep -vc " 0:00 grep " ) -eq 0 ]]; then
            ### If it's been marked to die, back it up temporarily
            if [[ -f "$WORKINGDIR""$CHILD_PID/die" ]]; then
               TIMESTAMP="$( date +%s )"
               mv "$WORKINGDIR""$CHILD_PID" "$WORKINGDIR""old_""$CHILD_PID""_""$TIMESTAMP"
            ### Otherwise, restart it, then backup the old data temporarily.
            else
               echo "$( date ) - [$CHILD_PID] - $( sed -n "1 p" "$WORKINGDIR""$CHILD_PID/params" 2> /dev/null | sed "s/^--//" ) $( egrep "^Server String:" "$WORKINGDIR""$CHILD_PID""/params" | tail -n1 | cut -d ":" -f2- ) - Child process was found dead. Restarting with new PID." >> "$v_LOG"
               NEW_JOB="$( date +%s )""_$RANDOM.job"
               cp -a "$WORKINGDIR""$CHILD_PID"/params "$WORKINGDIR""new/$NEW_JOB.job"
               if [[ -f "$WORKINGDIR""$CHILD_PID"/log ]]; then
                  ### If there's a log file, let's keep that too.
                  cp -a "$WORKINGDIR""$CHILD_PID"/log "$WORKINGDIR""new/$NEW_JOB".log
               fi
               TIMESTAMP="$( date +%s )"
               mv "$WORKINGDIR""$CHILD_PID" "$WORKINGDIR""old_""$CHILD_PID""_""$TIMESTAMP"
            fi
         fi
      done
      ### Has verbosity changed? If so, announce this fact!
      if [[ ! -f "$WORKINGDIR"verbosity ]]; then
         echo $VERBOSITY > "$WORKINGDIR"verbosity
      elif [[ $( cat "$WORKINGDIR"verbosity ) != $VERBOSITY ]]; then
         VERBOSITY=$( cat "$WORKINGDIR"verbosity )
         echo "***Verbosity is now set as \"$VERBOSITY\"***"
      fi
      ### Is there a file named "die" in the working directory? If so, end the master process.
      if [[ -f "$WORKINGDIR"die ]]; then
         fn_master_exit
      fi
      sleep 2
   done
}

function fn_spawn_child_process {
   ### This function launches the child process and makes sure that it has it's own working directory.
   ### Launch the child process
   "$PROGRAMDIR"xmonitor.sh $SERVER_STRING &
   ### Note - the server string doesn't need to be present, but it makes ps more readable. Each child process starts out as generic. Once the master process creates a working directory for it (based on its PID) and then puts the params file in place for it, only then does it discover its purpose.
   ### create the child's wirectory and move the params file there.
   CHILD_PID=$!
   mkdir -p "$WORKINGDIR""$CHILD_PID"
   touch "$WORKINGDIR""$CHILD_PID/#die" "$WORKINGDIR""$CHILD_PID/#reload" "$WORKINGDIR""$CHILD_PID/#status" "$WORKINGDIR""$CHILD_PID/#verbosity"
   mv "$WORKINGDIR""new/$i" "$WORKINGDIR""$CHILD_PID""/params"
   if [[ -f "$WORKINGDIR""new/$i".log ]]; then
   ### If there's a log file, let's move that log file into the appropriate directory as well.
      mv "$WORKINGDIR""new/$i".log "$WORKINGDIR""$CHILD_PID""/log"
   fi
}

function fn_master_exit {
   ### these steps are run after the master process has recieved a signal that it needs to die.
   if [[ ! -f "$WORKINGDIR"die ]]; then
      ### If the "die" file is not present, it was CTRL-C'd from the command line. Prompt if the child processes should be saved.
      if [[ -f "$WORKINGDIR"verbosity  ]]; then
         VERBOSITY=$( cat "$WORKINGDIR"verbosity )
      else
         VERBOSITY="standard"
      fi
      ### Set verbosity to "none2". This is only ever set here. If upon starting, it's found set to "none2", we know that this process was exited out of before completion and that the verbosity setting is therefore wrong. This allows us to retain verbosity information across sessions without having to worry that it's been misset by an aborted exit.
      echo "none2" > "$WORKINGDIR"verbosity
      echo "Options:"
      echo
      echo "  1) Kill the master process and all child processes."
      echo "  2) Back up the data for the child processes so that they'll start again next time Xmonitor is run, then kill the master process and all child processes."
      echo
      read -p "How would you like to proceed? " OPTION_NUM
      # If they've opted to kill off all the current running processes, place a "die" file in each of their directories.
      if [[ $OPTION_NUM == "1" ]]; then
         for i in $( find $WORKINGDIR -type d ); do
            CHILD_PID=$( basename $i )
            # if [[ $( echo $CHILD_PID | grep -vc [^0-9] ) -eq 1 ]]; then
            if [[ $( echo $CHILD_PID | sed "s/[[:digit:]]//g" | grep -c . ) -eq 0 ]]; then
               if [[ $( ps aux | grep "$CHILD_PID.*xmonitor.sh" | grep -vc " 0:00 grep " ) -gt 0 ]]; then
                  touch "$WORKINGDIR""$CHILD_PID/die"
               fi
            fi
         done
      fi
      echo $VERBOSITY > "$WORKINGDIR"verbosity
   fi
   rm -f "$WORKINGDIR"xmonitor.pid "$WORKINGDIR"die
   exit
}

#### Other Functions ####

function fn_verbosity {
   ### This is the menu front-end for determining verbosity.
   OLD_VERBOSITY=$( cat "$v_VERBOSITY_FILE" 2> /dev/null )
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
   ### This process handles the back-end of assigning verbosity.
   if [[ -z $v_VERBOSITY_FILE ]]; then
      v_VERBOSITY_FILE="$WORKINGDIR""verbosity"
   fi
   if [[ $VERBOSITY == "standard" ]]; then
      echo "standard" > "$v_VERBOSITY_FILE"
      echo "Verbosity is now set to \"standard\"."
   elif [[ $VERBOSITY == "verbose" ]]; then
      echo "verbose" > "$v_VERBOSITY_FILE"
      echo "Verbosity is now set to \"verbose\" - additional statistical information will now be printed with each check."
   elif [[ $VERBOSITY == "change" ]]; then
      echo "change" > "$v_VERBOSITY_FILE"
      echo "Verbosity is now set to \"change\" - only changes in status will be output to screen."
   elif [[ $VERBOSITY == "none" ]]; then
      echo "none" > "$v_VERBOSITY_FILE"
      echo "Verbosity is now set to \"none\" - nothing will be output to screen."
   fi
}

function fn_modify {
   ### This is the menu front-end for modifying child processes.
   if [[ $RUNNING_STATE == "master" ]]; then
      echo "No current xmonitor processes. Exiting"
      exit
   fi
   echo "List of currently running xmonitor processes:"
   echo
   CHILD_NUMBER="0"
   aCHILD_PID[0]="none"
   ### List the current xmonitor processes.
   for i in $( find $WORKINGDIR -type d ); do
      CHILD_PID=$( basename $i )
      ### if [[ $( echo $CHILD_PID | grep -vc [^0-9] ) -eq 1 ]]; then
      if [[ $( echo $CHILD_PID | sed "s/[[:digit:]]//g" | grep -c . ) -eq 0 ]]; then
         CHILD_NUMBER=$(( $CHILD_NUMBER + 1 ))
         echo "  $CHILD_NUMBER) [$CHILD_PID] - $( sed -n "1 p" "$WORKINGDIR""$CHILD_PID/params" | sed "s/^--//" ) $( egrep "^Server String:" "$WORKINGDIR""$CHILD_PID""/params" | tail -n1 | cut -d ":" -f2- )"
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
      ### sub-menu for if the master process is selected.
      echo -e "Options:\n"
      echo "  1) Exit out of the master process."
      echo "  2) First back-up the child processes so that they'll run immediately when xmonitor is next started, then exit out of the master process."
      echo "  3) Change the default verbosity."
      echo "  4) Exit out of this menu."
      echo
      read -p "Choose an option from the above list: " OPTION_NUM
      if [[ $OPTION_NUM == "1" ]]; then
         touch "$WORKINGDIR"die
      elif [[ $OPTION_NUM == "2" ]]; then
         touch "$WORKINGDIR"save
         touch "$WORKINGDIR"die
      elif [[ $OPTION_NUM == "3" ]]; then
         v_VERBOSITY_FILE="$WORKINGDIR""verbosity"
         fn_verbosity
      else
         echo "Exiting."
         exit
      fi
   else
      ### Sub-menu for if a child process is selected.
      echo "$( egrep "^Server String:" "$WORKINGDIR""$CHILD_PID""/params" | tail -n1 | cut -d ":" -f2- ):"
      echo
      echo "  1) Kill this process."
      echo "  2) Change the delay between checks from \"$( egrep "^Wait Seconds:" "$WORKINGDIR""$CHILD_PID""/params" | tail -n1 | cut -d ":" -f2- )\" seconds."
      echo "  3) Change e-mail address from \"$( egrep "^Email Address:" "$WORKINGDIR""$CHILD_PID""/params" | tail -n1 | cut -d ":" -f2- )\"."
      echo "  4) Change the number of consecutive failures or successes before an e-mail is sent from \"$( egrep "^Mail Delay:" "$WORKINGDIR""$CHILD_PID""/params" | tail -n1 | cut -d ":" -f2- )\""
      echo "  5) Change the title of the job as it's reported by the child process. (Currently \"$( egrep "^Server String:" "$WORKINGDIR""$CHILD_PID""/params" | tail -n1 | cut -d ":" -f2- )\")"
      echo "  6) Change the verbosity just for this process."
      echo "  7) Change the file that status information is output to. (Currently \"(Currently \"$( egrep "^Output:" "$WORKINGDIR""$CHILD_PID""/params" | tail -n1 | cut -d ":" -f2- )\")"
      echo "  8) Output the command to go to the working directory for this process."
      echo "  9) Directly edit the parameters file (with your EDITOR - \"$EDITOR\")."
      echo "  10) Exit out of this menu."
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
         sed -i "s/^Wait Seconds:.*$/Wait Seconds:$WAIT_SECONDS/" "$WORKINGDIR""$CHILD_PID/params"
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
         EMAIL_ADDRESS="$( echo $EMAIL_ADDRESS | sed -e 's/[\/&]/\\&/g' )"
         sed -i "s/^Email Address:.*$/Email Address:$EMAIL_ADDRESS/" "$WORKINGDIR""$CHILD_PID/params"
         touch "$WORKINGDIR""$CHILD_PID/reload"
         echo "E-mail address has been updated."
      elif [[ $OPTION_NUM == "4" ]]; then
         echo "Enter the number of consecutive failures or successes that should occur before an e-mail"
         read -p "message is sent (default 1; to never send a message, 0): " MAIL_DELAY
         if [[ -z $MAIL_DELAY || $( echo $MAIL_DELAY | grep -c "[^0-9]" ) -eq 1 ]]; then
            echo "Input must be a number. Exiting"
            exit
         fi
         sed -i "s/^Mail Delay:.*$/Mail Delay:$MAIL_DELAY/" "$WORKINGDIR""$CHILD_PID/params"
         touch "$WORKINGDIR""$CHILD_PID/reload"
         echo "Mail delay has been updated."
      elif [[ $OPTION_NUM == "5" ]]; then
         read -p "Enter a new identifying string to associate with this check: " SERVER_STRING
         SERVER_STRING="$( echo $SERVER_STRING | sed -e 's/[\/&]/\\&/g' )"
         sed -i "s/Server String:.*$/Server String:$SERVER_STRING/" "$WORKINGDIR""$CHILD_PID/params"
         touch "$WORKINGDIR""$CHILD_PID/reload"
         echo "The server string has been updated."
      elif [[ $OPTION_NUM == "6" ]]; then
         v_VERBOSITY_FILE="$WORKINGDIR""$CHILD_PID/verbosity"
         fn_verbosity
      elif [[ $OPTION_NUM == "7" ]]; then
         read -p "Enter a new file for status information to be output to: " v_OUTPUT
         if [[ ${v_OUTPUT:0:1} != "/" ]]; then
            echo "Please ensure that this file is referenced by an absolute path."
            exit
         fi
         touch "$v_OUTPUT" 2> /dev/null
         v_STATUS=$?
         if [[ ( ! -f "$v_OUTPUT" || ! -w "$v_OUTPUT" || $v_STATUS == 1 ) && "$v_OUTPUT" != "/dev/stdout" ]]; then
            echo "Please ensure that this file is already created, and has write permissions."
            exit
         fi
         v_OUTPUT="$( echo $v_OUTPUT | sed -e 's/[\/&]/\\&/g' )"
         sed -i "s/Output:.*$/Output:$v_OUTPUT/" "$WORKINGDIR""$CHILD_PID/params"
         touch "$WORKINGDIR""$CHILD_PID/reload"
         echo "The output file has been updated."
      elif [[ $OPTION_NUM == "8" ]]; then
         echo -en "\ncd $WORKINGDIR""$CHILD_PID/\n\n"
      elif [[ $OPTION_NUM == "9" ]]; then
         cp -a "$WORKINGDIR""$CHILD_PID/params" "$WORKINGDIR""$CHILD_PID/params.temp"
         if [[ ! -z $EDITOR ]]; then
            $EDITOR "$WORKINGDIR""$CHILD_PID/params"
         else
            vi "$WORKINGDIR""$CHILD_PID/params"
         fi
         ### Check to see if the params file has been modified. If so, reload.
         if [[ $( diff -q "$WORKINGDIR""$CHILD_PID/params" "$WORKINGDIR""$CHILD_PID/params.temp" | wc -l ) -gt 0 ]]; then
            touch "$WORKINGDIR""$CHILD_PID/reload"
         fi
         rm -f "$WORKINGDIR""$CHILD_PID/params.temp"
      else
         echo "Exiting"
      fi
   fi
}

function fn_options {
   ### this is the menu front end that's accessed when xmonitor is run with no flags
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
      echo "  8) Change default output verbosity for child processes."
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
      v_VERBOSITY_FILE="$WORKINGDIR""verbosity"
      fn_verbosity
   else
      echo "Invalid option. Exiting."
      exit
   fi
}

function fn_defaults {
   ### Gives the user a menu from which the defaults can be changed.
   echo
   echo "From this menu, you can set a default value for the following things:"
   echo
   echo "  1) E-mail address."
   echo "  2) Number of seconds between iterative checks."
   echo "  3) Number of consecutive failed or successful checks before an e-mail is sent."
   echo "  4) Number of seconds before curl times out."
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
   elif [[ $OPTION_NUM == "4" ]]; then
      echo
      echo "Current default number of seconds before curl times out is: \"$( cat "$WORKINGDIR"curl_timeout )\"."
      read -p "Enter the new default number of seconds: " v_CURL_TIMEOUT
      "$PROGRAMDIR"xmonitor.sh --default --curl-timeout $v_CURL_TIMEOUT
   fi
}

function fn_set_defaults {
   ### This function is run when using the --default flag in order to set default values.
   if [[ ! -z $EMAIL_ADDRESS ]]; then
      echo "$EMAIL_ADDRESS" > "$WORKINGDIR"email_address
      echo "Default e-mail address has been set to $EMAIL_ADDRESS."
   fi
   if [[ ! -z $WAIT_SECONDS ]]; then
      echo "$WAIT_SECONDS" > "$WORKINGDIR"wait_seconds
      echo "Default seconds between iterative checks has been set to $WAIT_SECONDS."
   fi
   if [[ ! -z $MAIL_DELAY ]]; then
      echo "$MAIL_DELAY" > "$WORKINGDIR"mail_delay
      echo "Default consecutive failed or successful checks before an e-mail is sent has been set to $MAIL_DELAY."
   fi
   if [[ ! -z $v_CURL_TIMEOUT ]]; then
      echo "$v_CURL_TIMEOUT" > "$WORKINGDIR"curl_timeout
      echo "Default number of seconds before curl times out has been set to $v_CURL_TIMEOUT."
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

Run ./xmonitor.sh --help-flags for further information.

Run ./xmonitor.sh --help-process-types for more information on master, control, and child processes.

Run ./xmonitor.sh --help-params-file for more information on editing the parameters file for a child process.


OTHER NOTES:

Note: Regarding e-mail alerts!
     Xmonitor sends e-mail messages using the "mail" binary (usually located in /usr/bin/mail). In order for this to work as expected, you will likely need to modify the ~/.mailrc file with credentials for a valid e-mail account, otherwise the messages that are sent will likely get rejected.

Note: Regarding the log file!
     Xmonitor keeps a log file titled "xmonitor.log" in the same directory in which xmonitor.sh is located. This file is used to log when checks are started and stopped, and when ever there is a change in status on any of the checks. In addition to this, there is another log file in the direcctory for each child process containing information only specific to that child process.

Note: Regarding url checks and specifying an IP!
     Xmonitor allows you to specify an IP from which to pull a URL, rather than allowing DNS to resolve the domain name to an IP address. This is very useful in situations where you're attempting to monitor multiple servers within a load balanced setup.

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

     Designates the process as a control process - I.E. it just lays out the specifics of a child process and puts them in place for the master process to spawn, but even if there is not currently a master process, it does not designate itself master and spawn the process that's been specified. Run ./xmonitor.sh --help-process-types for more information on master, control, and child processes.

--domain (domain name)

     If used with "--dns" specifies the domain name that you're querying the DNS server for. This is not a necessary flag when using "--url" or "--ping", but it can be used if you did not specify the URL, IP address, or domain after the "--url" or "--ping" flags. But why would you do that?

--ip (IP address)

     When used with "--url" this flag is used to specify that IP address of the server that you're running the check against. Without this flag, a DNS query is used to determine what IP the site needs to be pulled from. "--ip" is perfect for situations where multiple load balanced servers need to be monitored at once. When used with "--ping" or "--dns" this flag can be used to specify the IP address if not already specified after the "--ping" or "--dns" flags.

--mail (e-mail address)

     Specifies the e-mail address to which alerts regarding changes in status should be sent.

--mail-delay (number)

     Specifies the number of failed or successful chacks that need to occur in a row before an e-mail message is sent. The default is to send a message after each check that has a different result than the previous one, however for some monitoring jobs, this can be tedious and unnecessary. Setting this to "0" prevents e-mail allerts from being sent.

--outfile (file)

     By default, child processes output the results of their checks to the standard out (/dev/stdout) of the master process. This flag allows that output to be redirected to a file.

--seconds (number)

     Specifies the number of seconds after a check has completed to begin a new check. The default is 10 seconds.

--string

     When used with "--url", this specifies the string that the contents of the curl'd page will be searched for in order to confirm that it is loading correctly. Under optimal circumstances, this string should be something dynamically generated via php code that pulls information from a database - thus no matter if it's apache, mysql, or php that's failing, a change in status will be detected. Attempting to use this flag with "--ping or "--dns" will throw an error.

--user-agent

     When used with "--url", this will cause the curl command to be run in such a way that the chrome 41 user agent is imitated. This is useful in situations where a site is refusing connections from the standard curl user agent.

--curl-timeout (number)

     When used with "--url", this flag specifies how long a curl process should wait before giving up.

OTHER FLAGS:

--default

     Allows you to specify a default for "--mail", "--seconds", "--mail-delay", or "--curl-timeout" (or any combination thereof) that will be assumed if they are not specified.

--help

     Displays the basic help information.

--help-flags
 
     Outputs the help information specific to command line flags.

--help-params-file

     Gives detailed information on what's expected within the params file, for the purpose of manual editing.

--help-process-types

     Gives a better explanation of xmonitor.sh's master, control, and child processes.

--kill

     Used to terminate the master Xmonitor process, which in turn prompts any child processes to exit as well. This can be used in conjunction with the "--save" flag.
     
--master

     Immediately designates itself as the master process. If any prompts are waiting, it spawns child processes as they describe, it then checks periodically for new prompts and spawns processes accordingly. If the master process ends, all child processes it has spawned will recognize that it has ended, and end as well. Run ./xmonitor.sh --help-process-types for more information on master, control, and child processes.

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

function fn_help_process_types {
cat << 'EOF' > /dev/stdout

MASTER, CONTROL, AND CHILD PROCESSES

Any action taken by xmonitor.sh falls into one of three process categories - master processes, control processes or child processes.

MASTER PROCESS -
     The master process is just one continuius loop. It primarily accomplishes three things: 1) It checks to see if there is data for new child processes and spawns them accordingly. 2) It checks existing processes, makes sure that they are still running, and if they are not it decides whether they need to be respawned, or if they can be set aside as disabled. 3) If there is data from processes that has been set aside for more than seven days, it removes this data.
     Other than starting and stopping the master process, the user does not interact with it directly.

CONTROL PROCESSES -
     Control processes are how the user primarily interacts with xmonitor.sh, and they accomplish three primary tasks: 1) They gather data from the user regaring a new child process that the user wants to create, and then they put that data in a place where the master process will find it. 2) They gather data from the user on how a currently running child process should be modified (or exited). 3) They gather data from the user on how the master process should be modified (or exited).
     Control processes always exit after the data that they've collected has been put in place, except under the following circumstance: If there is no currently running master process, and the "--control" flag was not used, the control process will turn into the master process.

CHILD PROCESSES -
     These processes are not interacted with by the user at all, except through control processes. They are spawned by the master process. They loop continuously, checking against conditions set by the user, and then reporting success or failure. If at any point in time they detect that the associated master process has ended, they end as well.

EOF
#'do
exit
}

function fn_help_params_file {
cat << 'EOF' > /dev/stdout

PARAMETERS FILE
(located at ".xmonitor/[CHILD PID]/params")

The params file contains the specifics of an xmonitor.sh job. Any xmonitor.sh job that is currently running can be changed mid-run by editing the params file - this can be done manually, or some of the values can be modified using the "--modify" flag. The purpose of this document is to explain each value in the params file and what it does. On each of these lines (except the first) the values come immediately after a colon - adding spaces will break functionality.

After changes are made to the params file, these changes will not be recognized by the script until a file named ".xmonitor/[CHILD PID]/reload" is created.

First Line: --url, --dns, or --ping
     This line specifies what kind of job is being run. It's used to identify the job type initially. Making changes to it after the job has been initiated will not have any impact on the job.

"Wait Seconds:"
     This is the number of seconds that pass between iterative checks. This number does not take into account how long the check itself took, so for example, if it takes five seconds to curl a URL, that amount is not subtraced from the number of wait seconds before the next check begins.

"Email Address:"
     This is the email address that messages regarding failed or successful checks will be sent to.

"Mail Delay:" 
     The number of successful or failed checks that need to occur before an email is sent. If this is set to zero, no email messages will be sent.

"Domain:"
     For URL jobs where an IP address is specified, this value is necessary for the curl command, otherwise it is unused. 
     For DNS jobs, this is the domain associated with the zone file on the server that we're checking against.
     For ping jobs, this is the domain or IP address that we're pinging.

"IP Address:"
     For URL jobs, this will be "false" if an IP address has not been specified. Otherwise, it will contain the IP address that we're connecting to before telling the remote server the domain we're trying sending a request to.
     For DNS jobs, this is the IP or host name of the remote server that we're querying.
     For ping jobs, this value is not used.

"Server String:"
     This is the identifier for the job, as it will be output in the terminal window where the master process is being run. This will also be referenced in emails.

"Server String (Original):"
     This is the original server string for the job. It's used for logging purposes, as well as referenced in emails.

"URL:"
     For URL jobs, this is the URL that's being curl'd.
     For DNS and ping jobs, this line is not used.

"Port:"
     For URL jobs, this is the port that's being connected to.
     For DNS and ping jobs, this line is not being used.

"Check String:"
     For URL jobs, this is the string that's being checked against in the result of curl process. The format for this check is...

     egrep "$CHECK_STRING" site_file.html

     So anything that would be interpreted as a regular expression by egrep WILL be interpreted as such.
     For DNS and ping jobs, this line is not being used.

"Output:"
     The default for tihs value is /dev/stdout, however rather than being output to the terminal where the master process is running, the output of a child process can be redirected to a file.

"User Agent:"
     For URL jobs, this is a true or false value that dictates whether or not the curl for the site will be run with curl as the user agent (false) or with a user agent that makes it look as if it's Google Chrome (true).
     For DNS and ping jobs, this line is not being used.

"Curl Timeout:"
     For URL jobs, this is the amount of time before the curl process quits out and the check automatically fails.
     For DNS and ping jobs, this line is not being used.

EOF
#'do
exit
}

function fn_version {
echo "Current Version: $VERSION"
cat << 'EOF' > /dev/stdout

Version Notes:
Future Versions -
     In URL jobs, should I compare the current pull to the previous pull? Compare file size? Monitor page load times?
     Whether or not to use the user agent should be a settable default, like email and seconds between runs.
     Configuration file

1.2.2 (2015-11-25) -
     When a child process begins outputting to a different location, that information is now logged.
     Added the "--outfile" flag so that the output file can be assigned on job declaration. Can be assigned through menus as well.
     The remote die list can also include the $IP_ADDRESS or $DOMAIN associated with the job. In these cases, it will kill the individual jobs rather than the master process.
     The remote die list can also contain in-line comments.
     When a process kill is triggered by the remote die list, the full line, including comments, is logged.
     "Xmonitor" is now included in the user agent, whether or not the chrome user agent is being used. Tested to verify that this works on my one test case (http://www.celebdirtylaundry.com/)
     If the user agent field is set to neither true nor false, what ever is in the field will be used.
     All instances of "$v_LOG" are now in quotes, just in case the designated log file contains spaces.
     re-worked the sections of the master process that find dead children, and remove disabled children.

1.2.1 (2015-11-23) -
     The script checks against a remote list of IP addresses to see if it should exit. The benefit behind this is that if the activity from xmonitor is having a negative impact on a customer's server, we can disable the script without having to unplug an employee's workstation.
     The new flag "--help-params-file" explains what the directives in the parameters file do.
     Curl timeout can now have a default value set.
     The default config files were originally only being made when a master process was being run. I didn't see any reason not to always check whether or not these were present.
     No longer using "--resolve" to pull sites from a specific IP address.
     Fixed where the script was donig a terrible job of determining the port number.
     Verbose mode was showing the wrong time since last check on the first fail or success this is either fixed, or broken in a new and interesting way.
     Email subject now includes the word "Xmonitor".
     The presence of the file [child pid]/status causes the child process to print the full stats from verbose mode once, then return to the previous verbosity.
     The variables in the params file are no longer recognized by the line number they're on.
     "--modify" includes an option to directly edit a child process's params file.
     Child processes have their own verbosity file. This can be changed in the "--modify" menu.
     Now has the option for child processes to output in places other than /dec/stdout. This is accessable through the "--modify" menu.

1.2.0 (2015-11-16) -
     Script does its best to check if there are newer versions of curl installed elsewhere.
     The --curl-timeout flag allows the user to set how long to wait for the curl transaction to complete.
     The menu options for URL's not invlude curl timeout and user agent.
     Fixed a mistake where the "save" file never got deleted.
     Child loops now collect timestamps all at once.
     The Parameters file is not descriptive, and therefore easier to edit.
     The child directories have a #reload and #die file by default (easier for manual editing)
     There is an option in the --modify menu for a command to take you to the child process's working directory.
     Now keeps copies of the downloaded site:
          * The current copy
          * The previous copy
          * Any instance where the site has succeeded immediately before failing
          * Any instance where the site has failed immediately after succeeding
     Automatically cleans up these copies when there are more than 100 of them in total.
     When a process is found dead and restarted, the log file is kept.
     If anything that is not a job or a log ends up in the new/ directory, it is removed.
     Added a command line flag for an explanation on master, control, and child processes.
     The e-mail functions now use the child logs rather than pulling from the master log file.

1.1.5 (2015-04-18) -
     Added the "--user-agent" flag.
     Curl is now run with the "-k" flag 

1.1.4 (2014-03-26) -
     E-mail messages should contain the original server string as well as the modified server string in order to prevent ambiguity.

1.1.3 (2013-12-01) - 
     The line that was determining whether or not a folder represented a child process was working just fine on my workstation, but not my laptop. Changed it to work on both.
     The same string as above was in two other places. I modified it there as well.

1.1.2 (2013-09-29) -
     The default now is to restart a child process if it's found dead, no matter when it's found.
     When a child process is stopped, its folder is backed up for seven days. This may or may not be a reference to the movie "The Ring"
     Child processes log to their own directories as well.

1.1.1 (2013-09-20) -
     If it finds a dead child process on startup, it restarts that process.

1.1.0 (2013-07-15) -
     Added far more robust command line arguments
     Added the ability to parse those command line arguments
     Added a function that parses out any URL into a URL, IP address, domain, and port.
     Better descriptions of the verbosity settings in the menu
     Updated the help information and added a help option specifically for flags.
     Allowed for setting default e-mail address, wait_seconds, and mail_delay through "--default"
     E-mail messages are sent as a background process so that the script won't hang if mail isn't configured.

1.0.0 (2013-07-09) -
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

v_LOG="$PROGRAMDIR""xmonitor.log"

### find the newst version of curl
### /usr/bin/curl is the standard installation of curl
### /opt/curlssl/bin/curl is where cPanel keeps the version of curl that PHP works with, which is usually the most up to date
v_CURL_BIN=$( echo -e "$( /opt/curlssl/bin/curl --version 2> /dev/null | head -n1 | awk '{print $2}' ) /opt/curlssl/bin/curl\n$( /usr/bin/curl --version 2> /dev/null | head -n1 | awk '{print $2}' ) /usr/bin/curl\n$( $( which curl ) --version 2> /dev/null | head -n1 | awk '{print $2}' ) $( which curl )" | sort -n | grep "^[0-9]*\.[0-9]*.[0-9]*" | tail -n1 | awk '{print $2}' )
if [[ -z $v_CURL_BIN ]]; then
   echo "curl needs to be installed for xmonitor to perform some of its functions. Exiting."
   exit
fi
v_CURL_BIN_VERSION="$( $v_CURL_BIN --version 2> /dev/null | head -n1 | awk '{print $2}')"

### Make sure that bc, mail, ping, and dig are installed
if [[ -z $( which bc 2> /dev/null ) ]]; then
   echo "bc needs to be installed for xmonitor to perform some of its functions. Exiting."
   exit
fi
if [[ -z $( which mail 2> /dev/null ) ]]; then
   echo "mail needs to be installed for xmonitor to perform some of its functions. Exiting."
   exit
fi
if [[ -z $( which dig 2> /dev/null ) ]]; then
   echo "dig needs to be installed for xmonitor to perform some of its functions. Exiting."
   exit
fi
if [[ -z $( which ping 2> /dev/null ) ]]; then
   echo "ping needs to be installed for xmonitor to perform some of its functions. Exiting."
   exit
fi

### User agent should start out as false.
v_USER_AGENT=false
v_OUTPUT="/dev/stdout"

### Determine the running state
if [[ -f "$WORKINGDIR"xmonitor.pid && $( ps aux | grep "$( cat "$WORKINGDIR"xmonitor.pid 2> /dev/null ).*xmonitor.sh" | grep -vc " 0:00 grep " ) -gt 0 ]]; then
   if [[ $PPID == $( cat "$WORKINGDIR"xmonitor.pid 2> /dev/null ) ]]; then
      ### Child processes monitor one thing only they are spawned only by the master process and when the master process is no longer present, they die.
      RUNNING_STATE="child"
      fn_child
   else
      ### Control processes set up the parameters for new child processes and then exit.
      RUNNING_STATE="control"
   fi
else
   ### The master process (which typically starts out functioning as a control process) waits to see if there are waiting jobs present in the "new/" directory, and then spawns child processes for them.
   RUNNING_STATE="master"
   ### Create some necessary configuration files and directories
   mkdir -p "$WORKINGDIR""new/"
   echo $$ > "$WORKINGDIR"xmonitor.pid
   if [[ ! -f "$WORKINGDIR"verbosity || $( cat "$WORKINGDIR"verbosity ) == "none2" ]]; then
      echo "standard" > "$WORKINGDIR"verbosity
   fi
fi

### More necessary configuration files.
if [[ ! -f "$WORKINGDIR"email_address ]]; then
   echo "" > "$WORKINGDIR"email_address
fi
if [[ ! -f "$WORKINGDIR"wait_seconds ]]; then
   echo "10" > "$WORKINGDIR"wait_seconds
fi
if [[ ! -f "$WORKINGDIR"mail_delay ]]; then
   echo "1" > "$WORKINGDIR"mail_delay
fi
if [[ ! -f "$WORKINGDIR"curl_timeout ]]; then
   echo "10" > "$WORKINGDIR"curl_timeout
fi

### Turn the command line arguments into an array.
CL_ARGUMENTS=( "$@" )

### For each command line argument, determine what needs to be done.
for (( c=0; c<=$(( $# - 1 )); c++ )); do
   arg="${CL_ARGUMENTS[$c]}"
   if [[ $( echo $arg | egrep -c "^(--(url|dns|list|default|ping|master|version|help|help-flags|help-process-types|help-params-file|modify|verbosity|kill)|[^-]*-[hmvpud])$" ) -gt 0 ]]; then
      ### These flags indicate a specific action for the script to take. Two actinos cannot be taken at once.
      if [[ ! -z $RUN_TYPE ]]; then
         ### If another of these actions has already been specified, end.
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
   ### All other flags modify or contribute to one of the above actions.
   elif [[ $arg == "--control" ]]; then
      RUNNING_STATE="control"
   elif [[ $arg == "--save" ]]; then
      SAVE_JOBS=true
   elif [[ $arg == "--user-agent" ]]; then
      v_USER_AGENT=true
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
   elif [[ $arg == "--curl-timeout" ]]; then
      if [[ $( echo ${CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^[[:digit:]][[:digit:]]*$" ) -eq 1 ]]; then
         c=$(( $c + 1 ))
         v_CURL_TIMEOUT="${CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--curl-timeout\" needs to be followed by a number of seconds. Exiting"
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
         ### Specifically don't check if the value here is actually an IP address - fn_parse_server will take care of that. 
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
   elif [[ $arg == "--outfile" ]]; then
      if [[ $( echo ${CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^/" ) -eq 1 ]]; then
         c=$(( $c + 1 ))
         v_OUTPUT="${CL_ARGUMENTS[$c]}"
         touch "$v_OUTPUT" 2> /dev/null
         v_STATUS=$?
         if [[ ( ! -f "$v_OUTPUT" || ! -w "$v_OUTPUT" || $v_STATUS == 1 ) && "$v_OUTPUT" != "/dev/stdout" ]]; then
            echo "Please ensure that the --output file is already created, and has write permissions."
            exit
         fi
      else
         echo "The flag \"--outfile\" needs to be followed by a file referenced by its full path. Exiting"
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

### Some of these flags need to be used alone.
if [[ $RUN_TYPE == "--master" || $RUN_TYPE == "--verbosity" || $RUN_TYPE == "-v" || $RUN_TYPE == "--version" || $RUN_TYPE == "--help-flags" || $RUN_TYPE == "--help-process-types" || $RUN_TYPE == "--help-params-file" || $RUN_TYPE == "--help" || $RUN_TYPE == "--modify" || $RUN_TYPE == "-h" || $RUN_TYPE == "-m" ]]; then
   if [[ $NUM_ARGUMENTS -gt 1 ]]; then
      echo "The flag \"$RUN_TYPE\" cannot be used with other flags. Exiting."
      exit
   fi
fi
### Tells the script where to go with the type of job that was selected.
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
         echo "The \"--kill\" flag can only used alone, with the \"--save\" flag, or in conjunction with the ID number of a child process. Exiting."
         exit
      fi
      touch "$WORKINGDIR"save
   else
      if [[ $NUM_ARGUMENTS -gt 1 ]]; then
         echo "The \"--kill\" flag can only used alone, with the \"--save\" flag, or in conjunction with the ID number of a child process. Exiting."
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
elif [[ $RUN_TYPE == "--help-process-types" ]]; then
   fn_help_process_types
   exit
elif [[ $RUN_TYPE == "--help-params-file" ]]; then
   fn_help_params_file
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
