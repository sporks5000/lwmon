#! /bin/bash

v_VERSION="1.3.0"

#######################
### BEGIN FUNCTIONS ###
#######################

#### Functions that gather variables ####

function fn_url_vars {
   ### When a URL monitoring task is selected from the menu, it will run through this function in order to acquire the necessary variables.
   read -p "Enter the URL That you need to have monitored: " v_SERVER
   if [[ -z $v_SERVER ]]; then
      echo "A URL must be supplied. Exiting."
      exit
   fi
   fn_parse_server
   v_DOMAIN=$v_DOMAINa
   v_CURL_PORT=$v_CURL_PORTa
   v_CURL_URL=$v_CURL_URLa

   echo
   echo "When checking that URL, what string of characters will this script be searching for?"
   echo "(The search is done using 'egrep -c \"\$v_CURL_STRING\"'. It's up to you to compensate"
   echo "for any weirdness that might result. Keep in mind that this string should not begin"
   read -p "with whitespace, nor should it contain any new line characters): " v_CURL_STRING

   echo
   echo "Enter the IP Address that this URL should be monitored on. (Or just press enter"
   read -p  "to have the IP resolved via DNS): " v_SERVER
   if [[ ! -z $v_SERVER ]]; then
      fn_parse_server
      v_IP_ADDRESS=$v_IP_ADDRESSa
   fi
   if [[ -z $v_SERVER || $v_IP_ADDRESS == false ]]; then
      v_IP_ADDRESS=false
      v_SERVER_STRING=$v_CURL_URL
   else
      v_SERVER_STRING="$v_CURL_URL at $v_IP_ADDRESS"
   fi
   echo
   echo "Should the script use Google Chrome's use ragent when trying to access the site?"
   read -p "(Anything other than \"y\" or \"yes\" will be interpreted as \"no\".): " v_USER_AGENT
   if [[ $v_USER_AGENT == "y" || $v_USER_AGENT == "yes" ]]; then
      v_USER_AGENT=true
   else
      v_USER_AGENT=false
   fi

   echo
   echo "How many seconds should the script wait for a response from the server before"
   read -p "timing out? (default $v_DEFAULT_CURL_TIMEOUT seconds): " v_CURL_TIMEOUT
   if [[ -z $v_CURL_TIMEOUT || $( echo $v_CURL_TIMEOUT | grep -c "[^0-9]" ) -eq 1 ]]; then
      v_CURL_TIMEOUT="$v_DEFAULT_CURL_TIMEOUT"
   fi

   fn_email_address

   fn_url_confirm
   ### If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $v_RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_ping_vars {
   ### When a ping monitoring task is selected from the menu, it will run through this function in order to acquire the necessary variables.
   read -p "Enter the domain or IP that you wish to ping: " v_SERVER
   if [[ -z $v_SERVER ]]; then
      echo "A domain or IP must be supplied. Exiting."
      exit
   fi
   fn_parse_server
   v_IP_ADDRESS=$v_IP_ADDRESSa
   v_DOMAIN=$v_DOMAINa
   if [[ $v_IP_ADDRESS == false ]]; then
      echo "Error: Domain $v_DOMAIN does not resolve. Exiting."
      exit
   fi
   if [[ $v_DOMAIN == $v_IP_ADDRESS ]]; then
      v_SERVER_STRING=$v_IP_ADDRESS
   else
      v_SERVER_STRING="$v_DOMAIN ($v_IP_ADDRESS)"
   fi
   
   fn_email_address

   fn_ping_confirm
   ### If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $v_RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_dns_vars {
   ### When a DNS monitoring task is selected from the menu, it will run through this function in order to acquire the necessary variables.
   read -p "Enter the IP or domain of the DNS server that you want to watch: " v_SERVER
   fn_parse_server
   v_SERVER_STRING=$v_DOMAINa
   v_IP_ADDRESS=$v_IP_ADDRESSa
   if [[ $v_IP_ADDRESS == false ]]; then
      echo "Error: Domain $v_DOMAIN does not resolve. Exiting."
      exit
   fi

   echo
   read -p "Enter the domain that you wish to query for: " v_DOMAIN
   
   fn_email_address

   fn_dns_confirm
   ### If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $v_RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_email_address {
   ### When functions are run from the menu, they come here to gather the $v_WAIT_SECONDS $v_EMAIL_ADDRESS and $v_MAIL_DELAY variables.
   echo
   echo "Enter the number of seconds the script should wait between each iterative check."
   read -p "(Or just press enter for the default of $v_DEFAULT_WAIT_SECONDS seconds): " v_WAIT_SECONDS
   if [[ -z $v_WAIT_SECONDS || $( echo $v_WAIT_SECONDS | grep -c "[^0-9]" ) -eq 1 ]]; then
      v_WAIT_SECONDS="$v_DEFAULT_WAIT_SECONDS"
   fi
   echo
   echo "Enter the e-mail address that you want changes in status sent to."
   if [[ -z "$v_DEFAULT_EMAIL_ADDRESS" ]]; then
      read -p "(Or just press enter to have no e-mail messages sent): " v_EMAIL_ADDRESS
   else
      read -p "(Or just press enter to have it default to $v_DEFAULT_EMAIL_ADDRESS): " v_EMAIL_ADDRESS
   fi
   if [[ $( echo $v_EMAIL_ADDRESS | grep -c "^[^@][^@]*@[^.][^.]*\..*$" ) -eq 0 ]]; then
      v_EMAIL_ADDRESS="$v_DEFAULT_EMAIL_ADDRESS"
   fi
   echo
   echo "Enter the number of consecutive failures or successes that should occur before an e-mail"
   read -p "message is sent (default $v_DEFAULT_MAIL_DELAY; to never send a message, 0): " v_MAIL_DELAY
   if [[ -z $v_MAIL_DELAY || $( echo $v_MAIL_DELAY | grep -c "[^0-9]" ) -eq 1 ]]; then
      v_MAIL_DELAY="$v_DEFAULT_MAIL_DELAY"
   fi
   echo
   echo "Enter a file for status information to be output to (or press enter for the default"
   read -p "of \"$v_DEFAULT_OUTPUT_FILE\".): " v_OUTPUT_FILE
   if [[ -z $v_OUTPUT_FILE ]]; then
      v_OUTPUT_FILE="$v_DEFAULT_OUTPUT_FILE"
   else
      if [[ ${v_OUTPUT_FILE:0:1} != "/" ]]; then
         echo "Please ensure that this file is referenced by an absolute path. Exiting."
         exit
      fi
      touch "$v_OUTPUT_FILE" 2> /dev/null
      v_STATUS=$?
      if [[ ( ! -f "$v_OUTPUT_FILE" || ! -w "$v_OUTPUT_FILE" || $v_STATUS == 1 ) && "$v_OUTPUT_FILE" != "/dev/stdout" ]]; then
         echo "Please ensure that this file is already created, and has write permissions. Exiting."
         exit
      fi
   fi
}

function fn_parse_server {
   ### given a URL, Domain name, or IP address, this parses those out into the variables $v_CURL_URL, $v_DOMAIN, $v_IP_ADDRESS, and $v_CURL_PORT.
   if [[ $( echo $v_SERVER | grep -ci "^HTTP" ) -eq 0 ]]; then
      v_DOMAINa=$v_SERVER
      v_CURL_URLa=$v_SERVER
      v_CURL_PORTa="80"
   else
      ### get rid of "http(s)" at the beginning of the domain name
      v_DOMAINa=$( echo $v_SERVER | sed -e "s/^[Hh][Tt][Tt][Pp][Ss]*:\/\///" )
      if [[ $( echo $v_SERVER | grep -ci "^HTTPS" ) -eq 1 ]]; then
         v_CURL_URLa=$v_SERVER
         v_CURL_PORTa="443"
      else
         v_CURL_URLa=$( echo $v_SERVER | sed -e "s/^[Hh][Tt][Tt][Pp]:\/\///" )
         v_CURL_PORTa="80"
      fi
   fi
   ### get rid of the slash and anything else that follows the domain name
   v_DOMAINa="$( echo $v_DOMAINa | sed 's/^\([^/]*\).*$/\1/' )"
   ### check if it's an IP.
   if [[ $( echo $v_DOMAINa | egrep "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$" | wc -l ) -eq 0 ]]; then
      v_IP_ADDRESSa=$( dig +short $v_DOMAINa | tail -n1 )
      if [[ $( echo $v_IP_ADDRESSa | egrep -c "^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$" ) -eq 0 ]]; then
         v_IP_ADDRESSa=false
      fi
   else
      v_IP_ADDRESSa=$v_DOMAINa
   fi
   ### If the port is specified in the URL, lets use that.
   if [[ $( echo $v_DOMAINa | grep -c ":" ) -eq 1 ]]; then
      v_CURL_PORTa="$( echo $v_DOMAINa | cut -d ":" -f2 )"
      v_DOMAINa="$( echo $v_DOMAINa | cut -d ":" -f1 )"
   fi
}

#### Functions that gather variables from command line flags ####

function fn_url_cl {
   ### When a URL monitoring job is run from the command line, this parses out the commandline variables...
   if [[ -z $v_CURL_STRING ]]; then
      echo "It is required that you specify a check string using \"--string\" followed by a string in quotes that will be searched for when checking a URL. Exiting."
      exit
   elif [[ ! -z $v_CURL_URL && ! -z $v_DNS_DOMAIN && $v_CURL_URL != $v_DNS_DOMAIN ]]; then
      echo "Please specify either a URL or a domain, not both. Exiting."
      exit
   elif [[ ! -z $v_IP_ADDRESS ]]; then
      v_SERVER=$v_IP_ADDRESS
      fn_parse_server
      v_IP_ADDRESS=$v_IP_ADDRESSa
      if [[ $v_IP_ADDRESS == false ]]; then
         echo "Not a valid IP address. Exiting."
         exit
      fi
   fi
   if [[ -z $v_CURL_TIMEOUT || $( echo $v_CURL_TIMEOUT | grep -c "[^0-9]" ) -eq 1 ]]; then
      v_CURL_TIMEOUT="$v_DEFAULT_CURL_TIMEOUT"
   fi
   if [[ -z $v_USER_AGENT ]]; then
      v_USER_AGENT="$v_DEFAULT_USER_AGENT"
   fi
   if [[ -z $v_CURL_URL && ! -z $v_DNS_DOMAIN ]]; then
      v_CURL_URL=$v_DNS_DOMAIN
   fi
   ### ...and then makes sure that those variables are correctly assigned.
   v_SERVER=$v_CURL_URL
   fn_parse_server
   v_DOMAIN=$v_DOMAINa
   v_CURL_PORT=$v_CURL_PORTa
   v_CURL_URL=$v_CURL_URLa

   if [[ -z $v_IP_ADDRESS ]]; then
      v_IP_ADDRESS=false
      v_SERVER_STRING=$v_CURL_URL
   else
      v_SERVER_STRING="$v_CURL_URL at $v_IP_ADDRESS"
   fi

   fn_email_cl

   fn_cl_confirm
   ### If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $v_RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_ping_cl {
   ### When a Ping monitoring job is run from the command line, this parses out the commandline variables...
   if [[ -z $v_DOMAIN && -z $v_IP_ADDRESS && -z $v_DNS_DOMAIN ]]; then
      echo "You must specify an IP address or domain to ping, either as an argument after the \"--ip\" flag, the \"--domain\" flag or after the \"--ping\" flag itself. Exiting."
      exit
   elif [[ ! -z $v_DOMAIN && ! -z $v_IP_ADDRESS && $v_DOMAIN != $v_IP_ADDRESS ]]; then
      echo "Please specify the IP address / domain name only once. Exiting."
      exit
   elif [[ ! -z $v_DOMAIN && ! -z $v_DNS_DOMAIN && $v_DOMAIN != $v_DNS_DOMAIN ]]; then
      echo "Please specify the IP address / domain name only once. Exiting."
      exit
   elif [[ ! -z $v_DNS_DOMAIN && ! -z $v_IP_ADDRESS && $v_DNS_DOMAIN != $v_IP_ADDRESS ]]; then
      echo "Please specify the IP address / domain name only once. Exiting."
      exit
   elif [[ ! -z $v_CURL_STRING ]]; then
      echo "You should not specify a check string when using \"--ping\". Exiting."
      exit
   fi
   if [[ -z $v_DOMAIN && ! -z $v_DNS_DOMAIN ]]; then
      v_DOMAIN=$v_DNS_DOMAIN
   elif [[ -z $v_DOMAIN && ! -z $v_IP_ADDRESS ]]; then
      v_DOMAIN=$v_IP_ADDRESS
   fi
   ### ...and then makes sure that those variables are correctly assigned.
   v_SERVER=$v_DOMAIN
   fn_parse_server
   v_IP_ADDRESS=$v_IP_ADDRESSa
   v_DOMAIN=$v_DOMAINa
   if [[ $v_IP_ADDRESS == false ]]; then
      echo "Error: Domain $v_DOMAIN does not resolve. Exiting."
      exit
   fi
   if [[ $v_DOMAIN == $v_IP_ADDRESS ]]; then
      v_SERVER_STRING=$v_IP_ADDRESS
   else
      v_SERVER_STRING="$v_DOMAIN ($v_IP_ADDRESS)"
   fi
   
   fn_email_cl

   fn_cl_confirm
   ### If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $v_RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_dns_cl {
   ### When a DNS monitoring job is run from the command line, this parses out the commandline variables...
   if [[ ! -z $v_IP_ADDRESS && ! -z $v_DOMAIN && $v_DOMAIN != $v_IP_ADDRESS ]]; then
      echo "Please specify the IP address / domain name of the server you're checking against only once. Exiting."
      exit
   elif [[ -z $v_IP_ADDRESS && -z $v_DOMAIN ]]; then
      echo "Please specify the IP address / domain name of the server you're checking against, either as an argument directly after the \"--ip\" flag, of after the \"--dns\" flag itself. Exiting."
      exit
   elif [[ -z $v_DNS_DOMAIN ]]; then
      echo "Please specify a domain name that has a zone file on the server to check for as an argument after the \"--domain\" flag. Exiting."
      exit
   elif [[ ! -z $v_CURL_STRING ]]; then
      echo "You should not specify a check string when using \"--dns\". Exiting."
      exit
   fi
   if [[ -z $v_DOMAIN && ! -z $v_IP_ADDRESS ]]; then
      v_DOMAIN=$v_IP_ADDRESS
   fi
   ### ...and then makes sure that those variables are correctly assigned.
   v_SERVER=$v_DOMAIN
   fn_parse_server
   v_SERVER_STRING=$v_DOMAINa
   v_IP_ADDRESS=$v_IP_ADDRESSa
   if [[ $v_IP_ADDRESS == false ]]; then
      echo "Error: Domain $v_DOMAIN does not resolve. Exiting."
      exit
   fi
   v_DOMAIN=$v_DNS_DOMAIN
   v_SERVER_STRING="$v_DOMAIN @$v_SERVER_STRING"
   fn_email_cl

   fn_cl_confirm
   ### If this instance is running as master, go on to begin spawning child processes, etc.
   if [[ $v_RUNNING_STATE == "master" ]]; then
      fn_master
   fi
}

function fn_email_cl {
   ### This function parses out the command line information for e-mail address
   if [[ -z $v_WAIT_SECONDS || $( echo $v_WAIT_SECONDS | grep -c "[^0-9]" ) -eq 1 ]]; then
      v_WAIT_SECONDS="$v_DEFAULT_WAIT_SECONDS"
   fi
   if [[ -z $v_OUTPUT_FILE ]]; then
      v_OUTPUT_FILE="$v_DEFAULT_OUTPUT_FILE"
   fi
   if [[ $( echo $v_EMAIL_ADDRESS | grep -c "^[^@][^@]*@[^.@][^.@]*\..*$" ) -eq 0 ]]; then
      v_EMAIL_ADDRESS="$v_DEFAULT_EMAIL_ADDRESS"
   fi
   if [[ -z $v_MAIL_DELAY || $( echo $v_MAIL_DELAY | grep -c "[^0-9]" ) -eq 1 ]]; then
      v_MAIL_DELAY="$v_DEFAULT_MAIL_DELAY"
   fi
}

#### Confirmation Functions ####

function fn_ping_confirm {
   ### When run from the menu, this confirms the settings for a Ping job.
   echo "I will begin monitoring the following:"
   echo "---Domain / IP to ping: $v_SERVER_STRING"
   v_NEW_JOB="$( date +%s )""_$RANDOM.job"
   echo "JOB_TYPE = ping" > "$v_WORKINGDIR""$v_NEW_JOB"
   fn_mutual_confirm
   mv -f "$v_WORKINGDIR""$v_NEW_JOB" "$v_WORKINGDIR""new/$v_NEW_JOB"
}

function fn_dns_confirm {
   ### When run from the menu, this confirms the settings for a DNS job.
   echo "I will begin monitoring the following:"
   echo "---Domain / IP to query: $v_SERVER_STRING"
   v_SERVER_STRING="$v_DOMAIN @$v_SERVER_STRING"
   echo "---Domain to query for: $v_DOMAIN"
   v_NEW_JOB="$( date +%s )""_$RANDOM.job"
   echo "JOB_TYPE = dns" > "$v_WORKINGDIR""$v_NEW_JOB"
   fn_mutual_confirm
   mv -f "$v_WORKINGDIR""$v_NEW_JOB" "$v_WORKINGDIR""new/$v_NEW_JOB"
}

function fn_url_confirm {
   ### When run from the menu, this confirms the settings for a URL job.
   echo "I will begin monitoring the following:"
   echo "---URL to monitor: $v_CURL_URL"
   if [[ $v_IP_ADDRESS != false ]]; then
      echo "---IP Address to check against: $v_IP_ADDRESS"
   fi
   echo "---Port number: $v_CURL_PORT"
   echo "---String that must be present to result in a success: \"$v_CURL_STRING\""

   v_NEW_JOB="$( date +%s )""_$RANDOM.job"
   echo "JOB_TYPE = url" > "$v_WORKINGDIR""$v_NEW_JOB"
   fn_mutual_confirm
   ### There are additional variables for URL based jobs. Those are input into the params file here.
   echo "CURL_URL = $v_CURL_URL" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "CURL_PORT = $v_CURL_PORT" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "CURL_STRING = $v_CURL_STRING" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "USER_AGENT = $v_USER_AGENT" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "CURL_TIMEOUT = $v_CURL_TIMEOUT" >> "$v_WORKINGDIR""$v_NEW_JOB"
   mv -f "$v_WORKINGDIR""$v_NEW_JOB" "$v_WORKINGDIR""new/$v_NEW_JOB"
}

function fn_mutual_confirm {
   ### Confirms the remainder of the veriables from a menu-assigned task...
   echo "---Seconds to wait before initiating each new check: $v_WAIT_SECONDS"
   if [[ -z $v_EMAIL_ADDRESS ]]; then
      echo "---No e-mail allerts will be sent."
   else
      echo "---E-mail address to which allerts will be sent: $v_EMAIL_ADDRESS"
      echo "---Consecutive failures or successes before an e-mail will be sent: $v_MAIL_DELAY"
   fi
   echo "---Results will be output to \"$v_OUTPUT_FILE\"."
   echo
   read -p "Is this correct? (Y/n):" v_CHECK_CORRECT
   if [[ $( echo $v_CHECK_CORRECT | grep -c "^[Nn]" ) -eq 1 ]]; then
      rm -f "$v_WORKINGDIR""$v_NEW_JOB"
      echo "Exiting."
      exit
   fi
   ### ...and then inputs those variables into the params file so that the child process can read them.
   echo "WAIT_SECONDS = $v_WAIT_SECONDS" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "EMAIL_ADDRESS = $v_EMAIL_ADDRESS" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "MAIL_DELAY = $v_MAIL_DELAY" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "DOMAIN = $v_DOMAIN" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "IP_ADDRESS = $v_IP_ADDRESS" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "SERVER_STRING = $v_SERVER_STRING" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "ORIG_SERVER_STRING = $v_SERVER_STRING" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "OUTPUT_FILE = $v_OUTPUT_FILE" >> "$v_WORKINGDIR""$v_NEW_JOB"
}

function fn_cl_confirm {
   ### This takes the variables from a job started from the command line, and then places them in the params file in order for a child process to read them.
   v_NEW_JOB="$( date +%s )""_$RANDOM.job"
   if [[ $v_RUN_TYPE == "--url" || $v_RUN_TYPE == "-u" ]]; then
      echo "JOB_TYPE = url" > "$v_WORKINGDIR""$v_NEW_JOB"
   elif [[ $v_RUN_TYPE == "ping" || $v_RUN_TYPE == "-p" ]]; then
      echo "JOB_TYPE = --ping" > "$v_WORKINGDIR""$v_NEW_JOB"
   elif [[ $v_RUN_TYPE == "--dns" || $v_RUN_TYPE == "-d" ]]; then
      echo "JOB_TYPE = dns" > "$v_WORKINGDIR""$v_NEW_JOB"
   fi
   echo "WAIT_SECONDS = $v_WAIT_SECONDS" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "EMAIL_ADDRESS = $v_EMAIL_ADDRESS" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "MAIL_DELAY = $v_MAIL_DELAY" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "DOMAIN = $v_DOMAIN" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "IP_ADDRESS = $v_IP_ADDRESS" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "SERVER_STRING = $v_SERVER_STRING" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "ORIG_SERVER_STRING = $v_SERVER_STRING" >> "$v_WORKINGDIR""$v_NEW_JOB"
   echo "OUTPUT_FILE = $v_OUTPUT_FILE" >> "$v_WORKINGDIR""$v_NEW_JOB"
   if [[ $v_RUN_TYPE == "--url" || $v_RUN_TYPE == "-u" ]]; then
      echo "CURL_URL = $v_CURL_URL" >> "$v_WORKINGDIR""$v_NEW_JOB"
      echo "CURL_PORT = $v_CURL_PORT" >> "$v_WORKINGDIR""$v_NEW_JOB"
      echo "CURL_STRING = $v_CURL_STRING" >> "$v_WORKINGDIR""$v_NEW_JOB"
      echo "USER_AGENT = $v_USER_AGENT" >> "$v_WORKINGDIR""$v_NEW_JOB"
      echo "CURL_TIMEOUT = $v_CURL_TIMEOUT" >> "$v_WORKINGDIR""$v_NEW_JOB"
   fi
   mv -f "$v_WORKINGDIR""$v_NEW_JOB" "$v_WORKINGDIR""new/$v_NEW_JOB"
}

function fn_get_defaults {
   v_DEFAULT_EMAIL_ADDRESS="$( fn_read_conf EMAIL_ADDRESS "$v_WORKINGDIR"xmonitor.conf )"
   if [[ $( echo "$v_DEFAULT_EMAIL_ADDRESS" | grep -c "^[^@][^@]*@[^.@][^.@]*\..*$" ) -eq 0 ]]; then
      v_DEFAULT_EMAIL_ADDRESS=""
   fi
   v_DEFAULT_MAIL_DELAY="$( fn_read_conf MAIL_DELAY "$v_WORKINGDIR"xmonitor.conf )"
   v_DEFAULT_MAIL_DELAY="$( fn_test_variable "$v_DEFAULT_MAIL_DELAY" true false 2 )"
   v_DEFAULT_WAIT_SECONDS="$( fn_read_conf WAIT_SECONDS "$v_WORKINGDIR"xmonitor.conf )"
   v_DEFAULT_WAIT_SECONDS="$( fn_test_variable "$v_DEFAULT_WAIT_SECONDS" true false 10 )"
   v_DEFAULT_CURL_TIMEOUT="$( fn_read_conf CURL_TIMEOUT "$v_WORKINGDIR"xmonitor.conf )"
   v_DEFAULT_CURL_TIMEOUT="$( fn_test_variable "$v_DEFAULT_CURL_TIMEOUT" true false 10 )"
   v_DEFAULT_OUTPUT_FILE="$( fn_read_conf OUTPUT_FILE "$v_WORKINGDIR"xmonitor.conf )"
   touch $v_DEFAULT_OUTPUT_FILE
   v_STATUS=$?
   if [[ ( ! -f "$v_DEFAULT_OUTPUT_FILE" || ! -w "$v_DEFAULT_OUTPUT_FILE" || $v_STATUS == 1 ) && "$v_DEFAULT_OUTPUT_FILE" != "/dev/stdout" ]]; then
      v_DEFAULT_OUTPUT_FILE="/dev/stdout"
   fi
   v_DEFAULT_USER_AGENT="$( fn_read_conf USER_AGENT "$v_WORKINGDIR"xmonitor.conf "false" )"
}

#### Child Functions ####

function fn_child {
   ### The opening part of a child process!
   ### Wait to make sure that the params file is in place.
   sleep 1
   ### Make sure that the child processes are not exited out of o'er hastily.
   trap fn_child_exit SIGINT SIGTERM SIGKILL
   ### Define the variables that will be used over the life of the child process
   v_MY_PID=$$
   v_MASTER_PID=$( cat "$v_WORKINGDIR"xmonitor.pid )
   v_START_TIME=$( date +%s )
   v_TOTAL_CHECKS=0
   v_TOTAL_HITS=0
   v_LAST_STATUS="none"
   v_LAST_HIT="never"
   v_LAST_MISS="never"
   v_HIT_MAIL=false
   v_MISS_MAIL=false      
   v_NUM_HITS_EMAIL=0
   v_NUM_MISSES_EMAIL=0
   ### Get the colors for the job to output
   fn_get_colors
   if [[ $( grep -c "^[[:blank:]]*JOB_TYPE[[:blank:]]*=" "$v_WORKINGDIR""$v_MY_PID""/params" ) -eq 1 ]]; then
      v_JOB_TYPE="$( fn_read_conf JOB_TYPE "$v_WORKINGDIR""$v_MY_PID""/params" )"
      fn_child_vars
      if [[ $v_JOB_TYPE == "url" ]]; then
         fn_url_child
      elif [[ $v_JOB_TYPE == "ping" ]]; then
         fn_ping_child
      elif [[ $v_JOB_TYPE == "dns" ]]; then
         fn_dns_child
      else
         echo "$( date ) - [$v_MY_PID] - Job type is unexpected. Exiting." >> "$v_LOG"
         fn_child_exit
      fi
   else
      echo "$( date ) - [$v_MY_PID] - No job type, or more than one job type present. Exiting." >> "$v_LOG"
      fn_child_exit
   fi
}

function fn_child_vars {
   ### Pull the necessary variables for the child process from the params file.
   ### This function is run at the beginning of a child process, and each time a file named "reload" is found in it's directory.
   v_WAIT_SECONDS="$( fn_read_conf WAIT_SECONDS "$v_WORKINGDIR""$v_MY_PID""/params" )"
   v_WAIT_SECONDS="$( fn_test_variable "$v_WAIT_SECONDS" true WAIT_SECONDS 30 )"
   v_EMAIL_ADDRESS="$( fn_read_conf EMAIL_ADDRESS "$v_WORKINGDIR""$v_MY_PID""/params" )"
   v_EMAIL_ADDRESS="$( fn_test_variable "$v_EMAIL_ADDRESS" false EMAIL_ADDRESS "" )"
   if [[ $( echo "$v_EMAIL_ADDRESS" | grep -c "^[^@][^@]*@[^.@][^.@]*\..*$" ) -eq 0 ]]; then
      v_EMAIL_ADDRESS=""
   fi
   v_MAIL_DELAY="$( fn_read_conf MAIL_DELAY "$v_WORKINGDIR""$v_MY_PID""/params" )"
   v_MAIL_DELAY="$( fn_test_variable "$v_MAIL_DELAY" true MAIL_DELAY "2" )"
   v_DOMAIN="$( fn_read_conf DOMAIN "$v_WORKINGDIR""$v_MY_PID""/params" )"
   v_IP_ADDRESS="$( fn_read_conf IP_ADDRESS "$v_WORKINGDIR""$v_MY_PID""/params" )"
   v_SERVER_STRING="$( fn_read_conf SERVER_STRING "$v_WORKINGDIR""$v_MY_PID""/params" )"
   v_ORIG_SERVER_STRING="$( fn_read_conf ORIG_SERVER_STRING "$v_WORKINGDIR""$v_MY_PID""/params" )"
   v_CUSTOM_MESSAGE="$( fn_read_conf CUSTOM_MESSAGE "$v_WORKINGDIR""$v_MY_PID""/params" )"
   if [[ $v_JOB_TYPE == "url" ]]; then
      v_CURL_URL="$( fn_read_conf CURL_URL "$v_WORKINGDIR""$v_MY_PID""/params" )"
      v_CURL_PORT="$( fn_read_conf CURL_PORT "$v_WORKINGDIR""$v_MY_PID""/params" )"
      v_CURL_PORT="$( fn_test_variable "$v_CURL_PORT" true false "80" )"
      v_CURL_STRING="$( fn_read_conf CURL_STRING "$v_WORKINGDIR""$v_MY_PID""/params" )"
      v_USER_AGENT="$( fn_read_conf USER_AGENT "$v_WORKINGDIR""$v_MY_PID""/params" )"
      v_USER_AGENT="$( fn_test_variable "$v_USER_AGENT" false USER_AGENT "false" )"
      v_CURL_TIMEOUT="$( fn_read_conf CURL_TIMEOUT "$v_WORKINGDIR""$v_MY_PID""/params" )"
      v_CURL_TIMEOUT="$( fn_test_variable "$v_CURL_TIMEOUT" true CURL_TIMEOUT "10" )"
      ### If there's an IP address, then the URL needs to have the domain replaced with the IP address and the port number.
      if [[ $v_IP_ADDRESS != "false" && $( echo $v_CURL_URL | egrep -c "^(http://|https://)*$v_DOMAIN:[0-9][0-9]*" ) -eq 1 ]]; then
         ### If it's specified with a port in the URL, lets make sure that it's the right port (according to the params file).
         v_CURL_URL="$( echo $v_CURL_URL | sed "s/$v_DOMAIN:[0-9][0-9]*/$v_IP_ADDRESS:$v_CURL_PORT/" )"
      elif [[ $v_IP_ADDRESS != "false" ]]; then
         ### If it's not specified with the port in the URL, lets add the port.
         v_CURL_URL="$( echo $v_CURL_URL | sed "s/$v_DOMAIN/$v_IP_ADDRESS:$v_CURL_PORT/" )"
      fi
      if [[ $v_USER_AGENT == true ]]; then
         v_USER_AGENT='Mozilla/5.0 (X11; Linux x86_64) Xmonitor/'"$v_VERSION"' AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.85 Safari/537.36'
      elif [[ $v_USER_AGENT == false ]]; then
         v_USER_AGENT='Xmonitor/'"$v_VERSION"' curl/'"$v_CURL_BIN_VERSION"
      fi
   fi
   v_OUTPUT_FILE2="$( fn_read_conf OUTPUT_FILE "$v_WORKINGDIR""$v_MY_PID""/params" )"
   v_OUTPUT_FILE2="$( fn_test_variable "$v_OUTPUT_FILE2" false OUTPUT_FILE "/dev/stdout" )"
   touch "$v_OUTPUT_FILE2" 2> /dev/null
   ### If the designated output file looks good, and is different than it was previously, log it.
   if [[ ! -z "$v_OUTPUT_FILE2" && "${v_OUTPUT_FILE2:0:1}" == "/" && ( -f "$v_OUTPUT_FILE2" || "$v_OUTPUT_FILE2" == "/dev/stdout" ) && -w "$v_OUTPUT_FILE2" && "$v_OUTPUT_FILE2" != "$v_OUTPUT_FILE" ]]; then
      echo "$( date ) - [$v_MY_PID] - Output for child process $v_MY_PID is being directed to $v_OUTPUT2" >> "$v_LOG"
      v_OUTPUT_FILE="$v_OUTPUT_FILE2"
   elif [[ -z "$v_OUTPUT_FILE2" && -z "$v_OUTPUT_FILE" ]]; then
      ### If there is no designated output file, and there was none previously, stdout will be fine.
      v_OUTPUT_FILE="/dev/stdout"
   fi
}

### Here's an example to test the logic being used for port numbers:
### v_CURL_URL="https://sporks5000.com:4670/index.php"; v_DOMAIN="sporks5000.com"; v_CURL_PORT=8080; v_IP_ADDRESS="10.30.6.88"; if [[ $( echo $v_CURL_URL | egrep -c "^(http://|https://)*$v_DOMAIN:[0-9][0-9]*" ) -eq 1 ]]; then echo "curl $v_CURL_URL --header 'Host: $v_DOMAIN'" | sed "s/$v_DOMAIN:[0-9][0-9]*/$v_IP_ADDRESS:$v_CURL_PORT/"; else echo "curl $v_CURL_URL --header 'Host: $v_DOMAIN'" | sed "s/$v_DOMAIN/$v_IP_ADDRESS:$v_CURL_PORT/"; fi

function fn_url_child {
   ###The basic loop for a URL monitoring process.
   v_URL_OR_PING="URL"
   while [[ 1 == 1 ]]; do
      v_DATE3_LAST="$v_DATE3"
      v_DATE="$( date +%m"/"%d" "%H":"%M":"%S )"
      v_DATE2="$( date )"
      v_DATE3="$( date +%s )"
      if [[ -f "$v_WORKINGDIR""$v_MY_PID"/site_current.html ]]; then
         ### The only instalce where this isn't the case should be on the first run of the loop.
         mv -f "$v_WORKINGDIR""$v_MY_PID"/site_current.html "$v_WORKINGDIR""$v_MY_PID"/site_previous.html
      fi
      if [[ $v_IP_ADDRESS == false ]]; then
         ### If an IP address was specified, and the correct version of curl is present
         $v_CURL_BIN -kLsm $v_CURL_TIMEOUT $v_CURL_URL --header 'User-Agent: '"$v_USER_AGENT" 2> /dev/null > "$v_WORKINGDIR""$v_MY_PID"/site_current.html
         v_STATUS=$?
      elif [[ $v_IP_ADDRESS != false ]]; then
         ### If no IP address was specified
         $v_CURL_BIN -kLsm $v_CURL_TIMEOUT $v_CURL_URL --header "Host: $v_DOMAIN" --header 'User-Agent: '"$v_USER_AGENT" 2> /dev/null > "$v_WORKINGDIR""$v_MY_PID"/site_current.html
         v_STATUS=$?
      fi
      ### If the exit status of curl is 28, this means that the page timed out.
      if [[ $v_STATUS == 28 ]]; then
         echo "Curl return code: $v_STATUS (This means that the timeout was reached before the full page was returned.)" >> "$v_WORKINGDIR""$v_MY_PID"/site_current.html
      elif [[ $v_STATUS != 0 ]]; then
         echo "Curl return code: $v_STATUS" >> "$v_WORKINGDIR""$v_MY_PID"/site_current.html
      fi
      if [[ $( egrep -c "$v_CURL_STRING" "$v_WORKINGDIR""$v_MY_PID"/site_current.html ) -ne 0 ]]; then
         fn_hit
      else
         fn_miss
      fi
      fn_child_checks
   done
}

function fn_ping_child {
   ### The basic loop for a ping monitoring process
   v_URL_OR_PING="Ping of"
   while [[ 1 == 1 ]]; do
      v_DATE="$( date +%m"/"%d" "%H":"%M":"%S )"
      v_DATE2="$( date )"
      v_DATE3="$( date +%s )"
      v_PING_RESULT=$( ping -W2 -c1 $v_DOMAIN 2> /dev/null | grep "icmp_[rs]eq" )
      v_WATCH=$( echo $v_PING_RESULT | grep -c "icmp_[rs]eq" )
      if [[ $v_WATCH -ne 0 ]]; then
         fn_hit
      else
         fn_miss
      fi
      fn_child_checks
   done
}

function fn_dns_child {
   ### The basic loop for a DNS monitoring process
   ### Note: the DNS monitoring feature is a throwback to 2012 and 2013 when DNS was the first thing that would stop reporting on a cPanel server if it was under load. While this is no longer the case, I don't see any point in removing this feature.
   v_URL_OR_PING="DNS for"
   while [[ 1 == 1 ]]; do
      v_DATE="$( date +%m"/"%d" "%H":"%M":"%S )"
      v_DATE2="$( date )"
      v_DATE3="$( date +%s )"
      v_QUERY_RESULT=$( dig +tries=1 $v_DOMAIN @$v_IP_ADDRESS 2> /dev/null | grep -c "ANSWER SECTION" )
      if [[ $v_QUERY_RESULT -ne 0 ]]; then
         fn_hit
      else
         fn_miss
      fi
      fn_child_checks
   done
}

function fn_child_checks {
   ### Is there a file in place telling the child process to reload its params file, or to die?
   if [[ -f "$v_WORKINGDIR""$v_MY_PID"/reload ]]; then
      mv -f "$v_WORKINGDIR""$v_MY_PID"/reload "$v_WORKINGDIR""$v_MY_PID"/#reload
      fn_child_vars
      echo "$v_DATE2 - [$v_MY_PID] - Reloaded parameters for $v_URL_OR_PING $v_ORIG_SERVER_STRING." >> "$v_LOG"
      echo "$v_DATE2 - [$v_MY_PID] - Reloaded parameters for $v_URL_OR_PING $v_ORIG_SERVER_STRING." >> "$v_WORKINGDIR""$v_MY_PID"/log
      echo "***Reloaded parameters for $v_URL_OR_PING $v_SERVER_STRING.***"
   fi
   ### Check the conf to see how many copies of the html files to keep. Remove any beyond that.
   v_HTML_FILES_KEPT="$( fn_read_conf HTML_FILES_KEPT "$v_WORKINGDIR"xmonitor.conf )"
   v_HTML_FILES_KEPT="$( fn_test_variable "$v_HTML_FILES_KEPT" true false 100 )"
   if [[ $( ls -1 "$v_WORKINGDIR""$v_MY_PID"/ | grep "^site_" | egrep -cv "current|previous" ) -gt $v_HTML_FILES_KEPT ]]; then
      ### You'll notice that it's only removing one file. There should be no instances where more than one is generated per run, so removing one per run should always be sufficient.
      rm -f "$v_WORKINGDIR""$v_MY_PID"/site_"$( ls -1t "$v_WORKINGDIR""$v_MY_PID"/ | grep "^site_" | egrep -v "current|previous" | tail -n1 | sed "s/site_//" )"
   fi
   ### If the domain or IP address shows up on the die list, this process can be killed.
   if [[ $( egrep -c "^[[:blank:]]*($v_DOMAIN|$v_IP_ADDRESS)[[:blank:]]*(#.*)*$" "$v_WORKINGDIR"die_list ) -gt 0 ]]; then
      echo "$( date ) - [$v_MY_PID] - Process ended due to data on the remote list. The line reads \"$( egrep "^[[:blank:]]*($v_DOMAIN|$v_IP_ADDRESS)[[:blank:]]*(#.*)*$" "$v_WORKINGDIR"die_list | head -n1 )\"." >> "$v_LOG"
      echo "$( date ) - [$v_MY_PID] - Process ended due to data on the remote list. The line reads \"$( egrep "^[[:blank:]]*($v_DOMAIN|$v_IP_ADDRESS)[[:blank:]]*(#.*)*$" "$v_WORKINGDIR"die_list | head -n1 )\"." >> "$v_WORKINGDIR""$v_MY_PID"/log
      touch "$v_WORKINGDIR""$v_MY_PID"/die
   fi
   if [[ -f "$v_WORKINGDIR""$v_MY_PID"/die ]]; then
      fn_child_exit
   fi
   ### Get the colors for the child process to output.
   fn_get_colors
   sleep $v_WAIT_SECONDS
}

function fn_child_exit {
   ### When a child process exits, it needs to clean up after itself and log the fact that it has exited.
   if [[ $v_TOTAL_CHECKS -gt 0 ]]; then
      echo "$v_DATE2 - [$v_MY_PID] - Stopped watching $v_URL_OR_PING $v_ORIG_SERVER_STRING: Running for $v_RUN_TIME seconds. $v_TOTAL_CHECKS checks completed. $v_PERCENT_HITS% success rate." >> "$v_LOG"
      echo "$v_DATE2 - [$v_MY_PID] - Stopped watching $v_URL_OR_PING $v_ORIG_SERVER_STRING: Running for $v_RUN_TIME seconds. $v_TOTAL_CHECKS checks completed. $v_PERCENT_HITS% success rate." >> "$v_WORKINGDIR""$v_MY_PID"/log
   fi
   ### Instead of deleting the directory, back it up temporarily.
   if [[ -f "$v_WORKINGDIR""$v_MY_PID"/die ]]; then
      mv -f "$v_WORKINGDIR""$v_MY_PID"/die "$v_WORKINGDIR""$v_MY_PID"/#die
      mv "$v_WORKINGDIR""$v_MY_PID" "$v_WORKINGDIR""old_""$v_MY_PID""_""$v_DATE3"
   fi
   exit
}

#### Hit and Miss Functions ####

function fn_hit {
   ### This is run every time a monitoring process has a successful check
   ### gather variables for use in reporting, both to the log file and to e-mail.
   v_RUN_TIME=$(( $v_DATE3 - $v_START_TIME ))
   v_TOTAL_CHECKS=$(( $v_TOTAL_CHECKS + 1 ))
   v_TOTAL_HITS=$(( $v_TOTAL_HITS + 1 ))
   v_PERCENT_HITS=$( echo "scale=2; $v_TOTAL_HITS * 100 / $v_TOTAL_CHECKS" | bc )
   if [[ $v_LAST_MISS == "never" ]]; then
      v_LAST_MISS_STRING="never"
      if [[ $v_LAST_HIT == "never" ]]; then
         v_HIT_MAIL=true
      fi
   else
      v_LAST_MISS_STRING="$(( $v_DATE3 - $v_LAST_MISS )) seconds ago"
   fi
   v_LAST_HIT=$v_DATE3
   v_NUM_HITS_EMAIL=$(( $v_NUM_HITS_EMAIL + 1 ))
   ### Determine how verbose Xmonitor is set to be and prepare the message accordingly.
   v_VERBOSITY="$( fn_read_conf VERBOSITY "$v_WORKINGDIR""$v_MY_PID"/params )"
   v_VERBOSITY="$( fn_test_variable "$v_VERBOSITY" false VERBOSITY "standard" )"
   if [[ $( echo "$v_VERBOSITY" | egrep -c "^(standard|none|verbose|change)$" ) -eq 0 ]]; then
      v_VERBOSITY=""
   fi
   if [[ $v_VERBOSITY == "verbose" || -f "$v_WORKINGDIR""$v_MY_PID"/status ]]; then
      v_REPORT="$v_DATE - [$v_MY_PID] - $v_URL_OR_PING $v_SERVER_STRING: Succeeded! - Checking for $v_RUN_TIME seconds. Last failed check: $v_LAST_MISS_STRING. $v_TOTAL_CHECKS checks completed. $v_PERCENT_HITS% success rate."
      if [[ -f "$v_WORKINGDIR""$v_MY_PID"/status ]]; then
         echo "$v_REPORT" > "$v_WORKINGDIR""$v_MY_PID"/status
         mv -f "$v_WORKINGDIR""$v_MY_PID"/status "$v_WORKINGDIR""$v_MY_PID/#status"
      fi
   else
      v_REPORT="$v_DATE - $v_URL_OR_PING $v_SERVER_STRING: Succeeded!"
   fi
   ### Check to see if the parent is still in palce
   if [[ $( ps aux | grep "$v_MASTER_PID.*xmonitor.sh" | grep -vc " 0:00 grep " ) -eq 0 ]]; then
      fn_child_exit
   fi
   ### If the last check was also successful
   if [[ $v_LAST_STATUS == "hit" ]]; then
      if [[ $v_VERBOSITY != "change" && $v_VERBOSITY != "none" && ! -f "$v_WORKINGDIR"no_output ]]; then
         echo -e "$v_COLOR_SUCCESS""$v_REPORT""$v_RETURN_SUCCESS" >> "$v_OUTPUT_FILE"
      fi
      v_HIT_CHECKS=$(( $v_HIT_CHECKS + 1 ))
      if [[ $v_LAST_MISS != "never" ]]; then
         fn_hit_email
      fi
   ### If there was no last check
   elif [[ $v_LAST_STATUS == "none" ]]; then
      if [[ $v_VERBOSITY != "none" && ! -f "$v_WORKINGDIR"no_output ]]; then
         echo -e "$v_COLOR_FIRST_SUCCESS""$v_REPORT""$v_RETURN_FIRST_SUCCESS" >> "$v_OUTPUT_FILE"
      fi
      echo "$v_DATE2 - [$v_MY_PID] - Initial status for $v_URL_OR_PING $v_ORIG_SERVER_STRING: Check succeeded!" >> "$v_LOG"
      echo "$v_DATE2 - [$v_MY_PID] - Initial status for $v_URL_OR_PING $v_ORIG_SERVER_STRING: Check succeeded!" >> "$v_WORKINGDIR""$v_MY_PID"/log
      v_HIT_CHECKS=1
   ### If the last check failed
   else
      if [[ $v_VERBOSITY != "none" && ! -f "$v_WORKINGDIR"no_output ]]; then
         echo -e "$v_COLOR_FIRST_SUCCESS""$v_REPORT""$v_RETURN_FIRST_SUCCESS" >> "$v_OUTPUT_FILE"
      fi
      echo "$v_DATE2 - [$v_MY_PID] - Status changed for $v_URL_OR_PING $v_ORIG_SERVER_STRING: Check succeeded after $v_MISS_CHECKS failed checks!" >> "$v_LOG"
      echo "$v_DATE2 - [$v_MY_PID] - Status changed for $v_URL_OR_PING $v_ORIG_SERVER_STRING: Check succeeded after $v_MISS_CHECKS failed checks!" >> "$v_WORKINGDIR""$v_MY_PID"/log
      v_HIT_CHECKS=1
      fn_hit_email
   fi
   v_LAST_STATUS="hit"
}

function fn_get_colors {
   v_COLOR_SUCCESS="$( fn_read_conf COLOR_SUCCESS "$v_WORKINGDIR"xmonitor.conf "" )"
   v_COLOR_FIRST_SUCCESS="$( fn_read_conf COLOR_FIRST_SUCCESS "$v_WORKINGDIR"xmonitor.conf "\e[1;32m" )"
   v_COLOR_FAILURE="$( fn_read_conf COLOR_FAILURE "$v_WORKINGDIR"xmonitor.conf "\e[1;33m" )"
   v_COLOR_FIRST_FAILURE="$( fn_read_conf COLOR_FIRST_FAILURE "$v_WORKINGDIR"xmonitor.conf "\e[1;31m" )"
   v_RETURN_SUCCESS="$( fn_read_conf RETURN_SUCCESS "$v_WORKINGDIR"xmonitor.conf "" )"
   v_RETURN_FIRST_SUCCESS="$( fn_read_conf RETURN_FIRST_SUCCESS "$v_WORKINGDIR"xmonitor.conf "\e[00m" )"
   v_RETURN_FAILURE="$( fn_read_conf RETURN_FAILURE "$v_WORKINGDIR"xmonitor.conf "\e[00m" )"
   v_RETURN_FIRST_FAILURE="$( fn_read_conf RETURN_FIRST_FAILURE "$v_WORKINGDIR"xmonitor.conf "\e[00m" )"
}

function fn_miss {
   ### This is run every time a monitoring process has a failed check
   ### gather variables for use in reporting, both to the log file and to e-mail.
   v_RUN_TIME=$(( $v_DATE3 - $v_START_TIME ))
   v_TOTAL_CHECKS=$(( $v_TOTAL_CHECKS + 1 ))
   v_PERCENT_HITS=$( echo "scale=2; $v_TOTAL_HITS * 100 / $v_TOTAL_CHECKS" | bc )
   if [[ $v_LAST_HIT == "never" ]]; then
      v_LAST_HIT_STRING="never"
      if [[ $v_LAST_MISS == "never" ]]; then
         v_MISS_MAIL=true
      fi
   else
      v_LAST_HIT_STRING="$(( $v_DATE3 - $v_LAST_HIT )) seconds ago"
   fi
   v_LAST_MISS=$v_DATE3
   v_NUM_MISSES_EMAIL=$(( $v_NUM_MISSES_EMAIL + 1 ))
   ### determine what the verbosity is set to and prepare the message accordingly.
   v_VERBOSITY="$( fn_read_conf VERBOSITY "$v_WORKINGDIR""$v_MY_PID"/params )"
   v_VERBOSITY="$( fn_test_variable "$v_VERBOSITY" false VERBOSITY "standard" )"
   if [[ $( echo "$v_VERBOSITY" | egrep -c "^(standard|none|verbose|change)$" ) -eq 0 ]]; then
      v_VERBOSITY=""
   fi
   if [[ $v_VERBOSITY == "verbose" || -f "$v_WORKINGDIR""$v_MY_PID"/status ]]; then
      v_REPORT="$v_DATE - [$v_MY_PID] - $v_URL_OR_PING $v_SERVER_STRING: Failed! - Checking for $v_RUN_TIME seconds. Last successful check: $v_LAST_HIT_STRING. $v_TOTAL_CHECKS checks completed. $v_PERCENT_HITS% success rate."
      if [[ -f "$v_WORKINGDIR""$v_MY_PID"/status ]]; then
         echo "$v_REPORT" > "$v_WORKINGDIR""$v_MY_PID"/status
         mv -f "$v_WORKINGDIR""$v_MY_PID"/status "$v_WORKINGDIR""$v_MY_PID"/#status
      fi
   else
      v_REPORT="$v_DATE - $v_URL_OR_PING $v_SERVER_STRING: Failed!"
   fi
   if [[ $( ps aux | grep "$v_MASTER_PID.*xmonitor.sh" | grep -vc " 0:00 grep " ) -eq 0 ]]; then
      fn_child_exit
   fi
   if [[ $v_LAST_STATUS == "miss" ]]; then
      ### If the last check was also a miss
      if [[ $v_VERBOSITY != "change" && $v_VERBOSITY != "none" && ! -f "$v_WORKINGDIR"no_output ]]; then
         echo -e "$v_COLOR_FAILURE""$v_REPORT""$v_RETURN_FAILURE" >> "$v_OUTPUT_FILE"
      fi
      v_MISS_CHECKS=$(( $v_MISS_CHECKS + 1 ))
      if [[ $v_LAST_HIT != "never" ]]; then
         fn_miss_email
      fi
   elif [[ $v_LAST_STATUS == "none" ]]; then
      ### If there was no last check
      if [[ $v_VERBOSITY != "none" && ! -f "$v_WORKINGDIR"no_output ]]; then
         echo -e "$v_COLOR_FIRST_FAILURE""$v_REPORT""$v_RETURN_FIRST_FAILURE" >> "$v_OUTPUT_FILE"
      fi
      echo "$v_DATE2 - [$v_MY_PID] - Initial status for $v_URL_OR_PING $v_ORIG_SERVER_STRING: Check failed!" >> "$v_LOG"
      echo "$v_DATE2 - [$v_MY_PID] - Initial status for $v_URL_OR_PING $v_ORIG_SERVER_STRING: Check failed!" >> "$v_WORKINGDIR""$v_MY_PID"/log
      v_MISS_CHECKS=1
   else
      ### If the last check was a hit.
      if [[ $v_VERBOSITY != "none" && ! -f "$v_WORKINGDIR"no_output ]]; then
         echo -e "$v_COLOR_FIRST_FAILURE""$v_REPORT""$v_RETURN_FIRST_FAILURE" >> "$v_OUTPUT_FILE"
      fi
      ### The first failure after a hit should be the only instance where we need to save a copy of the site (if we're in URL mode).
      if [[ $v_URL_OR_PING == "URL" ]]; then
         cp -a "$v_WORKINGDIR""$v_MY_PID"/site_current.html "$v_WORKINGDIR""$v_MY_PID"/site_fail_"$v_DATE3".html
         cp -a "$v_WORKINGDIR""$v_MY_PID"/site_previous.html "$v_WORKINGDIR""$v_MY_PID"/site_success_"$v_DATE3_LAST".html
      fi
      echo "$v_DATE2 - [$v_MY_PID] - Status changed for $v_URL_OR_PING $v_ORIG_SERVER_STRING: Check failed after $v_HIT_CHECKS successful checks!" >> "$v_LOG"
      echo "$v_DATE2 - [$v_MY_PID] - Status changed for $v_URL_OR_PING $v_ORIG_SERVER_STRING: Check failed after $v_HIT_CHECKS successful checks!" >> "$v_WORKINGDIR""$v_MY_PID"/log
      v_MISS_CHECKS=1
      fn_miss_email
   fi
   v_LAST_STATUS="miss"
}

function fn_hit_email {
   ### Determines if a success e-mail needs to be sent and, if so, sends that e-mail.
   if [[ $v_HIT_CHECKS -eq $v_MAIL_DELAY && ! -z $v_EMAIL_ADDRESS && $v_MISS_MAIL == true ]]; then
      echo -e "$( if [[ ! -z $v_CUSTOM_MESSAGE ]]; then echo "$v_CUSTOM_MESSAGE\n\n"; fi )$v_DATE2 - Xmonitor - $v_URL_OR_PING $v_SERVER_STRING - Status changed: Appears to be succeeding again.\n\nYou're recieving this message to inform you that $v_MAIL_DELAY consecutive check(s) against $v_URL_OR_PING $( if [[ "$v_SERVER_STRING" == "$v_ORIG_SERVER_STRING" ]]; then echo "$v_SERVER_STRING"; else echo "$v_SERVER_STRING ($v_ORIG_SERVER_STRING)"; fi ) have succeeded, thus meeting your threshold for being alerted. Since the previous e-mail was sent (Or if none have been sent, since checks against this server were started) there have been a total of $v_NUM_HITS_EMAIL successful checks, and $v_NUM_MISSES_EMAIL failed checks.\n\nChecks have been running for $v_RUN_TIME seconds. $v_TOTAL_CHECKS checks completed. $v_PERCENT_HITS% success rate.\n\nLogs related to this check;\n\n$( cat "$v_WORKINGDIR""$v_MY_PID"/log )" | mail -s "Xmonitor - $v_URL_OR_PING $v_SERVER_STRING - Check PASSED!" $v_EMAIL_ADDRESS && echo "$v_DATE2 - [$v_MY_PID] - $v_URL_OR_PING $v_ORIG_SERVER_STRING: Success e-mail sent" >> "$v_LOG" &
      ### set the variables that prepare for the next message to be sent.
      v_HIT_MAIL=true
      v_MISS_MAIL=false
      v_NUM_HITS_EMAIL=0
      v_NUM_MISSES_EMAIL=0
   fi
}

function fn_miss_email {
   ### Determines if a failure e-mail needs to be sent and, if so, sends that e-mail.
   if [[ $v_MISS_CHECKS -eq $v_MAIL_DELAY && ! -z $v_EMAIL_ADDRESS && $v_HIT_MAIL == true ]]; then
      echo -e "$( if [[ ! -z $v_CUSTOM_MESSAGE ]]; then echo "$v_CUSTOM_MESSAGE\n\n"; fi )$v_DATE2 - Xmonitor - $v_URL_OR_PING $v_SERVER_STRING - Status changed: Appears to be failing.\n\nYou're recieving this message to inform you that $v_MAIL_DELAY consecutive check(s) against $v_URL_OR_PING $( if [[ "$v_SERVER_STRING" == "$v_ORIG_SERVER_STRING" ]]; then echo "$v_SERVER_STRING"; else echo "$v_SERVER_STRING ($v_ORIG_SERVER_STRING)"; fi ) have failed, thus meeting your threshold for being alerted. Since the previous e-mail was sent (Or if none have been sent, since checks against this server were started) there have been a total of $v_NUM_HITS_EMAIL successful checks, and $v_NUM_MISSES_EMAIL failed checks.\n\nChecks have been running for $v_RUN_TIME seconds. $v_TOTAL_CHECKS checks completed. $v_PERCENT_HITS% success rate.\n\nLogs related to this check;\n\n$( cat "$v_WORKINGDIR""$v_MY_PID"/log )" | mail -s "Xmonitor - $v_URL_OR_PING $v_SERVER_STRING - Check FAILED!" $v_EMAIL_ADDRESS && echo "$v_DATE2 - [$v_MY_PID] - $v_URL_OR_PING $v_ORIG_SERVER_STRING: Failure e-mail sent" >> "$v_LOG" &
      ### set the variables that prepare for the next message to be sent.
      v_HIT_MAIL=false
      v_MISS_MAIL=true
      v_NUM_HITS_EMAIL=0
      v_NUM_MISSES_EMAIL=0
   fi
}

#### Master Functions ####

function fn_master {
   ### This is the loop for the master function.
   if [[ $v_RUNNING_STATE != "master" ]]; then
      echo "Master process already present. Exiting"
      exit
   fi
   ### try to prevent the master process from exiting unexpectedly.
   trap fn_master_exit SIGINT SIGTERM SIGKILL
   v_VERBOSITY="$( fn_read_conf VERBOSITY "$v_WORKINGDIR"xmonitor.conf "standard" )"
   ### Get rid of the save file (if there is one).
   if [[ -f "$v_WORKINGDIR"save ]]; then
      rm -f "$v_WORKINGDIR"save
   fi
   v_TIMESTAMP_REMOTE_CHECK=0
   v_TIMESTAMP_LOCAL_CHECK=0
   $v_CURL_BIN -Lsm 10 http://72.52.228.74/xmonitor.txt --header "Host: tacobell.com" > "$v_WORKINGDIR"die_list
   while [[ 1 == 1 ]]; do
      ### Check to see what the current IP address is (thanks to VPN, this can change, so we need to check every half hour.
      if [[ $(( $( date +%s ) - 1800 )) -gt $v_TIMESTAMP_REMOTE_CHECK ]]; then
         v_TIMESTAMP_REMOTE_CHECK="$( date +%s )"
         v_LOCAL_IP="$( $v_CURL_BIN -Lsm 10 http://ip.liquidweb.com/ )"
         if [[ -z $v_LOCAL_IP ]]; then
            v_LOCAL_IP="Not_Found"
         fi
         ### Also, let's do getting rid of old processes here - there's no reason to do that every two seconds, and this already runs every half hour, so there's no need to create a separate timer for that.
         for v_OLD_CHILD in $( find "$v_WORKINGDIR" -maxdepth 1 -type d | rev | cut -d "/" -f1 | rev | grep "^old_[0-9][0-9]*_[0-9][0-9]*$" ); do
            if [[ $( echo $v_OLD_CHILD | grep -c "^old_[[:digit:]]*_[[:digit:]]*$" ) -eq 1 ]]; then
               if [[ $(( $( date +%s ) - $( echo $v_OLD_CHILD | cut -d "_" -f3 ) )) -gt 604800 ]]; then
                  ### 604800 seconds = seven days.
                  echo "$( date ) - [$( echo "$v_OLD_CHILD" | cut -d "_" -f2)] - $( fn_read_conf JOB_TYPE "$v_WORKINGDIR""$v_OLD_CHILD""/params" ) $( fn_read_conf SERVER_STRING "$v_WORKINGDIR""$v_OLD_CHILD""/params" ) - Child process dead for seven days. Deleting backed up data." >> "$v_LOG"
                  rm -rf "$v_WORKINGDIR""$v_OLD_CHILD"
               fi
            fi
         done
      fi
      ### Check a remote list to see if xmonitor should be stopped
      if [[ $(( $( date +%s ) - 300 )) -gt $v_TIMESTAMP_REMOTE_CHECK ]]; then
         v_TIMESTAMP_REMOTE_CHECK="$( date +%s )"
         $v_CURL_BIN -Lsm 10 http://72.52.228.74/xmonitor.txt --header "Host: tacobell.com" > "$v_WORKINGDIR"die_list
         if [[ $( egrep -c "^[[:blank:]]*$v_LOCAL_IP[[:blank:]]*(#.*)*$" "$v_WORKINGDIR"die_list ) -gt 0 ]]; then
            touch "$v_WORKINGDIR"die
            touch "$v_WORKINGDIR"save
            echo "$( date ) - [$$] - Local IP found on remote list. The line reads \"$( egrep "^[[:blank:]]*$v_LOCAL_IP[[:blank:]]*(#.*)*$" "$v_WORKINGDIR"die_list | head -n1 )\". Process ended." >> "$v_LOG"
            fn_master_exit
         fi
      fi
      ### Check if there are any new files within the new/ directory. Assume that they're params files for new jobs
      if [[ $( ls -1 "$v_WORKINGDIR""new/" | wc -l ) -gt 0 ]]; then
         for i in $( ls -1 "$v_WORKINGDIR""new/" | grep "\.job$" ); do
            ### Find all files that are not marked as log files.
            v_SERVER_STRING="$( fn_read_conf SERVER_STRING "$v_WORKINGDIR""new/$i" )"
               v_JOB_TYPE="$( fn_read_conf JOB_TYPE "$v_WORKINGDIR""new/$i" )"
            if [[ $v_JOB_TYPE == "url" ]]; then
               v_SERVER_STRING="URL $v_SERVER_STRING"
               fn_spawn_child_process
            elif [[ $v_JOB_TYPE == "ping" ]]; then
               v_SERVER_STRING="PING $v_SERVER_STRING"
               fn_spawn_child_process
            elif [[ $v_JOB_TYPE == "dns" ]]; then
               v_SERVER_STRING="DNS $v_SERVER_STRING"
               fn_spawn_child_process
            fi
         done
         ### If there's anything else left in this directory, it is neither a job, nor a log file. Let's get rid of it.
         if [[ $( ls -1 "$v_WORKINGDIR""new/" | wc -l ) -gt 0 ]]; then
            rm -f "$v_WORKINGDIR"new/*
         fi
      fi
      ### go through the directories for child processes. Make sure that each one is associated with a running child process. If not....
      ### go through the directories for child processes. Make sure that each one is associated with a running child process. If not....
      for v_CHILD_PID in $( find "$v_WORKINGDIR" -maxdepth 1 -type d | rev | cut -d "/" -f1 | rev | grep "^[0-9][0-9]*$" ); do
         if [[ $( ps aux | grep "$v_CHILD_PID.*xmonitor.sh" | grep -vc " 0:00 grep " ) -eq 0 ]]; then
            ### If it's been marked to die, back it up temporarily
            if [[ -f "$v_WORKINGDIR""$v_CHILD_PID/die" ]]; then
               v_TIMESTAMP="$( date +%s )"
               mv "$v_WORKINGDIR""$v_CHILD_PID" "$v_WORKINGDIR""old_""$v_CHILD_PID""_""$v_TIMESTAMP"
            ### Otherwise, restart it, then backup the old data temporarily.
            else
               echo "$( date ) - [$v_CHILD_PID] - $( fn_read_conf JOB_TYPE "$v_WORKINGDIR""$v_CHILD_PID""/params" ) $( fn_read_conf SERVER_STRING "$v_WORKINGDIR""$v_CHILD_PID""/params" ) - Child process was found dead. Restarting with new PID." >> "$v_LOG"
               v_NEW_JOB="$( date +%s )""_$RANDOM.job"
               cp -a "$v_WORKINGDIR""$v_CHILD_PID"/params "$v_WORKINGDIR""new/$v_NEW_JOB.job"
               if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/log ]]; then
                  ### If there's a log file, let's keep that too.
                  cp -a "$v_WORKINGDIR""$v_CHILD_PID"/log "$v_WORKINGDIR""new/$v_NEW_JOB".log
               fi
               v_TIMESTAMP="$( date +%s )"
               mv "$v_WORKINGDIR""$v_CHILD_PID" "$v_WORKINGDIR""old_""$v_CHILD_PID""_""$v_TIMESTAMP"
            fi
         fi
      done
      ### Has verbosity changed? If so, announce this fact!
      v_VERBOSITY2="$( fn_read_conf VERBOSITY "$v_WORKINGDIR"xmonitor.conf )"
      if [[ "$v_VERBOSITY2" != "$v_VERBOSITY" ]]; then
         if [[ $( echo "$v_VERBOSITY2" | egrep -c "^(standard|verbose|change|none)$" ) -ne 1 ]]; then
            fn_update_conf VERBOSITY "$v_VERBOSITY" "$v_WORKINGDIR"xmonitor.conf
         else
            v_VERBOSITY="$v_VERBOSITY2"
            echo "***Verbosity is now set as \"$v_VERBOSITY\"***"
         fi
      fi
      ### Is there a file named "die" in the working directory? If so, end the master process.
      if [[ -f "$v_WORKINGDIR"die ]]; then
         fn_master_exit
      fi
      sleep 2
   done
}

function fn_spawn_child_process {
   ### This function launches the child process and makes sure that it has it's own working directory.
   ### Launch the child process
   "$v_PROGRAMDIR"xmonitor.sh $v_SERVER_STRING &
   ### Note - the server string doesn't need to be present, but it makes ps more readable. Each child process starts out as generic. Once the master process creates a working directory for it (based on its PID) and then puts the params file in place for it, only then does it discover its purpose.
   ### create the child's wirectory and move the params file there.
   v_CHILD_PID=$!
   mkdir -p "$v_WORKINGDIR""$v_CHILD_PID"
   touch "$v_WORKINGDIR""$v_CHILD_PID/#die" "$v_WORKINGDIR""$v_CHILD_PID/#reload" "$v_WORKINGDIR""$v_CHILD_PID/#status"
   mv "$v_WORKINGDIR""new/$i" "$v_WORKINGDIR""$v_CHILD_PID""/params"
   if [[ -f "$v_WORKINGDIR""new/$i".log ]]; then
   ### If there's a log file, let's move that log file into the appropriate directory as well.
      mv "$v_WORKINGDIR""new/$i".log "$v_WORKINGDIR""$v_CHILD_PID""/log"
   fi
}

function fn_master_exit {
   ### these steps are run after the master process has recieved a signal that it needs to die.
   if [[ ! -f "$v_WORKINGDIR"die && $( find $v_WORKINGDIR -maxdepth 1 -type d | rev | cut -d "/" -f1 | rev | grep "." | grep -vc "[^0-9]" ) -gt 0 ]]; then
      ### If the "die" file is not present, it was CTRL-C'd from the command line. Check if there are child processes, then prompt if they should be saved.
      ### Create a no_output file
      touch "$v_WORKINGDIR"no_output
      echo "Options:"
      echo
      echo "  1) Kill the master process and all child processes."
      echo "  2) Back up the data for the child processes so that they'll start again next time Xmonitor is run, then kill the master process and all child processes."
      echo
      read -t 15 -p "How would you like to proceed? " v_OPTION_NUM
      # If they've opted to kill off all the current running processes, place a "die" file in each of their directories.
      if [[ $v_OPTION_NUM == "1" ]]; then
         for i in $( find $v_WORKINGDIR -type d ); do
            v_CHILD_PID=$( basename $i )
            # if [[ $( echo $v_CHILD_PID | grep -vc [^0-9] ) -eq 1 ]]; then
            if [[ $( echo $v_CHILD_PID | sed "s/[[:digit:]]//g" | grep -c . ) -eq 0 ]]; then
               if [[ $( ps aux | grep "$v_CHILD_PID.*xmonitor.sh" | grep -vc " 0:00 grep " ) -gt 0 ]]; then
                  touch "$v_WORKINGDIR""$v_CHILD_PID/die"
               fi
            fi
         done
      elif [[ -z $v_OPTION_NUM ]]; then
         echo
      fi
   fi
   rm -f "$v_WORKINGDIR"xmonitor.pid "$v_WORKINGDIR"die "$v_WORKINGDIR"no_output
   exit
}

#### Other Functions ####

function fn_verbosity {
   ### This is the menu front-end for determining verbosity.
   v_OLD_VERBOSITY=$( fn_read_conf VERBOSITY "$v_VERBOSITY_FILE" )
   if [[ -z $v_OLD_VERBOSITY ]]; then
      echo "Verbosity is not currently set"
   else
      echo "Verbosity is currently set to \"$v_OLD_VERBOSITY\"."
   fi
   echo
   echo "  1) Standard: A description of the server and whether the check passed or failed."
   echo "  2) Verbose: As standard, but with additional statistical information."
   echo "  3) Change: As standard, but only outputs when the status of the check is different than of the previous check."
   echo "  4) None: Nothing is output."
   echo
   read -p "What would you like the new verbosity to be? " v_OPTION_NUM
   if [[ $( echo "$v_OPTION_NUM" | egrep -vc "^0-9" ) -eq 0 || $v_OPTION_NUM -gt 4 ]]; then
      echo "Invalid input. Exiting"
      exit
   fi
   if [[ $v_OPTION_NUM == "1" ]]; then
      v_VERBOSITY="standard"
   elif [[ $v_OPTION_NUM == "2" ]]; then
      v_VERBOSITY="verbose"
   elif [[ $v_OPTION_NUM == "3" ]]; then
      v_VERBOSITY="change"
   elif [[ $v_OPTION_NUM == "4" ]]; then
      v_VERBOSITY="none"
   fi
   fn_verbosity_assign
}

function fn_verbosity_assign {
   ### This process handles the back-end of assigning verbosity.
   if [[ -z $v_VERBOSITY_FILE ]]; then
      v_VERBOSITY_FILE="$v_WORKINGDIR""verbosity"
   fi
   fn_update_conf VERBOSITY "$v_VERBOSITY" "$v_VERBOSITY_FILE"
   if [[ $v_VERBOSITY == "standard" ]]; then
      echo "Verbosity is now set to \"standard\"."
   elif [[ $v_VERBOSITY == "verbose" ]]; then
      echo "Verbosity is now set to \"verbose\" - additional statistical information will now be printed with each check."
   elif [[ $v_VERBOSITY == "change" ]]; then
      echo "Verbosity is now set to \"change\" - only changes in status will be output to screen."
   elif [[ $v_VERBOSITY == "none" ]]; then
      echo "Verbosity is now set to \"none\" - nothing will be output to screen."
   fi
}

function fn_modify {
   ### This is the menu front-end for modifying child processes.
   if [[ $v_RUNNING_STATE == "master" ]]; then
      echo "No current xmonitor processes. Exiting"
      exit
   fi
   echo "List of currently running xmonitor processes:"
   echo
   v_CHILD_NUMBER="0"
   a_CHILD_PID[0]="none"
   ### List the current xmonitor processes.
   for i in $( find $v_WORKINGDIR -maxdepth 1 -type d | rev | cut -d "/" -f1 | rev | grep "." | grep -v "[^0-9]" ); do
      v_CHILD_PID=$( basename $i )
      v_CHILD_NUMBER=$(( $v_CHILD_NUMBER + 1 ))
      echo "  $v_CHILD_NUMBER) [$v_CHILD_PID] - $( fn_read_conf JOB_TYPE "$v_WORKINGDIR""$v_CHILD_PID""/params" ) $( fn_read_conf SERVER_STRING "$v_WORKINGDIR""$v_CHILD_PID""/params" )"
      a_CHILD_PID[$v_CHILD_NUMBER]="$v_CHILD_PID"
   done
   if [[ $v_RUN_TYPE == "--list" || $v_RUN_TYPE == "-l" ]]; then
      echo
      exit
   fi
   v_CHILD_NUMBER=$(( $v_CHILD_NUMBER + 1 ))
   echo "  $v_CHILD_NUMBER) Master Process"
   a_CHILD_PID[$v_CHILD_NUMBER]="master"
   echo
   read -p "Which process do you want to modify? " v_CHILD_NUMBER
   if [[ $v_CHILD_NUMBER == "0" || $( echo $v_CHILD_NUMBER| grep -vc "[^0-9]" ) -eq 0 ]]; then
      echo "Invalid Option. Exiting."
      exit
   fi
   v_CHILD_PID=${a_CHILD_PID[$v_CHILD_NUMBER]}
   if [[ -z $v_CHILD_PID ]]; then
      echo "Invalid Option. Exiting."
      exit
   fi
   if [[ $v_CHILD_PID == "master" ]]; then
      ### sub-menu for if the master process is selected.
      echo -e "Options:\n"
      echo "  1) Exit out of the master process."
      echo "  2) First back-up the child processes so that they'll run immediately when xmonitor is next started, then exit out of the master process."
      echo "  3) Change the default verbosity."
      echo "  4) Edit the conf file."
      echo "  5) Exit out of this menu."
      echo
      read -p "Choose an option from the above list: " v_OPTION_NUM
      if [[ $v_OPTION_NUM == "1" ]]; then
         touch "$v_WORKINGDIR"die
      elif [[ $v_OPTION_NUM == "2" ]]; then
         touch "$v_WORKINGDIR"save
         touch "$v_WORKINGDIR"die
      elif [[ $v_OPTION_NUM == "3" ]]; then
         v_VERBOSITY_FILE="$v_WORKINGDIR""xmonitor.conf"
         fn_verbosity
      elif [[ $v_OPTION_NUM == "4" ]]; then
         if [[ ! -z $EDITOR ]]; then
            $EDITOR "$v_WORKINGDIR""xmonitor.conf"
         else
            vi "$v_WORKINGDIR""xmonitor.conf"
         fi
      else
         echo "Exiting."
         exit
      fi
   else
      ### Sub-menu for if a child process is selected.
      echo "$( fn_read_conf SERVER_STRING "$v_WORKINGDIR""$v_CHILD_PID""/params" ):"
      echo
      echo "  1) Kill this process."
      echo "  2) Change the delay between checks from \"$( fn_read_conf WAIT_SECONDS "$v_WORKINGDIR""$v_CHILD_PID""/params" "10" )\" seconds."
      echo "  3) Change e-mail address from \"$( fn_read_conf EMAIL_ADDRESS "$v_WORKINGDIR""$v_CHILD_PID""/params" )\"."
      echo "  4) Change the number of consecutive failures or successes before an e-mail is sent from \"$( fn_read_conf MAIL_DELAY "$v_WORKINGDIR""$v_CHILD_PID""/params" "2" )\"."
      echo "  5) Change the title of the job as it's reported by the child process. (Currently \"$( fn_read_conf SERVER_STRING "$v_WORKINGDIR""$v_CHILD_PID""/params" )\")."
      echo "  6) Change the verbosity just for this process."
      echo "  7) Change the file that status information is output to. (Currently \"$( fn_read_conf OUTPUT_FILE "$v_WORKINGDIR""$v_CHILD_PID""/params" "/dev/stdout" )\")"
      echo "  8) Output the command to go to the working directory for this process."
      echo "  9) Directly edit the parameters file (with your EDITOR - \"$EDITOR\")."
      echo "  10) Exit out of this menu."
      echo
      read -p "Chose an option from the above list: " v_OPTION_NUM
      if [[ $v_OPTION_NUM == "1" ]]; then
         touch "$v_WORKINGDIR""$v_CHILD_PID/die"
         echo "Process will exit out shortly."
      elif [[ $v_OPTION_NUM == "2" ]]; then
         read -p "Enter the number of seconds the script should wait before performing each iterative check: " v_WAIT_SECONDS
         if [[ -z $v_WAIT_SECONDS || $( echo $v_WAIT_SECONDS | grep -c "[^0-9]" ) -eq 1 ]]; then
            echo "Input must be a number. Exiting"
            exit
         fi
         fn_update_conf WAIT_SECONDS "$v_WAIT_SECONDS" "$v_WORKINGDIR""$v_CHILD_PID/params"
         touch "$v_WORKINGDIR""$v_CHILD_PID/reload"
         echo "Wait Seconds has been updated."
      elif [[ $v_OPTION_NUM == "3" ]]; then
         echo "Enter the e-mail address that you want changes in status sent to."
         read -p "(Or just press enter to have no e-mail messages sent): " v_EMAIL_ADDRESS
         if [[ ! -z $v_EMAIL_ADDRESS && $( echo $v_EMAIL_ADDRESS | grep -c "[^@][^@]*@[^.]*\..*" ) -eq 0 ]]; then
            echo "E-mail address does not appear to be valid. Exiting"
            exit
         elif [[ -z $v_EMAIL_ADDRESS ]]; then
            v_EMAIL_ADDRESS=""
         fi
         fn_update_conf EMAIL_ADDRESS "$v_EMAIL_ADDRESS" "$v_WORKINGDIR""$v_CHILD_PID/params"
         touch "$v_WORKINGDIR""$v_CHILD_PID/reload"
         echo "E-mail address has been updated."
      elif [[ $v_OPTION_NUM == "4" ]]; then
         echo "Enter the number of consecutive failures or successes that should occur before an e-mail"
         read -p "message is sent (default 1; to never send a message, 0): " v_MAIL_DELAY
         if [[ -z $v_MAIL_DELAY || $( echo $v_MAIL_DELAY | grep -c "[^0-9]" ) -eq 1 ]]; then
            echo "Input must be a number. Exiting"
            exit
         fi
         fn_update_conf MAIL_DELAY "$v_MAIL_DELAY" "$v_WORKINGDIR""$v_CHILD_PID/params"
         touch "$v_WORKINGDIR""$v_CHILD_PID/reload"
         echo "Mail delay has been updated."
      elif [[ $v_OPTION_NUM == "5" ]]; then
         read -p "Enter a new identifying string to associate with this check: " v_SERVER_STRING
         fn_update_conf SERVER_STRING "$v_SERVER_STRING" "$v_WORKINGDIR""$v_CHILD_PID/params"
         touch "$v_WORKINGDIR""$v_CHILD_PID/reload"
         echo "The server string has been updated."
      elif [[ $v_OPTION_NUM == "6" ]]; then
         v_VERBOSITY_FILE="$v_WORKINGDIR""$v_CHILD_PID/params"
         fn_verbosity
      elif [[ $v_OPTION_NUM == "7" ]]; then
         read -p "Enter a new file for status information to be output to: " v_OUTPUT_FILE
         if [[ ${v_OUTPUT_FILE:0:1} != "/" ]]; then
            echo "Please ensure that this file is referenced by an absolute path."
            exit
         fi
         touch "$v_OUTPUT_FILE" 2> /dev/null
         v_STATUS=$?
         if [[ ( ! -f "$v_OUTPUT_FILE" || ! -w "$v_OUTPUT_FILE" || $v_STATUS == 1 ) && "$v_OUTPUT_FILE" != "/dev/stdout" ]]; then
            echo "Please ensure that this file is already created, and has write permissions."
            exit
         fi
         fn_update_conf OUTPUT_FILE "$v_OUTPUT_FILE" "$v_WORKINGDIR""$v_CHILD_PID/params"
         touch "$v_WORKINGDIR""$v_CHILD_PID/reload"
         echo "The output file has been updated."
      elif [[ $v_OPTION_NUM == "8" ]]; then
         echo -en "\ncd $v_WORKINGDIR""$v_CHILD_PID/\n\n"
      elif [[ $v_OPTION_NUM == "9" ]]; then
         cp -a "$v_WORKINGDIR""$v_CHILD_PID/params" "$v_WORKINGDIR""$v_CHILD_PID/params.temp"
         if [[ ! -z $EDITOR ]]; then
            $EDITOR "$v_WORKINGDIR""$v_CHILD_PID/params"
         else
            vi "$v_WORKINGDIR""$v_CHILD_PID/params"
         fi
         ### Check to see if the params file has been modified. If so, reload.
         if [[ $( diff -q "$v_WORKINGDIR""$v_CHILD_PID/params" "$v_WORKINGDIR""$v_CHILD_PID/params.temp" | wc -l ) -gt 0 ]]; then
            touch "$v_WORKINGDIR""$v_CHILD_PID/reload"
         fi
         rm -f "$v_WORKINGDIR""$v_CHILD_PID/params.temp"
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
   if [[ $v_RUNNING_STATE == "master" ]]; then
      echo "  7) Spawn a master process without designating anything to monitor."
   elif [[ $v_RUNNING_STATE == "control" ]]; then
      echo "  7) Modify child processes or the master process."
   fi
   echo
   read -p "How would you like to proceed? " v_OPTION_NUM

   if [[ $v_OPTION_NUM == "1" ]]; then
      fn_get_defaults
      fn_url_vars
   elif [[ $v_OPTION_NUM == "2" ]]; then
      fn_get_defaults
      fn_ping_vars
   elif [[ $v_OPTION_NUM == "3" ]]; then
      fn_get_defaults
      fn_dns_vars
   elif [[ $v_OPTION_NUM == "4" ]]; then
      fn_help
   elif [[ $v_OPTION_NUM == "5" ]]; then
      fn_version
   elif [[ $v_OPTION_NUM == "6" ]]; then
      fn_defaults
   elif [[ $v_OPTION_NUM == "7" && $v_RUNNING_STATE == "master" ]]; then
      echo "The script will wait and watch for child processes to be spawned."
      fn_master
   elif [[ $v_OPTION_NUM == "7" && $v_RUNNING_STATE == "control" ]]; then
      fn_modify
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
   echo "  5) The default verbosity for child processes."
   echo
   read -p "Which would you like to set? " v_OPTION_NUM
   if [[ $v_OPTION_NUM == "1" ]]; then
      echo
      echo "Current default e-mail address is: \"$( fn_read_conf EMAIL_ADDRESS "$v_WORKINGDIR"xmonitor.conf )\"."
      read -p "Enter the new default e-mail address: " v_EMAIL_ADDRESS
      "$v_PROGRAMDIR"xmonitor.sh --default --mail $v_EMAIL_ADDRESS
   elif [[ $v_OPTION_NUM == "2" ]]; then
      echo
      echo "Current default number of seconds is: \"$( fn_read_conf WAIT_SECONDS "$v_WORKINGDIR"xmonitor.conf "10" )\"."
      read -p "Enter the new default number of seconds: " v_WAIT_SECONDS
      "$v_PROGRAMDIR"xmonitor.sh --default --seconds $v_WAIT_SECONDS
   elif [[ $v_OPTION_NUM == "3" ]]; then
      echo
      echo "Current default number of checks is: \"$( fn_read_conf MAIL_DELAY "$v_WORKINGDIR"xmonitor.conf "2" )\"."
      read -p "Enter the new default number of checks: " v_MAIL_DELAY
      "$v_PROGRAMDIR"xmonitor.sh --default --mail-delay $v_MAIL_DELAY
   elif [[ $v_OPTION_NUM == "4" ]]; then
      echo
      echo "Current default number of seconds before curl times out is: \"$( fn_read_conf CURL_TIMEOUT "$v_WORKINGDIR"xmonitor.conf "10" )\"."
      read -p "Enter the new default number of seconds: " v_CURL_TIMEOUT
      "$v_PROGRAMDIR"xmonitor.sh --default --curl-timeout $v_CURL_TIMEOUT
   elif [[ $v_OPTION_NUM == "5" ]]; then
      v_VERBOSITY_FILE="$v_WORKINGDIR""xmonitor.conf"
      fn_verbosity
   fi
}

function fn_set_defaults {
   ### This function is run when using the --default flag in order to set default values.
   if [[ ! -z $v_EMAIL_ADDRESS ]]; then
      fn_update_conf EMAIL_ADDRESS "$v_EMAIL_ADDRESS" "$v_WORKINGDIR"xmonitor.conf
      echo "Default e-mail address has been set to $v_EMAIL_ADDRESS."
   fi
   if [[ ! -z $v_WAIT_SECONDS ]]; then
      fn_update_conf WAIT_SECONDS "$v_WAIT_SECONDS" "$v_WORKINGDIR"xmonitor.conf
      echo "Default seconds between iterative checks has been set to $v_WAIT_SECONDS."
   fi
   if [[ ! -z $v_MAIL_DELAY ]]; then
      fn_update_conf MAIL_DELAY "$v_MAIL_DELAY" "$v_WORKINGDIR"xmonitor.conf
      echo "Default consecutive failed or successful checks before an e-mail is sent has been set to $v_MAIL_DELAY."
   fi
   if [[ ! -z $v_CURL_TIMEOUT ]]; then
      fn_update_conf CURL_TIMEOUT "$v_CURL_TIMEOUT" "$v_WORKINGDIR"xmonitor.conf
      echo "Default number of seconds before curl times out has been set to $v_CURL_TIMEOUT."
   fi
}

#### Functions related to the configuration ####

function fn_read_conf {
   # This function reads an item from the conf file. It expects $1 to be the name of the directive, $2 to be the name of the configuration file, and $3 to be the result if the nothing is pulled from the conf.
   if [[ -f "$2" ]]; then
      v_RESULT="$( egrep "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*" "$2" 2> /dev/null | tail -n1 | sed "s/^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*//" )"
      if [[ -z $v_RESULT && ! -z $3 ]]; then
          v_RESULT="$3"
      fi
      echo "$v_RESULT"
   fi
   unset v_RESULT
}

function fn_update_conf {
   # This function updates a value in the conf file. It expects $1 to be the name of the directive, $2 to be the new value for that directive, and $3 to be the name of the conf file.
   if [[ -f "$3" ]]; then
      ### We're about to run $2 through sed, so it needs to have all of its slashes escaped.
      v_MODIFIED_2="$( echo "$2" | sed -e 's/[\/&]/\\&/g' )"
      if [[ $( egrep -c "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*" "$3" 2> /dev/null ) -gt 0 ]]; then
         sed -i "$( egrep -n "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*" "$3" | tail -n1 | cut -d ":" -f1 )""s/\(^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*\).*$/\1""$v_MODIFIED_2/" "$3"
      else
         echo "$1 = $v_MODIFIED_2" >> "$3"
      fi
   fi
}

function fn_test_variable {
   ### This function assumes that $1 is the variable in question $2 is "true" or "false" whether it needs to be a number, $3 is "false" if the file cannot be pulled from the main config, and the directive name within the main config if it can be pulled from the main config, and $4 is what it should be set to if a setting is not found.
   if [[ $3 != "false" && ( -z $1 || $1 == "default" || ( $2 == true && $( echo $1 | grep -c "[^0-9]" ) -gt 0 ) ) ]]; then
      v_MODIFIED_1="$( fn_read_conf "$3" "$v_WORKINGDIR""xmonitor.conf" )"
   else
      v_MODIFIED_1="$1"
   fi
   if [[ -z $v_MODIFIED_1 || $V_MODIFIED_1 == "default" || ( $2 == true && $( echo $1 | grep -c "[^0-9]" ) -gt 0 ) ]]; then
      v_MODIFIED_1="$4"
   fi
   echo "$v_MODIFIED_1"
}

function fn_create_config {
### I tried to make everything run off of a configuration file at one point in time, however the results were overly complicated. This function remains in case I ever change my mind and try to go back to it.
cat << 'EOF' > "$v_WORKINGDIR"xmonitor.conf
# Xmonitor configuration file

# The "VERBOSITY" directive controls how verbose the output of the child processes is. 
# There are four options available: 1) Standard: Outputs whether any specific check has succeeded or failed. 2) Verbose: In addition to the information given from the standard output, also indicates how long checks for that job have been running, how many have been run, and the percentage of successful checks. 3) Change: Only outputs text on the first failure after any number of successes, or the first success after any number of failures. 4) None: Child processes output no text.
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will immediately impact all child processes they don't have their own verbosity specifically set.
VERBOSITY = standard

# The "EMAIL_ADDRESS" directive sets a default email address to which notifications will be sent for new jobs. If no address is set, no notifications will be sent.
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will only impact jobs that are created after the change is made.
EMAIL_ADDRESS = 

# The "MAIL_DELAY" directive sets a default for how many passes or failures have to occur in a row before an email is sent. This is useful in that it's typical for a single failure after a string of several succeses to be a false positive, rather than an actual indicator of an issue.
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will only impact jobs that are created after the change is made.
MAIL_DELAY = 2

# The "WAIT_SECONDS" directive sets a default number of seconds between each check that a job is doing. This does not include the amount of time that it takes for a check to complete - for example, it it takes three seconds to curl a page, and wait seconds is set at "10", it will take roughly thirteen seconds before the beginning of the next check.
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will only impact jobs that are created after the change is made.
WAIT_SECONDS = 10

# The "CURL_TIMEOUT" directive sets a default for the number of seconds before a curl operation ends. This prevents the script from waiting an unreasonable amount of time between checks.
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will only impact jobs that are created after the change is made.
CURL_TIMEOUT = 10

# The "OUTPUT_FILE" directive sets a default for where the results of child checks will be output. "/dev/stdout" indicates the standard out of the master process, and is typically the best place for this data to be pushed to. It can, however, be directed to a file, so that that file can be tailed by multiple users.
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will only impact jobs that are created after the change is made.
OUTPUT_FILE = /dev/stdout

# The "USER_AGENT" directive can be set to "true" or "false". For "true" the user agent string emulates chrome's user agent. For "false", the user agent string simply outputs the xmonitor and curl versions.
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will only impact jobs that are created after the change is made.
USER_AGENT = false

# When ever there is a change from success to failure on a URL monitoring job, a copy of the last successful curl result and the first failed curl result (with the associated error code) will be kept in the job's child directory. The "HTML_FILES_KEPT" directive controls the number of html files that are kept in addition to the results from the current and previous curls.
HTML_FILES_KEPT = 100

# The "COLOR_" and "RETURN_" directives allow the user to set specific strings that will be output before and after checks, depending on whether they're the first successful check, iterative successful checks, the first failed check, or iterative failed checks. This is designed to be used with bash color codes, but really anything that could be interpreted by "echo -e" can be used here.
COLOR_SUCCESS = 
COLOR_FIRST_SUCCESS = \e[1;32m
COLOR_FAILURE = \e[1;33m
COLOR_FIRST_FAILURE = \e[1;31m
RETURN_SUCCESS = 
RETURN_FIRST_SUCCESS = \e[00m
RETURN_FAILURE = \e[00m
RETURN_FIRST_FAILURE = \e[00m
EOF
#'do
}

#### Help and Version Functions ####

function fn_help {
cat << 'EOF' > /dev/stdout

Xmonitor - A script to organize and consolidate the monitoring of multiple servers. With Xmonitor you can run checks against multiple servers simultaneously, starting new jobs and stopping old ones as needed without interfering with any that are currently running. All output from the checks go by default to a single terminal window, allowing you to keep an eye on multiple things going on at once.


USAGE:

./xmonitor.sh (Followed by no arguments or flags)
     Prompts you on how you want to proceed, allowing you to choose from options similar to those presented by the descriptions below.


ADDITIONAL USAGE:

./xmonitor.sh [--url (or -u)|--ping (or -p)|--dns (or -d)] (followed by other flags)
     1) Leaves a prompt telling the master process to spawn a child process to either a) in the case of --url, check a site's contents for a string of characters b) in the case of --ping, ping a site and check for a response c) in the case of --dns, dig against a nameserver and check for a valid response.
     2) If there is no currently running master process, it goes on to declare itself the master process and spawn child processes accordingly.
     NOTE: For more information on the additional arguments and flags that can be used here, run ./xmonitor.sh --help-flags
     NOTE: For more information on Master, Child and Control processes, run ./xmonitor.sh --help-process-types

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

Note: Regarding the configuration file!
     There's a configuration file! Assuming that ./ is the directory where xmonitor.sh is located, the configuration file will be located at ./.xmonitor/xmonitor.conf.

Note: Regarding e-mail alerts!
     Xmonitor sends e-mail messages using the "mail" binary (usually located in /usr/bin/mail). In order for this to work as expected, you will likely need to modify the ~/.mailrc file with credentials for a valid e-mail account, otherwise the messages that are sent will likely get rejected.

Note: Regarding the log file!
     Xmonitor keeps a log file titled "xmonitor.log" in the same directory in which xmonitor.sh is located. This file is used to log when checks are started and stopped, and when ever there is a change in status on any of the checks. In addition to this, there is another log file in the direcctory for each child process containing information only specific to that child process.

Note: Regarding url checks and specifying an IP!
     Xmonitor allows you to specify an IP from which to pull a URL, rather than allowing DNS to resolve the domain name to an IP address. This is very useful in situations where you're attempting to monitor multiple servers within a load balanced setup, or if 
DNS for the site that you're monitoring isn't yet pointed to the server that it's on.

Note: Regarding text color!
     By default, the text output is color coded as follows: Green - The first check that has succeeded after any number of failed checks. White (Or what ever color is standard for your terminal) - a check that has succeeded when the previous check was also successful. Red - the first check that has failed after any number of successful checks. Yellow - a check that has failed when the previous check was also a failure.
     This can be changed by making modifications to the "COLOR_" and "RETURN_" directives in the configuration file.

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

     When used with "--url" this flag is used to specify the IP address of the server that you're running the check against. Without this flag, a DNS query is used to determine what IP the site needs to be pulled from. "--ip" is perfect for situations where multiple load balanced servers need to be monitored at once. When used with "--ping" or "--dns" this flag can be used to specify the IP address if not already specified after the "--ping" or "--dns" flags.

--mail (e-mail address)

     Specifies the e-mail address to which alerts regarding changes in status should be sent.

--mail-delay (number)

     Specifies the number of failed or successful chacks that need to occur in a row before an e-mail message is sent. The default is to send a message after each check that has a different result than the previous one, however for some monitoring jobs, this can be tedious and unnecessary. Setting this to "0" prevents e-mail allerts from being sent.

--outfile (file)

     By default, child processes output the results of their checks to the standard out (/dev/stdout) of the master process. This flag allows that output to be redirected to a file.

--seconds (number)

     Specifies the number of seconds after a check has completed to begin a new check. The default is 10 seconds.

--string

     When used with "--url", this specifies the string that the contents of the curl'd page will be searched for in order to confirm that it is loading correctly. Under optimal circumstances, this string should be something generated via php code that pulls information from a database - thus no matter if it's apache, mysql, or php that's failing, a change in status will be detected. Attempting to use this flag with "--ping" or "--dns" will throw an error. This string cannot contain new line characters and should not begin with whitespace.

--user-agent

     When used with "--url", this will cause the curl command to be run in such a way that the chrome 45 user agent is imitated. This is useful in situations where a site is refusing connections from the standard curl user agent.

--curl-timeout (number)

     When used with "--url", this flag specifies how long a curl process should wait before giving up. The default here is 10 seconds.

OTHER FLAGS:

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

--list

     Lists the current xmonitor child processes, then exits.
     
--master

     Immediately designates itself as the master process. If any prompts are waiting, it spawns child processes as they describe, it then checks periodically for new prompts and spawns processes accordingly. If the master process ends, all child processes it has spawned will recognize that it has ended, and end as well. Run ./xmonitor.sh --help-process-types for more information on master, control, and child processes.

--modify

     Prompts you with a list of currently running child processes and allows you to modify how they function and what they're checking against, or kill them off if they're no longer desired.

--save

     Used in conjunction with the "--kill" flag. Prompts Xmonitor to save all of the current running child processes before exiting so that they will be restarted automaticaly when xmonitor is next launched.

--verbosity

     Changes the verbosity level of the output of the child processes. Standard: Outputs whether any specific check has succeeded or failed. Verbose: In addition to the information given from the standard output, also indicates how long checks for that job have been running, how many have been run, and the percentage of successful checks. Change: Only outputs text on the first failure after any number of successes, or the first success after any number of failures. None: Child processes output no text.
     Note: verbosity can be set for an individual child process as well. If that is the ccase, the verbosity there will override the verbosity set here.

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

The params file contains the specifics of an xmonitor.sh job. Any xmonitor.sh job that is currently running can be changed mid-run by editing the params file - this can be done manually, or some of the values can be modified using the "--modify" flag. The purpose of this document is to explain each variable in the params file and what it does. 

After changes are made to the params file, these changes will not be recognized by the script until a file named ".xmonitor/[CHILD PID]/reload" is created.

"JOB_TYPE" 
     This line specifies what kind of job is being run. (url, dns, or ping) It's used to identify the job type initially. Making changes to it after the job has been initiated will not have any impact on the job.

"WAIT_SECONDS"
     This is the number of seconds that pass between iterative checks. This number does not take into account how long the check itself took, so for example, if it takes five seconds to curl a URL, and "WAIT_SECONDS" is set to 10, it will be rouchly 15 seconds between the start of the first check and the start of the next check.

"EMAIL_ADDRESS"
     This is the email address that messages regarding failed or successful checks will be sent to.

"MAIL_DELAY" 
     The number of successful or failed checks that need to occur before an email is sent. If this is set to zero, no email messages will be sent.

"DOMAIN"
     For URL jobs where an IP address is specified, this value is necessary for the curl command, otherwise it is unused. 
     For DNS jobs, this is the domain associated with the zone file on the server that we're checking against.
     For ping jobs, this is the domain or IP address that we're pinging.

"IP_ADDRESS"
     For URL jobs, this will be "false" if an IP address has not been specified. Otherwise, it will contain the IP address that we're connecting to before telling the remote server the domain we're trying sending a request to.
     For DNS jobs, this is the IP or host name of the remote server that we're querying.
     For ping jobs, this value is not used.

"SERVER_STRING"
     This is the identifier for the job. It will be output in the terminal window where the master process is being run (Or to where ever the "OUTPUT_FILE" directive indicates). This will also be referenced in emails.

"ORIG_SERVER_STRING"
     This is the original server string for the job. It's used for logging purposes, as well as referenced in emails. In many instances, this will be the same as the "SERVER_STRING" directive.

"CURL_URL"
     For URL jobs, this is the URL that's being curl'd.
     For DNS and ping jobs, this line is not used.

"CURL_PORT"
     For URL jobs, this is the port that's being connected to.
     For DNS and ping jobs, this line is not being used.

"CURL_STRING"
     For URL jobs, this is the string that's being checked against in the result of curl process. The format for this check is...

     egrep "$CURL_STRING" site_file.html

     So anything that would be interpreted as a regular expression by egrep WILL be interpreted as such.
     For DNS and ping jobs, this line is not being used.

"OUTPUT_FILE"
     The default for this value is "/dev/stdout", however rather than being output to the terminal where the master process is running, the output of a child process can be redirected to a file.

"USER_AGENT"
     For URL jobs, this is a true or false value that dictates whether or not the curl for the site will be run with curl as the user agent (false) or with a user agent that makes it look as if it's Google Chrome (true).
     For DNS and ping jobs, this line is not being used.

"CURL_TIMEOUT"
     For URL jobs, this is the amount of time before the curl process quits out and the check automatically fails.
     For DNS and ping jobs, this line is not being used.

"CUSTOM_MESSAGE"
     Anything here will be added as to email messages as a first paragraph. The string "\n" will be interpreted as a new line.

"VERBOSITY"
     Changes the verbosity level of the output of the child process. Standard: Outputs whether any specific check has succeeded or failed. Verbose: In addition to the information given from the standard output, also indicates how long checks for that job have been running, how many have been run, and the percentage of successful checks. Change: Only outputs text on the first failure after any number of successes, or the first success after any number of failures. None: outputs no text.
     NOTE: this overrides any verbosity setting in the main configuration file.

EOF
#'do
exit
}

function fn_version {
echo "Current Version: $v_VERSION"
cat << 'EOF' > /dev/stdout

Version Notes:
Future Versions -
     In URL jobs, should I compare the current pull to the previous pull? Compare file size? Monitor page load times?
     Command line flags that accept equal signs.

1.3.0 (2015-12-01) -
     A custom message can now be added to email messages using the "CUSTOM_MESSAGE" directive in the params file.
     When the master process recieves a "ctrl -c", the prompt now times out after 15 seconds.
     Replaced the old control files with a conf file.
     re-designed the params file as a conf-style file.
     The job type no longer has to be on the first line - it just has to be preceeded with "JOB_TYPE = ".
     Created functions to read from and write to conf files.
     More robust checks to make sure that the values pulled from the params files make sense.
     No more "none2" verbosity during the period where xmonitor is shutting down; handling this by touching a file instead.
     You can now set the number of html files that are kept.
     The e-mail only specifies the original server string if the server string has changed.
     The colors of output text can be modified using values within the configuration file.
     revised the interpretation of command line arguments so that they can be used with "=" rather than a space. I'll pretend that this makes things a little more posix compliant.
     Renamed all internal variables so that they start with "v_"

1.2.2 (2015-11-25) -
     When a child process begins outputting to a different location, that information is now logged.
     Added the "--outfile" flag so that the output file can be assigned on job declaration. Can be assigned through menus as well.
     The remote die list can also include the $IP_ADDRESS or $DOMAIN associated with the job. In these cases, it will kill the individual jobs rather than the master process.
     The remote die list can also contain in-line comments.
     When a process kill is triggered by the remote die list, the full line, including comments, is logged.
     "Xmonitor" is now included in the user agent, whether or not the chrome user agent is being used. Tested to verify that this works on my one test case (http://www.celebdirtylaundry.com/).
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

1.0.0 (2013-07-09) - 1.2.0 (2015-11-16) -
     Older revision informaion can be viewed here: http://www.sporks5000.com/scripts/xmonitor.sh.1.2.2

EOF
#'do
exit
}

###################
## END FUNCTIONS ##
###################

# Specify the working directory; create it if not present; specify the log file
v_PROGRAMDIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
v_PROGRAMDIR="$( echo "$v_PROGRAMDIR" | sed "s/\([^/]\)$/\1\//" )"
#"
v_WORKINGDIR="$v_PROGRAMDIR"".xmonitor/"
mkdir -p "$v_WORKINGDIR"

v_LOG="$v_PROGRAMDIR""xmonitor.log"

### find the newst version of curl
### /usr/bin/curl is the standard installation of curl
### /opt/curlssl/bin/curl is where cPanel keeps the version of curl that PHP works with, which is usually the most up to date
v_CURL_BIN=$( echo -e "$( /opt/curlssl/bin/curl --version 2> /dev/null | head -n1 | awk '{print $2}' ) /opt/curlssl/bin/curl\n$( /usr/bin/curl --version 2> /dev/null | head -n1 | awk '{print $2}' ) /usr/bin/curl\n$( $( which curl ) --version 2> /dev/null | head -n1 | awk '{print $2}' ) $( which curl )" | sort -n | grep "^[0-9]*\.[0-9]*.[0-9]*" | tail -n1 | awk '{print $2}' )
if [[ -z $v_CURL_BIN ]]; then
   echo "curl needs to be installed for xmonitor to perform some of its functions. Exiting."
   exit
fi
v_CURL_BIN_VERSION="$( $v_CURL_BIN --version 2> /dev/null | head -n1 | awk '{print $2}')"

### Make sure that bc, mail, ping, and dig are installed\
for i in bc mail dig ping; do
   if [[ -z $( which $i 2> /dev/null ) ]]; then
      echo "$i needs to be installed for xmonitor to perform some of its functions. Exiting."
      exit
   fi
done

### Determine the running state
if [[ -f "$v_WORKINGDIR"xmonitor.pid && $( ps aux | grep "$( cat "$v_WORKINGDIR"xmonitor.pid 2> /dev/null ).*xmonitor.sh" | grep -vc " 0:00 grep " ) -gt 0 ]]; then
   if [[ $PPID == $( cat "$v_WORKINGDIR"xmonitor.pid 2> /dev/null ) ]]; then
      ### Child processes monitor one thing only they are spawned only by the master process and when the master process is no longer present, they die.
      v_RUNNING_STATE="child"
      fn_child
   else
      ### Control processes set up the parameters for new child processes and then exit.
      v_RUNNING_STATE="control"
   fi
else
   ### The master process (which typically starts out functioning as a control process) waits to see if there are waiting jobs present in the "new/" directory, and then spawns child processes for them.
   v_RUNNING_STATE="master"
   ### Create some necessary configuration files and directories
   mkdir -p "$v_WORKINGDIR""new/"
   echo $$ > "$v_WORKINGDIR"xmonitor.pid
   if [[ -f "$v_WORKINGDIR"no_output ]]; then
      rm -f "$v_WORKINGDIR"no_output
   fi
fi

### More necessary configuration files.
if [[ ! -f "$v_WORKINGDIR"xmonitor.conf ]]; then
   fn_create_config
fi

### Turn the command line arguments into an array.
a_CL_ARGUMENTS=( "$@" )

### For each command line argument, determine what needs to be done.
for (( c=0; c<=$(( $# - 1 )); c++ )); do
   v_ARGUMENT="${a_CL_ARGUMENTS[$c]}"
   if [[ $( echo $v_ARGUMENT | egrep -c "^(--((url|dns|ping|verbosity|kill)(=.*)*|list|default|master|version|help|help-flags|help-process-types|help-params-file|modify)|[^-]*-[hmvpudl])$" ) -gt 0 ]]; then
      ### These flags indicate a specific action for the script to take. Two actinos cannot be taken at once.
      if [[ ! -z $v_RUN_TYPE ]]; then
         ### If another of these actions has already been specified, end.
         echo "Cannot use \"$v_RUN_TYPE\" and \"$v_ARGUMENT\" simultaneously. Exiting."
         exit
      fi
      v_RUN_TYPE=$( echo "$v_ARGUMENT" | cut -d "=" -f1 )
      if [[ $( echo ${a_CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^-" ) -eq 0 ]]; then
         if [[ $v_ARGUMENT == "--url" || $v_ARGUMENT == "-u" ]]; then
            c=$(( $c + 1 ))
            v_CURL_URL="${a_CL_ARGUMENTS[$c]}"
         elif [[ $v_ARGUMENT == "--dns" || $v_ARGUMENT == "-d" || $v_ARGUMENT == "--ping" || $v_ARGUMENT == "-p" ]]; then
            c=$(( $c + 1 ))
            v_DOMAIN="${a_CL_ARGUMENTS[$c]}"
         elif [[ $v_ARGUMENT == "--verbosity" || $v_ARGUMENT == "-v" ]]; then
            c=$(( $c + 1 ))
            v_VERBOSITY="${a_CL_ARGUMENTS[$c]}"
         elif [[ $v_ARGUMENT == "--kill" ]]; then
            c=$(( $c + 1 ))
            v_CHILD_PID="${a_CL_ARGUMENTS[$c]}"
         fi
      fi
      if [[ $( echo "$v_ARGUMENT" | egrep -c "^--url=" ) -eq 1 ]]; then
         v_CURL_URL="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
      elif [[ $( echo "$v_ARGUMENT" | egrep -c "^--(dns|ping)=" ) -eq 1 ]]; then
         v_DOMAIN="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
      elif [[ $( echo "$v_ARGUMENT" | egrep -c "^--verbosity=" ) -eq 1 ]]; then
         v_VERBOSITY="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
      elif [[ $( echo "$v_ARGUMENT" | egrep -c "^--kill=" ) -eq 1 ]]; then
         v_CHILD_PID="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
      fi
   ### All other flags modify or contribute to one of the above actions.
   elif [[ $v_ARGUMENT == "--control" ]]; then
      v_RUNNING_STATE="control"
   elif [[ $v_ARGUMENT == "--save" ]]; then
      v_SAVE_JOBS=true
   elif [[ $v_ARGUMENT == "--user-agent" ]]; then
      v_USER_AGENT=true
   elif [[ $v_ARGUMENT == "--mail" || $v_ARGUMENT == "--email" ]]; then
      if [[ $( echo ${a_CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^[^@][^@]*@[^.]*\..*$" ) -eq 1 ]]; then
         c=$(( $c + 1 ))
         v_EMAIL_ADDRESS="${a_CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--mail\" needs to be followed by an e-mail address. Exiting"
         exit
      fi
   elif [[ $( echo "$v_ARGUMENT" | egrep -c "^--(e)*mail=" ) -eq 1 ]]; then
      v_EMAIL_ADDRESS="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
   elif [[ $v_ARGUMENT == "--seconds" ]]; then
      if [[ $( echo ${a_CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^[[:digit:]][[:digit:]]*$" ) -eq 1 ]]; then
         c=$(( $c + 1 ))
         v_WAIT_SECONDS="${a_CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--seconds\" needs to be followed by a number of seconds. Exiting."
         exit
      fi
   elif [[ $( echo "$v_ARGUMENT" | egrep -c "^--seconds=" ) -eq 1 ]]; then
     v_WAIT_SECONDS="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
      if [[ -z $v_WAIT_SECONDS ]]; then
         echo "The flag \"--seconds\" needs to be followed by a number of seconds. Exiting."
         exit
      fi
   elif [[ $v_ARGUMENT == "--curl-timeout" ]]; then
      if [[ $( echo ${a_CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^[[:digit:]][[:digit:]]*$" ) -eq 1 ]]; then
         c=$(( $c + 1 ))
         v_CURL_TIMEOUT="${a_CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--curl-timeout\" needs to be followed by a number of seconds. Exiting."
         exit
      fi
   elif [[ $( echo "$v_ARGUMENT" | egrep -c "^--curl-timeout=" ) -eq 1 ]]; then
      v_WAIT_SECONDS="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
      if [[ -z $v_WAIT_SECONDS ]]; then
         echo "The flag \"--curl-timeout\" needs to be followed by a number of seconds. Exiting."
         exit
      fi
   elif [[ $v_ARGUMENT == "--mail-delay" ]]; then
      if [[ $( echo ${a_CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^[[:digit:]][[:digit:]]*$" ) -eq 1 ]]; then
         c=$(( $c + 1 ))
         v_MAIL_DELAY="${a_CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--mail-delay\" needs to be followed by a number. Exiting."
         exit
      fi
   elif [[ $( echo "$v_ARGUMENT" | egrep -c "^--mail-delay=" ) -eq 1 ]]; then
      v_MAIL_DELAY="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
      if [[ -z $v_MAIL_DELAY ]]; then
         echo "The flag \"--mail-delay\" needs to be followed by a number. Exiting."
         exit
      fi
   elif [[ $v_ARGUMENT == "--ip" || $v_ARGUMENT == "--ip-address" ]]; then
      if [[ $( echo ${a_CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^-" ) -eq 0 ]]; then
         ### Specifically don't check if the value here is actually an IP address - fn_parse_server will take care of that. 
         c=$(( $c + 1 ))
         v_IP_ADDRESS="${a_CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--ip\" needs to be followed by an IP address. Exiting."
         exit
      fi
   elif [[ $( echo "$v_ARGUMENT" | egrep -c "^--ip(-address)*=" ) -eq 1 ]]; then
      v_IP_ADDRESS="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
      if [[ -z $v_IP_ADDRESS ]]; then
         echo "The flag \"--ip\" needs to be followed by an IP address. Exiting."
         exit
      fi
   elif [[ $v_ARGUMENT == "--string" ]]; then
      if [[ $( echo ${a_CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^-" ) -eq 0 ]]; then
         c=$(( $c + 1 ))
         v_CURL_STRING="${a_CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--string\" needs to be followed by a string (in quotes, if it contains spaces) for which the contents of the URL will be searched. Exiting."
         exit
      fi
   elif [[ $( echo "$v_ARGUMENT" | egrep -c "^--string=" ) -eq 1 ]]; then
      v_CURL_STRING="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
      if [[ -z $v_CURL_STRING ]]; then
         echo "The flag \"--string\" needs to be followed by a string (in quotes, if it contains spaces) for which the contents of the URL will be searched. Exiting."
         exit
      fi
   elif [[ $v_ARGUMENT == "--domain" ]]; then
      if [[ $( echo ${a_CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^-" ) -eq 0 ]]; then
         c=$(( $c + 1 ))
         v_DNS_DOMAIN="${a_CL_ARGUMENTS[$c]}"
      else
         echo "The flag \"--domain\" needs to be followed by a domain name. Exiting."
         exit
      fi
   elif [[ $( echo "$v_ARGUMENT" | egrep -c "^--domain=" ) -eq 1 ]]; then
      v_DNS_DOMAIN="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
      if [[ -z $v_DNS_DOMAIN ]]; then
         echo "The flag \"--domain\" needs to be followed by a domain name. Exiting."
         exit
      fi
   elif [[ $v_ARGUMENT == "--outfile" ]]; then
      if [[ $( echo ${a_CL_ARGUMENTS[$(( $c + 1 ))]} | grep -c "^/" ) -eq 1 ]]; then
         c=$(( $c + 1 ))
         v_OUTPUT_FILE="${a_CL_ARGUMENTS[$c]}"
         touch "$v_OUTPUT_FILE" 2> /dev/null
         v_STATUS=$?
         if [[ ( ! -f "$v_OUTPUT_FILE" || ! -w "$v_OUTPUT_FILE" || $v_STATUS == 1 ) && "$v_OUTPUT_FILE" != "/dev/stdout" ]]; then
            echo "Please ensure that the --outfile file is already created, and has write permissions."
            exit
         fi
      else
         echo "The flag \"--outfile\" needs to be followed by a file referenced by its full path. Exiting."
         exit
      fi
   elif [[ $( echo "$v_ARGUMENT" | egrep -c "^--outfile=" ) -eq 1 ]]; then
      v_OUTPUT_FILE="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
      if [[ -z $v_OUTPUT_FILE ]]; then
         echo "The flag \"--outfile\" needs to be followed by a file referenced by its full path. Exiting."
         exit
      fi
      touch "$v_OUTPUT_FILE" 2> /dev/null
      v_STATUS=$?
      if [[ ( ! -f "$v_OUTPUT_FILE" || ! -w "$v_OUTPUT_FILE" || $v_STATUS == 1 ) && "$v_OUTPUT_FILE" != "/dev/stdout" ]]; then
         echo "Please ensure that the --outfile file is already created, and has write permissions."
         exit
      fi
   else
      if [[ $( echo "$v_ARGUMENT "| grep -c "^-" ) -eq 1 ]]; then
         echo "There is no such flag \"$v_ARGUMENT\". Exiting."
      else
         echo "I don't understand what flag the argument \"$v_ARGUMENT\" is supposed to be associated with. Exiting."
      fi
      exit
   fi
   v_NUM_ARGUMENTS=$(( $v_NUM_ARGUMENTS + 1 ))
done

### Some of these flags need to be used alone.
if [[ $v_RUN_TYPE == "--master" || $v_RUN_TYPE == "--verbosity" || $v_RUN_TYPE == "-v" || $v_RUN_TYPE == "--version" || $v_RUN_TYPE == "--help-flags" || $v_RUN_TYPE == "--help-process-types" || $v_RUN_TYPE == "--help-params-file" || $v_RUN_TYPE == "--help" || $v_RUN_TYPE == "--modify" || $v_RUN_TYPE == "-h" || $v_RUN_TYPE == "-m" ]]; then
   if [[ $v_NUM_ARGUMENTS -gt 1 ]]; then
      echo "The flag \"$v_RUN_TYPE\" cannot be used with other flags. Exiting."
      exit
   fi
fi
### Tells the script where to go with the type of job that was selected.
if [[ $v_RUN_TYPE == "--url" || $v_RUN_TYPE == "-u" ]]; then
   fn_get_defaults
   fn_url_cl
elif [[ $v_RUN_TYPE == "--ping" || $v_RUN_TYPE == "-p" ]]; then
   fn_get_defaults
   fn_ping_cl
elif [[ $v_RUN_TYPE == "--dns" || $v_RUN_TYPE == "-d" ]]; then
   fn_get_defaults
   fn_dns_cl
elif [[ $v_RUN_TYPE == "--kill" ]]; then
   if [[ ! -z $v_CHILD_PID ]]; then
      if [[ ! -f  "$v_WORKINGDIR"$v_CHILD_PID/params ]]; then
         echo "Child ID provided does not exist."
         exit
      fi
      touch "$v_WORKINGDIR"$v_CHILD_PID/die
      echo "The child process will exit shortly."
      exit   
   elif [[ $v_SAVE_JOBS == true ]]; then
      if [[ $v_NUM_ARGUMENTS -gt 2 ]]; then
         echo "The \"--kill\" flag can only used alone, with the \"--save\" flag, or in conjunction with the ID number of a child process. Exiting."
         exit
      fi
      touch "$v_WORKINGDIR"save
   else
      if [[ $v_NUM_ARGUMENTS -gt 1 ]]; then
         echo "The \"--kill\" flag can only used alone, with the \"--save\" flag, or in conjunction with the ID number of a child process. Exiting."
         exit
      fi
   fi
   touch "$v_WORKINGDIR"die
   exit
elif [[ $v_RUN_TYPE == "--verbosity" || $v_RUN_TYPE == "-v" ]]; then
   if [[ -z $v_VERBOSITY ]]; then
      fn_verbosity
   else
      fn_verbosity_assign
   fi
elif [[ $v_RUN_TYPE == "--version" ]]; then
   fn_version
   exit
elif [[ $v_RUN_TYPE == "--help" || $1 == "-h" ]]; then
   fn_help
   exit
elif [[ $v_RUN_TYPE == "--help-flags" ]]; then
   fn_help_flags
   exit
elif [[ $v_RUN_TYPE == "--help-process-types" ]]; then
   fn_help_process_types
   exit
elif [[ $v_RUN_TYPE == "--help-params-file" ]]; then
   fn_help_params_file
   exit
elif [[ $v_RUN_TYPE == "--modify" || $1 == "-m" ]]; then
   fn_modify
elif [[ $v_RUN_TYPE == "--list" || $1 == "-l" ]]; then
   fn_modify
elif [[ $v_RUN_TYPE == "--master" ]]; then
   fn_master
elif [[ $v_RUN_TYPE == "--default" ]]; then
   fn_set_defaults
elif [[ -z $v_RUN_TYPE ]]; then
   if [[ $v_NUM_ARGUMENTS -ne 0 ]]; then
      echo "Some of the flags you used didn't make sense in context. Here's a menu instead."
   fi
   fn_options
fi
