#! /bin/bash

v_VERSION="2.3.9"

#====================#
#== Default Values ==#
#====================#

function fn_set_defaults {
	v_DEFAULT_CURL_VERBOSE="true"
	v_DEFAULT_LOG_HTTP_CODE="true"
	v_DEFAULT_DNS_RECORD_TYPE="A"
	v_DEFAULT_CHECK_TIME_PARTIAL_SUCCESS="7"
	v_DEFAULT_CHECK_TIMEOUT="10"
	v_DEFAULT_WAIT_SECONDS="30"
	v_DEFAULT_MAIL_DELAY="2"
	v_DEFAULT_VERBOSITY="standard"
	v_DEFAULT_OUTPUT_FILE="/dev/stdout"
	v_DEFAULT_LOG_DURATION_DATA="true"
	v_DEFAULT_NUM_DURATIONS_RECENT="10"
	v_DEFAULT_NUM_STATUSES_RECENT="12"
	v_DEFAULT_NUM_STATUSES_NOT_SUCCESS="3"
	v_DEFAULT_HTML_FILES_KEPT="100"
	v_DEFAULT_USE_WGET="false"
	v_DEFAULT_USER_AGENT="false"
	v_DEFAULT_SERVER_PORT="22"
	v_DEFAULT_MIN_LOAD_PARTIAL_SUCCESS="4"
	v_DEFAULT_MIN_LOAD_FAILURE="8"
	v_DEFAULT_SSH_CONTROL_PATH="~/.ssh/control:%h:%p:%r"
	v_DEFAULT_REMOTE_DIE_LIST="http://lwmon.com/die_list.txt"
	v_DEFAULT_COLOR_SUCCESS=""
	v_DEFAULT_COLOR_FIRST_SUCCESS="\e[1;32m"
	v_DEFAULT_COLOR_FAILURE="\e[1;33m"
	v_DEFAULT_COLOR_FIRST_FAILURE="\e[1;31m"
	v_DEFAULT_COLOR_PARTIAL_SUCCESS="\e[1;34m"
	v_DEFAULT_COLOR_FIRST_PARTIAL_SUCCESS="\e[1;34m"
	v_DEFAULT_RETURN_SUCCESS=""
	v_DEFAULT_RETURN_FIRST_SUCCESS="\e[00m"
	v_DEFAULT_RETURN_FAILURE="\e[00m"
	v_DEFAULT_RETURN_FIRST_FAILURE="\e[00m"
	v_DEFAULT_RETURN_PARTIAL_SUCCESS="\e[00m"
	v_DEFAULT_RETURN_FIRST_PARTIAL_SUCCESS="\e[00m"
}

#================================#
#== Functions that create jobs ==#
#================================#

function fn_parse_server {
### This function assumes that $1 is a URL, Domain name, or IP address. It then parses those out into the variables $v_CURL_URLa, $v_DOMAINa, $v_IP_ADDRESSa, and $v_SERVER_PORTa.
	if [[ -z $1 || "$1" == "false" ]]; then
		unset v_SERVER
		v_CURL_URLa="false"
		v_DOMAINa="false"
		v_IP_ADDRESSa="false"
		v_SERVER_PORTa="false"
		return
	fi
	local v_PASSED="$1"
	if [[ -n $1 && -z $v_SERVER ]]; then
		v_SERVER="$1"
	fi
	if [[ $( echo "$v_SERVER" | grep -E -ci "^HTTP" ) -eq 0 ]]; then
	### If what's passed doesn't start with http or https, we can straight away assume that it's on port 80
		v_DOMAINa="$v_SERVER"
		v_CURL_URLa="$v_SERVER"
		v_SERVER_PORTa="80"
	else
		### For the domain, get rid of "http(s)" at the beginning
		v_DOMAINa="$( echo "$v_SERVER" | sed -e "s/^[Hh][Tt][Tt][Pp][Ss]*:\/\///" )"
		if [[ $( echo "$v_SERVER "| grep -E -ci "^HTTPS" ) -eq 1 ]]; then
		### If it starts with https, assume port 443 and don't strip out the protocol from the URL
			v_CURL_URLa="$v_SERVER"
			v_SERVER_PORTa="443"
		else
		### Otherwise assume port 80, and we don't need the protocol in the URL
			v_CURL_URLa="$( echo "$v_SERVER" | sed -e "s/^[Hh][Tt][Tt][Pp]:\/\///" )"
			v_SERVER_PORTa="80"
		fi
	fi
	unset v_SERVER
	### At this point in the script, we have the beginnings of a domain, a curl URL and a port
	### for the domain: get rid of the slash and anything else that follows the domain name
	v_DOMAINa="$( echo "$v_DOMAINa" | sed 's/^\([^/]*\).*$/\1/' )"
	v_DOMAINa="$( echo "$v_DOMAINa" | sed 's/[\xef\xbb\xbf]//g' )" ### <- Apparently billing is sometimes throwing special characters when you copy.
	### If the domain contains a closing square bracket followed by a colon, then numbers, then the end of the string, it's likely an ipv6 address with a port on the end
	if [[ $( echo "$v_DOMAINa" | grep -E -c "]:[0-9]+$" ) -ne 0 ]]; then
		v_SERVER_PORTa="$( echo "$v_DOMAINa" | sed "s/^.*]:\([0-9][0-9]*\)$/\1/" )"
		v_DOMAINa="$( echo "$v_DOMAINa" | sed "s/^\[*\(.*\)]:[0-9][0-9]*$/\1/" )"
	### Note: the regex here only covers IPv6 addresses.
	elif [[ $( echo "$v_DOMAINa" | grep -E -c ":[0-9]+$" ) -ne 0 && $( echo "$v_DOMAINa" | grep -E -c "^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$" ) -eq 0 ]]; then
	### If it doesn't match the above but it contains a colon, then numbers, then the end of the string, but is not a valid IPv6 address...
		v_SERVER_PORTa="$( echo "$v_DOMAINa" | sed "s/^.*:\([0-9][0-9]*\)$/\1/" )"
		v_DOMAINa="$( echo "$v_DOMAINa" | sed "s/^\(.*\):[0-9][0-9]*$/\1/" )"
	fi
	### check if it's an IP. The following should match all IPv4 and IPv6 addresses
	if [[ $( echo "$v_DOMAINa" | grep -E -c "^((([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))$" ) -eq 0 ]]; then
	### If it doesn't look like an IP address, let's find out what the IP address REALLY is
		### Let's start by checking the hosts file
		v_DOMAINa_EGREP_SAFE="$( echo "$v_DOMAINa" | sed 's/[]\.|$(){}?+*^]/\\&/g' )"
		if [[ $( sed "s/#.*$//" /etc/hosts | grep -E -c "[[:blank:]]$v_DOMAINa_EGREP_SAFE([[:blank:]]|$)" ) -gt 0 ]]; then
			v_IP_ADDRESSa="$( sed "s/#.*$//" /etc/hosts | grep -E "[[:blank:]]$v_DOMAINa_EGREP_SAFE([[:blank:]]|$)" | tail -n1 | awk '{print $1}' )"
		else
		### If it's not there, we'll dig for it.
			v_IP_ADDRESSa="$( dig +short "$v_DOMAINa" | sort -n | tail -n1 )"
		fi
		### If the result is empty, or doesn't match IPv4 or IPv6 addresses...
		if [[ -z "$v_IP_ADDRESSa" || $( echo "$v_IP_ADDRESSa" | grep -E -c "^((([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))$" ) -eq 0 ]]; then
			v_IP_ADDRESSa=false
		fi
	else
		v_IP_ADDRESSa="$v_DOMAINa"
	fi
	### If there was a port specified at the command line, let's use that.
	if [[ -n "$v_CL_PORT" ]]; then
		v_SERVER_PORTa="$v_CL_PORT"
	elif [[ "$v_RUN_TYPE" == "--ssh-load" ]]; then
		v_SERVER_PORTa="22"
	fi
	### The line below can be uncommented to test this function.
	# echo -e "PASSED:     $v_PASSED\nCURL_URL:   $v_CURL_URLa\nDOMAIN:     $v_DOMAINa\nIP_ADDRESS: $v_IP_ADDRESSa\nPORT:       $v_SERVER_PORTa\n"; exit
}

function fn_url_cl {
	### Verify that the correct information was given at the command line
	if [[ -z "$v_CURL_URL" || -z "${a_CURL_STRING[0]}" ]]; then
		echo "For url jobs, both the \"--url\" and \"--string\" flags require arguments."
		exit 1
	elif [[ $( echo -n "$v_DNS_CHECK_DOMAIN$v_DNS_CHECK_RESULT$v_DNS_RECORD_TYPE$v_SSH_USER$v_MIN_LOAD_PARTIAL_SUCCESS$v_MIN_LOAD_FAILURE$v_CL_PORT" | wc -c ) -gt 0 ]]; then
		echo "The only flags that can be used with url jobs are the following:"
		echo "--url, --string, --user-agent, --ip, --check-timeout, --ctps, --mail, --mail-delay, --outfile, --seconds, --verbosity, --wget, --ident, --job-name, --control, --ldd, --ndr, --nsns, --nds"
		exit 1
	fi
	### If there is an IP address, check to make sure that it's really an IP address, or can be translated into one.
	if [[ -n "$v_IP_ADDRESS" ]]; then
		fn_parse_server "$v_IP_ADDRESS"
		if [[ "$v_IP_ADDRESSa" == false ]]; then
			echo "The IP address provided with the \"--ip\" flag is not a valid IP address. Exiting."
			exit 1
		fi
		v_IP_ADDRESS="$v_IP_ADDRESSa"
	fi
	fn_parse_server "$v_CURL_URL"
	v_CURL_URL="$v_CURL_URLa"
	### If there isn't an IP address, we don't need to specify it in the job name.
	if [[ -z "$v_IP_ADDRESS" || "$v_IP_ADDRESS" == "false" ]]; then
		v_IP_ADDRESS=false
		v_ORIG_JOB_NAME="$v_CURL_URL"
	else
		v_ORIG_JOB_NAME="$v_CURL_URL at $v_IP_ADDRESS"
	fi 
	### Start inputting the values into the params file
	v_NEW_JOB="$( date +%s )""_$RANDOM.job"
	echo "JOB_TYPE = url" > "$v_WORKINGDIR""$v_NEW_JOB"

	echo "CURL_URL = $v_CURL_URL" >> "$v_WORKINGDIR""$v_NEW_JOB"
	i=0; while [[ $i -le $(( ${#a_CURL_STRING[@]} -1 )) ]]; do
		### The sed at the end of this line should make the string egrep safe (which is good, because egrepping with it is exactly what we're going to do).
		echo "CURL_STRING = ${a_CURL_STRING[$i]}" >> "$v_WORKINGDIR""$v_NEW_JOB"
		i=$(( $i + 1 ))
	done
	if [[ -z $v_USER_AGENT ]]; then
		echo "USER_AGENT = false" >> "$v_WORKINGDIR""$v_NEW_JOB"
	else
		echo "USER_AGENT = $v_USER_AGENT" >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi
	echo "IP_ADDRESS = $v_IP_ADDRESS" >> "$v_WORKINGDIR""$v_NEW_JOB"
	if [[ -n $v_USE_WGET ]]; then
		echo "USE_WGET = $v_USE_WGET" >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi
	if [[ $v_USE_WGET == "true" ]]; then
		v_CURL_VERBOSE="false"
		v_LOG_HTTP_CODE="false"
	else
		fn_read_conf CURL_VERBOSE master "$v_DEFAULT_CURL_VERBOSE"; v_CURL_VERBOSE="$v_RESULT"
		fn_read_conf LOG_HTTP_CODE master "$v_DEFAULT_LOG_HTTP_CODE"; v_LOG_HTTP_CODE="$v_RESULT"
	fi
	echo "#CURL_VERBOSE = $v_CURL_VERBOSE" >> "$v_WORKINGDIR""$v_NEW_JOB"
	echo "#LOG_HTTP_CODE = $v_LOG_HTTP_CODE" >> "$v_WORKINGDIR""$v_NEW_JOB"

	fn_mutual_cl
}

function fn_ping_cl {
	### Verify that the correct information was given at the command line
	if [[ -z "$v_DOMAIN" ]]; then
		echo "For ping jobs, the \"--ping\" flag requires an argument."
		exit 1
	elif [[ $( echo -n "$v_DNS_CHECK_DOMAIN$v_DNS_CHECK_RESULT$v_DNS_RECORD_TYPE$v_CURL_URL${a_CURL_STRING[0]}$v_USER_AGENT$v_CHECK_TIMEOUT$v_IP_ADDRESS$v_CHECK_TIME_PARTIAL_SUCCESS$v_SSH_USER$v_MIN_LOAD_PARTIAL_SUCCESS$v_MIN_LOAD_FAILURE$v_CL_PORT" | wc -c ) -gt 0 ]]; then
		echo "The only flags that can be used with ping jobs are the following:"
		echo "--ping, --mail, --mail-delay, --outfile, --seconds, --verbosity, --ident, --job-name, --control, --ldd, --ndr, --nsns, --nds"
		exit 1
	fi
	fn_parse_server "$v_DOMAIN"
	if [[ "$v_IP_ADDRESSa" == false ]]; then
		echo "Error: Domain $v_DOMAIN does not appear to resolve. Exiting."
		exit 1
	fi
	v_ORIG_JOB_NAME="$v_DOMAINa"
	v_DOMAIN=$v_DOMAINa
	v_NEW_JOB="$( date +%s )""_$RANDOM.job"
	echo "JOB_TYPE = ping" > "$v_WORKINGDIR""$v_NEW_JOB"

	fn_mutual_cl
}

function fn_dns_cl {
	### Verify that the correct information was given at the command line
	if [[ -z "$v_DOMAIN" || -z "$v_DNS_CHECK_DOMAIN" ]]; then
		echo "For dns jobs, both the \"--dns\" and \"--domain\" flags require arguments."
		exit 1
	elif [[ $( echo -n "$v_CURL_URL${a_CURL_STRING[0]}$v_USER_AGENT$v_CHECK_TIMEOUT$v_IP_ADDRESS$v_CHECK_TIME_PARTIAL_SUCCESS$v_SSH_USER$v_MIN_LOAD_PARTIAL_SUCCESS$v_MIN_LOAD_FAILURE$v_CL_PORT" | wc -c ) -gt 0 ]]; then
		echo "The only flags that can be used with dns jobs are the following:"
		echo "--dns, --domain, --check-result, --record-type, --mail, --mail-delay, --outfile, --seconds, --verbosity, --ident, --job-name, --control, --ldd, --ndr, --nsns, --nds"
		exit 1
	fi
	### Make sure that the domain resolves and is properly formatted
	fn_parse_server "$v_DOMAIN"
	if [[ "$v_IP_ADDRESSa" == false ]]; then
		echo "Error: Domain $v_DOMAIN does not appear to resolve. Exiting."
		exit 1
	fi
	v_DOMAIN="$v_DOMAINa"
	### Make sure that the domain we're digging is properly formatted as well
	fn_parse_server "$v_DNS_CHECK_DOMAIN"
	v_DNS_CHECK_DOMAIN="$v_DOMAINa"
	v_ORIG_JOB_NAME="$v_DNS_CHECK_DOMAIN @$v_DOMAIN"
	v_NEW_JOB="$( date +%s )""_$RANDOM.job"
	echo "JOB_TYPE = dns" > "$v_WORKINGDIR""$v_NEW_JOB"
	echo "DNS_CHECK_DOMAIN = $v_DNS_CHECK_DOMAIN" >> "$v_WORKINGDIR""$v_NEW_JOB"
	if [[ -n $v_DNS_CHECK_RESULT ]]; then
		echo "DNS_CHECK_RESULT = $v_DNS_CHECK_RESULT" >> "$v_WORKINGDIR""$v_NEW_JOB"
	else
		echo "#DNS_CHECK_RESULT = " >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi
	if [[ -n $v_DNS_RECORD_TYPE ]]; then
		echo "DNS_RECORD_TYPE = $v_DNS_RECORD_TYPE" >> "$v_WORKINGDIR""$v_NEW_JOB"
	else
		echo "#DNS_RECORD_TYPE = $v_DEFAULT_DNS_RECORD_TYPE" >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi

	fn_mutual_cl
}

function fn_load_cl {
	### Verify that the correct information was given at the command line
	### We're not going to check for the user here - we'll cover that below once we confirm that the job isn't for localhost
	if [[ -z "$v_DOMAIN" ]]; then
		echo "For ssh-load jobs, both the \"--ssh-load\" and \"--user\" flags require arguments."
		exit 1
	elif [[ $( echo -n "$v_DNS_CHECK_DOMAIN$v_DNS_CHECK_RESULT$v_DNS_RECORD_TYPE$v_CURL_URL${a_CURL_STRING[0]}$v_USER_AGENT$v_IP_ADDRESS" | wc -c ) -gt 0 ]]; then
		echo "The only flags that can be used with ssh-load jobs are the following:"
		echo "--ssh-load, --load-ps, --load-fail, --user, --port, --check-timeout, --ctps, --mail, --mail-delay, --outfile, --seconds, --verbosity, --ident, --job-name, --control, --ldd, --ndr, --nsns, --nds"
		exit 1
	fi
	fn_parse_server "$v_DOMAIN"
	if [[ "$v_IP_ADDRESSa" == false ]]; then
		echo "Error: Domain $v_DOMAIN does not appear to resolve. Exiting."
		exit 1
	elif [[ "$v_IP_ADDRESSa" != "127.0.0.1" && "$v_IP_ADDRESSa" != "::1" && -z "$v_SSH_USER" ]]; then
	### If it's not for localhost and there is no user, warn and exit.
		echo "For ssh-load jobs, both the \"--ssh-load\" and \"--user\" flags require arguments."
		exit 1
	fi
	v_ORIG_JOB_NAME="$v_DOMAINa"
	v_DOMAIN="$v_DOMAINa"
	if [[ -z "$v_CL_PORT" && "$v_SERVER_PORTa" == "22" ]]; then
		v_SERVER_PORT=22
	elif [[ -n $v_CL_PORT ]]; then
		v_SERVER_PORT="$v_CL_PORT"
	elif [[ $v_SERVER_PORT != "22" ]]; then
		v_SERVER_PORT="$v_SERVER_PORTa"
	fi
	fn_read_conf SSH_CONTROL_PATH master "$v_DEFAULT_SSH_CONTROL_PATH"; v_SSH_CONTROL_PATH="$v_RESULT"
	fn_test_file "$v_SSH_CONTROL_PATH" false false; v_SSH_CONTROL_PATH2="$v_RESULT"
	if [[ ! -e "$( echo "$v_SSH_CONTROL_PATH2" | sed "s/%h/$v_DOMAIN/;s/%p/$v_SERVER_PORT/;s/%r/$v_SSH_USER/" )" && "$v_IP_ADDRESSa" != "127.0.0.1" && "$v_IP_ADDRESSa" != "::1" ]]; then
		echo
		echo "There doesn't appear to be an SSH control socket open for this server. Use the following command to SSH into this server (you'll probably want to do this in another window, or a screen), and then try starting the job again:"
		echo
		echo "ssh -o ControlMaster=auto -o ControlPath=\"$v_SSH_CONTROL_PATH\" -p $v_SERVER_PORT $v_SSH_USER@$v_DOMAIN"
		echo
		echo "Be sure to exit out of the master ssh process when you're done monitoring the remote server."
		echo
		exit 1
	fi
	v_NEW_JOB="$( date +%s )""_$RANDOM.job"
	echo "JOB_TYPE = ssh-load" > "$v_WORKINGDIR""$v_NEW_JOB"
	echo "SERVER_PORT = $v_SERVER_PORT" >> "$v_WORKINGDIR""$v_NEW_JOB"
	echo "SSH_USER = $v_SSH_USER" >> "$v_WORKINGDIR""$v_NEW_JOB"
	echo "MIN_LOAD_PARTIAL_SUCCESS = $v_MIN_LOAD_PARTIAL_SUCCESS" >> "$v_WORKINGDIR""$v_NEW_JOB"
	echo "MIN_LOAD_FAILURE = $v_MIN_LOAD_FAILURE" >> "$v_WORKINGDIR""$v_NEW_JOB"

	fn_mutual_cl
}

function fn_mutual_cl {
	if [[ -n "$v_IDENT" ]]; then
		v_ORIG_JOB_NAME="$v_ORIG_JOB_NAME $v_IDENT"
	fi
	if [[ -z "$v_JOB_NAME" ]]; then
		v_JOB_NAME="$v_ORIG_JOB_NAME"
	fi
	echo "JOB_NAME = $v_JOB_NAME" >> "$v_WORKINGDIR""$v_NEW_JOB"
	echo "ORIG_JOB_NAME = $v_ORIG_JOB_NAME" >> "$v_WORKINGDIR""$v_NEW_JOB"
	if [[ "$v_RUN_TYPE" == "--url" || "$v_RUN_TYPE" == "-u" || "$v_RUN_TYPE" == "--ssh-load" ]]; then
		if [[ -z "$v_CHECK_TIME_PARTIAL_SUCCESS" ]]; then
			fn_read_conf CHECK_TIME_PARTIAL_SUCCESS master; v_CHECK_TIME_PARTIAL_SUCCESS="$v_RESULT"
			fn_test_variable "$v_CHECK_TIME_PARTIAL_SUCCESS" true "false" "$v_DEFAULT_CHECK_TIME_PARTIAL_SUCCESS"; v_CHECK_TIME_PARTIAL_SUCCESS="$v_RESULT"
			echo "#CHECK_TIME_PARTIAL_SUCCESS = $v_CHECK_TIME_PARTIAL_SUCCESS" >> "$v_WORKINGDIR""$v_NEW_JOB"
		else
			echo "CHECK_TIME_PARTIAL_SUCCESS = $v_CHECK_TIME_PARTIAL_SUCCESS" >> "$v_WORKINGDIR""$v_NEW_JOB"
		fi
		if [[ -z "$v_CHECK_TIMEOUT" ]]; then
			fn_read_conf CHECK_TIMEOUT master; v_CHECK_TIMEOUT="$v_RESULT"
			fn_test_variable "$v_CHECK_TIMEOUT" true "false" "$v_DEFAULT_CHECK_TIMEOUT"; v_CHECK_TIMEOUT="$v_RESULT"
			echo "#CHECK_TIMEOUT = $v_CHECK_TIMEOUT" >> "$v_WORKINGDIR""$v_NEW_JOB"
		else
			echo "CHECK_TIMEOUT = $v_CHECK_TIMEOUT" >> "$v_WORKINGDIR""$v_NEW_JOB"
		fi
	fi
	if [[ "$v_RUN_TYPE" == "--ping" || "$v_RUN_TYPE" == "--dns" || "$v_RUN_TYPE" == "-p" || "$v_RUN_TYPE" == "-d" || "$v_RUN_TYPE" == "--ssh-load" ]]; then
		echo "DOMAIN = $v_DOMAIN" >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi
	if [[ -z "$v_WAIT_SECONDS" ]]; then
		fn_read_conf WAIT_SECONDS master; v_WAIT_SECONDS="$v_RESULT"
		fn_test_variable "$v_WAIT_SECONDS" true "false" "$v_DEFAULT_WAIT_SECONDS"; v_WAIT_SECONDS="$v_RESULT"
		echo "#WAIT_SECONDS = $v_WAIT_SECONDS" >> "$v_WORKINGDIR""$v_NEW_JOB"
	else
		echo "WAIT_SECONDS = $v_WAIT_SECONDS" >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi
	if [[ -z "$v_EMAIL_ADDRESS" ]]; then
		fn_read_conf EMAIL_ADDRESS master ""; v_EMAIL_ADDRESS="$v_RESULT"
		echo "#EMAIL_ADDRESS = $v_EMAIL_ADDRESS" >> "$v_WORKINGDIR""$v_NEW_JOB"
	else
		echo "EMAIL_ADDRESS = $v_EMAIL_ADDRESS" >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi
	if [[ -z "$v_MAIL_DELAY" ]]; then
		fn_read_conf MAIL_DELAY master; v_MAIL_DELAY="$v_RESULT"
		fn_test_variable "$v_MAIL_DELAY" true "false" "$v_DEFAULT_MAIL_DELAY"; v_MAIL_DELAY="$v_RESULT"
		echo "#MAIL_DELAY = $v_MAIL_DELAY" >> "$v_WORKINGDIR""$v_NEW_JOB"
	else
		echo "MAIL_DELAY = $v_MAIL_DELAY" >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi
	if [[ -z "$v_VERBOSITY" ]]; then
		fn_read_conf VERBOSITY master "$v_DEFAULT_VERBOSITY"; v_VERBOSITY="$v_RESULT"
		echo "#VERBOSITY = $v_VERBOSITY" >> "$v_WORKINGDIR""$v_NEW_JOB"
	else
		echo "VERBOSITY = $v_VERBOSITY" >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi
	if [[ -z "$v_OUTPUT_FILE" ]]; then
		fn_read_conf OUTPUT_FILE master "$v_DEFAULT_OUTPUT_FILE"; v_OUTPUT_FILE2="$v_RESULT"
		echo "#OUTPUT_FILE = $v_OUTPUT_FILE2" >> "$v_WORKINGDIR""$v_NEW_JOB"
	else
		echo "OUTPUT_FILE = $v_OUTPUT_FILE" >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi
	fn_read_conf CUSTOM_MESSAGE master ""; v_CUSTOM_MESSAGE="$v_RESULT"
	echo "#CUSTOM_MESSAGE = $v_CUSTOM_MESSAGE" >> "$v_WORKINGDIR""$v_NEW_JOB"
	if [[ -z $v_LOG_DURATION_DATA ]]; then
		fn_read_conf LOG_DURATION_DATA master "$v_DEFAULT_LOG_DURATION_DATA"; v_LOG_DURATION_DATA="$v_RESULT"
		echo "#LOG_DURATION_DATA = $v_LOG_DURATION_DATA" >> "$v_WORKINGDIR""$v_NEW_JOB"
	else
		echo "LOG_DURATION_DATA = $v_LOG_DURATION_DATA" >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi
	if [[ -z "$v_NUM_DURATIONS_RECENT" ]]; then
		fn_read_conf NUM_DURATIONS_RECENT master; v_NUM_DURATIONS_RECENT="$v_RESULT"
		fn_test_variable "$v_NUM_DURATIONS_RECENT" true "false" "$v_DEFAULT_NUM_DURATIONS_RECENT"; v_NUM_DURATIONS_RECENT="$v_RESULT"
		echo "#NUM_DURATIONS_RECENT = $v_NUM_DURATIONS_RECENT" >> "$v_WORKINGDIR""$v_NEW_JOB"
	else
		echo "NUM_DURATIONS_RECENT = $v_NUM_DURATIONS_RECENT" >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi
	if [[ -z "$v_NUM_STATUSES_RECENT" ]]; then
		fn_read_conf NUM_STATUSES_RECENT master; v_NUM_STATUSES_RECENT="$v_RESULT"
		fn_test_variable "$v_NUM_STATUSES_RECENT" true "false" "$v_DEFAULT_NUM_STATUSES_RECENT"; v_NUM_STATUSES_RECENT="$v_RESULT"
		echo "#NUM_STATUSES_RECENT = $v_NUM_STATUSES_RECENT" >> "$v_WORKINGDIR""$v_NEW_JOB"
	else
		echo "NUM_STATUSES_RECENT = $v_NUM_STATUSES_RECENT" >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi
	if [[ -z "$v_NUM_STATUSES_NOT_SUCCESS" ]]; then
		fn_read_conf NUM_STATUSES_NOT_SUCCESS master; v_NUM_STATUSES_NOT_SUCCESS="$v_RESULT"
		fn_test_variable "$v_NUM_STATUSES_NOT_SUCCESS" true "false" "$v_DEFAULT_NUM_STATUSES_NOT_SUCCESS"; v_NUM_STATUSES_NOT_SUCCESS="$v_RESULT"
		echo "#NUM_STATUSES_NOT_SUCCESS = $v_NUM_STATUSES_NOT_SUCCESS" >> "$v_WORKINGDIR""$v_NEW_JOB"
	else
		echo "NUM_STATUSES_NOT_SUCCESS = $v_NUM_STATUSES_NOT_SUCCESS" >> "$v_WORKINGDIR""$v_NEW_JOB"
	fi
	echo "#SCRIPT = " >> "$v_WORKINGDIR""$v_NEW_JOB"
	mv -f "$v_WORKINGDIR""$v_NEW_JOB" "$v_WORKINGDIR""new/$v_NEW_JOB"
	### If this instance is running as master, go on to begin spawning child processes, etc.
	if [[ "$v_RUNNING_STATE" == "master" ]]; then
		fn_master
	else
		### Rebuild the child script if necesasary
		if [[ $v_TESTING == true ]]; then
			fn_create_mini_script
		fi
		exit 0
	fi
}

#=====================#
#== Child Functions ==#
#=====================#

function fn_child {
	### The opening part of a child process!
	### Wait to make sure that the params file is in place.
	sleep 1
	### Make sure that the child processes are not exited out of o'er hastily.
	trap fn_child_exit SIGINT SIGTERM SIGKILL
	### Define the variables that will be used over the life of the child process
	v_CHILD_PID=$$
	if [[ ! -f "$v_WORKINGDIR"lwmon.pid ]]; then 
		echo ""$( date +%F":"%T" "%Z )" - [$v_CHILD_PID] - No Master Process present. Exiting." >> "$v_LOG"
		exit 1
	fi
	v_MASTER_PID=$( cat "$v_WORKINGDIR"lwmon.pid )
	v_START_TIME=$( date +%s )
	v_TOTAL_DURATIONS=0
	v_AVERAGE_DURATION=0
	v_TOTAL_SUCCESS_DURATIONS=0
	v_AVERAGE_SUCCESS_DURATION=0
	v_TOTAL_SUCCESSES=0
	v_TOTAL_PARTIAL_SUCCESSES=0
	v_TOTAL_FAILURES=0
	v_NUM_SUCCESSES_EMAIL=0
	v_NUM_PARTIAL_SUCCESSES_EMAIL=0
	v_NUM_FAILURES_EMAIL=0
	v_LAST_HTML_RESPONSE_CODE="none"
	if [[ $( grep -E -c "^[[:blank:]]*JOB_TYPE[[:blank:]]*=" "$v_WORKINGDIR""$v_CHILD_PID""/params" ) -eq 1 ]]; then
		fn_read_conf JOB_TYPE child; v_JOB_TYPE="$v_RESULT"
		v_JOB_CL_STRINGa="--$v_JOB_TYPE"
		fn_read_conf ORIG_JOB_NAME child; v_ORIG_JOB_NAME="$v_RESULT"
		fn_child_vars
		if [[ $v_JOB_TYPE == "url" ]]; then
			fn_url_child
		elif [[ $v_JOB_TYPE == "ping" ]]; then
			fn_ping_child
		elif [[ $v_JOB_TYPE == "dns" ]]; then
			fn_dns_child
		elif [[ $v_JOB_TYPE == "ssh-load" ]]; then
			fn_load_child
		else
			echo "$( date +%F" "%T" "%Z ) - [$v_CHILD_PID] - Job type is unexpected. Exiting." >> "$v_LOG"
			fn_child_exit 1
		fi
	else
		echo "$( date +%F" "%T" "%Z ) - [$v_CHILD_PID] - No job type, or more than one job type present. Exiting." >> "$v_LOG"
		fn_child_exit 1
	fi
}

function fn_child_vars {
	### Pull the necessary variables for the child process from the params file.
	### This function is run at the beginning of a child process, as well as each time the mtime of the params file increases.
	v_PARAMS_RELOAD="$( stat --format=%Y "$v_WORKINGDIR""$v_CHILD_PID/params" )" #"
	v_MASTER_RELOAD="$( stat --format=%Y "$v_WORKINGDIR""lwmon.conf" )" #"
	fn_check_mail_binary
	### Check the conf to see how many copies of the html files to keep. This won't technicially be a variable in the params file, but why not allow it to be if the user desires - Almost certainly this will default to the master value.
	fn_read_conf HTML_FILES_KEPT child; v_HTML_FILES_KEPT="$v_RESULT"
	fn_test_variable "$v_HTML_FILES_KEPT" true HTML_FILES_KEPT "$v_DEFAULT_HTML_FILES_KEPT"; v_HTML_FILES_KEPT="$v_RESULT"
	### If it's one of the job types that has a domain in the conf file, find the domain; else find the curl URL
	if [[ "$v_JOB_TYPE" == "ping" || "$v_JOB_TYPE" == "dns" || "$v_JOB_TYPE" == "ssh-load" ]]; then
		fn_read_conf DOMAIN child; v_DOMAIN="$v_RESULT"
		fn_parse_server "$v_DOMAIN"; v_DOMAIN="$v_DOMAINa"
		v_JOB_CL_STRING="$v_JOB_CL_STRINGa $v_DOMAIN"
		if [[ "$v_JOB_TYPE" == "ssh-load" && ( "$v_IP_ADDRESSa" == "127.0.0.1" || $v_IP_ADDRESSa == "::1" ) ]]; then
			v_DOMAIN="$v_IP_ADDRESSa"
		fi
	elif [[ "$v_JOB_TYPE" == "url" ]]; then
		fn_read_conf CURL_URL child; v_CURL_URL="$v_RESULT"
		fn_parse_server "$v_CURL_URL"
		v_CURL_URL="$v_CURL_URLa"
		v_DOMAIN="$v_DOMAINa"
		v_SERVER_PORT="$v_SERVER_PORTa"
		v_JOB_CL_STRING="$v_JOB_CL_STRINGa \"$v_CURL_URL\""
	fi
	### Directives
	fn_read_conf WAIT_SECONDS child; v_WAIT_SECONDS="$v_RESULT"
	fn_test_variable "$v_WAIT_SECONDS" true WAIT_SECONDS "$v_DEFAULT_WAIT_SECONDS"; v_WAIT_SECONDS="$v_RESULT"
	fn_read_conf EMAIL_ADDRESS child; v_EMAIL_ADDRESS="$v_RESULT"
	fn_test_variable "$v_EMAIL_ADDRESS" false EMAIL_ADDRESS ""; v_EMAIL_ADDRESS="$v_RESULT"
	if [[ $( echo "$v_EMAIL_ADDRESS" | grep -E -c "^[^@]+@[^.@]+\.[^@]+$" ) -eq 0 ]]; then
		v_EMAIL_ADDRESS=""
	fi
	fn_read_conf MAIL_DELAY child; v_MAIL_DELAY="$v_RESULT"
	fn_test_variable "$v_MAIL_DELAY" true MAIL_DELAY "$v_DEFAULT_MAIL_DELAY"; v_MAIL_DELAY="$v_RESULT"
	### Figure out where the verbosity is set
	fn_read_conf VERBOSITY child; v_VERBOSITY="$v_RESULT"
	fn_test_variable "$v_VERBOSITY" false VERBOSITY "$v_DEFAULT_VERBOSITY"; v_VERBOSITY="$v_RESULT"
	if [[ $( echo "$v_VERBOSITY" | grep -E -c "^(standard|none|more verbose|verbose|change)$" ) -eq 0 ]]; then
		v_VERBOSITY="standard"
	fi
	fn_read_conf JOB_NAME child; v_JOB_NAME="$v_RESULT"
	fn_read_conf CUSTOM_MESSAGE child; v_CUSTOM_MESSAGE="$v_RESULT"
	fn_test_variable "$v_CUSTOM_MESSAGE" false CUSTOM_MESSAGE ""; v_CUSTOM_MESSAGE="$v_RESULT"
	fn_read_conf LOG_DURATION_DATA child; v_LOG_DURATION_DATA="$v_RESULT"
	fn_test_variable "$v_LOG_DURATION_DATA" false LOG_DURATION_DATA "$v_DEFAULT_LOG_DURATION_DATA"; v_LOG_DURATION_DATA="$v_RESULT"
	fn_read_conf NUM_DURATIONS_RECENT child; v_NUM_DURATIONS_RECENT="$v_RESULT"
	fn_test_variable "$v_NUM_DURATIONS_RECENT" true NUM_DURATIONS_RECENT "$v_DEFAULT_NUM_DURATIONS_RECENT"; v_NUM_DURATIONS_RECENT="$v_RESULT"
	fn_read_conf NUM_STATUSES_RECENT child; v_NUM_STATUSES_RECENT="$v_RESULT"
	fn_test_variable "$v_NUM_STATUSES_RECENT" true NUM_STATUSES_RECENT "$v_DEFAULT_NUM_STATUSES_RECENT"; v_NUM_STATUSES_RECENT="$v_RESULT"
	fn_read_conf NUM_STATUSES_NOT_SUCCESS child; v_NUM_STATUSES_NOT_SUCCESS="$v_RESULT"
	fn_test_variable "$v_NUM_STATUSES_NOT_SUCCESS" true NUM_STATUSES_NOT_SUCCESS "$v_DEFAULT_NUM_STATUSES_NOT_SUCCESS"; v_NUM_STATUSES_NOT_SUCCESS="$v_RESULT"
	### If there's no output file, set it as standard out, then test to see where the output file is. IF it's different than what it was previously, log it.
	if [[ -z $v_OUTPUT_FILE ]]; then
		v_OUTPUT_FILE="/dev/stdout"
	fi
	fn_read_conf OUTPUT_FILE child; v_OUTPUT_FILE2="$v_RESULT"
	fn_test_variable "$v_OUTPUT_FILE2" false OUTPUT_FILE "$v_DEFAULT_OUTPUT_FILE"; v_OUTPUT_FILE2="$v_RESULT"
	fn_test_file "$v_OUTPUT_FILE2" false true; v_OUTPUT_FILE2="$v_RESULT"
	a_SCRIPT=()
	fn_read_conf SCRIPT child; v_SCRIPT="$v_RESULT"
	for word in $( echo $v_SCRIPT ); do
		a_SCRIPT[${#a_SCRIPT[@]}]="$word"
	done
	unset v_SCRIPT
	if [[ ${a_SCRIPT[0]:0:1} != "/" ]]; then
		unset a_SCRIPT
	fi
	### If the designated output file looks good, and is different than it was previously, log it.
	if [[ -n "$v_OUTPUT_FILE2" && "$v_OUTPUT_FILE2" != "$v_OUTPUT_FILE" ]]; then
		echo "$( date +%F" "%T" "%Z ) - [$v_CHILD_PID] - Output for child process $v_CHILD_PID is being directed to $v_OUTPUT_FILE2" >> "$v_LOG"
		v_OUTPUT_FILE="$v_OUTPUT_FILE2"
	elif [[ -z "$v_OUTPUT_FILE2" && -z "$v_OUTPUT_FILE" ]]; then
		### If there is no designated output file, and there was none previously, stdout will be fine.
		v_OUTPUT_FILE="/dev/stdout"
	fi
	if [[ "$v_JOB_TYPE" == "ping" ]]; then
		if [[ $( echo $v_WAIT_SECONDS | cut -d "." -f1 ) -lt 2 ]]; then
			v_WAIT_SECONDS=2
		fi
	else
		if [[ $( echo $v_WAIT_SECONDS | cut -d "." -f1 ) -lt 5 ]]; then
			v_WAIT_SECONDS=5
		fi
	fi
	if [[ "$v_JOB_TYPE" == "url" || "$v_JOB_TYPE" == "ssh-load" ]]; then
		fn_read_conf CHECK_TIMEOUT child; v_CHECK_TIMEOUT="$v_RESULT"
		fn_test_variable "$v_CHECK_TIMEOUT" true CHECK_TIMEOUT "$v_DEFAULT_CHECK_TIMEOUT"; v_CHECK_TIMEOUT="$v_RESULT"
		fn_read_conf CHECK_TIME_PARTIAL_SUCCESS child; v_CHECK_TIME_PARTIAL_SUCCESS="$v_RESULT"
		fn_test_variable "$v_CHECK_TIME_PARTIAL_SUCCESS" true CHECK_TIME_PARTIAL_SUCCESS "$v_DEFAULT_CHECK_TIME_PARTIAL_SUCCESS"; v_CHECK_TIME_PARTIAL_SUCCESS="$v_RESULT"
		v_JOB_CL_STRING="$v_JOB_CL_STRING --check-timeout $v_CHECK_TIMEOUT --ctps $v_CHECK_TIME_PARTIAL_SUCCESS"
		v_CHECK_TIME_PARTIAL_SUCCESS="$( awk "BEGIN {printf \"%.0f\",${v_CHECK_TIME_PARTIAL_SUCCESS} * 100}" )"
	fi
	if [[ $v_JOB_TYPE == "url" ]]; then
		fn_read_conf IP_ADDRESS child; v_IP_ADDRESS="$v_RESULT"
		fn_parse_server "$v_IP_ADDRESS"; v_IP_ADDRESS="$v_IP_ADDRESSa"
		if [[ "$v_IP_ADDRESS" != "false" ]]; then
			v_JOB_CL_STRING="$v_JOB_CL_STRING --ip $v_IP_ADDRESS"
		fi
		fn_read_conf CURL_STRING child "" "multi" ; a_CURL_STRING=("${a_RESULT[@]}")
		i=0; while [[ $i -lt ${#a_CURL_STRING[@]} ]]; do
			v_JOB_CL_STRING="$v_JOB_CL_STRING --string \"${a_CURL_STRING[$i]}\""
			i=$(( $i + 1 ))
		done
		fn_read_conf USE_WGET child; v_USE_WGET="$v_RESULT"
		fn_test_variable "$v_USE_WGET" false USE_WGET "$v_DEFAULT_USE_WGET"; v_USE_WGET="$v_RESULT"
		if [[ $v_USE_WGET == "true" ]]; then
			fn_use_wget
			v_CURL_VERBOSE="false"
			v_LOG_HTTP_CODE="false"
		else
			fn_read_conf CURL_VERBOSE child; v_CURL_VERBOSE="$v_RESULT"
			fn_test_variable "$v_CURL_VERBOSE" false CURL_VERBOSE "$v_DEFAULT_CURL_VERBOSE"; v_CURL_VERBOSE="$v_RESULT"
			fn_read_conf LOG_HTTP_CODE child; v_LOG_HTTP_CODE="$v_RESULT"
			fn_test_variable "$v_LOG_HTTP_CODE" false LOG_HTTP_CODE "$v_DEFAULT_LOG_HTTP_CODE"; v_LOG_HTTP_CODE="$v_RESULT"
		fi
		fn_read_conf USER_AGENT child; v_USER_AGENT="$v_RESULT"
		fn_test_variable "$v_USER_AGENT" false USER_AGENT "$v_DEFAULT_USER_AGENT"; v_USER_AGENT="$v_RESULT"
		### If there's an IP address, then the URL needs to have the domain replaced with the IP address and the port number.
		if [[ $v_IP_ADDRESS != "false" && $( echo $v_CURL_URL | grep -E -c "^(https?://)?$v_DOMAIN:[0-9]+" ) -eq 1 ]]; then
			### If it's specified with a port in the URL, lets make sure that it's the right port (according to the params file).
			v_CURL_URL="$( echo $v_CURL_URL | sed "s/$v_DOMAIN:[0-9][0-9]*/$v_IP_ADDRESS:$v_SERVER_PORT/" )" #"
		elif [[ $v_IP_ADDRESS != "false" ]]; then
			### If it's not specified with the port in the URL, lets add the port.
			v_CURL_URL="$( echo $v_CURL_URL | sed "s/$v_DOMAIN/$v_IP_ADDRESS:$v_SERVER_PORT/" )" #"
		else
			### If there's no IP address, lets throw the port on there as well.
			v_CURL_URL="$( echo $v_CURL_URL | sed "s/$v_DOMAIN:*[0-9]*/$v_DOMAIN:$v_SERVER_PORT/" )" #"
		fi
		if [[ $v_USER_AGENT == true ]]; then
			v_JOB_CL_STRING="$v_JOB_CL_STRING --user-agent"
			v_USER_AGENT='Mozilla/5.0 (X11; Linux x86_64) LWmon/'"$v_VERSION"' AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36'
		elif [[ $v_USER_AGENT == false && $v_WGET_BIN == "false" ]]; then
			v_JOB_CL_STRING="$v_JOB_CL_STRING --user-agent false"
			v_USER_AGENT='LWmon/'"$v_VERSION"' curl/'"$v_CURL_BIN_VERSION"
		elif [[ $v_USER_AGENT == false && $v_WGET_BIN != "false" ]]; then
			v_JOB_CL_STRING="$v_JOB_CL_STRING --user-agent false"
			v_USER_AGENT='LWmon/'"$v_VERSION"' wget/'"$v_WGET_BIN_VERSION"
		fi
	fi
	if [[ $v_JOB_TYPE == "ssh-load" ]]; then
		fn_read_conf SERVER_PORT child; v_SERVER_PORT="$v_RESULT"
		fn_test_variable "$v_SERVER_PORT" true false "$v_DEFAULT_SERVER_PORT"; v_SERVER_PORT="$v_RESULT"
		fn_read_conf MIN_LOAD_PARTIAL_SUCCESS child; v_MIN_LOAD_PARTIAL_SUCCESS="$v_RESULT"
		fn_test_variable "$v_MIN_LOAD_PARTIAL_SUCCESS" true false "$v_DEFAULT_MIN_LOAD_PARTIAL_SUCCESS"; v_MIN_LOAD_PARTIAL_SUCCESS="$v_RESULT"
		fn_read_conf MIN_LOAD_FAILURE child; v_MIN_LOAD_FAILURE="$v_RESULT"
		fn_test_variable "$v_MIN_LOAD_FAILURE" true false "$v_DEFAULT_MIN_LOAD_FAILURE"; v_MIN_LOAD_FAILURE="$v_RESULT"
		fn_read_conf SSH_USER child; v_SSH_USER="$v_RESULT"
		v_JOB_CL_STRING="$v_JOB_CL_STRING --port $v_SERVER_PORT --load-ps $v_MIN_LOAD_PARTIAL_SUCCESS --load-fail $v_MIN_LOAD_FAILURE --user $v_SSH_USER"
		v_MIN_LOAD_PARTIAL_SUCCESS="$( awk "BEGIN {printf \"%.0f\",${v_MIN_LOAD_PARTIAL_SUCCESS} * 100}" )"
		v_MIN_LOAD_FAILURE="$( awk "BEGIN {printf \"%.0f\",${v_MIN_LOAD_FAILURE} * 100}" )"
		fn_read_conf SSH_CONTROL_PATH child; v_SSH_CONTROL_PATH="$v_RESULT"
		fn_test_variable "$v_SSH_CONTROL_PATH" false SSH_CONTROL_PATH "$v_DEFAULT_SSH_CONTROL_PATH"; v_SSH_CONTROL_PATH="$v_RESULT"
		fn_test_file "$v_SSH_CONTROL_PATH" false false; v_SSH_CONTROL_PATH="$v_RESULT"
	fi
	if [[ $v_JOB_TYPE == "dns" ]]; then
		fn_read_conf DNS_CHECK_DOMAIN child; v_DNS_CHECK_DOMAIN="$v_RESULT"
		fn_parse_server "$v_DNS_CHECK_DOMAIN"; v_DNS_CHECK_DOMAIN="$v_DOMAINa"
		fn_read_conf DNS_CHECK_RESULT child; v_DNS_CHECK_RESULT="$v_RESULT"
		fn_read_conf DNS_RECORD_TYPE child; v_DNS_RECORD_TYPE="$v_RESULT"
		v_JOB_CL_STRING="$v_JOB_CL_STRING --check-domain $v_DNS_CHECK_DOMAIN"
		if [[ -n $v_DNS_CHECK_RESULT ]]; then
			v_JOB_CL_STRING="$v_JOB_CL_STRING --check-result \"$v_DNS_CHECK_RESULT\""
		fi
		if [[ -n $v_DNS_RECORD_TYPE ]]; then
			v_JOB_CL_STRING="$v_JOB_CL_STRING --record-type $v_DNS_RECORD_TYPE"
		fi
	fi
	v_JOB_CL_STRING="$v_JOB_CL_STRING --mail-delay $v_MAIL_DELAY --verbosity \"$v_VERBOSITY\" --outfile \"$v_OUTPUT_FILE\" --seconds $v_WAIT_SECONDS --ldd $v_LOG_DURATION_DATA --ndr $v_NUM_DURATIONS_RECENT --nsns $v_NUM_STATUSES_NOT_SUCCESS --nsr $v_NUM_STATUSES_RECENT --job-name \"$v_JOB_NAME\""
	echo "$v_JOB_CL_STRING" > "$v_WORKINGDIR""$v_CHILD_PID"/cl
}

### Here's an example to test the logic being used for port numbers:
### v_CURL_URL="https://sporks5000.com:4670/index.php"; v_DOMAIN="sporks5000.com"; v_SERVER_PORT=8080; v_IP_ADDRESS="10.30.6.88"; if [[ $( echo $v_CURL_URL | grep -E -c "^(http://|https://)*$v_DOMAIN:[0-9][0-9]*" ) -eq 1 ]]; then echo "curl $v_CURL_URL --header 'Host: $v_DOMAIN'" | sed "s/$v_DOMAIN:[0-9][0-9]*/$v_IP_ADDRESS:$v_SERVER_PORT/"; else echo "curl $v_CURL_URL --header 'Host: $v_DOMAIN'" | sed "s/$v_DOMAIN/$v_IP_ADDRESS:$v_SERVER_PORT/"; fi

function fn_child_dates {
	v_DATE3_LAST="$v_DATE3"
	v_DATE="$( date +%m"/"%d" "%H":"%M":"%S )"
	v_DATE2="$( date +%F" "%T" "%Z )"
	v_DATE3="$( date +%s )"
}

function fn_url_child {
	###The basic loop for a URL monitoring process.
	v_URL_OR_PING="URL"
	while [[ 1 == 1 ]]; do
		fn_child_dates
		### Set up the command line arguments for curl
		f_STDERR="/dev/null"
		if [[ $v_WGET_BIN == "false" ]]; then
			if [[ $v_IP_ADDRESS == false ]]; then
				a_CURL_ARGS=( "$v_CHECK_TIMEOUT" "$v_CURL_URL" "--header" "User-Agent: $v_USER_AGENT" "-o" "$v_WORKINGDIR""$v_CHILD_PID/site_current.html" )
			else
				a_CURL_ARGS=( "$v_CHECK_TIMEOUT" "$v_CURL_URL" "--header" "Host: $v_DOMAIN" "--header" "User-Agent: $v_USER_AGENT" "-o" "$v_WORKINGDIR""$v_CHILD_PID/site_current.html" )
			fi
			if [[ $v_CURL_VERBOSE != true ]]; then
				a_CURL_ARGS=( "-kLsm" "${a_CURL_ARGS[@]}" )
			else
				a_CURL_ARGS=( "-kLsvm" "${a_CURL_ARGS[@]}" )
				f_STDERR="$v_WORKINGDIR""$v_CHILD_PID"/current_verbose_output.txt
				echo "$v_CURL_BIN ${a_CURL_ARGS[@]}" > "$f_STDERR"
			fi
		else
			if [[ $v_IP_ADDRESS == false ]]; then
				a_WGET_ARGS=( "--no-check-certificate" "-q" "--timeout=$v_CHECK_TIMEOUT" "-O" "$v_WORKINGDIR""$v_CHILD_PID/site_current.html" "$v_CURL_URL" "--header=User-Agent: $v_USER_AGENT" )
			else
				a_WGET_ARGS=( "--no-check-certificate" "-q" "--timeout=$v_CHECK_TIMEOUT" "-O" "$v_WORKINGDIR""$v_CHILD_PID/site_current.html" "$v_CURL_URL" "--header=Host: $v_DOMAIN" "--header=User-Agent: $v_USER_AGENT" )
			fi
		fi
		### Move the current download of the site to the previous
		if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/site_current.html ]]; then
			### The only instance where this isn't the case should be on the first run of the loop.
			mv -f "$v_WORKINGDIR""$v_CHILD_PID"/site_current.html "$v_WORKINGDIR""$v_CHILD_PID"/site_previous.html
		fi
		if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/previous_verbose_output.txt ]]; then
			rm -f "$v_WORKINGDIR""$v_CHILD_PID"/previous_verbose_output.txt
		fi
		if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/current_verbose_output.txt ]]; then
			mv -f "$v_WORKINGDIR""$v_CHILD_PID"/current_verbose_output.txt "$v_WORKINGDIR""$v_CHILD_PID"/previous_verbose_output.txt
		fi
		### curl it!
		v_CHECK_START=$( date +%s"."%N | head -c -6 )
		if [[ $v_WGET_BIN == "false" ]]; then
			$v_CURL_BIN "${a_CURL_ARGS[@]}" >> "$f_STDERR" 2>> "$f_STDERR"
		else
			$v_WGET_BIN "${a_WGET_ARGS[@]}" >> "$f_STDERR" 2>> "$f_STDERR"
		fi
		v_STATUS=$?
		v_CHECK_END=$( date +%s"."%N | head -c -6 )
		### If the exit status of curl is 28, this means that the page timed out.
		if [[ $v_STATUS == 28 && $v_WGET_BIN == "false" ]]; then
			echo -e "\n\n\n\nCurl return code: $v_STATUS (This means that the timeout was reached before the full page was returned.)" >> "$v_WORKINGDIR""$v_CHILD_PID"/current_verbose_output.txt
		elif [[ $v_STATUS != 0 && $v_WGET_BIN == "false" ]]; then
			echo -e "\n\n\n\nCurl return code: $v_STATUS" >> "$v_WORKINGDIR""$v_CHILD_PID"/current_verbose_output.txt
		elif [[ $v_STATUS != 0 ]]; then
			echo -e "\n\n\n\nWget return code: $v_STATUS" >> "$v_WORKINGDIR""$v_CHILD_PID"/current_verbose_output.txt
		fi
		if [[ $v_CURL_VERBOSE == true && $v_LOG_HTTP_CODE == true ]]; then
		### Capture the html response code, if so directed.
			v_HTML_RESPONSE_CODE="$( cat "$v_WORKINGDIR""$v_CHILD_PID"/current_verbose_output.txt | grep -E -m1 "<" | cut -d " " -f3- | tr -dc '[[:print:]]' )"
			if [[ -z $v_HTML_RESPONSE_CODE ]]; then
				v_HTML_RESPONSE_CODE="No Code Reported"
			fi
		fi
		### Check the curl strings
		i=0; j=0; while [[ $i -lt ${#a_CURL_STRING[@]} ]]; do
			if [[ $( fgrep -c "${a_CURL_STRING[$i]}" "$v_WORKINGDIR""$v_CHILD_PID"/site_current.html ) -gt 0 ]]; then
				j=$(( $j + 1 ))
			fi
			i=$(( $i + 1 ))
		done
		v_CHECK_DURATION="$( awk "BEGIN {printf \"%.4f\",( ${v_CHECK_END} - ${v_CHECK_START} ) * 100}" )"
		if [[ $j -lt $i && $j -gt 0 ]]; then
			fn_report_status "partial success" save
		elif [[ $( echo $v_CHECK_DURATION | cut -d "." -f1 ) -ge "$v_CHECK_TIME_PARTIAL_SUCCESS" && $j -gt 0 ]]; then
			fn_report_status "partial success"
		elif [[ $i -eq $j ]]; then
			fn_report_status success
		else
			fn_report_status failure save
		fi
		### if we're logging http response codes, and the response code has changed...
		if [[ $v_CURL_VERBOSE == true && $v_LOG_HTTP_CODE == true && "$v_HTML_RESPONSE_CODE" != "$v_LAST_HTML_RESPONSE_CODE" ]]; then
			echo "$v_DATE2 - [$v_CHILD_PID] - The HTML response code has changed to \"$v_HTML_RESPONSE_CODE\"." >> "$v_WORKINGDIR""$v_CHILD_PID"/log
			v_LAST_HTML_RESPONSE_CODE="$v_HTML_RESPONSE_CODE"
		fi
		fn_child_checks
	done
}

function fn_load_child {
	v_URL_OR_PING="Load on"
	while [[ 1 == 1 ]]; do
		fn_child_dates
		if [[ "$v_DOMAIN" == "127.0.0.1" || "$v_DOMAIN" == "::1" ]]; then
		### If we're checking localhost, there's no need to use ssh
			v_CHECK_START=$( date +%s"."%N | head -c -6 )
			v_LOAD_AVG="$( cat /proc/loadavg | cut -d " " -f1 )"
			v_CHECK_END=$( date +%s"."%N | head -c -6 )
		else
			v_CHECK_START=$( date +%s"."%N | head -c -6 )
			### Check to make sure that the control file is in place. If it's not, don't even try to connect.
			if [[ -e "$( echo "$v_SSH_CONTROL_PATH" | sed "s/%h/$v_DOMAIN/;s/%p/$v_SERVER_PORT/;s/%r/$v_SSH_USER/" )" ]]; then
				v_LOAD_AVG="$( ssh -t -q -o ConnectTimeout=$v_CHECK_TIMEOUT -o ConnectionAttempts=1 -o ControlPath="$v_SSH_CONTROL_PATH" $v_SSH_USER@$v_DOMAIN -p $v_SERVER_PORT "cat /proc/loadavg | cut -d \" \" -f1" 2> /dev/null )"
			else
				v_LOAD_AVG=""
			fi
			v_CHECK_END=$( date +%s"."%N | head -c -6 )
		fi
		if [[ -n $v_LOAD_AVG ]]; then
			v_MODIFIED_LOAD_AVERAGE="$( awk "BEGIN {printf \"%.0f\",${v_LOAD_AVG} * 100}" )"
		fi
		v_CHECK_DURATION="$( awk "BEGIN {printf \"%.4f\",(${v_CHECK_END} - ${v_CHECK_START} ) * 100}" )"
		if [[ -n $v_LOAD_AVG && $v_MODIFIED_LOAD_AVERAGE -lt $v_MIN_LOAD_PARTIAL_SUCCESS && $v_MODIFIED_LOAD_AVERAGE -lt $v_MIN_LOAD_FAILURE && $( echo $v_CHECK_DURATION | cut -d "." -f1 ) -ge "$v_CHECK_TIME_PARTIAL_SUCCESS" ]]; then
			fn_report_status "partial success"
		elif [[ -n $v_LOAD_AVG && $v_MODIFIED_LOAD_AVERAGE -lt $v_MIN_LOAD_PARTIAL_SUCCESS && $v_MODIFIED_LOAD_AVERAGE -lt $v_MIN_LOAD_FAILURE ]]; then
			fn_report_status success
		elif [[ -z $v_LOAD_AVG || $v_MODIFIED_LOAD_AVERAGE -ge $v_MIN_LOAD_FAILURE ]]; then
			fn_report_status failure
		else
			fn_report_status "partial success"
		fi
		fn_child_checks
	done
}

function fn_ping_child {
	### The basic loop for a ping monitoring process
	v_URL_OR_PING="Ping of"
	while [[ 1 == 1 ]]; do
		fn_child_dates
		v_CHECK_START=$( date +%s"."%N | head -c -6 )
		v_PING_RESULT=$( ping -W2 -c1 $v_DOMAIN 2> /dev/null | grep -E "icmp_[rs]eq" )
		v_CHECK_END=$( date +%s"."%N | head -c -6 )
		v_WATCH=$( echo $v_PING_RESULT | grep -E -c "icmp_[rs]eq" )
		if [[ $v_WATCH -ne 0 ]]; then
			fn_report_status success
		else
			fn_report_status failure
		fi
		fn_child_checks
	done
}

function fn_dns_child {
	### The basic loop for a DNS monitoring process
	### Note: the DNS monitoring feature is a throwback to 2012 and 2013 when DNS was the first thing that would stop reporting on a cPanel server if it was under load. While this is no longer the case, I don't see any point in removing this feature.
	v_URL_OR_PING="DNS for"
	while [[ 1 == 1 ]]; do
		fn_child_dates
		v_CHECK_START=$( date +%s"."%N | head -c -6 )
		if [[ -n $v_DNS_RECORD_TYPE && -n $v_DNS_CHECK_RESULT ]]; then
			v_QUERY_RESULT=$( dig +tries=1 +short $v_DNS_RECORD_TYPE $v_DNS_CHECK_DOMAIN @$v_DOMAIN 2> /dev/null | fgrep -c "$v_DNS_CHECK_RESULT" )
		elif [[ -n $v_DNS_RECORD_TYPE ]]; then
			v_QUERY_RESULT=$( dig +tries=1 +short $v_DNS_RECORD_TYPE $v_DNS_CHECK_DOMAIN @$v_DOMAIN 2> /dev/null | wc -l )
		elif [[ -n $v_DNS_CHECK_RESULT ]]; then
			v_QUERY_RESULT=$( dig +tries=1 +short $v_DNS_CHECK_DOMAIN @$v_DOMAIN 2> /dev/null | fgrep -c "$v_DNS_CHECK_RESULT" )
		else
			v_QUERY_RESULT=$( dig +tries=1 $v_DNS_CHECK_DOMAIN @$v_DOMAIN 2> /dev/null | grep -F -c "ANSWER SECTION" )
		fi
		v_CHECK_END=$( date +%s"."%N | head -c -6 )
		if [[ $v_QUERY_RESULT -ne 0 ]]; then
			fn_report_status success
		else
			fn_report_status failure
		fi
		fn_child_checks
	done
}

function fn_child_checks {
	### has the mtime of the params file increased?
	if [[ "$( stat --format=%Y "$v_WORKINGDIR""$v_CHILD_PID/params" )" -gt "$v_PARAMS_RELOAD" ]]; then
		fn_child_vars
		echo "$v_DATE2 - [$v_CHILD_PID] - Reloaded parameters for $v_URL_OR_PING $v_ORIG_JOB_NAME." >> "$v_LOG"
		echo "$v_DATE2 - [$v_CHILD_PID] - Reloaded parameters for $v_URL_OR_PING $v_ORIG_JOB_NAME." >> "$v_WORKINGDIR""$v_CHILD_PID"/log
		echo "***Reloaded parameters for $v_URL_OR_PING $v_JOB_NAME.***"
	elif [[ "$( stat --format=%Y "$v_WORKINGDIR""lwmon.conf" )" -gt "$v_MASTER_RELOAD" ]]; then
	### fn_child_vars updates both the reload variables.
		fn_child_vars
	fi
	if [[ $( ls -1 "$v_WORKINGDIR""$v_CHILD_PID"/ | grep -E "^site_" | grep -E -cv "current|previous" ) -gt $v_HTML_FILES_KEPT ]]; then
		### You'll notice that it's only removing one file. There should be no instances where more than one is generated per run, so removing one per run should always be sufficient.
		rm -f "$v_WORKINGDIR""$v_CHILD_PID"/site_"$( ls -1t "$v_WORKINGDIR""$v_CHILD_PID"/ | grep -E "^site_" | grep -E -v "current|previous" | tail -n1 | sed "s/site_//" )"
	fi
	### If the domain or IP address shows up on the die list, this process can be killed.
	if [[ $( grep -E -c "^[[:blank:]]*($v_DOMAIN|$v_IP_ADDRESS)[[:blank:]]*(#.*)*$" "$v_WORKINGDIR"die_list ) -gt 0 ]]; then
		echo "$v_DATE2 - [$v_CHILD_PID] - Process ended due to data on the remote list. The line reads \"$( grep -E "^[[:blank:]]*($v_DOMAIN|$v_IP_ADDRESS)[[:blank:]]*(#.*)*$" "$v_WORKINGDIR"die_list | head -n1 )\"." >> "$v_LOG"
		echo "$v_DATE2 - [$v_CHILD_PID] - Process ended due to data on the remote list. The line reads \"$( grep -E "^[[:blank:]]*($v_DOMAIN|$v_IP_ADDRESS)[[:blank:]]*(#.*)*$" "$v_WORKINGDIR"die_list | head -n1 )\"." >> "$v_WORKINGDIR""$v_CHILD_PID"/log
		touch "$v_WORKINGDIR""$v_CHILD_PID"/die
	fi
	### Wait until the next loop to die so that the full status will be recorded
	### Generally all of the STUFF between the actual check and running sleep lasts 0.1 seconds-ish. No harm in calculating exactly how long it took and then subtracting that from the wait seconds.
	v_CHECK_END2=$( date +%s"."%N | head -c -6 )
	v_SLEEP_SECONDS="$( awk "BEGIN {printf \"%.2f\",${v_WAIT_SECONDS} - ( ${v_CHECK_END2} - ${v_CHECK_END} )}" )"
	if [[ "${v_SLEEP_SECONDS:0:1}" != "-" ]]; then
		sleep $v_SLEEP_SECONDS
	fi
}

function fn_child_exit {
	### When a child process exits, it needs to clean up after itself and log the fact that it has exited. "$1" is the exit code that should be output.
	v_EXIT_CODE="$1"
	if [[ $v_TOTAL_CHECKS -gt 0 ]]; then
		echo "$v_DATE2 - [$v_CHILD_PID] - Stopped watching $v_URL_OR_PING $v_ORIG_JOB_NAME: Running for $v_RUN_TIME seconds. $v_TOTAL_CHECKS checks completed. $v_PERCENT_SUCCESSES% success rate." >> "$v_LOG"
		echo "$v_DATE2 - [$v_CHILD_PID] - Stopped watching $v_URL_OR_PING $v_ORIG_JOB_NAME: Running for $v_RUN_TIME seconds. $v_TOTAL_CHECKS checks completed. $v_PERCENT_SUCCESSES% success rate." >> "$v_WORKINGDIR""$v_CHILD_PID"/log
	fi
	### Instead of deleting the directory, back it up temporarily.
	if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/die ]]; then
		mv -f "$v_WORKINGDIR""$v_CHILD_PID"/die "$v_WORKINGDIR""$v_CHILD_PID"/#die
		mv "$v_WORKINGDIR""$v_CHILD_PID" "$v_WORKINGDIR""old_""$v_CHILD_PID""_""$v_DATE3"
	fi

	### Record the final "more verbose" status
	
	exit $v_EXIT_CODE
}

#===================================#
#== Success and Failure Functions ==#
#===================================#

function fn_report_status {
	### $1 is the status. $2 is whether or not to try to save the file
	v_THIS_STATUS="$1"
	local v_SAVE="$2"

	### This is present if, for testing purposes, we need to override the result of a check
	if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/force_success ]]; then
		v_THIS_STATUS="success"
		rm -f "$v_WORKINGDIR""$v_CHILD_PID"/force_success
	elif [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/force_failure ]]; then
		v_THIS_STATUS="failure"
		rm -f "$v_WORKINGDIR""$v_CHILD_PID"/force_failure
	elif [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/force_partial ]]; then
		v_THIS_STATUS="partial success"
		rm -f "$v_WORKINGDIR""$v_CHILD_PID"/force_partial
	fi

	### Gather the specifics for each status
	if [[ "$v_THIS_STATUS" == "success" ]]; then
		v_TOTAL_SUCCESSES=$(( $v_TOTAL_SUCCESSES + 1 ))
		v_LAST_SUCCESS=$v_DATE3
		v_NUM_SUCCESSES_EMAIL=$(( $v_NUM_SUCCESSES_EMAIL + 1 ))
		v_DESCRIPTOR1="Success"
		v_DESCRIPTOR2="Check succeeded"
		v_SUCCESS_CHECKS=$(( $v_SUCCESS_CHECKS + 1 ))
		if [[ $v_LAST_STATUS == "success" ]]; then
			fn_read_conf COLOR_SUCCESS master "$v_DEFAULT_COLOR_SUCCESS"; v_COLOR_START="$v_RESULT"
			fn_read_conf RETURN_SUCCESS master "$v_DEFAULT_RETURN_SUCCESS"; v_COLOR_END="$v_RESULT"
		else
			fn_read_conf COLOR_FIRST_SUCCESS master "$v_DEFAULT_COLOR_FIRST_SUCCESS"; v_COLOR_START="$v_RESULT"
			fn_read_conf RETURN_FIRST_SUCCESS master "$v_DEFAULT_RETURN_FIRST_SUCCESS"; v_COLOR_END="$v_RESULT"
		fi
	elif [[ "$v_THIS_STATUS" == "partial success" ]]; then
		v_TOTAL_PARTIAL_SUCCESSES=$(( $v_TOTAL_PARTIAL_SUCCESSES + 1 ))
		v_LAST_PARTIAL_SUCCESS=$v_DATE3
		v_NUM_PARTIAL_SUCCESSES_EMAIL=$(( $v_NUM_PARTIAL_SUCCESSES_EMAIL + 1 ))
		v_DESCRIPTOR1="Partial Success"
		v_DESCRIPTOR2="Partial success"
		v_PARTIAL_SUCCESS_CHECKS=$(( $v_PARTIAL_SUCCESS_CHECKS + 1 ))
		if [[ $v_LAST_STATUS == "partial success" ]]; then
			fn_read_conf COLOR_PARTIAL_SUCCESS master "$v_DEFAULT_COLOR_PARTIAL_SUCCESS"; v_COLOR_START="$v_RESULT"
			fn_read_conf RETURN_PARTIAL_SUCCESS master "$v_DEFAULT_RETURN_PARTIAL_SUCCESS"; v_COLOR_END="$v_RESULT"
		else
			fn_read_conf COLOR_FIRST_PARTIAL_SUCCESS master "$v_DEFAULT_COLOR_FIRST_PARTIAL_SUCCESS"; v_COLOR_START="$v_RESULT"
			fn_read_conf RETURN_FIRST_PARTIAL_SUCCESS master "$v_DEFAULT_RETURN_FIRST_PARTIAL_SUCCESS"; v_COLOR_END="$v_RESULT"
		fi
	elif [[ "$v_THIS_STATUS" == "failure" ]]; then
		v_TOTAL_FAILURES=$(( $v_TOTAL_FAILURES + 1 ))
		v_LAST_FAILURE=$v_DATE3
		v_NUM_FAILURES_EMAIL=$(( $v_NUM_FAILURES_EMAIL + 1 ))
		v_DESCRIPTOR1="Failure"
		v_DESCRIPTOR2="Check failed"
		v_FAILURE_CHECKS=$(( $v_FAILURE_CHECKS + 1 ))
		if [[ $v_LAST_STATUS == "failure" ]]; then
			fn_read_conf COLOR_FAILURE master "$v_DEFAULT_COLOR_FAILURE"; v_COLOR_START="$v_RESULT"
			fn_read_conf RETURN_FAILURE master "$v_DEFAULT_RETURN_FAILURE"; v_COLOR_END="$v_RESULT"
		else
			fn_read_conf COLOR_FIRST_FAILURE master "$v_DEFAULT_COLOR_FIRST_FAILURE"; v_COLOR_START="$v_RESULT"
			fn_read_conf RETURN_FIRST_FAILURE master "$v_DEFAULT_RETURN_FIRST_FAILURE"; v_COLOR_END="$v_RESULT"
		fi
	fi
	if [[ $v_JOB_TYPE == "ssh-load" ]]; then
		v_DESCRIPTOR1="$v_LOAD_AVG"
	fi

	### Statistics and duration information.

	### Figure out how long the script has run and what percent are successes, etc.
	v_RUN_SECONDS="$(( $v_DATE3 - $v_START_TIME ))"
	v_RUN_TIME="$( fn_convert_seconds $v_RUN_SECONDS )"
	v_TOTAL_CHECKS=$(( $v_TOTAL_CHECKS + 1 ))
	v_PERCENT_SUCCESSES="$( awk "BEGIN {printf \"%.2f\",( ${v_TOTAL_SUCCESSES} * 100 ) / ${v_TOTAL_CHECKS}}" )"
	v_PERCENT_PARTIAL_SUCCESSES="$( awk "BEGIN {printf \"%.2f\",( ${v_TOTAL_PARTIAL_SUCCESSES} * 100 ) / ${v_TOTAL_CHECKS}}" )"
	v_PERCENT_FAILURES="$( awk "BEGIN {printf \"%.2f\",( ${v_TOTAL_FAILURES} * 100 ) / ${v_TOTAL_CHECKS}}" )"
	### How long did the check itself take?
	v_CHECK_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_CHECK_END} - ${v_CHECK_START}}" )"
	v_TOTAL_DURATIONS="$( awk "BEGIN {printf \"%.4f\",${v_CHECK_DURATION} + ${v_TOTAL_DURATIONS}}" )"
	v_AVERAGE_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_TOTAL_DURATIONS} / ${v_TOTAL_CHECKS}}" )"

	### Subtract old values from the the total recent duration and add the new value
	if [[ -z $v_TOTAL_RECENT_DURATION ]]; then
		v_TOTAL_RECENT_DURATION=0
	fi
	while [[ ${#a_RECENT_DURATIONS[@]} -ge $v_NUM_DURATIONS_RECENT  ]]; do
		v_TOTAL_RECENT_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_TOTAL_RECENT_DURATION} - ${a_RECENT_DURATIONS[0]}}" )"
		a_RECENT_DURATIONS=("${a_RECENT_DURATIONS[@]:1}")
	done
	a_RECENT_DURATIONS[${#a_RECENT_DURATIONS[@]}]="$v_CHECK_DURATION"
	v_TOTAL_RECENT_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_TOTAL_RECENT_DURATION} + ${v_CHECK_DURATION}}" )"

	### Calculate the average recent duration
	v_AVERAGE_RECENT_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_TOTAL_RECENT_DURATION} / ${#a_RECENT_DURATIONS[@]}}" )"
	if [[ "$v_THIS_STATUS" == "success" ]]; then
		v_TOTAL_SUCCESS_DURATIONS="$( awk "BEGIN {printf \"%.4f\",${v_CHECK_DURATION} + ${v_TOTAL_SUCCESS_DURATIONS}}" )"
		v_AVERAGE_SUCCESS_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_TOTAL_SUCCESS_DURATIONS} / ${v_TOTAL_SUCCESSES}}" )"
	fi

	### Make sure that the initial variables are there for long and short hours
	v_LONG_HOURS="8";
	if [[ -z $v_LONG_TOTAL_DURATION ]]; then
		v_LONG_TOTAL_DURATION=0
		v_LONG_SUCCESS=0
		v_LONG_PARTIAL=0
		v_LONG_FAIL=0
	fi
	v_SHORT_HOURS="1";
	if [[ -z $v_SHORT_TOTAL_DURATION ]]; then
		v_SHORT_TOTAL_DURATION=0
		v_SHORT_SUCCESS=0
		v_SHORT_PARTIAL=0
		v_SHORT_FAIL=0
		v_SHORT_PLACE=0
	fi

	### add the current values to the long array
	v_LONG_COUNT=$(( $v_LONG_COUNT + 1 ))
	v_SHORT_COUNT=$(( $v_SHORT_COUNT + 1 ))
	a_LONG_STAMPS[${#a_LONG_STAMPS[@]}]="$v_DATE3"
	if [[ "$v_THIS_STATUS" == "success" ]]; then
		a_LONG_STATUSES[${#a_LONG_STATUSES[@]}]="s"
		v_LONG_SUCCESS=$(( $v_LONG_SUCCESS + 1 ))
		v_SHORT_SUCCESS=$(( $v_SHORT_SUCCESS + 1 ))
	elif [[ "$v_THIS_STATUS" == "partial success" ]]; then
		a_LONG_STATUSES[${#a_LONG_STATUSES[@]}]="p"
		v_LONG_PARTIAL=$(( $v_LONG_PARTIAL + 1 ))
		v_SHORT_PARTIAL=$(( $v_SHORT_PARTIAL + 1 ))
	elif [[ "$v_THIS_STATUS" == "failure" ]]; then
		a_LONG_STATUSES[${#a_LONG_STATUSES[@]}]="f"
		v_LONG_FAIL=$(( $v_LONG_FAIL + 1 ))
		v_SHORT_FAIL=$(( $v_SHORT_FAIL + 1 ))
	fi
	a_LONG_DURATIONS[${#a_LONG_DURATIONS[@]}]="$v_CHECK_DURATION"

	### Get rid of entries from the long array, adjust the placement of the for the short hours
	if [[ -n ${a_LONG_STAMPS[0]} ]]; then
		while [[ ${a_LONG_STAMPS[0]} -le $(( $v_DATE3 - $(( 3600 * $v_LONG_HOURS )) )) ]]; do
			if [[ ${a_LONG_STAMPS[0]} == "s" ]]; then
				v_LONG_SUCCESS=$(( $v_LONG_SUCCESS - 1 ))
			elif [[ ${a_LONG_STAMPS[0]} == "p" ]]; then
				v_LONG_PARTIAL=$(( $v_LONG_PARTIAL - 1 ))
			elif [[ ${a_LONG_STAMPS[0]} == "f" ]]; then
				v_LONG_FAIL=$(( $v_LONG_FAIL - 1 ))
			fi
			v_LONG_TOTAL_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_LONG_TOTAL_DURATION} - ${a_LONG_DURATIONS[0]}}" )"
			v_LONG_COUNT=$(( $v_LONG_COUNT - 1 ))
			a_LONG_STAMPS=("${a_LONG_STAMPS[@]:1}")
			a_LONG_STATUSES=("${a_LONG_STATUSES[@]:1}")
			a_LONG_DURATIONS=("${a_LONG_DURATIONS[@]:1}")
			v_SHORT_PLACE=$(( $v_SHORT_PLACE - 1 ))
		done
	fi

	### adjust placement for the short array
	if [[ -n ${a_LONG_STAMPS[0]} ]]; then
		while [[ ${a_LONG_STAMPS[$v_SHORT_PLACE]} -le $(( $v_DATE3 - $(( 3600 * $v_SHORT_HOURS )) )) ]]; do
			if [[ ${a_LONG_STAMPS[$v_SHORT_PLACE]} == "s" ]]; then
				v_SHORT_SUCCESS=$(( $v_SHORT_SUCCESS - 1 ))
			elif [[ ${a_LONG_STAMPS[$v_SHORT_PLACE]} == "p" ]]; then
				v_SHORT_PARTIAL=$(( $v_SHORT_PARTIAL - 1 ))
			elif [[ ${a_LONG_STAMPS[$v_SHORT_PLACE]} == "f" ]]; then
				v_SHORT_FAIL=$(( $v_SHORT_FAIL - 1 ))
			fi
			v_SHORT_TOTAL_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_SHORT_TOTAL_DURATION} - ${a_LONG_DURATIONS[$v_SHORT_PLACE]}}" )"
			v_SHORT_COUNT=$(( $v_SHORT_COUNT - 1 ))
			v_SHORT_PLACE=$(( $v_SHORT_PLACE + 1 ))
		done
	fi

	### Do the math for long hours
	v_LONG_PERCENT_SUCCESS="$( awk "BEGIN {printf \"%.2f\",( ${v_LONG_SUCCESS} * 100 ) / ${v_LONG_COUNT}}" )"
	v_LONG_PERCENT_PARTIAL="$( awk "BEGIN {printf \"%.2f\",( ${v_LONG_PARTIAL} * 100 ) / ${v_LONG_COUNT}}" )"
	v_LONG_PERCENT_FAIL="$( awk "BEGIN {printf \"%.2f\",( ${v_LONG_FAIL} * 100 ) / ${v_LONG_COUNT}}" )"
	v_LONG_TOTAL_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_LONG_TOTAL_DURATION} + ${v_CHECK_DURATION}}" )"
	v_LONG_AVERAGE_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_LONG_TOTAL_DURATION} / ${v_LONG_COUNT}}" )"	

	### Do the math for short hours
	v_SHORT_PERCENT_SUCCESS="$( awk "BEGIN {printf \"%.2f\",( ${v_SHORT_SUCCESS} * 100 ) / ${v_SHORT_COUNT}}" )"
	v_SHORT_PERCENT_PARTIAL="$( awk "BEGIN {printf \"%.2f\",( ${v_SHORT_PARTIAL} * 100 ) / ${v_SHORT_COUNT}}" )"
	v_SHORT_PERCENT_FAIL="$( awk "BEGIN {printf \"%.2f\",( ${v_SHORT_FAIL} * 100 ) / ${v_SHORT_COUNT}}" )"
	v_SHORT_TOTAL_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_SHORT_TOTAL_DURATION} + ${v_CHECK_DURATION}}" )"
	v_SHORT_AVERAGE_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_SHORT_TOTAL_DURATION} / ${v_SHORT_COUNT}}" )"

	### Set the status strings

	### set v_LAST_LAST_STATUS
	if [[ $v_LAST_STATUS != "$v_THIS_STATUS" ]]; then
		v_LAST_LAST_STATUS="$v_LAST_STATUS"
	fi
	### Figure out when the last partial success and last failure were.
	if [[ "$v_THIS_STATUS" != "success" ]]; then
		if [[ $v_LAST_SUCCESS == "never" || -z $v_LAST_SUCCESS ]]; then
			v_LAST_SUCCESS_STRING="never"
		else
			v_LAST_SUCCESS_STRING="$( fn_convert_seconds $(( $v_DATE3 - $v_LAST_SUCCESS )) ) ago"
		fi
	fi
	if [[ "$v_THIS_STATUS" != "partial success" ]]; then
		if [[ $v_LAST_PARTIAL_SUCCESS == "never" || -z $v_LAST_PARTIAL_SUCCESS ]]; then
			v_LAST_PARTIAL_SUCCESS_STRING="never"
		else
			v_LAST_PARTIAL_SUCCESS_STRING="$( fn_convert_seconds $(( $v_DATE3 - $v_LAST_PARTIAL_SUCCESS )) ) ago"
		fi
	fi
	if [[ "$v_THIS_STATUS" != "failure" ]]; then
		if [[ $v_LAST_FAILURE == "never" || -z $v_LAST_FAILURE ]]; then
			v_LAST_FAILURE_STRING="never"
		else
			v_LAST_FAILURE_STRING="$( fn_convert_seconds $(( $v_DATE3 - $v_LAST_FAILURE )) ) ago"
		fi
	fi

	v_DUMP_STATUS=false
	if [[ -z $v_OUT_STATUS_NEXT ]]; then
		v_OUT_STATUS_NEXT=600
	fi

	if [[ $v_RUN_SECONDS -gt $v_OUT_STATUS_NEXT ]]; then
		v_DUMP_STATUS=true
		v_OUT_STATUS_NEXT=$(( $v_OUT_STATUS_NEXT + 600 ))
	fi

	### Check to see if the parent is still in place, and die if not.
	if [[ $( cat /proc/$v_MASTER_PID/cmdline 2> /dev/null | tr "\0" " " | grep -E -c "$v_PROGRAMNAME[[:blank:]]" ) -eq 0 || -f "$v_WORKINGDIR""$v_CHILD_PID"/die ]]; then
		v_DUMP_STATUS=true
		v_DIE=true
	fi

	if [[ $v_VERBOSITY == "more verbose" || -f "$v_WORKINGDIR""$v_CHILD_PID"/status || $v_DUMP_STATUS == true ]]; then
		### set up the "more verose" output if necessary.
		v_REPORT2="$v_DATE2 - [$v_CHILD_PID] - $v_URL_OR_PING $v_JOB_NAME\n  Check Status:                 $v_DESCRIPTOR1\n  Checking for:                 $v_RUN_TIME\n  "
		if [[ "$v_THIS_STATUS" != "success" ]]; then
			v_REPORT2="$v_REPORT2""Last successful check:        $v_LAST_SUCCESS_STRING\n  "
		fi
		if [[ "$v_THIS_STATUS" != "partial success" ]]; then
			v_REPORT2="$v_REPORT2""Last partial success:         $v_LAST_PARTIAL_SUCCESS_STRING\n  "
		fi
		if [[ "$v_THIS_STATUS" != "failure" ]]; then
			v_REPORT2="$v_REPORT2""Last failed check:            $v_LAST_FAILURE_STRING\n  "
		fi
		v_REPORT2="$v_REPORT2""Number of checks completed:   $v_TOTAL_CHECKS\n  #Success/#Partial/#Failure:   $v_TOTAL_SUCCESSES / $v_TOTAL_PARTIAL_SUCCESSES / $v_TOTAL_FAILURES\n  %Success/%Partial/%Failure:   $v_PERCENT_SUCCESSES% / $v_PERCENT_PARTIAL_SUCCESSES% / $v_PERCENT_FAILURES%\n  This check:                   $v_CHECK_DURATION seconds\n  Average check:                $v_AVERAGE_DURATION seconds\n  Average recent check:         $v_AVERAGE_RECENT_DURATION seconds\n  Average successful check:     $v_AVERAGE_SUCCESS_DURATION seconds"
		if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/status || $v_DUMP_STATUS == true ]]; then
			echo -e "$v_REPORT2""\n  Total duration:               $v_TOTAL_DURATIONS seconds\n  Total recent duration:        $v_TOTAL_RECENT_DURATION seconds\n  Total successful duration:    $v_TOTAL_SUCCESS_DURATIONS seconds\n  Last $v_LONG_HOURS hours:\n    Number of checks completed: $v_LONG_COUNT\n    #Success/#Partial/#Failure: $v_LONG_SUCCESS / $v_LONG_PARTIAL / $v_LONG_FAIL\n    %Success/%Partial/%Failure: $v_LONG_PERCENT_SUCCESS% / $v_LONG_PERCENT_PARTIAL% / $v_LONG_PERCENT_FAIL%\n    Average check:              $v_LONG_AVERAGE_DURATION seconds\n    Total duration:             $v_LONG_TOTAL_DURATION seconds\n  Last $v_SHORT_HOURS hours:\n    Number of checks completed: $v_SHORT_COUNT\n    #Success/#Partial/#Failure: $v_SHORT_SUCCESS / $v_SHORT_PARTIAL / $v_SHORT_FAIL\n    %Success/%Partial/%Failure: $v_SHORT_PERCENT_SUCCESS% / $v_SHORT_PERCENT_PARTIAL% / $v_SHORT_PERCENT_FAIL%\n    Average check:              $v_SHORT_AVERAGE_DURATION seconds\n    Total duration:             $v_SHORT_TOTAL_DURATION seconds" > "$v_WORKINGDIR""$v_CHILD_PID"/status
			mv -f "$v_WORKINGDIR""$v_CHILD_PID"/status "$v_WORKINGDIR""$v_CHILD_PID/#status"
		fi
	fi

	### die if we need to die.
	if [[ $v_DIE == true ]]; then
		fn_child_exit 0
	fi

	### Set $v_REPORT based on where the verbosity is set

	if [[ "$v_VERBOSITY" == "verbose" ]]; then
		### verbose
		v_REPORT="$v_DATE - [$v_CHILD_PID] - $v_URL_OR_PING $v_JOB_NAME: $v_DESCRIPTOR1 - Checking for $v_RUN_TIME."
		if [[ $v_LAST_LAST_STATUS == "success" ]]; then
			v_REPORT="$v_REPORT Last success: $v_LAST_SUCCESS_STRING."
		elif [[ $v_LAST_LAST_STATUS == "partial success" ]]; then
			v_REPORT="$v_REPORT Last partial success: $v_LAST_PARTIAL_SUCCESS_STRING."
		elif [[ $v_LAST_LAST_STATUS == "failure" ]]; then
			v_REPORT="$v_REPORT Last failed check: $v_LAST_FAILURE_STRING."
		fi
		v_REPORT="$v_REPORT $v_TOTAL_CHECKS checks completed. $v_PERCENT_SUCCESSES% success rate."
	elif [[ "$v_VERBOSITY" == "more verbose" || -f "$v_WORKINGDIR""$v_CHILD_PID"/status ]]; then
		### more verbose
		v_REPORT="$v_REPORT2"
	else
		### other
		v_REPORT="$v_DATE - $v_URL_OR_PING $v_JOB_NAME: $v_DESCRIPTOR1"
	fi
	v_LOG_MESSAGE="$v_DATE2 - [$v_CHILD_PID] - Status changed for $v_URL_OR_PING $v_ORIG_JOB_NAME: $v_DESCRIPTOR2"

	### The part that actually outputs the stuff

	### If the last status was the same as this status
	if [[ "$v_THIS_STATUS" == "$v_LAST_STATUS" ]]; then
		if [[ "$v_VERBOSITY" != "change" && "$v_VERBOSITY" != "none" && ! -f "$v_WORKINGDIR"no_output ]]; then
			echo -e "$v_COLOR_START""$v_REPORT""$v_COLOR_END" >> "$v_OUTPUT_FILE"
		fi
		fn_send_email
	### If there was no last status
	elif [[ -z $v_LAST_STATUS ]]; then
		if [[ "$v_VERBOSITY" != "none" && ! -f "$v_WORKINGDIR"no_output ]]; then
			echo -e "$v_COLOR_START""$v_REPORT""$v_COLOR_END" >> "$v_OUTPUT_FILE"
		fi
		echo "$v_DATE2 - [$v_CHILD_PID] - Initial status for $v_URL_OR_PING $v_ORIG_JOB_NAME: $v_DESCRIPTOR2" >> "$v_LOG"
		echo "$v_DATE2 - [$v_CHILD_PID] - Initial status for $v_URL_OR_PING $v_ORIG_JOB_NAME: $v_DESCRIPTOR2" >> "$v_WORKINGDIR""$v_CHILD_PID"/log
		### Mark the email type so that a message is not sent erroneously
		v_LAST_EMAIL_SENT="$v_THIS_STATUS"
	### If the last status was also successful
	elif [[ "$v_LAST_STATUS" == "success" ]]; then
		if [[ "$v_VERBOSITY" != "none" && ! -f "$v_WORKINGDIR"no_output ]]; then
			echo -e "$v_COLOR_START""$v_REPORT""$v_COLOR_END" >> "$v_OUTPUT_FILE"
		fi
		echo "$v_LOG_MESSAGE after $v_SUCCESS_CHECKS successful checks" >> "$v_LOG"
		echo "$v_LOG_MESSAGE after $v_SUCCESS_CHECKS successful checks" >> "$v_WORKINGDIR""$v_CHILD_PID"/log
		v_SUCCESS_CHECKS=0
		if [[ "$v_SAVE" == "save" && "$v_THIS_STATUS" == "failure" ]]; then
			cp -a "$v_WORKINGDIR""$v_CHILD_PID"/site_current.html "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3"_fail.html
			if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/current_verbose_output.txt ]]; then
				echo -e "\n\n\n\n" >> "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3"_fail.html
				cat "$v_WORKINGDIR""$v_CHILD_PID"/current_verbose_output.txt >> "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3"_fail.html
			fi
			cp -a "$v_WORKINGDIR""$v_CHILD_PID"/site_previous.html "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3_LAST"_success.html
			if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/previous_verbose_output.txt ]]; then
				echo -e "\n\n\n\n" >> "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3_LAST"_success.html
				cat "$v_WORKINGDIR""$v_CHILD_PID"/previous_verbose_output.txt >> "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3_LAST"_success.html
			fi
		elif [[ "$v_SAVE" == "save" && "$v_THIS_STATUS" == "partial success" ]]; then
			cp -a "$v_WORKINGDIR""$v_CHILD_PID"/site_current.html "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3"_psuccess.html
			if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/current_verbose_output.txt ]]; then
				echo -e "\n\n\n\n" >> "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3"_psuccess.html
				cat "$v_WORKINGDIR""$v_CHILD_PID"/current_verbose_output.txt >> "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3"_psuccess.html
			fi
			cp -a "$v_WORKINGDIR""$v_CHILD_PID"/site_previous.html "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3_LAST"_success.html
			if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/previous_verbose_output.txt ]]; then
				echo -e "\n\n\n\n" >> "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3_LAST"_success.html
				cat "$v_WORKINGDIR""$v_CHILD_PID"/previous_verbose_output.txt >> "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3_LAST"_success.html
			fi
		fi
		fn_send_email
	### If the last status was partial success
	elif [[ "$v_LAST_STATUS" == "partial success" ]]; then
		if [[ "$v_VERBOSITY" != "none" && ! -f "$v_WORKINGDIR"no_output ]]; then
			echo -e "$v_COLOR_START""$v_REPORT""$v_COLOR_END" >> "$v_OUTPUT_FILE"
		fi
		echo "$v_LOG_MESSAGE after $v_PARTIAL_SUCCESS_CHECKS partial successes" >> "$v_LOG"
		echo "$v_LOG_MESSAGE after $v_PARTIAL_SUCCESS_CHECKS partial successes" >> "$v_WORKINGDIR""$v_CHILD_PID"/log
		v_PARTIAL_SUCCESS_CHECKS=0
		if [[ "$v_SAVE" == "save" && "$v_THIS_STATUS" == "failure" ]]; then
			cp -a "$v_WORKINGDIR""$v_CHILD_PID"/site_current.html "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3"_fail.html
			if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/current_verbose_output.txt ]]; then
				echo -e "\n\n\n\n" >> "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3"_fail.html
				cat "$v_WORKINGDIR""$v_CHILD_PID"/current_verbose_output.txt >> "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3"_fail.html
			fi
			cp -a "$v_WORKINGDIR""$v_CHILD_PID"/site_previous.html "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3_LAST"_psuccess.html
			if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/previous_verbose_output.txt ]]; then
				echo -e "\n\n\n\n" >> "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3_LAST"_psuccess.html
				cat "$v_WORKINGDIR""$v_CHILD_PID"/previous_verbose_output.txt >> "$v_WORKINGDIR""$v_CHILD_PID"/site_"$v_DATE3_LAST"_psuccess.html
			fi
		fi
		fn_send_email
	### If the last status was failure
	elif [[ "$v_LAST_STATUS" == "failure" ]]; then
		if [[ "$v_VERBOSITY" != "none" && ! -f "$v_WORKINGDIR"no_output ]]; then
			echo -e "$v_COLOR_START""$v_REPORT""$v_COLOR_END" >> "$v_OUTPUT_FILE"
		fi
		echo "$v_LOG_MESSAGE after $v_FAILURE_CHECKS failed checks" >> "$v_LOG"
		echo "$v_LOG_MESSAGE after $v_FAILURE_CHECKS failed checks" >> "$v_WORKINGDIR""$v_CHILD_PID"/log
		v_FAILURE_CHECKS=0
		fn_send_email
	fi
	### If we need to log the duration data, do so
	if [[ "$v_LOG_DURATION_DATA" == "true" ]]; then
		echo "$v_DATE2 - [$v_CHILD_PID] - Status: $v_DESCRIPTOR2 - Duration $v_CHECK_DURATION seconds" >> "$v_WORKINGDIR""$v_CHILD_PID"/log
	fi

	### Preparing for the next loop

	### set the v_LAST_STATUS variable to "success"
	unset v_REPORT
	v_LAST_STATUS="$v_THIS_STATUS"
	a_RECENT_STATUSES[${#a_RECENT_STATUSES[@]}]="$v_THIS_STATUS"
	if [[ ${#a_RECENT_STATUSES[@]} -gt $v_NUM_STATUSES_RECENT ]]; then
		while [[ ${#a_RECENT_STATUSES[@]} -gt $v_NUM_STATUSES_RECENT ]]; do
			a_RECENT_STATUSES=("${a_RECENT_STATUSES[@]:1}")
		done
		### If there are symptoms of intermittent failures, send an email regarding such.
		if [[ $( echo "${a_RECENT_STATUSES[@]}" | grep -E -o "failure|partial success" | wc -l ) -ge $v_NUM_STATUSES_NOT_SUCCESS && "$v_THIS_STATUS" == "success" ]]; then
			v_THIS_STATUS="intermittent failure"
			fn_send_email
		fi
	fi
}

function fn_send_email {
	v_MUTUAL_EMAIL="thus meeting your threshold for being alerted. Since the previous e-mail was sent (Or if none have been sent, since checks against this server were started) there have been a total of $v_NUM_SUCCESSES_EMAIL successful checks, $v_NUM_PARTIAL_SUCCESSES_EMAIL partially successful checks, and $v_NUM_FAILURES_EMAIL failed checks.\n\nChecks have been running for $v_RUN_TIME. $v_TOTAL_CHECKS checks completed. $v_PERCENT_SUCCESSES% success rate.\n\nThis check took $v_CHECK_DURATION seconds to complete. The last ${#a_RECENT_DURATIONS[@]} checks took an average of $v_AVERAGE_RECENT_DURATION seconds to complete. The average successful check has taken $v_AVERAGE_SUCCESS_DURATION seconds to complete. The average check overall has taken $v_AVERAGE_DURATION seconds to complete.\n\nLogs related to this check:\n\n$( cat "$v_WORKINGDIR""$v_CHILD_PID"/log | grep -E -v "\] - (The HTML response code|Status: (Check (failed|succeeded)|Partial success) - Duration)" )"
	if [[ "$v_THIS_STATUS" == "intermittent failure" ]]; then
		fn_intermittent_failure_email
	elif [[ "$v_THIS_STATUS" == "success" ]]; then
		fn_success_email
	elif [[ "$v_THIS_STATUS" == "partial success" ]]; then
		fn_partial_success_email
	elif [[ "$v_THIS_STATUS" == "failure" ]]; then
		fn_failure_email
	fi
	if [[ $v_SENT == true ]]; then
	### Note the $v_SENT indicates any instance where an email WOULD HAVE BEEN sent whether or not it was sent
		### set the variables that prepare for the next message to be sent.
		v_NUM_SUCCESSES_EMAIL=0
		v_NUM_PARTIAL_SUCCESSES_EMAIL=0
		v_NUM_FAILURES_EMAIL=0
	fi
	unset v_MUTUAL_EMAIL v_SENT
}

function fn_success_email {
	### Determines if a success e-mail needs to be sent and, if so, sends that e-mail.
	### In order for mail to be sent here
		### If the last message was an intermittent fail, we need to have seen exactly $v_NUM_STATUSES_RECENT consecutive successes
		### Otherwise, we only need to have seen exactly $v_MAIL_DELAY consecutive successes
	if [[ $v_TOTAL_CHECKS != $v_MAIL_DELAY && "$v_LAST_EMAIL_SENT" != "success" ]]; then
		v_GO=false
		if [[ $v_SUCCESS_CHECKS -eq $v_MAIL_DELAY && "$v_LAST_EMAIL_SENT" != "intermittent" ]]; then
			v_GO=true
		elif [[ $v_SUCCESS_CHECKS -eq $v_NUM_STATUSES_RECENT && "$v_LAST_EMAIL_SENT" == "intermittent" ]]; then
			v_GO=true
		fi
		if [[ $v_GO == true ]]; then
			if [[ $v_SEND_MAIL == true && -n $v_EMAIL_ADDRESS ]]; then
				echo -e "$( if [[ -n $v_CUSTOM_MESSAGE ]]; then echo "$v_CUSTOM_MESSAGE\n\n"; fi )$v_DATE2 - LWmon - $v_URL_OR_PING $v_JOB_NAME - Status changed: Appears to be succeeding.\n\nYou're recieving this message to inform you that $v_SUCCESS_CHECKS consecutive check(s) against $v_URL_OR_PING $( if [[ "$v_JOB_NAME" == "$v_ORIG_JOB_NAME" ]]; then echo "$v_JOB_NAME"; else echo "$v_JOB_NAME ($v_ORIG_JOB_NAME)"; fi ) have succeeded, $v_MUTUAL_EMAIL" | "${a_MAIL_BIN[@]}" -s "LWmon - $v_URL_OR_PING $v_JOB_NAME - Check PASSED!" $v_EMAIL_ADDRESS && echo "$v_DATE2 - [$v_CHILD_PID] - $v_URL_OR_PING $v_ORIG_JOB_NAME: Success e-mail sent" >> "$v_LOG" &
			fi
			if [[ -n "${a_SCRIPT[0]}" && -f "${a_SCRIPT[0]}" && -x "${a_SCRIPT[0]}" ]]; then
				"${a_SCRIPT[@]}" success &
			fi
			v_LAST_EMAIL_SENT="success"
			v_SENT=true
			a_RECENT_STATUSES=()
		fi
	fi
}

function fn_partial_success_email {
	### Determines if a failure e-mail needs to be sent and, if so, sends that e-mail.
	if [[ $v_PARTIAL_SUCCESS_CHECKS -eq $v_MAIL_DELAY && $v_TOTAL_CHECKS != $v_MAIL_DELAY && "$v_LAST_EMAIL_SENT" != "partial success" ]]; then
		if [[ $v_SEND_MAIL == true && -n $v_EMAIL_ADDRESS ]]; then
			echo -e "$( if [[ -n $v_CUSTOM_MESSAGE ]]; then echo "$v_CUSTOM_MESSAGE\n\n"; fi )$v_DATE2 - LWmon - $v_URL_OR_PING $v_JOB_NAME - Status changed: Appears to be succeeding in some regards but failing in others.\n\nYou're recieving this message to inform you that $v_MAIL_DELAY consecutive check(s) against $v_URL_OR_PING $( if [[ "$v_JOB_NAME" == "$v_ORIG_JOB_NAME" ]]; then echo "$v_JOB_NAME"; else echo "$v_JOB_NAME ($v_ORIG_JOB_NAME)"; fi ) have only been partially successful, $v_MUTUAL_EMAIL" | "${a_MAIL_BIN[@]}" -s "LWmon - $v_URL_OR_PING $v_JOB_NAME - Partial success" $v_EMAIL_ADDRESS && echo "$v_DATE2 - [$v_CHILD_PID] - $v_URL_OR_PING $v_ORIG_JOB_NAME: Partial Success e-mail sent" >> "$v_LOG" &
		fi
		if [[ -n "${a_SCRIPT[0]}" && -f "${a_SCRIPT[0]}" && -x "${a_SCRIPT[0]}" ]]; then
				"${a_SCRIPT[@]}" psuccess &
		fi
		v_LAST_EMAIL_SENT="partial success"
		v_SENT=true
	fi
}

function fn_intermittent_failure_email {
	### Determines if a internittent failure e-mail needs to be sent and, if so, sends that e-mail.
	### In order for an email to be sent here:
		### The last email has to have been declaring a success (Or there have been no emails yet)
		### At least $v_NUM_STATUSES_RECENT checks have to have occurred since the last success email (or since the start)
		### At least $v_NUM_STATUSES_NOT_SUCCESS of them have to have not been successes
		### $v_NUM_STATUSES_NOT_SUCCESS has to be greater than zero
		### There has to be an email address declared
		### The mail binary has to be present
	if [[ $v_LAST_EMAIL_SENT == "success" && $v_NUM_STATUSES_NOT_SUCCESS -gt 0 ]]; then
		if [[ $v_SEND_MAIL == true && -n $v_EMAIL_ADDRESS ]]; then
			echo -e "$( if [[ -n $v_CUSTOM_MESSAGE ]]; then echo "$v_CUSTOM_MESSAGE\n\n"; fi )$v_DATE2 - LWmon - $v_URL_OR_PING $v_JOB_NAME - Status changed: Appears to be failing intermittently.\n\nYou're recieving this message to inform you that $v_NUM_STATUSES_NOT_SUCCESS out of the last $v_NUM_STATUSES_RECENT checks against $v_URL_OR_PING $( if [[ "$v_JOB_NAME" == "$v_ORIG_JOB_NAME" ]]; then echo "$v_JOB_NAME"; else echo "$v_JOB_NAME ($v_ORIG_JOB_NAME)"; fi ) have not been fully successful, $v_MUTUAL_EMAIL\n\n" | "${a_MAIL_BIN[@]}" -s "LWmon - $v_URL_OR_PING $v_JOB_NAME - Check failing intermittently!" $v_EMAIL_ADDRESS && echo "$v_DATE2 - [$v_CHILD_PID] - $v_URL_OR_PING $v_ORIG_JOB_NAME: Failure e-mail sent" >> "$v_LOG" &
		fi
		if [[ -n "${a_SCRIPT[0]}" && -f "${a_SCRIPT[0]}" && -x "${a_SCRIPT[0]}" ]]; then
				"${a_SCRIPT[@]}" intermittent &
		fi
		v_LAST_EMAIL_SENT="intermittent"
		v_SENT=true
	fi
}

function fn_failure_email {
	### Determines if a failure e-mail needs to be sent and, if so, sends that e-mail.
	if [[ $v_FAILURE_CHECKS -eq $v_MAIL_DELAY && $v_TOTAL_CHECKS != $v_MAIL_DELAY && "$v_LAST_EMAIL_SENT" != "failure" ]]; then
		if [[ $v_SEND_MAIL == true && -n $v_EMAIL_ADDRESS ]]; then
			echo -e "$( if [[ -n $v_CUSTOM_MESSAGE ]]; then echo "$v_CUSTOM_MESSAGE\n\n"; fi )$v_DATE2 - LWmon - $v_URL_OR_PING $v_JOB_NAME - Status changed: Appears to be failing.\n\nYou're recieving this message to inform you that $v_MAIL_DELAY consecutive check(s) against $v_URL_OR_PING $( if [[ "$v_JOB_NAME" == "$v_ORIG_JOB_NAME" ]]; then echo "$v_JOB_NAME"; else echo "$v_JOB_NAME ($v_ORIG_JOB_NAME)"; fi ) have failed, $v_MUTUAL_EMAIL" | "${a_MAIL_BIN[@]}" -s "LWmon - $v_URL_OR_PING $v_JOB_NAME - Check FAILED!" $v_EMAIL_ADDRESS && echo "$v_DATE2 - [$v_CHILD_PID] - $v_URL_OR_PING $v_ORIG_JOB_NAME: Failure e-mail sent" >> "$v_LOG" &
		fi
		if [[ -n "${a_SCRIPT[0]}" && -f "${a_SCRIPT[0]}" && -x "${a_SCRIPT[0]}" ]]; then
				"${a_SCRIPT[@]}" failure &
		fi
		v_LAST_EMAIL_SENT="failure"
		v_SENT=true
	fi
}

function fn_check_mail_binary {
	### Check to see if an alternate mail binary has been set
	a_MAIL_BIN=()
	fn_read_conf ALT_MAIL master; v_ALT_MAIL="$v_RESULT"
	for word in $( echo "$v_ALT_MAIL" ); do
		a_ALT_MAIL[${#a_ALT_MAIL[@]}]="$word"
	done
	unset v_ALT_MAIL
	if [[ -z ${a_ALT_MAIL[0]} || ! -x "${a_ALT_MAIL[0]}" ]]; then
		unset a_ALT_MAIL
		if [[ -z $( which mail 2> /dev/null ) ]]; then
			v_SEND_MAIL=false
		else
			v_SEND_MAIL=true
			a_MAIL_BIN=( "$( which mail 2> /dev/null )" )
		fi
	else
		v_SEND_MAIL=true
		a_MAIL_BIN=( "${a_ALT_MAIL[@]}" )
	fi
}

function fn_convert_seconds {
### I really haven't wrapped my head around how this function I stole works, but it converts a number of seconds to hours, minutes, and seconds.
	((h=${1}/3600))
	### This is the part where it does some stuff.
	((m=(${1}%3600)/60))
	((s=${1}%60))
	### I'm really excited about this part here that does the thing.
	printf "%02d:%02d:%02d\n" $h $m $s
}

#======================#
#== Master Functions ==#
#======================#

function fn_master {
	### This is the loop for the master function.
	if [[ $v_RUNNING_STATE != "master" ]]; then
		echo "Master process already present. Exiting."
		exit 1
	fi
	### try to prevent the master process from exiting unexpectedly.
	trap fn_master_exit SIGINT SIGTERM SIGKILL
	fn_read_conf VERBOSITY master "$v_DEFAULT_VERBOSITY"; v_VERBOSITY="$v_RESULT"
	### Get rid of the save file (if there is one).
	if [[ -f "$v_WORKINGDIR"save ]]; then
		rm -f "$v_WORKINGDIR"save
	fi
	v_TIMESTAMP_FIVE_MINUTES=0
	v_TIMESTAMP_THIRTY_MINUTES=0
	if [[ "$v_WGET_BIN" == "false" ]]; then
		if [[ -n $v_DEFAULT_REMOTE_DIE_LIST ]]; then
			$v_CURL_BIN -Lsm 10 "$v_DEFAULT_REMOTE_DIE_LIST" > "$v_WORKINGDIR"die_list 2> /dev/null
		fi
		v_REMOTE_VERSION="$( $v_CURL_BIN -Lsm 10 http://lwmon.com/lwmon.sh 2> /dev/null | head -n 10 | grep -E "^v_VERSION" | cut -d "\"" -f2 )"
	else
		if [[ -n $v_DEFAULT_REMOTE_DIE_LIST ]]; then
			$v_WGET_BIN -q --timeout=10 -O "$v_WORKINGDIR"die_list "$v_DEFAULT_REMOTE_DIE_LIST" 2> /dev/null
		fi
		v_REMOTE_VERSION="$( $v_WGET_BIN -q --timeout=10 -O "/dev/stdout" http://lwmon.com/lwmon.sh 2> /dev/null | head -n 10 | grep -E "^v_VERSION" | cut -d "\"" -f2 )"
	fi
	fn_compare_version "http://wlmon.com/lwmon.sh" "color"
	fn_create_mini_script
	fn_check_mail_binary
	if [[ $v_SEND_MAIL == false ]]; then
		echo
		echo -e "\e[1;31mThe \"mail\" binary needs to be installed for lwmon to perform some of its functions. Monitoring jobs will not be able to send email allerts regarding changes of status.\e[00m"
		echo
	fi
	echo "$( date +%F" "%T" "%Z ) - [$$] - Starting the Master Process" >> "$v_LOG"
	while [[ 1 == 1 ]]; do

		### Every thirty minutes check to see what the current IP address is (thanks to VPN, this can change).
		if [[ $(( $( date +%s ) - 1800 )) -gt $v_TIMESTAMP_THIRTY_MINUTES ]]; then
			v_TIMESTAMP_THIRTY_MINUTES="$( date +%s )"
			if [[ "$v_WGET_BIN" == "false" ]]; then
				v_LOCAL_IP="$( $v_CURL_BIN -Lsm 10 http://ip.liquidweb.com/ 2> /dev/null )"
			else
				v_LOCAL_IP="$( $v_WGET_BIN -q --timeout=10 -O /dev/null http://ip.liquidweb.com/ 2> /dev/null )"
			fi
			if [[ -z $v_LOCAL_IP ]]; then
				v_LOCAL_IP="Not_Found"
			fi
			### Also, let's do getting rid of old processes here - there's no reason to do that every two seconds, and this already runs every half hour, so there's no need to create a separate timer for that.
			for v_OLD_CHILD in $( find "$v_WORKINGDIR" -maxdepth 1 -type d | rev | cut -d "/" -f1 | rev | grep -E "^old_[0-9]+_[0-9]+$" ); do
				if [[ $( echo $v_OLD_CHILD | grep -E -c "^old_[[:digit:]]*_[[:digit:]]*$" ) -eq 1 ]]; then
					if [[ $(( $( date +%s ) - $( echo $v_OLD_CHILD | cut -d "_" -f3 ) )) -gt 604800 ]]; then
						### 604800 seconds = seven days.
						fn_read_conf JOB_TYPE "$v_WORKINGDIR""$v_OLD_CHILD""/params"; v_JOB_TYPE="$v_RESULT"
						fn_read_conf JOB_NAME "$v_WORKINGDIR""$v_OLD_CHILD""/params"; v_JOB_NAME="$v_RESULT"
						echo "$( date +%F" "%T" "%Z ) - [$( echo "$v_OLD_CHILD" | cut -d "_" -f2)] - $v_JOB_TYPE $v_JOB_NAME - Child process dead for seven days. Deleting backed up data." >> "$v_LOG"
						rm -rf "$v_WORKINGDIR""$v_OLD_CHILD"
					fi
				fi
			done
		fi

		### Every five minutes, check a remote list to see if lwmon should be stopped, and check to see if old processes need to be backed up.
		if [[ $(( $( date +%s ) - 300 )) -gt $v_TIMESTAMP_FIVE_MINUTES ]]; then
			v_TIMESTAMP_FIVE_MINUTES="$( date +%s )"
			if [[ -n $v_DEFAULT_REMOTE_DIE_LIST && "$v_WGET_BIN" == "false" ]]; then
				$v_CURL_BIN -Lsm 10 "$v_DEFAULT_REMOTE_DIE_LIST" > "$v_WORKINGDIR"die_list 2> /dev/null
			elif [[ -n $v_DEFAULT_REMOTE_DIE_LIST ]]; then
				$v_WGET_BIN -q --timeout=10 -O "$v_WORKINGDIR"die_list "$v_DEFAULT_REMOTE_DIE_LIST" 2> /dev/null
			fi
			if [[ $( grep -E -c "^[[:blank:]]*$v_LOCAL_IP[[:blank:]]*(#.*)*$" "$v_WORKINGDIR"die_list ) -gt 0 ]]; then
				touch "$v_WORKINGDIR"die
				touch "$v_WORKINGDIR"save
				echo "$( date +%F" "%T" "%Z ) - [$$] - Local IP found on remote list. The line reads \"$( grep -E "^[[:blank:]]*$v_LOCAL_IP[[:blank:]]*(#.*)*$" "$v_WORKINGDIR"die_list | head -n1 )\". Process ended." >> "$v_LOG"
				fn_master_exit 1
			fi
			### Go through the directories for child processes. Make sure that each one is associated with a running child process. If not....
			for v_CHILD_PID in $( find "$v_WORKINGDIR" -maxdepth 1 -type d | rev | cut -d "/" -f1 | rev | grep -E "^[0-9]+$" ); do
				if [[ $( cat /proc/$v_CHILD_PID/cmdline 2> /dev/null | tr "\0" " " | grep -E -c "$v_PROGRAMNAME[[:blank:]]" ) -eq 0 ]]; then
					### If it hasn't been marked to die, restart it.
					if [[ ! -f "$v_WORKINGDIR""$v_CHILD_PID/die" ]]; then
						fn_read_conf JOB_TYPE child; v_JOB_TYPE="$v_RESULT"
						fn_read_conf JOB_NAME child; v_JOB_NAME="$v_RESULT"
						echo "$( date +%F" "%T" "%Z ) - [$v_CHILD_PID] - $v_JOB_TYPE $v_JOB_NAME - Child process was found dead. Restarting with new PID." >> "$v_LOG"
						v_NEW_JOB="$( date +%s )""_$RANDOM.job"
						cp -a "$v_WORKINGDIR""$v_CHILD_PID"/params "$v_WORKINGDIR""new/$v_NEW_JOB.job"
						if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/log ]]; then
							### If there's a log file, let's keep that too.
							cp -a "$v_WORKINGDIR""$v_CHILD_PID"/log "$v_WORKINGDIR""new/$v_NEW_JOB".log
						fi
					fi
					### Regardless of whether or not it's been marked to die, back it up.
					v_TIMESTAMP="$( date +%s )"
					mv "$v_WORKINGDIR""$v_CHILD_PID" "$v_WORKINGDIR""old_""$v_CHILD_PID""_""$v_TIMESTAMP"
				fi
			done
		fi

		### Every Two Seconds, check if there are any new files within the new/ directory. Assume that they're params files for new jobs
		if [[ $( ls -1 "$v_WORKINGDIR"new/*.job 2> /dev/null | wc -l ) -gt 0 ]]; then
		### If there are any at all, take the first one and start a job from it. The next one can wait for the next loop.
			v_LWMON_JOB="$( ls -1 "$v_WORKINGDIR"new/*.job 2> /dev/null | head -n1 )"
			fn_read_conf JOB_TYPE "$v_LWMON_JOB"; v_JOB_TYPE="$v_RESULT"
			fn_read_conf JOB_NAME "$v_LWMON_JOB"; v_JOB_NAME="$v_RESULT"
			if [[ $v_JOB_TYPE == "url" ]]; then
				v_JOB_NAME="URL $v_JOB_NAME"
				fn_spawn_child_process
			elif [[ $v_JOB_TYPE == "ping" ]]; then
				v_JOB_NAME="PING $v_JOB_NAME"
				fn_spawn_child_process
			elif [[ $v_JOB_TYPE == "dns" ]]; then
				v_JOB_NAME="DNS $v_JOB_NAME"
				fn_spawn_child_process
			elif [[ $v_JOB_TYPE == "ssh-load" ]]; then
				v_JOB_NAME="SSH-LOAD $v_JOB_NAME"
				fn_spawn_child_process
			fi
		else
			if [[ $( ls -1 "$v_WORKINGDIR""new/" | wc -l ) -gt 0 ]]; then
				rm -f "$v_WORKINGDIR"new/*
			fi
		fi
		### Is there a file named "die" in the working directory? If so, end the master process.
		if [[ -f "$v_WORKINGDIR"die ]]; then
			fn_master_exit 0
		fi
		sleep 2
	done
}

function fn_compare_version {
### Function Version 1.1.2
### "$1" is the remote URL of the script. "$2" is "run" if a newer version should be run automatically, "color" if we should alert the user in color, and "plain" if we should alert the user with plain text. "plain" is assumed if none of these values are set.
### The "run" functionality assumes that "${a_CL_ARGUMENTS[@]}" is populated with the command line arguments of the current run. It also assumes that the string "End of Script" is within the last 10 lines of the script.
### This function can optionally make use of the fn_timeout function.
	### Check to see if a newer version of the script is available; report if that's the case.
	v_PROGRAMDIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd | sed "s/\([^/]\)$/\1\//" )"
	v_PROGRAMNAME="$( basename "${BASH_SOURCE[0]}" )"
	v_SCRIPT_URL="$1"
	if [[ ! -f "${HOME:-$v_PROGRAMDIR}/.$v_PROGRAMNAME"".version_check" || $(( $(date +%s) - $( stat --format=%Y "${HOME:-$v_PROGRAMDIR}/.$v_PROGRAMNAME"".version_check" ) )) -gt 7200 ]]; then
		if [[ "$2" == "run" && "$( type -t timeout )" == "file" ]]; then
			timeout 5 wget -q -o /dev/null --timeout=3 -O "$v_PROGRAMDIR""$v_PROGRAMNAME"1 "$v_SCRIPT_URL"
			v_REMOTE_VERSION="$( head -n 10 "$v_PROGRAMDIR""$v_PROGRAMNAME"1 2> /dev/null | grep -E "^(my .)*v_VERSION" | cut -d "\"" -f2 )"
		elif [[ "$( type -t timeout )" == "file" ]]; then
			v_REMOTE_VERSION="$( timeout 5 wget -q -o /dev/null --timeout=3 -O "/dev/stdout" "$v_SCRIPT_URL" | head -n 10 | grep -E "^(my .)*v_VERSION" | cut -d "\"" -f2 )"
		elif [[ "$2" == "run" && "$( type -t fn_timeout )" == "function" ]]; then
			fn_timeout 5 wget -q -o /dev/null --timeout=3 -O "$v_PROGRAMDIR""$v_PROGRAMNAME"1 "$v_SCRIPT_URL" 
			v_REMOTE_VERSION="$( head -n 10 "$v_PROGRAMDIR""$v_PROGRAMNAME"1 2> /dev/null | grep -E "^(my .)*v_VERSION" | cut -d "\"" -f2 )"
		elif [[ "$( type -t fn_timeout )" == "function" ]]; then
			v_REMOTE_VERSION="$( fn_timeout 5 wget -q -o /dev/null --timeout=3 -O "/dev/stdout" "$v_SCRIPT_URL" | head -n 10 | grep -E "^(my .)*v_VERSION" | cut -d "\"" -f2 )"
		elif [[ "$2" == "run" ]]; then
			wget -q -o /dev/null --timeout=3 -O "$v_PROGRAMDIR""$v_PROGRAMNAME"1 "$v_SCRIPT_URL" 
			v_REMOTE_VERSION="$( head -n 10 "$v_PROGRAMDIR""$v_PROGRAMNAME"1 2> /dev/null | grep -E "^(my .)*v_VERSION" | cut -d "\"" -f2 )"
		else
			v_REMOTE_VERSION="$( wget -q -o /dev/null --timeout=3 -O "/dev/stdout" "$v_SCRIPT_URL" | head -n 10 | grep -E "^(my .)*v_VERSION" | cut -d "\"" -f2 )"
		fi
		if [[ -n "$v_REMOTE_VERSION" ]]; then
			if [[ ( "$2" == "run" && $( tail -n 10 "$v_PROGRAMDIR""$v_PROGRAMNAME"1 2> /dev/null | grep -E -c "^### End of Script" ) -eq 1 ) || "$2" != "run" ]]; then
			### If the version number is present and the last line of the script is present...
				if [[ $( echo "$v_REMOTE_VERSION" | cut -d "." -f1 ) -gt $( echo "$v_VERSION" | cut -d "." -f1 ) ]]; then
					v_UPDATE=true
				elif [[ $( echo "$v_REMOTE_VERSION" | cut -d "." -f1 ) -eq $( echo "$v_VERSION" | cut -d "." -f1 ) && $( echo "$v_REMOTE_VERSION" | cut -d "." -f2 ) -gt $( echo "$v_VERSION" | cut -d "." -f2 ) ]]; then
					v_UPDATE=true
				elif [[ $( echo "$v_REMOTE_VERSION" | cut -d "." -f1 ) -eq $( echo "$v_VERSION" | cut -d "." -f1 ) && $( echo "$v_REMOTE_VERSION" | cut -d "." -f2 ) -eq $( echo "$v_VERSION" | cut -d "." -f2 ) && $( echo "$v_REMOTE_VERSION" | cut -d "." -f3 ) -gt $( echo "$v_VERSION" | cut -d "." -f3 ) ]]; then
					v_UPDATE=true
				fi
				if [[ $v_UPDATE == true && "$2" == "run" ]]; then
					mv -f "$v_PROGRAMDIR""$v_PROGRAMNAME"1 "$v_PROGRAMDIR""$v_PROGRAMNAME"
					chmod +x "$v_PROGRAMDIR""$v_PROGRAMNAME"
					echo 
					echo "Downloaded a newer version of $v_PROGRAMNAME."
					echo
					"$v_PROGRAMDIR""$v_PROGRAMNAME" "${a_CL_ARGUMENTS[@]}" --no-version-check
					exit $?
				elif [[ $v_UPDATE == true && "$2" = "color" ]]; then
					echo
					echo -e "\e[1;31mThere is a newer version of $v_PROGRAMNAME available at $1""\e[00m"
					echo
				elif [[ $v_UPDATE == true ]]; then
					echo
					echo "--------There is a newer version of $v_PROGRAMNAME available at $1""--------"
					echo
				else
					rm -f "$v_PROGRAMDIR""$v_PROGRAMNAME"1
				fi
			fi
			touch "${HOME:-$v_PROGRAMDIR}/.$v_PROGRAMNAME"".version_check"
		fi
	fi
}


### Version Information for fn_timeout
### Version 1.0.0 - 
###      Original version

function fn_timeout { (
### Function Version 1.0.0
### This function expects $1 to be a number of seconds. Optionally $2 can be "--verbose" for verbose output.
	v_VERBOSE=false
	if [[ $( echo "$1" | grep -E -c "^[0-9]+$" ) -eq 1 ]]; then
		v_SECONDS="$1"
		shift
	else
		v_SECONDS=10
	fi
	if [[ "$1" == "--verbose" ]]; then
		v_VERBOSE=true
		shift
	fi
	a_CL_ARGUMENTS=( "$@" )
	a_CL_ARGUMENTS[0]="$( which ${a_CL_ARGUMENTS[0]} )"
	if [[ -n ${a_CL_ARGUMENTS[0]} ]]; then
		"${a_CL_ARGUMENTS[@]}" &
		v_PID=$!
		v_TIMESTAMP1=$( date +%s )
		v_TIMESTAMP2=$( date +%N )
		if [[ -n $v_PID ]]; then
			while [[ -e /proc/$v_PID/cmdline && -z $( grep -E -v "^${a_CL_ARGUMENTS[0]}" /proc/$v_PID/cmdline > /dev/null 2>&1 ) ]]; do
				if [[ "$(( $v_TIMESTAMP1 + $v_SECONDS ))$v_TIMESTAMP2" -lt "$( date +%s )$( date +%N )" ]]; then
					if [[ $v_VERBOSE == true ]]; then
						echo "killing"
					fi
					kill $v_PID > /dev/null 2>&1
					wait $v_PID 2> /dev/null
					break
				else
					if [[ $v_VERBOSE == true ]]; then
						echo "sleeping"
					fi
					sleep 0.1
				fi
			done
		fi
	elif [[ $v_VERBOSE == true ]]; then
		echo "Command is not a recognized"
	fi
) }

function fn_create_mini_script {
	v_MINI_VERSION="$( head -n 10 $v_MINI_SCRIPT 2> /dev/null | grep -E "^v_VERSION" | cut -d "\"" -f2 )"
	if [[ $v_VERSION != $v_MINI_VERSION || $v_TESTING == true ]]; then
		echo "#! /bin/bash" > "$v_MINI_SCRIPT"
		echo "v_VERSION=\"$v_VERSION\"" >> "$v_MINI_SCRIPT"

		type fn_set_defaults | tail -n +2  >> "$v_MINI_SCRIPT"
		type fn_child | tail -n +2  >> "$v_MINI_SCRIPT"
		type fn_child_vars | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_read_conf | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_test_variable | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_test_file | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_child_dates | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_url_child | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_ping_child | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_dns_child | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_load_child | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_child_checks | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_child_exit | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_report_status | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_send_email | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_success_email | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_partial_success_email | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_intermittent_failure_email | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_failure_email | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_start_script | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_use_wget | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_parse_server | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_check_mail_binary | tail -n +2 >> "$v_MINI_SCRIPT"
		type fn_convert_seconds | tail -n +2 >> "$v_MINI_SCRIPT"

		echo "v_RUNNING_STATE=\"child\"" >> "$v_MINI_SCRIPT"
		echo "fn_start_script" >> "$v_MINI_SCRIPT"
		echo 'if [[ -n $1 ]]; then fn_child; fi' >> "$v_MINI_SCRIPT"
		chmod +x "$v_MINI_SCRIPT"
	fi
}

function fn_spawn_child_process {
	### This function launches the child process and makes sure that it has it's own working directory.
	### Launch the child process
	"$v_MINI_SCRIPT" $v_JOB_NAME &
	### Note - the job name doesn't need to be present, but it makes ps more readable. Each child process starts out as generic. Once the master process creates a working directory for it (based on its PID) and then puts the params file in place for it, only then does it discover its purpose.
	### create the child's wirectory and move the params file there.
	v_CHILD_PID=$!
	mkdir -p "$v_WORKINGDIR""$v_CHILD_PID"
	touch "$v_WORKINGDIR""$v_CHILD_PID/#die"
	mv "$v_LWMON_JOB" "$v_WORKINGDIR""$v_CHILD_PID""/params"
	if [[ -f "${v_LWMON_JOB[@]%.job}".log ]]; then
	### If there's a log file, let's move that log file into the appropriate directory as well.
		mv "${v_LWMON_JOB[@]%.job}".log "$v_WORKINGDIR""$v_CHILD_PID""/log"
	fi
}

function fn_master_exit {
	### these steps are run after the master process has recieved a signal that it needs to die. "$1" is the exit code that should be passed.
	v_EXIT_CODE="$1"
	echo "$( date +%F" "%T" "%Z ) - [$$] - Ending the Master Process" >> "$v_LOG"
	if [[ ! -f "$v_WORKINGDIR"die && $( find $v_WORKINGDIR -maxdepth 1 -type d | rev | cut -d "/" -f1 | rev | grep -E "." | grep -E -vc "[^0-9]" ) -gt 0 ]]; then
		### If the "die" file is not present, it was CTRL-C'd from the command line. Check if there are child processes, then prompt if they should be saved.
		### Create a no_output file
		touch "$v_WORKINGDIR"no_output
		echo "Options:"
		echo
		echo "  1) Kill the master process and all child processes."
		echo "  2) Back up the data for the child processes so that they'll start again next time LWmon is run, then kill the master process and all child processes."
		echo
		read -t 15 -ep "How would you like to proceed? " v_OPTION_NUM
		# If they've opted to kill off all the current running processes, place a "die" file in each of their directories.
		if [[ $v_OPTION_NUM == "1" ]]; then
			for i in $( find $v_WORKINGDIR -maxdepth 1 -type d | rev | cut -d "/" -f1 | rev | grep -E "." | grep -E -v "[^0-9]" ); do
				v_CHILD_PID=$( basename $i )
				if [[ $( cat /proc/$v_CHILD_PID/cmdline 2> /dev/null | tr "\0" " " | grep -E -c "$v_PROGRAMNAME[[:blank:]]" ) -gt 0 ]]; then
					touch "$v_WORKINGDIR""$v_CHILD_PID/die"
				fi
			done
		elif [[ -z $v_OPTION_NUM ]]; then
			echo
		fi
	elif [[ -f "$v_WORKINGDIR"die && ! -f "$v_WORKINGDIR"save ]]; then
		for i in $( find $v_WORKINGDIR -maxdepth 1 -type d | rev | cut -d "/" -f1 | rev | grep -E "." | grep -E -v "[^0-9]" ); do
			v_CHILD_PID=$( basename $i )
			if [[ $( cat /proc/$v_CHILD_PID/cmdline 2> /dev/null | tr "\0" " " | grep -E -c "$v_PROGRAMNAME[[:blank:]]" ) -gt 0 ]]; then
				touch "$v_WORKINGDIR""$v_CHILD_PID/die"
			fi
		done
	fi
	rm -f "$v_WORKINGDIR"lwmon.pid "$v_WORKINGDIR"die
	exit $v_EXIT_CODE
}

#=============================#
#== Other Control Functions ==#
#=============================#

function fn_list {
	### This just lists the lwmon master process and all child processes.
	if [[ $v_RUNNING_STATE == "master" ]]; then
		echo "No current lwmon processes. Exiting."
		exit 1
	fi
	echo "List of currently running lwmon processes:"
	echo
	echo "  1) [$( cat "$v_WORKINGDIR"lwmon.pid )] - Master Process (and lwmon in general)" #"
	v_CHILD_NUMBER=2
	a_CHILD_PID=()
	for v_CHILD_PID in $( find "$v_WORKINGDIR" -maxdepth 1 -type d | rev | cut -d "/" -f1 | rev | grep -E "." | grep -E -v "[^0-9]" ); do
		### The params files here have to be referenced rather than just the word "child" Otherwise, it will reuse the same set of variables throughout the loop.
		fn_read_conf JOB_NAME "$v_WORKINGDIR""$v_CHILD_PID/params"; v_JOB_NAME="$v_RESULT"
		fn_read_conf JOB_TYPE "$v_WORKINGDIR""$v_CHILD_PID/params"; v_JOB_TYPE="$v_RESULT"
		echo "  $v_CHILD_NUMBER) [$v_CHILD_PID] - $v_JOB_TYPE $v_JOB_NAME"
		a_CHILD_PID[$(( $v_CHILD_NUMBER - 2 ))]="$v_CHILD_PID"
		v_CHILD_NUMBER=$(( $v_CHILD_NUMBER + 1 ))
	done
}

function fn_modify_master {
### Options for the master process
	echo -e "Options:\n"
	echo "  1) Exit out of the master process without backing up the child processes."
	echo "  2) First back-up the child processes so that they'll run immediately when lwmon is next started, then exit out of the master process."
	echo "  3) Edit the configuration file."
	echo "  4) View the log file."
	echo "  5) Old monotoring jobs."
	echo "  6) Exit out of this menu."
	echo
	read -ep "Choose an option from the above list: " v_OPTION_NUM
	if [[ $v_OPTION_NUM == "1" ]]; then
		touch "$v_WORKINGDIR"die
	elif [[ $v_OPTION_NUM == "2" ]]; then
		touch "$v_WORKINGDIR"save
		touch "$v_WORKINGDIR"die
	elif [[ $v_OPTION_NUM == "3" ]]; then
		if [[ -n $EDITOR ]]; then
			$EDITOR "$v_WORKINGDIR""lwmon.conf"
		else
			vi "$v_WORKINGDIR""lwmon.conf"
		fi
	elif [[ $v_OPTION_NUM == "4" ]]; then
		echo "Viewing the log at $v_LOG"
		less +G "$v_LOG"
	elif [[ $v_OPTION_NUM == "5" ]]; then
		fn_modify_old_jobs
	else
		echo "Exiting."
	fi
	exit 0
}

function fn_modify_no_master {
### Options if there is no master process
	echo -e "Options:\n"
	echo "  1) Output general help information (same as with \"--help\" flag)."
	echo "  2) Output help information specific to flags (same as with \"--help-flags\" flag)."
	echo "  3) Edit the configuration file."
	echo "  4) View the log file."
	echo "  5) Launch a master process (same as with \"--master\" flag)."
	echo "  6) Old monotoring jobs."
	echo "  7) Exit out of this menu."
	echo
	read -ep "Choose an option from the above list: " v_OPTION_NUM
	if [[ $v_OPTION_NUM == "1" ]]; then
		fn_help
	elif [[ $v_OPTION_NUM == "2" ]]; then
		fn_help_flags
	elif [[ $v_OPTION_NUM == "3" ]]; then
		if [[ -n $EDITOR ]]; then
			$EDITOR "$v_WORKINGDIR""lwmon.conf"
		else
			vi "$v_WORKINGDIR""lwmon.conf"
		fi
	elif [[ $v_OPTION_NUM == "4" ]]; then
		echo "Viewing the log at $v_LOG"
		less +G "$v_LOG"
	elif [[ $v_OPTION_NUM == "5" ]]; then
		fn_master
	elif [[ $v_OPTION_NUM == "6" ]]; then
		fn_modify_old_jobs
	else
		echo "Exiting."
	fi
	exit 0
}

function fn_modify_old_jobs {
	### This is the menu front-end for modifying old child processes.
	echo "List of old lwmon jobs:"
	echo
	v_CHILD_NUMBER=1
	a_CHILD_PID=()
	for v_CHILD_PID in $( find "$v_WORKINGDIR" -maxdepth 1 -type d | rev | cut -d "/" -f1 | rev | grep -E "old_[0-9]*_[0-9]*" | awk -F_ '{print $3"_"$2"_"$1}' | sort -n | awk -F_ '{print $3"_"$2"_"$1}' ); do
		v_ENDED_DATE="$( echo "$v_CHILD_PID" | cut -d "_" -f3 )"
		v_ENDED_DATE="$( date --date="@$v_ENDED_DATE" +%m"/"%d" "%H":"%M":"%S )"
		### The params files here have to be referenced rather than just the word "child" Otherwise, it will reuse the same set of variables throughout the loop.
		fn_read_conf JOB_NAME "$v_WORKINGDIR""$v_CHILD_PID/params"; v_JOB_NAME="$v_RESULT"
		fn_read_conf JOB_TYPE "$v_WORKINGDIR""$v_CHILD_PID/params"; v_JOB_TYPE="$v_RESULT"
		echo "  $v_CHILD_NUMBER) $v_JOB_TYPE $v_JOB_NAME (ended $v_ENDED_DATE)"
		a_CHILD_PID[$(( $v_CHILD_NUMBER - 1 ))]="$v_CHILD_PID"
		v_CHILD_NUMBER=$(( $v_CHILD_NUMBER + 1 ))
	done
	if [[ ${#a_CHILD_PID[@]} -eq 0 ]]; then
		echo "There are no old jobs. Exiting."
		echo
		exit 1
	fi
	echo
	read -ep "Which process do you want to modify? " v_CHILD_NUMBER
	if [[ "$v_CHILD_NUMBER" == "0" || $( echo "$v_CHILD_NUMBER" | grep -E -vc "[^0-9]" ) -eq 0 || "$v_CHILD_NUMBER" -ge $(( ${#a_CHILD_PID[@]} + 1 )) ]]; then
		echo "Invalid Option. Exiting."
		exit 1
	fi
	v_CHILD_PID="${a_CHILD_PID[$(( $v_CHILD_NUMBER - 1 ))]}"
	fn_read_conf JOB_NAME child; v_JOB_NAME="$v_RESULT"
	echo "$v_JOB_NAME:"
	echo
	echo "  1) Delete this monitoring job."
	echo "  2) Output the command to go to the working directory for this monitoring job."
	echo "  3) Restart this monitoring job"
	echo "  4) View the log file associated with this monitoring job."
	echo "  5) Output the commands to reproduce this job."
	echo "  6) Change the end stamp on this job (stop it from being auto-deleted until 7 days from now)"
	echo "  7) View associated html files (if any)."
	echo "  8) Exit out of this menu."
	echo
	read -ep "Chose an option from the above list: " v_OPTION_NUM
if [[ $v_OPTION_NUM == "1" && -n "$v_WORKINGDIR" && -n "$v_CHILD_PID" ]]; then
		rm -rf "$v_WORKINGDIR""$v_CHILD_PID"
		echo "This job has been parmanently removed."
	elif [[ $v_OPTION_NUM == "2" ]]; then
		echo -en "\ncd $v_WORKINGDIR""$v_CHILD_PID/\n\n"
	elif [[ $v_OPTION_NUM == "3" ]]; then
		v_NEW_JOB="$( date +%s )""_$RANDOM.job"
		cp -a "$v_WORKINGDIR""$v_CHILD_PID"/params "$v_WORKINGDIR""new/$v_NEW_JOB.job"
		if [[ -f "$v_WORKINGDIR""$v_CHILD_PID"/log ]]; then
			### If there's a log file, let's keep that too.
			cp -a "$v_WORKINGDIR""$v_CHILD_PID"/log "$v_WORKINGDIR""new/$v_NEW_JOB".log
		fi
	elif [[ "$v_OPTION_NUM" == "4" ]]; then
		echo "Viewing the log at $v_WORKINGDIR""$v_CHILD_PID/log"
		less +G "$v_WORKINGDIR""$v_CHILD_PID/log"
	elif [[ "$v_OPTION_NUM" == "5" ]]; then
		echo
		echo "wget -O ./lwmon.sh http://lwmon.com/lwmon.sh"
		echo "chmod +x ./lwmon.sh"
		echo "./lwmon.sh $( cat "$v_WORKINGDIR""$v_CHILD_PID/cl" )"
		echo
	elif [[ "$v_OPTION_NUM" == "6" && -n "$v_WORKINGDIR" && -n "$v_CHILD_PID" ]]; then
		v_NEW_DIRECTORY="$( basename $i | awk -F_ '{print $1"_"$2}' )_$( date +%s )"
		mv -f "$v_WORKINGDIR""$v_CHILD_PID" "$v_WORKINGDIR""$v_NEW_DIRECTORY"
	elif [[ "$v_OPTION_NUM" == "7" ]]; then
		fn_modify_html
	else
		echo "Exiting."
	fi
	exit 0
}

function fn_modify_html {
### Lists html files associated with a process and then gives options for them.
	echo "List of html files associated with $v_JOB_NAME"
	echo
	v_HTML_NUMBER=1
	a_HTML_LIST=()
	for v_HTML_NAME in $( find "$v_WORKINGDIR""$v_CHILD_PID" -maxdepth 1 -type f | rev | cut -d "/" -f1 | rev | grep -E "(success|fail)\.html$" | awk -F_ '{print $2"_"$3"_"$1}' | sort -n | awk -F_ '{print $3"_"$1"_"$2}' ); do
		v_HTML_TIMESTAMP="$( echo "$v_HTML_NAME" | grep -E -o "[0-9]+_[psf]" | cut -d "_" -f1 )"
		v_HTML_TIMESTAMP="$( date --date="@$v_HTML_TIMESTAMP" +%m"/"%d" "%H":"%M":"%S )"
		### The params files here have to be referenced rather than just the word "child" Otherwise, it will reuse the same set of variables throughout the loop.
		echo "  $v_HTML_NUMBER) $v_HTML_TIMESTAMP - $v_HTML_NAME"
		a_HTML_LIST[$(( $v_HTML_NUMBER - 1 ))]="$v_HTML_NAME"
		v_HTML_NUMBER=$(( $v_HTML_NUMBER + 1 ))
	done
	echo
	if [[ ${#a_HTML_LIST[@]} -eq 0 ]]; then
		echo "There are no html files associated with this job. Exiting."
		exit 1
	fi
	read -ep "Which html file do you want options on? " v_HTML_NUMBER
	if [[ "$v_HTML_NUMBER" == "0" || $( echo "$v_HTML_NUMBER" | grep -E -vc "[^0-9]" ) -eq 0 || "$v_HTML_NUMBER" -ge $(( ${#a_HTML_LIST[@]} + 1 )) ]]; then
		echo "Invalid Option. Exiting."
		exit 1
	fi
	v_HTML_NAME="${a_HTML_LIST[$(( $v_HTML_NUMBER - 1 ))]}"
	echo "$v_HTML_NAME:"
	echo
	echo "  1) Delete this file."
	echo "  2) Output the full file name."
	echo "  3) Exit out of this menu."
	echo
	read -ep "Chose an option from the above list: " v_OPTION_NUM
	if [[ $v_OPTION_NUM == "1" && -n "$v_WORKINGDIR" && -n "$v_CHILD_PID" && "$v_HTML_NAME" ]]; then
		rm -f "$v_WORKINGDIR""$v_CHILD_PID"/"$v_HTML_NAME"
		echo "The file has been deleted."
	elif [[ $v_OPTION_NUM == "2" ]]; then
		echo
		echo "$v_WORKINGDIR""$v_CHILD_PID"/"$v_HTML_NAME"
		echo
	else
		echo "Exiting."
	fi
	exit 0
}

function fn_modify {
### lists the lwmon processes and then gives options for the currently running processes.
	if [[ $v_RUNNING_STATE == "master" ]]; then
		fn_modify_no_master
	fi
	fn_list
	echo
	read -ep "Which process do you want to modify? " v_CHILD_NUMBER
	if [[ "$v_CHILD_NUMBER" == "0" || $( echo "$v_CHILD_NUMBER" | grep -E -vc "[^0-9]" ) -eq 0 || "$v_CHILD_NUMBER" -ge $(( ${#a_CHILD_PID[@]} + 2 )) ]]; then
		echo "Invalid Option. Exiting."
		exit 1
	fi
	if [[ $v_CHILD_NUMBER -lt 2 ]]; then
		fn_modify_master
	fi
	v_CHILD_PID="${a_CHILD_PID[$(( $v_CHILD_NUMBER - 2 ))]}"
	fn_read_conf JOB_NAME child; v_JOB_NAME="$v_RESULT"
	echo "$v_JOB_NAME:"
	echo
	echo "  1) Kill this process."
	echo "  2) Output the command to go to the working directory for this process."
	echo "  3) Directly edit the parameters file (with your EDITOR - \"$EDITOR\")."
	echo "  4) View the log file associated with this process."
	echo "  5) Output the commands to reproduce this job."
	echo "  6) Change the title of the job as it's reported by the child process. (Currently \"$v_JOB_NAME\")."
	echo "  7) Show the most recent full status output for the job."
	echo "  8) View associated html files (if any)."
	echo "  9) Exit out of this menu."
	echo
	read -ep "Chose an option from the above list: " v_OPTION_NUM
	if [[ $v_OPTION_NUM == "1" ]]; then
		touch "$v_WORKINGDIR""$v_CHILD_PID/die"
		echo "Process will exit out shortly."
	elif [[ $v_OPTION_NUM == "2" ]]; then
		echo -en "\ncd $v_WORKINGDIR""$v_CHILD_PID/\n\n"
	elif [[ $v_OPTION_NUM == "3" ]]; then
		cp -a "$v_WORKINGDIR""$v_CHILD_PID/params" "$v_WORKINGDIR""$v_CHILD_PID/params.temp"
		if [[ -n $EDITOR ]]; then
			$EDITOR "$v_WORKINGDIR""$v_CHILD_PID/params"
		else
			vi "$v_WORKINGDIR""$v_CHILD_PID/params"
		fi
		rm -f "$v_WORKINGDIR""$v_CHILD_PID/params.temp"
	elif [[ "$v_OPTION_NUM" == "4" ]]; then
		echo "Viewing the log at $v_WORKINGDIR""$v_CHILD_PID/log"
		less +G "$v_WORKINGDIR""$v_CHILD_PID/log"
	elif [[ "$v_OPTION_NUM" == "5" ]]; then
		echo
		echo "wget -O ./lwmon.sh http://lwmon.com/lwmon.sh"
		echo "chmod +x ./lwmon.sh"
		echo "./lwmon.sh $( cat "$v_WORKINGDIR""$v_CHILD_PID/cl" )"
		echo
	elif [[ "$v_OPTION_NUM" == "6" ]]; then
		read -ep "Enter a new identifying string to associate with this check: " v_JOB_NAME
		fn_update_conf JOB_NAME "$v_JOB_NAME" "$v_WORKINGDIR""$v_CHILD_PID/params"
		echo "The job name has been updated."
	elif [[ "$v_OPTION_NUM" == "7" ]]; then
		if [[ ! -f "$v_WORKINGDIR""$v_CHILD_PID"/'#status' ]]; then
			echo -e "\nData not yet available. Prompting for output."
			touch "$v_WORKINGDIR""$v_CHILD_PID"/status
			while [[ ! -f "$v_WORKINGDIR""$v_CHILD_PID"/'#status' ]]; do
				sleep 1
			done
		fi
		echo
		cat "$v_WORKINGDIR""$v_CHILD_PID"/'#status'
		echo
	elif [[ "$v_OPTION_NUM" == "8" ]]; then
		fn_modify_html
	else
		echo "Exiting."
	fi
	exit 0
}

#============================================#
#== Functions related to the configuration ==#
#============================================#

function fn_read_conf {
	### This function reads an item from the conf file. It expects $1 to be the name of the directive, $2 to be the name of the configuration file (or "master' or "child"), and $3 to be the result if nothing is pulled from the conf. If $4 has the value of "multi" then all instances of $1 in the conf will be assigned to an array.
	unset v_RESULT a_RESULT
	### The pattern being searched for in the conf is:
	### ^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[^[:blank:]][^[:blank:]]*
	### The start of the line, followed by any number of blank characters, followed by the directive that we're looking for, followed by any number of blank characters, followed by an equal sign, followed by any number of blank characters, followed by at least one non-blank character.
	if [[ $2 == "child" && -f "$v_WORKINGDIR""$v_CHILD_PID/params" ]]; then
		if [[ "$( stat --format=%Y "$v_WORKINGDIR""$v_CHILD_PID/params" )" -gt "$v_CHILD_CONF_STAT" ]]; then
		### Only re-read the conf file if there have been changes to it.
			v_CHILD_CONF_STAT="$( stat --format=%Y "$v_WORKINGDIR""$v_CHILD_PID/params" )"
			v_CHILD_CONF="$( grep -E -v "^[[:blank:]]*(#|$)" "$v_WORKINGDIR""$v_CHILD_PID/params" | xxd -p | tr -d '\n' )"
		fi
		if [[ $4 == "multi" ]]; then
			i=0; while [[ $i -lt $( echo -n "$v_CHILD_CONF" | xxd -r -p | grep -E -c "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[^[:blank:]][^[:blank:]]*" ) ]]; do
				a_RESULT[$i]="$( echo -n "$v_CHILD_CONF" | xxd -r -p | grep -E "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[^[:blank:]][^[:blank:]]*" | sed -n "$(( $i + 1 )) p" | sed "s/^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*//;s/[[:blank:]]*$//" )"
				i=$(( $i + 1 ))
			done
		else
			v_RESULT="$( echo -n "$v_CHILD_CONF" | xxd -r -p | grep -E "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[^[:blank:]][^[:blank:]]*" | tail -n1 | sed "s/^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*//;s/[[:blank:]]*$//" )"
		fi
	elif [[ $2 == "master" && -f "$v_WORKINGDIR""lwmon.conf" ]]; then
		if [[ "$( stat --format=%Y "$v_WORKINGDIR""lwmon.conf" )" -gt "$v_MASTER_CONF_STAT" ]]; then
		### Only re-read the conf file if there have been changes to it.
			v_MASTER_CONF_STAT="$( stat --format=%Y "$v_WORKINGDIR""lwmon.conf" )"
			v_MASTER_CONF="$( grep -E -v "^[[:blank:]]*(#|$)" "$v_WORKINGDIR""lwmon.conf" | xxd -p | tr -d '\n' )"
		fi
		if [[ $4 == "multi" ]]; then
			i=0; while [[ $i -lt $( echo -n "$v_MASTER_CONF" | xxd -r -p | grep -E -c "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[^[:blank:]][^[:blank:]]*" ) ]]; do
				a_RESULT[$i]="$( echo -n "$v_MASTER_CONF" | xxd -r -p | grep -E "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[^[:blank:]][^[:blank:]]*" | sed -n "$(( $i + 1 )) p" | sed "s/^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*//;s/[[:blank:]]*$//" )"
				i=$(( $i + 1 ))
			done
		else
			v_RESULT="$( echo -n "$v_MASTER_CONF" | xxd -r -p | grep -E "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[^[:blank:]][^[:blank:]]*" | tail -n1 | sed "s/^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*//;s/[[:blank:]]*$//" )"
		fi
	elif [[ -f $2 && $4 == "multi" ]]; then
		i=0; while [[ $i -lt $( grep -E -c "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[^[:blank:]][^[:blank:]]*" "$2" 2> /dev/null) ]]; do
			a_RESULT[$i]="$( grep -E "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[^[:blank:]][^[:blank:]]*" "$2" 2> /dev/null) | sed -n "$(( $i + 1 )) p" | sed "s/^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*//;s/[[:blank:]]*$//" )"
			i=$(( $i + 1 ))
		done
	elif [[ -f $2 ]]; then
		v_RESULT="$( grep -E "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*[^[:blank:]][^[:blank:]]*" "$2" 2> /dev/null | tail -n1 | sed "s/^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*//;s/[[:blank:]]*$//" )"
	fi
	if [[ -z ${a_RESULT[@]} && -n $3 && $4 == "multi" ]]; then
		a_RESULT[0]="$3"
	elif [[ -z $v_RESULT && -n $3 ]]; then
		v_RESULT="$3"
	fi
}

function fn_update_conf {
	### This function updates a value in the conf file. It expects $1 to be the name of the directive, $2 to be the new value for that directive, and $3 to be the name of the conf file.
	if [[ $3 == "child" && -f "$v_WORKINGDIR""$v_CHILD_PID/params" ]]; then
		v_CONF_FILE="$v_WORKINGDIR""$v_CHILD_PID/params"
	elif [[ $3 == "master" && -f "$v_WORKINGDIR""lwmon.conf" ]]; then
		v_CONF_FILE="$v_WORKINGDIR""lwmon.conf"
	else
		v_CONF_FILE="$3"
	fi
	if [[ -f "$v_CONF_FILE" ]]; then
		### We're about to run $2 through sed, so it needs to have all of its slashes escaped.
		v_MODIFIED_2="$( echo "$2" | sed -e 's/[\/&]/\\&/g' )"
		if [[ $( grep -E -c "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*" "$v_CONF_FILE" 2> /dev/null ) -gt 0 ]]; then
			sed -i "$( grep -E -n "^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*" "$v_CONF_FILE" | tail -n1 | cut -d ":" -f1 )""s/\(^[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*\).*$/\1""$v_MODIFIED_2/" "$v_CONF_FILE"
		elif [[ $( grep -E -c "^[[:blank:]]*##*[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*$" "$v_CONF_FILE" 2> /dev/null ) -gt 0 ]]; then
		### If there's a commended-out line, but it doesn't have a value afterward...
			sed -i "$( grep -E -n "^[[:blank:]]*##*[[:blank:]]*$1[[:blank:]]*=[[:blank:]]*" "$v_CONF_FILE" | tail -n1 | cut -d ":" -f1 )""s/^[[:blank:]]*##*\([[:blank:]]*$1[[:blank:]]*=[[:blank:]]*\).*$/\1""$v_MODIFIED_2/" "$v_CONF_FILE"
		else
			echo "$1 = $v_MODIFIED_2" >> "$v_CONF_FILE"
		fi
	fi
}

function fn_test_variable {
	### This function assumes that $1 is the variable in question $2 is "true" or "false" whether it needs to be a number, $3 is "false" if the variable cannot be pulled from the main config, and the directive name within the main config if it can be pulled from the main config, and $4 is what it should be set to if a setting is not found.
	unset v_RESULT
	if [[ $3 != "false" && ( -z $1 || $1 == "default" || ( $2 == true && $( echo $1 | grep -E -c "[^0-9.]" ) -gt 0 ) ) ]]; then
		fn_read_conf "$3" master; v_RESULT="$v_RESULT"
	else
		v_RESULT="$1"
	fi
	if [[ -z $v_RESULT || $v_RESULT == "default" || ( $2 == true && $( echo $1 | grep -E -c "[^0-9.]" ) -gt 0 ) ]]; then
		v_RESULT="$4"
	fi
}

function fn_test_file {
	### This function expects $1 to be the path to a file, $2 to be true or false whether the file needs to be tested for read permission, and $3 to be true or false whether the file needs to be tested for write permission.
	v_RESULT="$1"
	if [[ -n "$v_RESULT" ]]; then 
		if [[ -n "$HOME" && "${v_RESULT:0:2}" == "~/" ]]; then
			v_RESULT="$HOME""${v_RESULT:1}"
		fi
		if [[ ${v_RESULT:0:1} == "/" && "$3" == true && "$2" != true ]]; then
			touch "$v_RESULT" 2> /dev/null
			v_STATUS=$?
			if [[ ! -e "$v_RESULT" || ! -w "$v_RESULT" || $v_STATUS == 1 ]]; then
				unset v_RESULT
			fi
		elif [[ ${v_RESULT:0:1} == "/" && "$3" != true && "$2" == true ]]; then
			tail -n1 "$v_RESULT" 2> /dev/null
			v_STATUS=$?
			if [[ ! -e "$v_RESULT" || ! -r "$v_RESULT" || $v_STATUS == 1 ]]; then
				unset v_RESULT
			fi
		elif [[ ${v_RESULT:0:1} == "/" && "$3" == true && "$2" == true ]]; then
			touch "$v_RESULT" 2> /dev/null
			v_STATUS=$?
			if [[ ! -e "$v_RESULT" || ! -w "$v_RESULT" || $v_STATUS == 1 ]]; then
				unset v_RESULT
			else
				tail -n1 "$v_RESULT" 2> /dev/null
				v_STATUS=$?
				if [[ ! -e "$v_RESULT" || ! -r "$v_RESULT" || $v_STATUS == 1 ]]; then
					unset v_RESULT
				fi
			fi
		elif [[ ${v_RESULT:0:1} != "/" ]]; then
			unset v_RESULT
		fi
	else
		unset v_RESULT
	fi
}

function fn_parse_cl_argument {
	### Function Version 1.1.0
	### For this function, $1 is the flag that was passed (without trailing equal sign), $2 is "num" or "int" if it's a number, "float" if it's a number with the potential of having a decimal point, "string" if it's a string, "bool" if it's true or false, "date" if it's a date, "file" if it's a file, "directory" if it's a directory, and "none" if nothing follows it, and $3 is an alternate flag with the same functionality. If $2 is bool, then $4 determines the behavior for a boolean flags if no argument is passed for them: "true" sets them to true, "false" sets them to "false" and "exit" tells the script to exit with an error. If $2 is "file" or "directory", then $4 can be "create" if the file should be created, and "error" if the file needs to have existed previously.
	### This function will prompt for responses if the variable "$v_CL_PROMPT" is set to "true".
	### This function makes use of, but does not rely on the function "fn_fix_home".
	### Currently scrub.sh has the prettiest implimentation of passing data to this function.
	unset v_RESULT
	if [[ "$2" == "none" ]]; then
		v_RESULT="true"
	elif [[ "$v_ARGUMENT" =~ ^$1$ && "$2" != "none" ]]; then
	### If there is no equal sign, the next argument is the modifier for the flag
		if [[ -n "${a_CL_ARGUMENTS[$(( $c + 1 ))]}" && ! "${a_CL_ARGUMENTS[$(( $c + 1 ))]}" =~ ^- ]]; then
		### If the next argument doesn't begin with a dash.
			if [[ "$2" != "bool" || ( "$2" == "bool" && $( echo "${a_CL_ARGUMENTS[$(( $c + 1 ))]}" | grep -E -c "^([Tt]([Rr][Uu][Ee])*|[Ff]([Aa][Ll][Ss][Ee])*)$" ) -eq 1 ) ]]; then
			### If it's not bool, or if it is bool, but the next argument is neither true nor false
				c=$(( $c + 1 ))
				v_RESULT="${a_CL_ARGUMENTS[$c]}"
			fi
		elif [[ "$2" != "bool" && $v_CL_PROMPT == true ]]; then
			read -ep "The \"$v_ARGUMENT\" flag requires an argument: " v_RESULT
		elif [[ "$2" != "bool" && $v_CL_PROMPT != true ]]; then
			echo "The flag \"$1\" needs to be followed by an argument. Exiting."
			exit 1
		fi
	elif [[ "$v_ARGUMENT" =~ ^$1[0-9]*$ && ( $2 == "int" || $2 == "num" ) ]]; then
	### If the argument doesn't have an equal sign, has a number on the end, and it's type is "int" or "num", then the number is the modifier (example "-n1")
		v_RESULT="$( echo "$v_ARGUMENT" | sed "s/^$1//" )"
	elif [[ "$v_ARGUMENT" =~ ^$1= && "$2" != "none" ]]; then
	### If the argument has an equal sign, then the modifier for the flag is within this argument
		v_RESULT="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
		if [[ -z "$v_RESULT" && "$2" != "bool" && $v_CL_PROMPT == true ]]; then
			read -ep "The \"$v_ARGUMENT\" flag requires an argument: " v_RESULT
		elif [[ -z "$v_RESULT" && "$2" != "bool" && $v_CL_PROMPT != true ]]; then
			echo "The flag \"$1\" needs to be followed by an argument. Exiting."
			exit 1
		fi
	elif [[ -n "$3" && "$v_ARGUMENT" =~ ^$3$ && "$2" != "none" ]]; then
	### If there is no equal sign, the next argument is the modifier for the alternate flag
		if [[ -n "${a_CL_ARGUMENTS[$(( $c + 1 ))]}" && ! "${a_CL_ARGUMENTS[$(( $c + 1 ))]}" =~ ^- ]]; then
			if [[ "$2" != "bool" || ( "$2" == "bool" && $( echo "${a_CL_ARGUMENTS[$(( $c + 1 ))]}" | grep -E -c "^([Tt]([Rr][Uu][Ee])*|[Ff]([Aa][Ll][Ss][Ee])*)$" ) -eq 1 ) ]]; then
				c=$(( $c + 1 ))
				v_RESULT="${a_CL_ARGUMENTS[$c]}"
			fi
		elif [[ "$2" != "bool" && $v_CL_PROMPT == true ]]; then
			read -ep "The \"$v_ARGUMENT\" flag requires an argument: " v_RESULT
		elif [[ "$2" != "bool" && $v_CL_PROMPT != true ]]; then
			echo "The flag \"$3\" needs to be followed by an argument. Exiting."
			exit 1
		fi
	elif [[ "$v_ARGUMENT" =~ ^$3[0-9]*$ && ( $2 == "int" || $2 == "num" ) ]]; then
	### If the argument has a number on the end, and it's type is "int" or "num", then the number is the modifier
		v_RESULT="$( echo "$v_ARGUMENT" | sed "s/^$3//" )"
	elif [[ -n "$3" && "$v_ARGUMENT" =~ ^$3= && "$2" != "none" ]]; then
	### If the argument has an equal sign, then the modifier for the alternate flag is within this argument
		v_RESULT="$( echo "$v_ARGUMENT" | cut -d "=" -f2- )"
		if [[ -z "$v_RESULT" && "$2" != "bool" && $v_CL_PROMPT == true ]]; then
			read -ep "The \"$v_ARGUMENT\" flag requires an argument: " v_RESULT
		elif [[ -z "$v_RESULT" && "$2" != "bool" && $v_CL_PROMPT != true ]]; then
			echo "The flag \"$3\" needs to be followed by an argument. Exiting."
			exit 1
		fi
	fi
	if [[ ( $2 == "num" || $2 == "int" ) && ! "$v_RESULT" =~ ^[0-9]+$ ]]; then
		echo "The flag \"$1\" needs to be followed by an integer. Exiting."
		exit 1
	elif [[ $2 == "date" ]]; then
		### Dates are validated by ensuring that they can be passed to the "date" command,so things like "yesterday" also work.
		date --date="$v_RESULT" > /dev/null 2>&1
		if [[ $? -ne 0 ]]; then
			echo "The flag \"$1\" needs to be followed by a date. Exiting."
			exit 1
		fi
		v_RESULT="$( date --date="$v_RESULT" +%F )"
	elif [[ $2 == "float" && ! "$v_RESULT" =~ ^[0-9.]+$ ]]; then
		echo "The flag \"$1\" needs to be followed by a number. Exiting."
		exit 1
	elif [[ $2 == "file" ]]; then
		if [[ $( type -t fn_fix_home ) == "function" ]]; then
			v_RESULT=$( fn_fix_home "$v_RESULT" )
		fi
		if [[ $4 == "error" && ! -f "$v_RESULT" ]]; then
			echo "File \"$v_RESULT\" does not appear to exist. Exiting."
			exit 1
		elif [[ $4 == "create" ]]; then
			touch "$v_RESULT"
			v_EXIT_CODE=$?
			if [[ $v_EXIT_CODE -ne 0 ]]; then
				echo "Error creating file \"$v_RESULT\". Exiting."
				exit 1
			fi
		fi
	elif [[ $2 == "directory" ]]; then
		if [[ $( type -t fn_fix_home ) == "function" ]]; then
			v_RESULT=$( fn_fix_home "$v_RESULT" --directory )
		fi
		if [[ $4 == "error" && ! -d "$v_RESULT" ]]; then
			echo "Directory \"$v_RESULT\" does not appear to exist. Exiting."
			exit 1
		elif [[ $4 == "create" ]]; then
			mkdir -p "$v_RESULT"
			v_EXIT_CODE=$?
			if [[ $v_EXIT_CODE -ne 0 ]]; then
				echo "Error creating directory \"$v_RESULT\". Exiting."
				exit 1
			fi
		fi
		if [[ "$v_RESULT" =~ /$ ]]; then
			v_RESULT="$v_RESULT/"
		fi
	elif [[ $2 == "bool" ]]; then
		if [[ $( echo "$v_RESULT" | grep -E -c "^([Tt]([Rr][Uu][Ee])*|[Ff]([Aa][Ll][Ss][Ee])*)$" ) -eq 0 ]]; then
			if [[ -z "$4" || "$4" == "exit" ]]; then
				echo "The flag \"$1\" needs to be followed by \"true\" or \"false\". Exiting."
				exit 1
			elif [[ "$4" == "false" ]]; then
				v_RESULT="false"
			else
				v_RESULT="true"
			fi
		elif [[ $( echo "$v_RESULT" | grep -E -c "^[Tt]([Rr][Uu][Ee])*$" ) -eq 1 ]]; then
			v_RESULT="true"
		elif [[ $( echo "$v_RESULT" | grep -E -c "^[Ff]([Aa][Ll][Ss][Ee])*$" ) -eq 1 ]]; then
			v_RESULT="false"
		fi
	fi
}

function fn_create_config {
cat << EOF > "$v_WORKINGDIR"lwmon.conf
# LWmon configuration file

# The "VERBOSITY" directive controls how verbose the output of the child processes is. 
# There are five options available: 1) "standard": Outputs whether any specific check has succeeded or failed. 2) "verbose": In addition to the information given from the standard output, also indicates how long checks for that job have been running, how many have been run, and the percentage of successful checks. 3) "more verbose": In addition to the information from "verbose" mode, information regarding how long checks are taking to complete will be output. 4) "change": Only outputs text on the first failure after any number of successes, or the first success after any number of failures. 5) "none": Child processes output no text.
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will immediately impact all child processes they don't have their own verbosity specifically set.
VERBOSITY = $v_DEFAULT_VERBOSITY

# The "EMAIL_ADDRESS" directive sets a default email address to which notifications will be sent for new jobs. If no address is set, no notifications will be sent.
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will only impact jobs that are created after the change is made.
EMAIL_ADDRESS = 

# The "MAIL_DELAY" directive sets a default for how many passes or failures have to occur in a row before an email is sent. This is useful in that it's typical for a single failure after a string of several succeses to be a false positive, rather than an actual indicator of an issue.
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will only impact jobs that are created after the change is made.
MAIL_DELAY = $v_DEFAULT_MAIL_DELAY

# The "WAIT_SECONDS" directive sets a default number of seconds between each check that a job is doing. This does not include the amount of time that it takes for a check to complete - for example, it it takes three seconds to curl a page, and wait seconds is set at "10", it will take roughly thirteen seconds before the beginning of the next check.
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will only impact jobs that are created after the change is made.
WAIT_SECONDS = $v_DEFAULT_WAIT_SECONDS

# The "CHECK_TIMEOUT" directive sets a default for the number of seconds before a curl operation ends. This prevents the script from waiting an unreasonable amount of time between checks.
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will only impact jobs that are created after the change is made.
CHECK_TIMEOUT = $v_DEFAULT_CHECK_TIMEOUT

# The "OUTPUT_FILE" directive sets a default for where the results of child checks will be output. "/dev/stdout" indicates the standard out of the master process, and is typically the best place for this data to be pushed to. It can, however, be directed to a file, so that that file can be tailed by multiple users. this file HAS TO BE referenced by its full path.
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will only impact jobs that are created after the change is made.
OUTPUT_FILE = $v_DEFAULT_OUTPUT_FILE

# The "USER_AGENT" directive can be set to "true" or "false". For "true" the user agent string emulates chrome's user agent. For "false", the user agent string simply outputs the lwmon and curl versions.
# If this is set to something other than "true" or "false", what ever it's set to will be used as the user agent instead
# Note: This can also be set on a per-child basis
# Note: Changes to this directive will only impact jobs that are created after the change is made.
USER_AGENT = $v_DEFAULT_USER_AGENT

# When ever there is a change from success to failure on a URL monitoring job, a copy of the last successful curl result and the first failed curl result (with the associated error code) will be kept in the job's child directory. The "HTML_FILES_KEPT" directive controls the number of html files that are kept in addition to the results from the current and previous curls.
HTML_FILES_KEPT = $v_DEFAULT_HTML_FILES_KEPT

# One of the stats output in "more verbose" mode is how long the average recent check took - "recent" being within the last X checks. By default this number is 10, but that can be changed with the "NUM_DURATIONS_RECENT" directive.
NUM_DURATIONS_RECENT = $v_DEFAULT_NUM_DURATIONS_RECENT

# The "NUM_STATUSES_RECENT" and "NUM_STATUSES_NOT_SUCCESS" directives allow the user to configure the script to send email alerts when out of the X most recent statuses, Y of them are not a success. X being the value set for "NUM_STATUSES_RECENT" and Y being the value set for "NUM_STATUSES_NOT_SUCCESS".
# After an email has been sent indicating intermittent failures, there must be a number of successful checks equal to the number specified by "NUM_STATUSES_RECENT" before another success message will be sent
NUM_STATUSES_RECENT = $v_DEFAULT_NUM_STATUSES_RECENT
NUM_STATUSES_NOT_SUCCESS = $v_DEFAULT_NUM_STATUSES_NOT_SUCCESS

# For URL based jobs, it's possible to set a time limit for the process to be considered a "partial success" - Even if the curl process finished before it reaches "CHECK_TIMEOUT", the amount of time it look to complete took long enough that it should be brought to the user's attention.
CHECK_TIME_PARTIAL_SUCCESS = $v_DEFAULT_CHECK_TIME_PARTIAL_SUCCESS

# If the "LOG_DURATION_DATA" directive is set to "true", then the amount of time it takes for each check to complete will be output to the log file in the child directory.
LOG_DURATION_DATA = $v_DEFAULT_LOG_DURATION_DATA

# For URL jobs, when using curl and not wget: when the "CURL_VERBOSE" directive is set to "true", the script will capture the verbose output and append it to the end of the html file.
CURL_VERBOSE = $v_DEFAULT_CURL_VERBOSE

# For URL jobs, when curl is being used and not wget, if the "LOG_HTTP_CODE" directive is set to "true" the http return code will be logged in the log file for the child process.
LOG_HTTP_CODE = $v_DEFAULT_LOG_HTTP_CODE

# Setting the "USE_WGET" directive to "true" forces the script to use wget rather than curl to pull files. Curl is typically preferred as its behavior is slightly more predictable and its error output is slightly more specific.
USE_WGET = $v_DEFAULT_USE_WGET

# The "ALT_MAIL" directive allows the user to set an alternate mail binary to use when sending mail. By default LWmon will use what ever is in the path for the user to send mail in the format of "echo 'message' | mail -s 'subject' user@example.com". using this directive will replace "mail" with what ever is specified.
# You can include additional arguments for the alternate binary to use previous to "-s"
# If the path to the alternate binary includes spaces, be sure to quote the path appropriately.
ALT_MAIL = 

# The "SSH_CONTROL_PATH" directive allows the user to specify where the control path socket file for an ssh-load job is located.
SSH_CONTROL_PATH = $v_DEFAULT_SSH_CONTROL_PATH

# The "COLOR_" and "RETURN_" directives allow the user to set specific strings that will be output before and after checks, depending on whether they're the first successful check, iterative successful checks, the first failed check, or iterative failed checks. This is designed to be used with bash color codes, but really anything that could be interpreted by "echo -e" can be used here.
COLOR_SUCCESS = $v_DEFAULT_COLOR_SUCCESS
COLOR_FIRST_SUCCESS = $v_DEFAULT_COLOR_FIRST_SUCCESS
COLOR_FAILURE = $v_DEFAULT_COLOR_FAILURE
COLOR_FIRST_FAILURE = $v_DEFAULT_COLOR_FIRST_FAILURE
COLOR_PARTIAL_SUCCESS = $v_DEFAULT_COLOR_PARTIAL_SUCCESS
COLOR_FIRST_PARTIAL_SUCCESS = $v_DEFAULT_COLOR_FIRST_PARTIAL_SUCCESS
RETURN_SUCCESS = $v_DEFAULT_RETURN_SUCCESS
RETURN_FIRST_SUCCESS = $v_DEFAULT_RETURN_FIRST_SUCCESS
RETURN_FAILURE = $v_DEFAULT_RETURN_FAILURE
RETURN_FIRST_FAILURE = $v_DEFAULT_RETURN_FIRST_FAILURE
RETURN_PARTIAL_SUCCESS = $v_DEFAULT_RETURN_PARTIAL_SUCCESS
RETURN_FIRST_PARTIAL_SUCCESS = $v_DEFAULT_RETURN_FIRST_PARTIAL_SUCCESS
EOF
#'do
echo -e "\e[1;32mA configuration file has been created at \"$v_WORKINGDIR""lwmon.conf\". You totally want to check it out.\e[00m"
sleep 1
}

#================================#
#== Help and Version Functions ==#
#================================#

function fn_help {
cat << EOF | fold -s -w $(( $(tput cols) - 1 )) > /dev/stdout

LWmon (Less Worry Monitor) - A script to organize and consolidate the monitoring of multiple servers. With LWmon you can run checks against multiple servers simultaneously, starting new jobs and stopping old ones as needed without interfering with any that are currently running. All output from the checks go by default to a single terminal window, allowing you to keep an eye on multiple things going on at once.


USAGE:

./lwmon.sh (Followed by no arguments or flags)
    - Either prompts you on how you want to proceed, allowing you to choose from options similar to those presented by the descriptions below, or if there are no currently running jobs, outputs information on the flags that can be used to start a monitoring job.


ADDITIONAL USAGE:

./lwmon.sh [--url (or -u)|--ping (or -p)|--dns (or -d)|--ssh-load] (followed by other flags)
      1) Leaves a prompt telling the master process to spawn a child process to either a) in the case of --url, check a site's contents for a string of characters b) in the case of --ping, ping a site and check for a response c) in the case of --dns, dig against a nameserver and check for a valid response, d) In the case of --ssh-load, use an existing ssh connection to check the server's load.
      2) If there is no currently running master process, it goes on to declare itself the master process and spawn child processes accordingly.
    - NOTE: For more information on the additional arguments and flags that can be used here, run ./lwmon.sh --help-flags
    - NOTE: For more information on Master, Child and Control processes, run ./lwmon.sh --help-process-types
    - NOte: For more information on the various files that LWmon will create and use, run ./lwmon.sh --help-files

./lwmon.sh --modify (or -m)
    - Prompts you with a list of currently running child processes and allows you to change how frequently their checks occur and how they send e-mail allerts, or kill them off if they're no longer desired.

./lwmon.sh --help or (-h)
    - Displays this dialogue.

./lwmon.sh --help-flags
    - Outputs help information with specific descriptions of all of the command line flags.

./lwmon.sh --version
    - Displays changes over the various versions.

./lwmon.sh --kill (--save)
    - Kills off the lwmon master process, which in turn prompts any child processes to exit as well. Optionally, you can use the "--save" flag in conjunction with "--kill" to save all of the current running child processes so that they will be restarted automaticaly when lwmon is next launched.


ADDITIONAL ADDITIONAL USAGE:

Run ./lwmon.sh --help-flags for further information.

Run ./lwmon.sh --help-process-types for more information on master, control, and child processes.

Run ./lwmon.sh --help-params-file for more information on editing the parameters file for a child process.

Run ./lwmon.sh --help-files for more information on the files and directories that LWmon will create and use


OTHER NOTES:

Note: Regarding the configuration file!
    - There's a configuration file! Assuming that ./ is the directory where lwmon.sh is located, the configuration file will be located at ./.lwmon/lwmon.conf.

Note: Regarding e-mail alerts!
    - LWmon sends e-mail messages using the "mail" binary (usually located in /usr/bin/mail). In order for this to work as expected, you will likely need to modify the ~/.mailrc file with credentials for a valid e-mail account, otherwise the messages that are sent will likely get rejected.

Note: Regarding the log file!
    - LWmon keeps a log file titled "lwmon.log" in the same directory in which lwmon.sh is located. This file is used to log when checks are started and stopped, and when ever there is a change in status on any of the checks. In addition to this, there is another log file in the direcctory for each child process containing information only specific to that child process.

Note: Regarding url checks and specifying an IP!
    - LWmon allows you to specify an IP from which to pull a URL, rather than allowing DNS to resolve the domain name to an IP address. This is very useful in situations where you're attempting to monitor multiple servers within a load balanced setup, or if DNS for the site that you're monitoring isn't yet pointed to the server that it's on.

Note: Regarding text color!
    - By default, the text output is color coded as follows:
          - Green - The first check that has succeeded after any number of failed checks. White (Or what ever color is standard for your terminal) - a check that has succeeded when the previous check was also successful.
          - Red - The first check that has failed after any number of successful checks.
          - Yellow - A check that has failed when the previous check was also a failure.
          - Blue - The first instance of a check meeting some, but not all, of the specified success conditions.
          - Purple - A check meeting some, but not all, of the specified success conditions, and the previous check also met some but not all success conditions
          - White - A check that has succeeded after previous checks have succeeded
    - These can be changed by making modifications to the "COLOR_" and "RETURN_" directives in the configuration file.

EOF
#"'do
exit 0
}

function fn_help_flags {
cat << EOF | fold -s -w $(( $(tput cols) - 1 )) > /dev/stdout

FLAGS FOR MONITORING JOB TYPES:

--dns (host name or IP)
    - This flag is used to start a new monitoring job for DNS services on a remote server. It requires the use of the "--domain" flag, and can also be used in conjunction with the following flags:

      "--record-type", "--check-result", "--mail", "--mail-delay", "--outfile", "--seconds", "--verbosity", "--ident", "--job-name", "--control", "--ldd", "--ndr", "--nsns", "--nds"

--ping (host name or IP)
    - This flag is used to start a new monitoring job to watch whether or not a server is pinging. It can be used in conjunction with the following flags:

      "--mail", "--mail-delay", "--outfile", "--seconds", "--verbosity", "--ident", "--job-name", "--control", "--ldd", "--ndr", "--nsns", "--nds"

--ssh-load (host name or IP)
--load (host name or IP)
    - This flag is used to start a new monitoring job to watch a remote server's load. It requires the "--user" flag, and also requires the presence of an SSH control socket (You will be told hiw to fix this if you try running a job without one). It can be used in conjunction with the following flags:

      "--load-ps", "--load-fail", "--port", "--check-timeout", "--ctps", "--mail", "--mail-delay", "--outfile", "--seconds", "--verbosity", "--ident", "--job-name", "--control", "--ldd", "--ndr", "--nsns", "--nds"

--url (url)
--curl (url)
    - This flag is used to start a new monitoring job to confirm that a URL is loading as expected. It requires one or more uses of the "--string" flag, and can also be used in conjunction with the following flags:

      "--user-agent", "--ip", "--check-timeout", "--ctps", "--mail", "--mail-delay", "--outfile", "--seconds", "--verbosity", "--wget", "--ident", "--job-name", "--control", "--ldd", "--ndr", "--nsns", "--nds"


FLAGS FOR ADDITIONAL SPECIFICATIONS FOR MONITORING JOBS

--check-result (string)
    - This flag allows the user to specify a string of text that must be present in the "dig +short" result of a DNS check.

--check-timeout (number (with or without decimal places))
    - This flag specifies how long a check should wait before giving up. The default here is $v_DEFAULT_CHECK_TIMEOUT seconds.

--control
    - Designates the process as a control process - I.E. it just lays out the specifics of a child process and puts them in place for the master process to spawn, but even if there is not currently a master process, it does not designate itself master and spawn the process that's been specified. Run ./lwmon.sh --help-process-types for more information on master, control, and child processes.

--ctps (number (with or without decimal places))
    - Allows the user to specify a minimum number of seconds before a url or ssh-load job is considered a partial success. That is, should the result that's returned be considered a success in every other way, the amount of time that it took for the result to be returned should still be conveyed as a cause of concern to the user.

--domain (domain name)
--check-domain (domain name)
    - For DNS Jobs, specifies the domain name that you're querying the DNS server for. 

--ident (number)
--ticket (number)
    - Allows the user to specify an identifying string of numbers that can be added to the job name. This can, for example, be an account number or ticket number. If the --job-name flag isn't used, this string is added to the end of the job name. 

--ip (IP address)
--ip-address (IP address)
    - Used with "--url". This flag is used to specify the IP address of the server that you're running the check against. Without this flag, a DNS query is used to determine what IP the site needs to be pulled from. "--ip" is perfect for situations where multiple load balanced servers need to be monitored at once, or where the customer's DNS A record is pointing at cloudflare, and you're trying to determine whether connectivity issues are server specific, or cloudflare specific.

--job-name (string of text)
    - Allows the user to specify an identifying job name at the command line.

--ldd (true|false)
--log-duration-data (true|false)
    - Tells the job whether or not to add the time it takes for each check to complete to the child process's log file.

--load-fail (number (with or without decimal places))
    - For an ssh-load job, this is the flag used to specify the minimum load at which the check returns as a failure rather than as a success or partial success.

--load-ps (number (with or without decimal places))
    - For an ssh-load job, this is the flag used to specify the minimum load at which the check returns as a partial success rather than as a success.

--mail (email address)
--email (email address)
    - Specifies the e-mail address to which alerts regarding changes in status should be sent.

--mail-delay (number)
    - Specifies the number of failed or successful chacks that need to occur in a row before an e-mail message is sent. The default is to send a message after $v_DEFAULT_MAIL_DELAY checks that have had a different result than the previous ones. Setting this to "0" prevents e-mail allerts from being sent.

--ndr (number)
--num-durations-recent (number)
    - The script keeps track of the average amount of time it takes to perform a check over X number of checks. This is $v_DEFAULT_NUM_DURATIONS_RECENT by default, but you can change this using the "--ndr" flag.

--nsns (number)
--num-statuses-not-success (number)
    - The "--nsns" and "--nsr" flags can be used together to determine if an email alert needs to be sent regarding a job that keeps fluctuating between success and failure, but has succeeded enough that an email would not otherwise be sent. If the ststus of a job is not successful X out of Y times, an email will be sent. "--nsns" allows the user to set X; "--nsr" allows the user to set Y.

--nsr (number)
--num-statuses-recent (number)
    - The "--nsns" and "--nsr" flags can be used together to determine if an email alert needs to be sent regarding a job that keeps fluctuating between success and failure, but has succeeded enough that an email would not otherwise be sent. If the ststus of a job is not successful X out of Y times, an email will be sent. "--nsns" allows the user to set X; "--nsr" allows the user to set Y.
    - After an email has been send indicating intermittent failures, there must be a number of successful checks equal to the number specified by "--nsr" before another success message will be sent

--outfile (file)
--output-file (file)
    - By default, child processes output the results of their checks to the standard out (/dev/stdout) of the master process. This flag allows that output to be redirected to a file.

--port (port number)
    - Specify a port number to connect to for ssh-load jobs.

--record-type
    - This flag allows the user to specify the type of DNS record that is being requested in a DNS job.

--seconds (number (with or without decimal places))
    - Specifies the number of seconds after a check has completed to begin a new check. The default is $v_DEFAULT_WAIT_SECONDS seconds.

--string (string of text)
    - Used with "--url". This specifies the string that the contents of the curl'd page will be searched for in order to confirm that it is loading correctly. Under optimal circumstances, this string should be something generated via php code that pulls information from a database - thus no matter if it's apache, mysql, or php that's failing, a change in status will be detected. This string cannot contain new line characters and should not begin with whitespace.
    - This string is searched for using "fgrep", so no regex will be interpreted.
    - This flag can be used mo rethan once gor a job. If so, a full success will be reported only if all strings are present.

--user (user name)
--ssh-user (user name)
    - For an ssh-load job, this is flag is used to specify that user that we are connecting to the server with.

--user-agent (true|false)
    - When used with "--url", this will cause the curl command to be run in such a way that the chrome 67 user agent is imitated. This is useful in situations where a site is refusing connections from the standard user agent.

--verbosity (standard|verbose|more verbose|change|none)
--verbose (standard|verbose|more verbose|change|none)
    - Allows the user to specify the verbosity level of the output of a child processes.
          - "standard": Outputs whether any specific check has succeeded or failed.
          - "verbose": In addition to the information given from the standard output, also indicates how long checks for that job have been running, how many have been run, and the percentage of successful checks.
          - "more verbose": Outputs multiple lines with the data from verbose, as well as data on how long the checks are taking.
          - "change": Only outputs text on the first failure after any number of successes, or the first success after any number of failures.
          - "none": output no text.

--wget (true|false)
    - Forces the script to use wget rather than curl. Curl is typically preferred as its behavior is slightly more predictable and its error output is slightly more specific.

OTHER FLAGS:

--help
-h
    - Displays the basic help information.

--help-flags
    - Outputs the help information specific to command line flags.

--help-params-file
    - Gives detailed information on what's expected within the params file, for the purpose of manual editing.

--help-process-types
    - Gives a better explanation of lwmon.sh's master, control, and child processes.

--kill
    - Used to terminate the master lwmon process, which in turn prompts any child processes to exit as well. This can be used in conjunction with the "--save" flag.

--list
-l
    - Lists the current lwmon child processes, then exits.
     
--master
    - Immediately designates itself as the master process. If any prompts are waiting, it spawns child processes as they describe, it then checks periodically for new prompts and spawns processes accordingly. If the master process ends, all child processes it has spawned will recognize that it has ended, and end as well. Run ./lwmon.sh --help-process-types for more information on master, control, and child processes.

--modify
-m
    - Prompts you with a list of currently running child processes and allows you to modify how they function and what they're checking against, or kill them off if they're no longer desired.

--save
    - Used in conjunction with the "--kill" flag. Prompts lwmon to save all of the current running child processes before exiting so that they will be restarted automaticaly when lwmon is next launched.

--testing
    - Requires that the minified version of the script be rebuilt for every new child process. This flag only has function when used to spawn the master process.

--version
    - Outputs information regarding the changes over the various versions.

EOF
#'"do
exit 0
}

function fn_help_process_types {
cat << EOF | fold -s -w $(( $(tput cols) - 1 )) > /dev/stdout

MASTER, CONTROL, AND CHILD PROCESSES

Any action taken by lwmon.sh falls into one of three process categories - master processes, control processes, or child processes.

MASTER PROCESS -
    - The master process is just one continuius loop. It primarily accomplishes three things: 1) It checks to see if there is data for new child processes and spawns them accordingly. 2) It checks existing processes, makes sure that they are still running, and if they are not it decides whether they need to be respawned, or if they can be set aside as disabled. 3) If there is data from processes that has been set aside for more than seven days, it removes this data.
    - Other than starting and stopping the master process, the user does not interact with it directly.

CONTROL PROCESSES -
    - Control processes are how the user primarily interacts with lwmon.sh, and they accomplish three primary tasks: 1) They gather data from the user regaring a new child process that the user wants to create, and then they put that data in a place where the master process will find it. 2) They gather data from the user on how a currently running child process should be modified (or exited). 3) They gather data from the user on how the master process should be modified (or exited).
    - Control processes always exit after the data that they've collected has been put in place, except under the following circumstance: If there is no currently running master process, and the "--control" flag was not used, the control process will turn into the master process.

CHILD PROCESSES -
    - These processes are not interacted with by the user at all, except through control processes. They are spawned by the master process. They loop continuously, checking against conditions set by the user, and then reporting success or failure. If at any point in time they detect that the associated master process has ended, they end as well.

EOF
#'do
exit 0
}

function fn_help_params_file {
cat << EOF | fold -s -w $(( $(tput cols) - 1 )) > /dev/stdout

PARAMETERS FILE
(located at ".lwmon/[CHILD PID]/params")

The params file contains the specifics of an lwmon.sh job. Any lwmon.sh job that is currently running can be changed mid-run by editing the params file - this file can be accessed manually, or by using the "--modify" flag. The purpose of this document is to explain each variable in the params file and what it does. 

After changes are made to the params file, these changes will not be recognized by the script until a file named ".lwmon/[CHILD PID]/reload" is created.

"CHECK_TIME_PARTIAL_SUCCESS"
    - For URL and ssh-load jobs, an amount of seconds beyond which the check is considered a partial success. The point of this designation is to alert the user that there's something amiss, even though portions of the process seem to indicate that everything's okay.
    - For DNS and ping jobs, this directive is not being used.

"CHECK_TIMEOUT"
    - For URL and ssh-load jobs, this is the amount of time before the check times out and automatically fails.
    - For DNS and ping jobs, this directive is not being used.

"CURL_STRING"
    - For URL jobs, this is the string that's being checked against in the result of curl process. This directive can be used multiple times. fgrep is used to check whether there's a match or not.

"CURL_URL"
    - For URL jobs, this is the URL that's being curl'd.

"CURL_VERBOSE"
    - For URL jobs, when using curl and not wget: when this is set to "true" the script will capture the verbose output and append it to the end of the html file.

"CUSTOM_MESSAGE"
    - Anything here will be added as to email messages as a first paragraph. The string "\n" will be interpreted as a new line.

"DNS_CHECK_DOMAIN"
    - For a DNS job, when it sends a dig request to the remote server, this is the domain that it sends that request for.

"DNS_CHECK_RESULT"
    - For a DNS job, this is some or all of the text that's expected in the result of the "dig +short" response. fgrep is used to check whether there's a match or not.

"DNS_RECORD_TYPE"
    - For a dns job, this specifies the record type that should be checked for. 

"DOMAIN" 
    - For DNS jobs, this is the domain associated with the zone file on the server that we're checking against.
    - For ping jobs, this is the domain or IP address that we're pinging.
    - For ssh-load jobs, this is the domain that we're connecting to via ssh.

"EMAIL_ADDRESS"
    - This is the email address that messages regarding failed or successful checks will be sent to.

"IP_ADDRESS"
    - For URL jobs, this will be "false" if an IP address has not been specified. Otherwise, it will contain the IP address that we're connecting to before telling the remote server the domain we're trying sending a request to. With this as false, a DNS query is used to determine what IP the site needs to be pulled from. This directive is perfect for situations where multiple load balanced servers need to be monitored at once, or where the customer's A record is pointing at cloudflare, and you're trying to determine whether connectivity issues are server specific, or cloudflare specific.

"JOB_NAME"
    - This is the identifier for the job. It will be output in the terminal window where the master process is being run (Or to where ever the "OUTPUT_FILE" directive indicates). This will also be referenced in emails.

"JOB_TYPE" 
    - This directive specifies what kind of job is being run. (url, dns, ssh-load, or ping) It's used to identify the job type initially. Making changes to it after the job has been initiated will not have any impact on the job, but would prevent the job from restarting correctly.

"LOG_DURATION_DATA"
    - If this is set to "true", the duration of each check will be output to the log file in the child directory.

"LOG_HTTP_CODE"
    - For URL jobs, when curl is being used and not wget, if this is set to "true" the http return code will be logged in the log file for the child process.

"MAIL_DELAY" 
    - The number of successful or failed checks that need to occur before an email is sent. If this is set to zero, no email messages will be sent.

"MIN_LOAD_FAILURE"
    - For a ssh-load job, this is the minimum load that will be considered a failure, rather than a success or partial success.

"MIN_LOAD_PARTIAL_SUCCESS"
    - For a ssh-load job, this is the minimum load that will be considered a partial success, rather than a complete success.

"NUM_DURATIONS_RECENT"
    - One of the stats output in "more verbose" mode is how long the average recent check took - "recent" being within the last X checks. By default this number is 10, but that can be changed with the "NUM_DURATIONS_RECENT" directive.

"NUM_STATUSES_NOT_SUCCESS"
"NUM_STATUSES_RECENT"
    - The "NUM_STATUSES_RECENT" and "NUM_STATUSES_NOT_SUCCESS" directives allow the user to configure the script to send email alerts when out of the X most recent statuses, Y of them are not a success. X being the value set for "NUM_STATUSES_RECENT" and Y being the value set for "NUM_STATUSES_NOT_SUCCESS".
    - After an email has been sent indicating intermittent failures, there must be a number of successful checks equal to the number specified by "NUM_STATUSES_RECENT" before another success message will be sent

"ORIG_JOB_NAME"
    - This is the original identifier for the job. It's used for logging purposes, as well as referenced in emails. In many instances, this will be the same as the "JOB_NAME" directive.

"OUTPUT_FILE"
    - The default for this value is "/dev/stdout", however rather than being output to the terminal where the master process is running, the output of a child process can be redirected to a file. This file HAS TO BE referenced by its full path.

"SCRIPT"
    - You can specify a script to be run at any time that an email would be sent (minus the requirements for having the "mail" binary and having the "EMAIL_ADDRESS" parameter defined)
    - You can include any arguments or flags that you would like the script to be run with. The final argument passed to the script specified will be one of the following arguments (depending on the type of email that would be sent): "success" "psuccess" "intermittent" "failure".
    - The full path to the script must be used, and the script itself must be executable. If the path to the script contains any spaces, it's path will need to be quoted

"SERVER_PORT"
    - For ssh-load jobs, this is the port that's being connected to.

"SSH_USER"
    - For a ssh-load job, this is the user that LWmon will be accessing the server as.

"USE_WGET"
    - Forces the child process to use wget rather than curl.

"USER_AGENT"
    - For URL jobs, this is a true or false value that dictates whether or not the curl for the site will be run with curl as the user agent (false) or with a user agent that makes it look as if it's Google Chrome (true).
    - If the value here is neither "true" nor "false", the value will be used as the user agent string.

"VERBOSITY"
    - Changes the verbosity level of the output of the child process.
          - "standard": Outputs whether any specific check has succeeded or failed.
          - "verbose": In addition to the information given from the standard output, also indicates how long checks for that job have been running, how many have been run, and the percentage of successful checks.
          - "more verbose": Outputs multiple lines with the data from verbose, as well as data on how lnog the checks are taking.
          - "change": Only outputs text on the first failure after any number of successes, or the first success after any number of failures.
          - "none": Child processes output no text.
    - NOTE: this overrides any verbosity setting in the main configuration file.

"WAIT_SECONDS"
    - This is the number of seconds that pass between iterative checks. This number does not take into account how long the check itself took, so for example, if it takes five seconds to curl a URL, and "WAIT_SECONDS" is set to 10, it will be roughly 15 seconds between the start of the first check and the start of the next check.

EOF
#'do
exit 0
}

function fn_help_files {
cat << EOF | fold -s -w $(( $(tput cols) - 1 )) > /dev/stdout

LWMON FILES AND DIRECTORIES

./lwmon.log
    - The log file for the master process. Child processes also log some details to this file

./lwmon.sh
    - The main lwmon.sh script

./.lwmon/
    - LWmon's Working directory

./.lwmon/[CHILD PID]/
    - The working directory for a specific LWmon child process

./.lwmon/[CHILD PID]/#die
    - An empty file, present to remind the end user that at any time they can rename it to "./.lwmon/[CHILD PID]/die" in order to clearnly kill that child process

./.lwmon/[CHILD PID]/#status
    - This file is present to remind the end user that at any time they can rename it to "./.lwmon/[CHILD PID]/status" in order to have that LWmon child process output a full status
    - If a full status has been run previously, this file will contain the text of the most recent full status

./.lwmon/[CHILD PID]/cl
    - The command line arguments to reproduce the child process

./.lwmon/[CHILD PID]/current_verbose_output.txt
    - This file captures the curl verbose output for "--url" monitoritoring job. 

./.lwmon/[CHILD PID]/die
    - If an LWmon child process sees this present in its working directory, it will output a full status to "./.lwmon/[CHILD PID]/#status" and then exit

./.lwmon/[CHILD PID]/force_failure
    - Having this file present will cause an LWmon child process to interpret its next attempt as a failure, regardless of what it would have been otherwise

./.lwmon/[CHILD PID]/force_partial
    - Having this file present will cause an LWmon child process to interpret its next attempt as a partial success, regardless of what it would have been otherwise

./.lwmon/[CHILD PID]/force_success
    - Having this file present will cause an LWmon child process to interpret its next attempt as a success, regardless of what it would have been otherwise

./.lwmon/[CHILD PID]/log
    - This is the log file for a specific child process

./.lwmon/[CHILD PID]/params
    - These are the parameters for the child process. Editing this file will change the operation of the child process

./.lwmon/[CHILD PID]/previous_verbose_output.txt
    - When a new check for a "--url" monitorin job runs, the "./.lwmon/[CHILD PID]/current_verbose_output.txt" file is moved to this location incase the data is needed.

./.lwmon/[CHILD PID]/site_current.html
    - for a "--url" job, this file will contain the most recent curl of the site being monitored

./.lwmon/[CHILD PID]/site_[EPOCH TIMESTAMP]_fail.html
    - for a "--url" job, these files show the result of the first failure after any other status

./.lwmon/[CHILD PID]/site_previous.html
    - for a "--url" job, this file will contain the previous curl of the site.

./.lwmon/[CHILD PID]/site_[EPOCH TIMESTAMP]_psuccess.html
    - for a "--url" job, these files show the result of the first partial success after a success, or the last partial success before a failure

./.lwmon/[CHILD PID]/site_[EPOCH TIMESTAMP]_success.html
    - for a "--url" job, these files show the result of the last success before any other status

./.lwmon/[CHILD PID]/status
    - Creating this file will tell an LWmon child process to output the full status on its next check

./.lwmon/no_output
    - When this file is present, the child processes will not output status information

./.lwmon/die
    - Creating this file tells the LWmon master process to exit out cleanly

./.lwmon/die_list
    - The most recent pull of the remote die list

./.lwmon/lwmon.conf
    - This is the main configuration file for LWmon

./.lwmon/lwmon.pid
    - This is the process ID of the current LWmon master process

./.lwmon/lwmon.sh
    - This is a minified version of the lwmon.sh script specifically for child processes

./.lwmon/new/
    - This directory is where LWmon control processes will place new jobs so that they can wait for the master process to start them up.

./.lwmon/old_[CHILD PID]_[EPOCH TIMESTAMP]
    - This is the working directory of an old LWmon child process, archived temporarily in case data from it is needed.

./.lwmon/save
    - Having this file present while the LWmon master process is exiting tells it to save all child processes so that they will start again next time a master process is started

EOF
#'do
exit 0
}

function fn_version {
cat << EOF | fold -s -w $(( $(tput cols) - 1 )) > /dev/stdout
Current Version: $v_VERSION

Version Notes:
Future Versions -
    - In URL jobs, should I compare the current pull to the previous pull? Compare file size?
    - Rather than have a job run indefinitely, have the user be able to set a duration or a time for it to stop.
    - Because "--string" uses fgrep, does it make sense to make a "--reg-string" flag that uses egrep?
    - Switch to using local variables where possible
    - Have data on the last hour, last four hours, last 24 hours

2.3.9 (2018-08-03) -
    - Added the "ALT_MAIL" directive; an alternate mail program can be specified
    - Scripts defined by the "SCRIPT" parameter can now include arguments
    - Separated the curl result from the verbose output
    - Saved html files now have the timestamp before the status, so alphabetical order will also be chronological order
    - Changed all instances of "egrep" to "grep -E"

2.3.8 (2018-08-02) -
    - "--curl" is now synonymous with "--url"
    - Fixed a bug where shild processes were not dying when being told to
    - Fixed a bug where URLs with arguments might be interpreted incorrectly due to poor quoting
    - Fixed a bug where wonky DNS resolvers could result in false negatives under circumstances where an IP was not specified
    - Changed all instances of "grep" to "egrep"
    - Custom messages can now be set in the master configuration file
    - "CURL_VERBOSE" now also outputs the curl command and all command line arguments as it was ran
    - The commented out lines in child parameters files now include what the default value would have been
    - Reorganized the script so that default values were declared at the top of the script
    - Fixed a bug where intermittent failure emails did not have the correct text
    - Added more definitive rules to when the intermittent failure emails would be sent
    - Added help output for the various files and directories that LWmon uses
    - Added the "SCRIPT" parameter. The user can define a script to run every time an eamil would be sent

2.3.7 (2018-06-21) -
    - "More verbose" output now includes the number of successes, partial successes, and failures
    - The "more verbose" version of the status is output roughly every ten minutes to .lwmon/[CHILD PID]/#status
    - The .lwmon/[CHILD PID]/#status file also contains the numbers being used to calculate durations (not output with "more verbose")
    - When child processes close, they will populate .lwmon/[CHILD PID]/#status with the final output
    - Added the "--trace-time" flag for curl verbose output

2.3.6 (2016-11-09) -
    - Added the following sed command to remove non-printing characters that billing is sometimes apparently throwing in: sed 's/[\xef\xbb\xbf]//g'

2.3.5 (2016-03-30) -
    - Replaced any math using bc with awk instead.

2.3.4 (2016-03-23) -
    - Newer version of the function that handles how command line arguments are processed.
    - Any instance where the script exits now has an exit code of "0" or "1"

2.3.3 (2016-03-18) -
    - Fixed a mistake where ssh-load jobs couldn't use the "--check-timeout" or "--ctps" flags.

2.3.2 (2016-02-19) -
    - The amount of time the checks have been running is now reported in hh:mm:ss rather than seconds.
    - DNS jobs now have a minimum of five seconds rather than two seconds between checks.
    - The "--testing" flag now rebuilds the child script for every new job.
    - Fixed an error where the recreation of the command line output was wrong for "load-ps" and "load-fail"

2.3.1 (2016-01-06) -
    - Re-worded the warnings that certain components need to be installed in order to make the message more clear.
    - Not having the mail binary installed no longer stops the script from running, it just stops mail from being sent.
    - Added the "CURL_VERBOSE" and "LOG_HTTP_CODE" directives per a request from dev team.

2.3.0 (2016-01-06) -
    - Added the "--testing" flag to indicate that the mini script should be rebuilt.
    - Added the "--record-type" and "--check-result" flags for DNS jobs.
    - "--string" now relies on fgrep rather than egrep. This changes some functionality, but makes a lot more sense.

2.2.2 (2016-01-04) -
    - Added the "--job-name" flag, because it seemed weird that you couldn't specify a job name.
    - Help output now word wraps with line breaks on spaces.

2.2.1 (2015-12-28) -
    - No longer relies on "ps aux" to check if processes are running.
    - The master process only spawns one child process per loop rather than potentially spawning several all at once. Staggering them makes for less chance of taxing the processor.

1.0.0 (2013-07-09) - 2.2.0 (2015-12-24)
     Older revision information can be viewed here:
     - http://www.sporks5000.com/scripts/xmonitor.sh.1.2.1
     - http://www.sporks5000.com/scripts/lwmon.sh.1.3.1
     - http://www.sporks5000.com/scripts/lwmon.sh.1.4.1
     - http://www.sporks5000.com/scripts/lwmon.sh.2.2.0

EOF
#'do
exit 0
}

#======================#
#== Start the script ==#
#======================#

function fn_start_script {
	fn_set_defaults
	### Specify the working directory; create it if not present; specify the log file
	v_PROGRAMDIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd | sed "s/\([^/]\)$/\1\//" )"
	#"
	v_PROGRAMNAME="$( basename "${BASH_SOURCE[0]}" )"
	#"
	if [[ $v_RUNNING_STATE == "child" ]]; then
		v_WORKINGDIR="$v_PROGRAMDIR"
		v_LOG="$v_PROGRAMDIR""../""lwmon.log"
	else
		v_WORKINGDIR="$v_PROGRAMDIR"".lwmon/"
		v_LOG="$v_PROGRAMDIR""lwmon.log"
		mkdir -p "$v_WORKINGDIR"
	fi

	v_MINI_SCRIPT="$v_WORKINGDIR""$v_PROGRAMNAME"
	### find the newst version of curl
	### /usr/bin/curl is the standard installation of curl
	### /opt/curlssl/bin/curl is where cPanel keeps the version of curl that PHP works with, which is usually the most up to date
	v_CURL_BIN=$( echo -e "$( /opt/curlssl/bin/curl --version 2> /dev/null | head -n1 | awk '{print $2}' ) /opt/curlssl/bin/curl\n$( /usr/bin/curl --version 2> /dev/null | head -n1 | awk '{print $2}' ) /usr/bin/curl\n$( $( which curl ) --version 2> /dev/null | head -n1 | awk '{print $2}' ) $( which curl )" | sort -n | grep -E "^[0-9]+\.[0-9]+" | tail -n1 | awk '{print $2}' )
	fn_read_conf USE_WGET master "$v_DEFAULT_USE_WGET"; v_USE_WGET="$v_RESULT"
	if [[ -z "$v_CURL_BIN" || $v_USE_WGET == "true" ]]; then
		fn_use_wget
	else
		v_CURL_BIN_VERSION="$( $v_CURL_BIN --version 2> /dev/null | head -n1 | awk '{print $2}')"
		v_WGET_BIN="false"
	fi
}

function fn_use_wget {
	v_WGET_BIN="$( which wget 2> /dev/null )"
	if [[ -z "$v_WGET_BIN" ]]; then
		echo "curl or wget needs to be installed for lwmon to perform some of its functions. Exiting."
		exit 1
	fi
	v_WGET_BIN_VERSION="$( wget --version | head -n1 | awk '{print $3}' )"
	v_CURL_BIN="false"
}

#===================#
#== END FUNCTIONS ==#
#===================#

fn_start_script

### If there's a no-output file from the previous session, remove it.
rm -f "$v_WORKINGDIR"no_output

### Make sure that ping, and dig are installed
### curl, wget, and mail are being checked elsewhere within the script.
for i in dig ping stat ssh; do
	if [[ -z $( which $i 2> /dev/null ) ]]; then
		echo "The \"$i\" binary needs to be installed for lwmon to perform some of its functions. Exiting."
		exit 1
	fi
done

### Determine the running state
if [[ -f "$v_WORKINGDIR"lwmon.pid && $( cat /proc/$( cat "$v_WORKINGDIR"lwmon.pid )/cmdline 2> /dev/null | tr "\0" " " | grep -E -c "$v_PROGRAMNAME[[:blank:]]" ) -gt 0 ]]; then
	if [[ $PPID == $( cat "$v_WORKINGDIR"lwmon.pid ) ]]; then
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
	echo $$ > "$v_WORKINGDIR"lwmon.pid
	if [[ -f "$v_WORKINGDIR"no_output ]]; then
		rm -f "$v_WORKINGDIR"no_output
	fi
fi

### More necessary configuration files.
if [[ ! -f "$v_WORKINGDIR"lwmon.conf ]]; then
	fn_create_config
fi

### Turn the command line arguments into an array.
a_CL_ARGUMENTS=( "$@" )
v_CURL_STRING_COUNT=0

### For each command line argument, determine what needs to be done.
for (( c=0; c<=$(( $# - 1 )); c++ )); do
	v_ARGUMENT="${a_CL_ARGUMENTS[$c]}"
	if [[ $( echo $v_ARGUMENT | grep -E -c "^(--((c?url|dns|ping|kill|(ssh-)*load)(=.*)*|list|master|version|help|help-flags|help-process-types|help-params-file|help-files|modify)|[^-]*-[hmpudl])$" ) -gt 0 ]]; then
		### These flags indicate a specific action for the script to take. Two actinos cannot be taken at once.
		if [[ -n $v_RUN_TYPE ]]; then
			### If another of these actions has already been specified, end.
			echo "Cannot use \"$v_RUN_TYPE\" and \"$v_ARGUMENT\" simultaneously. Exiting."
			exit 1
		fi
		v_RUN_TYPE="$( echo "$v_ARGUMENT" | cut -d "=" -f1 )"
		if [[ $( echo "$v_ARGUMENT" | grep -E -c "^-(u|-c?url)($|=)" ) -eq 1 ]]; then
			fn_parse_cl_argument "$v_RUN_TYPE" "string" "-u"; v_CURL_URL="$v_RESULT"
			v_RUN_TYPE="--url"
		elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^-(d|-dns)($|=)" ) -eq 1 ]]; then
			fn_parse_cl_argument "--dns" "string" "-d"; v_DOMAIN="$v_RESULT"
			v_RUN_TYPE="--dns"
		elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^-(p|-ping)($|=)" ) -eq 1 ]]; then
			fn_parse_cl_argument "--ping" "string" "-p"; v_DOMAIN="$v_RESULT"
			v_RUN_TYPE="--ping"
		elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--(ssh-)*load($|=)" ) -eq 1 ]]; then
			fn_parse_cl_argument "--ssh-load" "string" "--load"; v_DOMAIN="$v_RESULT"
			v_RUN_TYPE="--ssh-load"
		elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--kill($|=)" ) -eq 1 ]]; then
			if [[ $( echo "$v_ARGUMENT" | grep -E -c "^--kill=" ) -eq 1 || ( -n ${a_CL_ARGUMENTS[$(( $c + 1 ))]} && $( echo ${a_CL_ARGUMENTS[$(( $c + 1 ))]} | grep -E -c "^-" ) -eq 0 ) ]]; then
				fn_parse_cl_argument "--kill" "num"; v_CHILD_PID="$v_RESULT"
			fi
		fi
	### All other flags modify or contribute to one of the above actions.
	elif [[ $v_ARGUMENT == "--control" ]]; then
		v_RUNNING_STATE="control"
	elif [[ $v_ARGUMENT == "--save" ]]; then
		v_SAVE_JOBS=true
	elif [[ $v_ARGUMENT == "--testing" ]]; then
		v_TESTING=true
		v_NUM_ARGUMENTS=$(( $v_NUM_ARGUMENTS - 1 ))
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--user-agent($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--user-agent" "bool" "--user-agent" "true"; v_USER_AGENT="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--(ldd|log-duration-data)($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--ldd" "bool" "--log-duration-data" "true"; v_LOG_DURATION_DATA="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--wget($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--wget" "bool" "--wget" "false"; v_USE_WGET="$v_RESULT"
		if [[ $v_USE_WGET == "true" ]]; then
			fn_use_wget
		fi
		v_NUM_ARGUMENTS=$(( $v_NUM_ARGUMENTS - 1 ))
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--(e)*mail($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--mail" "string" "--email"; v_EMAIL_ADDRESS="$v_RESULT"
		if [[ -z $v_EMAIL_ADDRESS || $( echo $v_EMAIL_ADDRESS | grep -E -c "^[^@]+@[^.@]+\.[^@]+$" ) -lt 1 ]]; then
			echo "The flag \"--mail\" needs to be followed by an e-mail address. Exiting."
			exit 1
		fi
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--seconds($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--seconds" "float"; v_WAIT_SECONDS="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--ctps($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--ctps" "float"; v_CHECK_TIME_PARTIAL_SUCCESS="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--check-timeout($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--check-timeout" "float"; v_CHECK_TIMEOUT="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--mail-delay($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--mail-delay" "num"; v_MAIL_DELAY="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--load-ps($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--load-ps" "float"; v_MIN_LOAD_PARTIAL_SUCCESS="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--load-fail($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--load-fail" "float"; v_MIN_LOAD_FAILURE="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--port($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--port" "num"; v_CL_PORT="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--(ndr|num-durations-recent)($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--ndr" "num" "--num-durations-recent"; v_NUM_DURATIONS_RECENT="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--(nsr|num-statuses-recent)($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--nsr" "num" "--num-statuses-recent"; v_NUM_STATUSES_RECENT="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--(nsns|num-statuses-not-success)($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--nsns" "num" "--num-statuses-not-success"; v_NUM_STATUSES_NOT_SUCCESS="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--(ident|ticket)($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--ident" "num" "--ticket"; v_IDENT="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--ip(-address)*($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--ip" "string" "--ip-address"; v_IP_ADDRESS="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--string($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--string" "string"; a_CURL_STRING[${#a_CURL_STRING[@]}]="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--(check-)*domain($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--domain" "string" "--check-domain"; v_DNS_CHECK_DOMAIN="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--check-result($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--check-result" "string"; v_DNS_CHECK_RESULT="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--record-type($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--record-type" "string"; v_DNS_RECORD_TYPE="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--(ssh-)*user($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--user" "string" "--ssh-user"; v_SSH_USER="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--job-name($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--job-name" "string"; v_JOB_NAME="$v_RESULT"
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--verbos(e|ity)($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--verbosity" "string" "--verbose"; v_VERBOSITY="$v_RESULT"
		if [[ $v_VERBOSITY == "more" && "${a_CL_ARGUMENTS[$(( $c + 1 ))]}" == "verbose" ]]; then
			c=$(( $c + 1 ))
			v_VERBOSITY="more verbose"
		elif [[ $v_VERBOSITY == "more" ]]; then
			v_VERBOSITY="more verbose"
		fi
		if [[ $( echo "$v_VERBOSITY" | grep -E -c "^(verbose|more verbose|standard|change|none)$" ) -eq 0 ]]; then
			echo "The flag \"--verbosity\" needs to be followed by either \"verbose\", \"more verbose\", \"standard\", \"change\", or \"none\". Exiting."
			exit 1
		fi
	elif [[ $( echo "$v_ARGUMENT" | grep -E -c "^--out(put-)*file($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--outfile" "string" "--output-file"; v_OUTPUT_FILE="$v_RESULT"
		fn_test_file "$v_OUTPUT_FILE" false true; v_OUTPUT_FILE="$v_RESULT"
		if [[ -z "$v_OUTPUT_FILE" ]]; then
			echo "The flag \"--outfile\" needs to be followed by a file with write permissions referenced by its full path. Exiting."
			exit 1
		fi
	else
		if [[ $( echo "$v_ARGUMENT "| grep -E -c "^-" ) -eq 1 ]]; then
			echo "There is no such flag \"$v_ARGUMENT\". Exiting."
		else
			echo "I don't understand what flag the argument \"$v_ARGUMENT\" is supposed to be associated with. Exiting."
		fi
		exit 1
	fi
	v_NUM_ARGUMENTS=$(( $v_NUM_ARGUMENTS + 1 ))
done

### Some of these flags need to be used alone.
if [[ $v_RUN_TYPE == "--master" || $v_RUN_TYPE == "--version" || $v_RUN_TYPE == "--help-files" || $v_RUN_TYPE == "--help-flags" || $v_RUN_TYPE == "--help-process-types" || $v_RUN_TYPE == "--help-params-file" || $v_RUN_TYPE == "--help" || $v_RUN_TYPE == "--modify" || $v_RUN_TYPE == "-h" || $v_RUN_TYPE == "-m" ]]; then
	if [[ $v_NUM_ARGUMENTS -gt 1 ]]; then
		echo "The flag \"$v_RUN_TYPE\" cannot be used with other flags. Exiting."
		exit 1
	fi
fi
### Tells the script where to go with the type of job that was selected.
if [[ $v_RUN_TYPE == "--url" || $v_RUN_TYPE == "-u" ]]; then
	fn_url_cl
elif [[ $v_RUN_TYPE == "--ping" || $v_RUN_TYPE == "-p" ]]; then
	fn_ping_cl
elif [[ $v_RUN_TYPE == "--dns" || $v_RUN_TYPE == "-d" ]]; then
	fn_dns_cl
elif [[ $v_RUN_TYPE == "--ssh-load" ]]; then
	fn_load_cl
elif [[ $v_RUN_TYPE == "--kill" ]]; then
	if [[ -n $v_CHILD_PID ]]; then
		if [[ ! -f  "$v_WORKINGDIR"$v_CHILD_PID/params ]]; then
			echo "Child ID provided does not exist."
			exit 1
		fi
		touch "$v_WORKINGDIR"$v_CHILD_PID/die
		echo "The child process will exit shortly."
		exit 0
	elif [[ $v_SAVE_JOBS == true ]]; then
		if [[ $v_NUM_ARGUMENTS -gt 2 ]]; then
			echo "The \"--kill\" flag can only used alone, with the \"--save\" flag, or in conjunction with the ID number of a child process. Exiting."
			exit 1
		fi
		touch "$v_WORKINGDIR"save
	else
		if [[ $v_NUM_ARGUMENTS -gt 1 ]]; then
			echo "The \"--kill\" flag can only used alone, with the \"--save\" flag, or in conjunction with the ID number of a child process. Exiting."
			exit 1
		fi
	fi
	touch "$v_WORKINGDIR"die
	exit 0
elif [[ $v_RUN_TYPE == "--version" ]]; then
	fn_version
	exit 0
elif [[ $v_RUN_TYPE == "--help" || $v_RUN_TYPE == "-h" ]]; then
	fn_help
	exit 0
elif [[ $v_RUN_TYPE == "--help-flags" ]]; then
	fn_help_flags
	exit 0
elif [[ $v_RUN_TYPE == "--help-files" ]]; then
	fn_help_files
	exit 0
elif [[ $v_RUN_TYPE == "--help-process-types" ]]; then
	fn_help_process_types
	exit 0
elif [[ $v_RUN_TYPE == "--help-params-file" ]]; then
	fn_help_params_file
	exit 0
elif [[ $v_RUN_TYPE == "--modify" || $v_RUN_TYPE == "-m" ]]; then
	fn_modify
elif [[ $v_RUN_TYPE == "--list" || $v_RUN_TYPE == "-l" ]]; then
	fn_list
	echo
	exit 0
elif [[ $v_RUN_TYPE == "--master" ]]; then
	fn_master
elif [[ -z $v_RUN_TYPE ]]; then
	if [[ $v_NUM_ARGUMENTS -ne 0 ]]; then
		echo "Some of the flags you used didn't make sense in context. Here's a menu instead."
	fi
	fn_modify
fi

echo "The script should not get to this point. Exiting"
exit 1




### End of Script
