#! /bin/bash
v_VERSION="#####"

function fn_locate {
	f_PROGRAM="$( readlink "${BASH_SOURCE[0]}" )"
	if [[ -z $f_PROGRAM ]]; then
		f_PROGRAM="${BASH_SOURCE[0]}"
	fi
	d_PROGRAM="$( cd -P "$( dirname "$f_PROGRAM" )" && cd ../ && pwd )"
	f_PROGRAM="$( basename "$f_PROGRAM" )"
}
fn_locate
source "$d_PROGRAM"/includes/mutual.shf

function fn_child {
	### The opening part of a child process!
	### Wait to make sure that the params file is in place.
	sleep 1
	### Make sure that the child processes are not exited out of o'er hastily.
	trap fn_child_exit SIGINT SIGTERM SIGKILL
	### Define the variables that will be used over the life of the child process
	v_CHILD_PID=$$
	if [[ ! -f "$d_WORKING"/lwmon.pid ]]; then
		echo ""$( date +%F":"%T" "%Z )" - [$v_CHILD_PID] - No Master Process present. Exiting." >> "$v_LOG"
		exit 1
	fi
	v_MASTER_PID=$( cat "$d_WORKING"/lwmon.pid )
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
	if [[ $( grep -E -c "^[[:blank:]]*JOB_TYPE[[:blank:]]*=" "$d_WORKING"/"$v_CHILD_PID""/params" ) -eq 1 ]]; then
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
	v_PARAMS_RELOAD="$( stat --format=%Y "$d_WORKING"/"$v_CHILD_PID/params" )" #"
	v_MASTER_RELOAD="$( stat --format=%Y "$d_WORKING"/"lwmon.conf" )" #"
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
	echo "$v_JOB_CL_STRING" > "$d_WORKING"/"$v_CHILD_PID"/cl
}

function fn_child_dates {
	v_DATE3_LAST="$v_DATE3"
	v_DATE="$( date +%m"/"%d" "%H":"%M":"%S )"
	v_DATE2="$( date +%F" "%T" "%Z )"
	v_DATE3="$( date +%s )"
}
function fn_url_child {
	###The basic loop for a URL monitoring process.
	v_URL_OR_PING="URL"
	unset -f fn_load_child
	unset -f fn_ping_child
	unset -f fn_dns_child
	while [[ 1 == 1 ]]; do
		fn_child_dates
		### Set up the command line arguments for curl
		f_STDERR="/dev/null"
		if [[ $v_WGET_BIN == "false" ]]; then
			if [[ $v_IP_ADDRESS == false ]]; then
				a_CURL_ARGS=( "$v_CHECK_TIMEOUT" "$v_CURL_URL" "--header" "User-Agent: $v_USER_AGENT" "-o" "$d_WORKING"/"$v_CHILD_PID/site_current.html" )
			else
				a_CURL_ARGS=( "$v_CHECK_TIMEOUT" "$v_CURL_URL" "--header" "Host: $v_DOMAIN" "--header" "User-Agent: $v_USER_AGENT" "-o" "$d_WORKING"/"$v_CHILD_PID/site_current.html" )
			fi
			if [[ $v_CURL_VERBOSE != true ]]; then
				a_CURL_ARGS=( "-kLsm" "${a_CURL_ARGS[@]}" )
			else
				a_CURL_ARGS=( "-kLsvm" "${a_CURL_ARGS[@]}" )
				f_STDERR="$d_WORKING"/"$v_CHILD_PID"/current_verbose_output.txt
				echo "$v_CURL_BIN ${a_CURL_ARGS[@]}" > "$f_STDERR"
			fi
		else
			if [[ $v_IP_ADDRESS == false ]]; then
				a_WGET_ARGS=( "--no-check-certificate" "-q" "--timeout=$v_CHECK_TIMEOUT" "-O" "$d_WORKING"/"$v_CHILD_PID/site_current.html" "$v_CURL_URL" "--header=User-Agent: $v_USER_AGENT" )
			else
				a_WGET_ARGS=( "--no-check-certificate" "-q" "--timeout=$v_CHECK_TIMEOUT" "-O" "$d_WORKING"/"$v_CHILD_PID/site_current.html" "$v_CURL_URL" "--header=Host: $v_DOMAIN" "--header=User-Agent: $v_USER_AGENT" )
			fi
		fi
		### Move the current download of the site to the previous
		if [[ -f "$d_WORKING"/"$v_CHILD_PID"/site_current.html ]]; then
			### The only instance where this isn't the case should be on the first run of the loop.
			mv -f "$d_WORKING"/"$v_CHILD_PID"/site_current.html "$d_WORKING"/"$v_CHILD_PID"/site_previous.html
		fi
		if [[ -f "$d_WORKING"/"$v_CHILD_PID"/previous_verbose_output.txt ]]; then
			rm -f "$d_WORKING"/"/$v_CHILD_PID"/previous_verbose_output.txt
		fi
		if [[ -f "$d_WORKING"/"$v_CHILD_PID"/current_verbose_output.txt ]]; then
			mv -f "$d_WORKING"/"$v_CHILD_PID"/current_verbose_output.txt "$d_WORKING"/"$v_CHILD_PID"/previous_verbose_output.txt
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
			echo -e "\n\n\n\nCurl return code: $v_STATUS (This means that the timeout was reached before the full page was returned.)" >> "$d_WORKING"/"$v_CHILD_PID"/current_verbose_output.txt
		elif [[ $v_STATUS != 0 && $v_WGET_BIN == "false" ]]; then
			echo -e "\n\n\n\nCurl return code: $v_STATUS" >> "$d_WORKING"/"$v_CHILD_PID"/current_verbose_output.txt
		elif [[ $v_STATUS != 0 ]]; then
			echo -e "\n\n\n\nWget return code: $v_STATUS" >> "$d_WORKING"/"$v_CHILD_PID"/current_verbose_output.txt
		fi
		if [[ $v_CURL_VERBOSE == true && $v_LOG_HTTP_CODE == true ]]; then
		### Capture the html response code, if so directed.
			v_HTML_RESPONSE_CODE="$( cat "$d_WORKING"/"$v_CHILD_PID"/current_verbose_output.txt | grep -E -m1 "<" | cut -d " " -f3- | tr -dc '[[:print:]]' )"
			if [[ -z $v_HTML_RESPONSE_CODE ]]; then
				v_HTML_RESPONSE_CODE="No Code Reported"
			fi
		fi
		### Check the curl strings
		i=0; j=0; while [[ $i -lt ${#a_CURL_STRING[@]} ]]; do
			if [[ $( fgrep -c "${a_CURL_STRING[$i]}" "$d_WORKING"/"$v_CHILD_PID"/site_current.html ) -gt 0 ]]; then
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
			echo "$v_DATE2 - [$v_CHILD_PID] - The HTML response code has changed to \"$v_HTML_RESPONSE_CODE\"." >> "$d_WORKING"/"$v_CHILD_PID"/log
			v_LAST_HTML_RESPONSE_CODE="$v_HTML_RESPONSE_CODE"
		fi
		fn_child_checks
	done
}

function fn_load_child {
	v_URL_OR_PING="Load on"
	unset -f fn_url_child
	unset -f fn_ping_child
	unset -f fn_dns_child
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
	unset -f fn_url_child
	unset -f fn_load_child
	unset -f fn_dns_child
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
	unset -f fn_url_child
	unset -f fn_load_child
	unset -f fn_ping_child
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
	if [[ "$( stat --format=%Y "$d_WORKING"/"$v_CHILD_PID/params" )" -gt "$v_PARAMS_RELOAD" ]]; then
		fn_child_vars
		echo "$v_DATE2 - [$v_CHILD_PID] - Reloaded parameters for $v_URL_OR_PING $v_ORIG_JOB_NAME." >> "$v_LOG"
		echo "$v_DATE2 - [$v_CHILD_PID] - Reloaded parameters for $v_URL_OR_PING $v_ORIG_JOB_NAME." >> "$d_WORKING"/"$v_CHILD_PID"/log
		echo "***Reloaded parameters for $v_URL_OR_PING $v_JOB_NAME.***"
	elif [[ "$( stat --format=%Y "$d_WORKING"/"lwmon.conf" )" -gt "$v_MASTER_RELOAD" ]]; then
	### fn_child_vars updates both the reload variables.
		fn_child_vars
	fi
	if [[ $( ls -1 "$d_WORKING"/"$v_CHILD_PID"/ | grep -E "^site_" | grep -E -cv "current|previous" ) -gt $v_HTML_FILES_KEPT ]]; then
		### You'll notice that it's only removing one file. There should be no instances where more than one is generated per run, so removing one per run should always be sufficient.
		rm -f "$d_WORKING"/"$v_CHILD_PID"/site_"$( ls -1t "$d_WORKING"/"$v_CHILD_PID"/ | grep -E "^site_" | grep -E -v "current|previous" | tail -n1 | sed "s/site_//" )"
	fi
	### If the domain or IP address shows up on the die list, this process can be killed.
	if [[ $( grep -E -c "^[[:blank:]]*($v_DOMAIN|$v_IP_ADDRESS)[[:blank:]]*(#.*)*$" "$d_WORKING"/die_list ) -gt 0 ]]; then
		echo "$v_DATE2 - [$v_CHILD_PID] - Process ended due to data on the remote list. The line reads \"$( grep -E "^[[:blank:]]*($v_DOMAIN|$v_IP_ADDRESS)[[:blank:]]*(#.*)*$" "$d_WORKING"/die_list | head -n1 )\"." >> "$v_LOG"
		echo "$v_DATE2 - [$v_CHILD_PID] - Process ended due to data on the remote list. The line reads \"$( grep -E "^[[:blank:]]*($v_DOMAIN|$v_IP_ADDRESS)[[:blank:]]*(#.*)*$" "$d_WORKING"/die_list | head -n1 )\"." >> "$d_WORKING"/"$v_CHILD_PID"/log
		touch "$d_WORKING"/"$v_CHILD_PID"/die
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
		echo "$v_DATE2 - [$v_CHILD_PID] - Stopped watching $v_URL_OR_PING $v_ORIG_JOB_NAME: Running for $v_RUN_TIME seconds. $v_TOTAL_CHECKS checks completed. $v_PERCENT_SUCCESSES% success rate." >> "$d_WORKING"/"$v_CHILD_PID"/log
	fi
	### Instead of deleting the directory, back it up temporarily.
	if [[ -f "$d_WORKING"/"$v_CHILD_PID"/die ]]; then
		mv -f "$d_WORKING"/"$v_CHILD_PID"/die "$d_WORKING"/"$v_CHILD_PID"/#die
		mv "$d_WORKING"/"$v_CHILD_PID" "$d_WORKING"/"old_""$v_CHILD_PID""_""$v_DATE3"
	fi

	### Record the final "more verbose" status
	
	exit $v_EXIT_CODE
}

function fn_report_status {
	### $1 is the status. $2 is whether or not to try to save the file
	v_THIS_STATUS="$1"
	local v_SAVE="$2"

	### This is present if, for testing purposes, we need to override the result of a check
	if [[ -f "$d_WORKING"/"$v_CHILD_PID"/force_success ]]; then
		v_THIS_STATUS="success"
		rm -f "$d_WORKING"/"$v_CHILD_PID"/force_success
	elif [[ -f "$d_WORKING"/"$v_CHILD_PID"/force_failure ]]; then
		v_THIS_STATUS="failure"
		rm -f "$d_WORKING"/"$v_CHILD_PID"/force_failure
	elif [[ -f "$d_WORKING"/"$v_CHILD_PID"/force_partial ]]; then
		v_THIS_STATUS="partial success"
		rm -f "$d_WORKING"/"$v_CHILD_PID"/force_partial
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
	if [[ $( cat /proc/$v_MASTER_PID/cmdline 2> /dev/null | tr "\0" " " | grep -E -c "lwmon.sh[[:blank:]]" ) -eq 0 || -f "$d_WORKING"/"$v_CHILD_PID"/die ]]; then
		v_DUMP_STATUS=true
		v_DIE=true
	fi

	if [[ $v_VERBOSITY == "more verbose" || -f "$d_WORKING"/"$v_CHILD_PID"/status || $v_DUMP_STATUS == true ]]; then
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
		if [[ -f "$d_WORKING"/"$v_CHILD_PID"/status || $v_DUMP_STATUS == true ]]; then
			echo -e "$v_REPORT2""\n  Total duration:               $v_TOTAL_DURATIONS seconds\n  Total recent duration:        $v_TOTAL_RECENT_DURATION seconds\n  Total successful duration:    $v_TOTAL_SUCCESS_DURATIONS seconds\n  Last $v_LONG_HOURS hours:\n    Number of checks completed: $v_LONG_COUNT\n    #Success/#Partial/#Failure: $v_LONG_SUCCESS / $v_LONG_PARTIAL / $v_LONG_FAIL\n    %Success/%Partial/%Failure: $v_LONG_PERCENT_SUCCESS% / $v_LONG_PERCENT_PARTIAL% / $v_LONG_PERCENT_FAIL%\n    Average check:              $v_LONG_AVERAGE_DURATION seconds\n    Total duration:             $v_LONG_TOTAL_DURATION seconds\n  Last $v_SHORT_HOURS hours:\n    Number of checks completed: $v_SHORT_COUNT\n    #Success/#Partial/#Failure: $v_SHORT_SUCCESS / $v_SHORT_PARTIAL / $v_SHORT_FAIL\n    %Success/%Partial/%Failure: $v_SHORT_PERCENT_SUCCESS% / $v_SHORT_PERCENT_PARTIAL% / $v_SHORT_PERCENT_FAIL%\n    Average check:              $v_SHORT_AVERAGE_DURATION seconds\n    Total duration:             $v_SHORT_TOTAL_DURATION seconds" > "$d_WORKING"/"$v_CHILD_PID"/status
			mv -f "$d_WORKING"/"$v_CHILD_PID"/status "$d_WORKING"/"$v_CHILD_PID/#status"
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
	elif [[ "$v_VERBOSITY" == "more verbose" || -f "$d_WORKING"/"$v_CHILD_PID"/status ]]; then
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
		if [[ "$v_VERBOSITY" != "change" && "$v_VERBOSITY" != "none" && ! -f "$d_WORKING"/no_output ]]; then
			echo -e "$v_COLOR_START""$v_REPORT""$v_COLOR_END" >> "$v_OUTPUT_FILE"
		fi
		fn_send_email
	### If there was no last status
	elif [[ -z $v_LAST_STATUS ]]; then
		if [[ "$v_VERBOSITY" != "none" && ! -f "$d_WORKING"/no_output ]]; then
			echo -e "$v_COLOR_START""$v_REPORT""$v_COLOR_END" >> "$v_OUTPUT_FILE"
		fi
		echo "$v_DATE2 - [$v_CHILD_PID] - Initial status for $v_URL_OR_PING $v_ORIG_JOB_NAME: $v_DESCRIPTOR2" >> "$v_LOG"
		echo "$v_DATE2 - [$v_CHILD_PID] - Initial status for $v_URL_OR_PING $v_ORIG_JOB_NAME: $v_DESCRIPTOR2" >> "$d_WORKING"/"$v_CHILD_PID"/log
		### Mark the email type so that a message is not sent erroneously
		v_LAST_EMAIL_SENT="$v_THIS_STATUS"
	### If the last status was also successful
	elif [[ "$v_LAST_STATUS" == "success" ]]; then
		if [[ "$v_VERBOSITY" != "none" && ! -f "$d_WORKING"/no_output ]]; then
			echo -e "$v_COLOR_START""$v_REPORT""$v_COLOR_END" >> "$v_OUTPUT_FILE"
		fi
		echo "$v_LOG_MESSAGE after $v_SUCCESS_CHECKS successful checks" >> "$v_LOG"
		echo "$v_LOG_MESSAGE after $v_SUCCESS_CHECKS successful checks" >> "$d_WORKING"/"$v_CHILD_PID"/log
		v_SUCCESS_CHECKS=0
		if [[ "$v_SAVE" == "save" && "$v_THIS_STATUS" == "failure" ]]; then
			cp -a "$d_WORKING"/"$v_CHILD_PID"/site_current.html "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3"_fail.html
			if [[ -f "$d_WORKING"/"$v_CHILD_PID"/current_verbose_output.txt ]]; then
				echo -e "\n\n\n\n" >> "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3"_fail.html
				cat "$d_WORKING"/"$v_CHILD_PID"/current_verbose_output.txt >> "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3"_fail.html
			fi
			cp -a "$d_WORKING"/"$v_CHILD_PID"/site_previous.html "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3_LAST"_success.html
			if [[ -f "$d_WORKING"/"$v_CHILD_PID"/previous_verbose_output.txt ]]; then
				echo -e "\n\n\n\n" >> "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3_LAST"_success.html
				cat "$d_WORKING"/"$v_CHILD_PID"/previous_verbose_output.txt >> "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3_LAST"_success.html
			fi
		elif [[ "$v_SAVE" == "save" && "$v_THIS_STATUS" == "partial success" ]]; then
			cp -a "$d_WORKING"/"$v_CHILD_PID"/site_current.html "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3"_psuccess.html
			if [[ -f "$d_WORKING"/"$v_CHILD_PID"/current_verbose_output.txt ]]; then
				echo -e "\n\n\n\n" >> "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3"_psuccess.html
				cat "$d_WORKING"/"$v_CHILD_PID"/current_verbose_output.txt >> "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3"_psuccess.html
			fi
			cp -a "$d_WORKING"/"$v_CHILD_PID"/site_previous.html "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3_LAST"_success.html
			if [[ -f "$d_WORKING"/"$v_CHILD_PID"/previous_verbose_output.txt ]]; then
				echo -e "\n\n\n\n" >> "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3_LAST"_success.html
				cat "$d_WORKING"/"$v_CHILD_PID"/previous_verbose_output.txt >> "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3_LAST"_success.html
			fi
		fi
		fn_send_email
	### If the last status was partial success
	elif [[ "$v_LAST_STATUS" == "partial success" ]]; then
		if [[ "$v_VERBOSITY" != "none" && ! -f "$d_WORKING"/no_output ]]; then
			echo -e "$v_COLOR_START""$v_REPORT""$v_COLOR_END" >> "$v_OUTPUT_FILE"
		fi
		echo "$v_LOG_MESSAGE after $v_PARTIAL_SUCCESS_CHECKS partial successes" >> "$v_LOG"
		echo "$v_LOG_MESSAGE after $v_PARTIAL_SUCCESS_CHECKS partial successes" >> "$d_WORKING"/"$v_CHILD_PID"/log
		v_PARTIAL_SUCCESS_CHECKS=0
		if [[ "$v_SAVE" == "save" && "$v_THIS_STATUS" == "failure" ]]; then
			cp -a "$d_WORKING"/"$v_CHILD_PID"/site_current.html "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3"_fail.html
			if [[ -f "$d_WORKING"/"$v_CHILD_PID"/current_verbose_output.txt ]]; then
				echo -e "\n\n\n\n" >> "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3"_fail.html
				cat "$d_WORKING"/"$v_CHILD_PID"/current_verbose_output.txt >> "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3"_fail.html
			fi
			cp -a "$d_WORKING"/"$v_CHILD_PID"/site_previous.html "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3_LAST"_psuccess.html
			if [[ -f "$d_WORKING"/"$v_CHILD_PID"/previous_verbose_output.txt ]]; then
				echo -e "\n\n\n\n" >> "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3_LAST"_psuccess.html
				cat "$d_WORKING"/"$v_CHILD_PID"/previous_verbose_output.txt >> "$d_WORKING"/"$v_CHILD_PID"/site_"$v_DATE3_LAST"_psuccess.html
			fi
		fi
		fn_send_email
	### If the last status was failure
	elif [[ "$v_LAST_STATUS" == "failure" ]]; then
		if [[ "$v_VERBOSITY" != "none" && ! -f "$d_WORKING"/no_output ]]; then
			echo -e "$v_COLOR_START""$v_REPORT""$v_COLOR_END" >> "$v_OUTPUT_FILE"
		fi
		echo "$v_LOG_MESSAGE after $v_FAILURE_CHECKS failed checks" >> "$v_LOG"
		echo "$v_LOG_MESSAGE after $v_FAILURE_CHECKS failed checks" >> "$d_WORKING"/"$v_CHILD_PID"/log
		v_FAILURE_CHECKS=0
		fn_send_email
	fi
	### If we need to log the duration data, do so
	if [[ "$v_LOG_DURATION_DATA" == "true" ]]; then
		echo "$v_DATE2 - [$v_CHILD_PID] - Status: $v_DESCRIPTOR2 - Duration $v_CHECK_DURATION seconds" >> "$d_WORKING"/"$v_CHILD_PID"/log
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
	v_MUTUAL_EMAIL="thus meeting your threshold for being alerted. Since the previous e-mail was sent (Or if none have been sent, since checks against this server were started) there have been a total of $v_NUM_SUCCESSES_EMAIL successful checks, $v_NUM_PARTIAL_SUCCESSES_EMAIL partially successful checks, and $v_NUM_FAILURES_EMAIL failed checks.\n\nChecks have been running for $v_RUN_TIME. $v_TOTAL_CHECKS checks completed. $v_PERCENT_SUCCESSES% success rate.\n\nThis check took $v_CHECK_DURATION seconds to complete. The last ${#a_RECENT_DURATIONS[@]} checks took an average of $v_AVERAGE_RECENT_DURATION seconds to complete. The average successful check has taken $v_AVERAGE_SUCCESS_DURATION seconds to complete. The average check overall has taken $v_AVERAGE_DURATION seconds to complete.\n\nLogs related to this check:\n\n$( cat "$d_WORKING"/"$v_CHILD_PID"/log | grep -E -v "\] - (The HTML response code|Status: (Check (failed|succeeded)|Partial success) - Duration)" )"
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

v_RUNNING_STATE="child"
fn_start_script
if [[ -n "$1" ]]; then
	fn_child
fi
