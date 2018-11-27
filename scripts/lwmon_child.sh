#! /bin/bash

#=======================#
#== Declare Variables ==#
#=======================#

### Debugging variables
b_DEBUG=false
b_DEBUG_FUNCTIONS=false

### Global variables not related to running jobs
d_PROGRAM=

### Things that I should probably make variables in the master conf
v_STATUS_DUMP_INC=600
v_LONG_HOURS=8
v_SHORT_HOURS=1

### Variables with initial values
v_CHILD_PID="$$"
v_START_TIME="$( date +%s )"
v_TOTAL_DURATIONS=0
v_AVERAGE_DURATION=0
v_TOTAL_SUCCESS_DURATIONS=0
v_TOTAL_SUCCESSES=0
v_TOTAL_PARTIAL_SUCCESSES=0
v_TOTAL_FAILURES=0
v_NUM_SUCCESSES_EMAIL=0
v_NUM_PARTIAL_SUCCESSES_EMAIL=0
v_NUM_FAILURES_EMAIL=0
v_LAST_HTML_RESPONSE_CODE="none"
v_NEXT_STATUS_DUMP="$v_STATUS_DUMP_INC"

### Initial variables for long and short hours
v_LONG_TOTAL_DURATION=0
v_LONG_SUCCESS=0
v_LONG_PARTIAL=0
v_LONG_FAIL=0
v_SHORT_TOTAL_DURATION=0
v_SHORT_SUCCESS=0
v_SHORT_PARTIAL=0
v_SHORT_FAIL=0
v_SHORT_PLACE=0

### Revolving variables related to keeping track of things over time
v_LONG_COUNT=0
v_SHORT_COUNT=0
a_LONG_STAMPS=()
a_LONG_STATUSES=()
a_LONG_DURATIONS=()
v_TOTAL_RECENT_DURATION=0
a_RECENT_DURATIONS=()
v_AVERAGE_RECENT_DURATION=0
a_RECENT_STATUSES=()

### Date Variables
v_DATE3_LAST=
v_DATE=
v_DATE2=
v_DATE3=

### Other global variables that are used throughout
v_MASTER_PID=
d_CHILD=
v_PARAMS_RELOAD=
v_MASTER_RELOAD=
v_VERSION=
v_URL_OR_PING=
v_CHECK_START=
v_CHECK_START=
v_CHECK_END=
v_CHECK_DURATION=
v_LOAD_AVG=
v_LAST_SUCCESS=
v_DESCRIPTOR1=
v_DESCRIPTOR2=
v_SUCCESS_CHECKS=
v_LAST_PARTIAL_SUCCESS=
v_PARTIAL_SUCCESS_CHECKS=
v_LAST_FAILURE=
v_FAILURE_CHECKS=
v_RUN_TIME=
v_TOTAL_CHECKS=
v_PERCENT_SUCCESSES=
v_SENT=
v_LAST_EMAIL_SENT=
v_LAST_STATUS=

#=====================#
#== Begin Functions ==#
#=====================#

function fn_locate {
	if [[ "$b_DEBUG_FUNCTIONS" == true ]]; then echo "$$: fn_locate" > /dev/stderr; fi
	local f_PROGRAM="$( readlink -f "${BASH_SOURCE[0]}" )"
	if [[ -z "$f_PROGRAM" ]]; then
		f_PROGRAM="${BASH_SOURCE[0]}"
	fi
	d_PROGRAM="$( cd -P "$( dirname "$f_PROGRAM" )" && cd ../ && pwd )"
}

#==================================================#
#== Functions for Starting and Ending Child Jobs ==#
#==================================================#

function fn_child {
### The opening part of a child process!
	fn_debug "fn_child"
	### Wait to make sure that the params file is in place.
	sleep 1
	### Make sure that the child processes are not exited out of o'er hastily.
	trap fn_child_exit SIGINT SIGTERM SIGKILL
	### Define the variables that will be used over the life of the child process
	if [[ ! -f "$d_WORKING"/lwmon.pid ]]; then
		echo "$( date +%F":"%T" "%Z ) - [$v_CHILD_PID] - No Master Process present. Exiting." >> "$v_LOG"
		exit 1
	fi
	v_MASTER_PID="$( cat "$d_WORKING"/lwmon.pid )"
	d_CHILD="$d_WORKING"/"$v_CHILD_PID"
	v_PARAMS_RELOAD="$( stat --format=%Y "$d_CHILD"/params )"
	v_MASTER_RELOAD="$( stat --format=%Y "$f_CONF" )"
	if [[ $( grep -E -c "^[[:blank:]]*JOB_TYPE[[:blank:]]*=" "$d_CHILD"/params ) -eq 1 ]]; then
		fn_read_child_params "$d_CHILD"/params
		if [[ "$v_JOB_TYPE" == "url" ]]; then
			fn_url_child
		elif [[ "$v_JOB_TYPE" == "ping" ]]; then
			fn_ping_child
		elif [[ "$v_JOB_TYPE" == "dns" ]]; then
			fn_dns_child
		elif [[ "$v_JOB_TYPE" == "ssh-load" ]]; then
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

function fn_child_exit {
	fn_debug "fn_child_exit"

	### When a child process exits, it needs to clean up after itself and log the fact that it has exited. "$1" is the exit code that should be output.
	v_EXIT_CODE="$1"
	if [[ "$v_TOTAL_CHECKS" -gt 0 ]]; then
		echo "$v_DATE2 - [$v_CHILD_PID] - Stopped watching $v_URL_OR_PING $v_ORIG_JOB_NAME: Running for $v_RUN_TIME seconds. $v_TOTAL_CHECKS checks completed. $v_PERCENT_SUCCESSES% success rate." >> "$v_LOG"
		echo "$v_DATE2 - [$v_CHILD_PID] - Stopped watching $v_URL_OR_PING $v_ORIG_JOB_NAME: Running for $v_RUN_TIME seconds. $v_TOTAL_CHECKS checks completed. $v_PERCENT_SUCCESSES% success rate." >> "$d_CHILD"/log
	fi
	### Instead of deleting the directory, back it up temporarily.
	if [[ -f "$d_CHILD"/die ]]; then
		mv -f "$d_CHILD"/die "$d_CHILD"/#die
		mv "$d_CHILD" "$d_WORKING"/"old_""$v_CHILD_PID""_""$v_DATE3"
	fi

	### Record the final "more verbose" status
	
	exit "$v_EXIT_CODE"
}

#==========================================#
#== Functions for Specific Types of Jobs ==#
#==========================================#

function fn_url_child {
### The basic loop for a URL monitoring process.
	fn_debug "fn_url_child"
	v_URL_OR_PING="URL"
	unset -f fn_load_child
	unset -f fn_ping_child
	unset -f fn_dns_child
	local v_LAST_HTML_RESPONSE_CODE
	local f_STDERR="/dev/null"
	local a_CURL_ARGS=()
	v_VERSION="$( fn_version )"
	while [[ 1 == 1 ]]; do
		fn_child_start_loop
		### Change the name of the previous download of the site
		if [[ -f "$d_CHILD"/site_current.html ]]; then
			### The only instance where this isn't the case should be on the first run of the loop.
			mv -f "$d_CHILD"/site_current.html "$d_CHILD"/site_previous.html
		fi
		if [[ -f "$d_CHILD"/current_verbose_output.txt ]]; then
			mv -f "$d_CHILD"/current_verbose_output.txt "$d_CHILD"/previous_verbose_output.txt
		fi
		### Set up the command line arguments for curl
		if [[ "$v_WGET_BIN" == "false" ]]; then
			if [[ "$v_IP_ADDRESS" == false ]]; then
				a_CURL_ARGS=( "$v_CHECK_TIMEOUT" "$v_CURL_URL" "--header" "User-Agent: $v_USER_AGENT" "-o" "$d_CHILD/site_current.html" )
			else
				a_CURL_ARGS=( "$v_CHECK_TIMEOUT" "$v_CURL_URL" "--header" "Host: $v_DOMAIN" "--header" "User-Agent: $v_USER_AGENT" "-o" "$d_CHILD/site_current.html" )
			fi
			if [[ "$v_CURL_VERBOSE" != true ]]; then
				a_CURL_ARGS=( "-kLsm" "${a_CURL_ARGS[@]}" )
			else
				a_CURL_ARGS=( "-kLsvm" "${a_CURL_ARGS[@]}" )
				f_STDERR="$d_CHILD"/current_verbose_output.txt
				echo "$v_CURL_BIN ${a_CURL_ARGS[@]}" > "$f_STDERR"
			fi
		else
			if [[ "$v_IP_ADDRESS" == false ]]; then
				a_WGET_ARGS=( "--no-check-certificate" "-q" "--timeout=$v_CHECK_TIMEOUT" "-O" "$d_CHILD/site_current.html" "$v_CURL_URL" "--header=User-Agent: $v_USER_AGENT" )
			else
				a_WGET_ARGS=( "--no-check-certificate" "-q" "--timeout=$v_CHECK_TIMEOUT" "-O" "$d_CHILD/site_current.html" "$v_CURL_URL" "--header=Host: $v_DOMAIN" "--header=User-Agent: $v_USER_AGENT" )
			fi
		fi
		### curl it!
		if [[ "$v_WGET_BIN" == "false" ]]; then
			v_CHECK_START="$( date +%s"."%N | head -c -6 )"
			"$v_CURL_BIN" "${a_CURL_ARGS[@]}" >> "$f_STDERR" 2>> "$f_STDERR"
			v_STATUS="$?"
			v_CHECK_END="$( date +%s"."%N | head -c -6 )"
		else
			v_CHECK_START="$( date +%s"."%N | head -c -6 )"
			"$v_WGET_BIN" "${a_WGET_ARGS[@]}" >> "$f_STDERR" 2>> "$f_STDERR"
			v_STATUS="$?"
			v_CHECK_END="$( date +%s"."%N | head -c -6 )"
		fi
		### If the exit status of curl is 28, this means that the page timed out.
		if [[ "$v_STATUS" == 28 && "$v_WGET_BIN" == "false" ]]; then
			echo -e "\n\n\n\nCurl return code: $v_STATUS (This means that the timeout was reached before the full page was returned.)" >> "$d_CHILD"/current_verbose_output.txt
		elif [[ "$v_STATUS" != 0 && "$v_WGET_BIN" == "false" ]]; then
			echo -e "\n\n\n\nCurl return code: $v_STATUS" >> "$d_CHILD"/current_verbose_output.txt
		elif [[ "$v_STATUS" != 0 ]]; then
			echo -e "\n\n\n\nWget return code: $v_STATUS" >> "$d_CHILD"/current_verbose_output.txt
		fi
		local v_HTML_RESPONSE_CODE
		if [[ "$v_CURL_VERBOSE" == true && "$v_LOG_HTTP_CODE" == true ]]; then
		### Capture the html response code, if so directed.
			v_HTML_RESPONSE_CODE="$( cat "$d_CHILD"/current_verbose_output.txt | grep -E -m1 "<" | cut -d " " -f3- | tr -dc '[[:print:]]' )"
			if [[ -z "$v_HTML_RESPONSE_CODE" ]]; then
				v_HTML_RESPONSE_CODE="No Code Reported"
			fi
		fi
		### Check the curl strings
		local i
		local j
		i=0; j=0; while [[ "$i" -lt "${#a_CURL_STRING[@]}" ]]; do
			if [[ -f "$d_CHILD"/site_current.html && $( grep -c -F "${a_CURL_STRING[$i]}" "$d_CHILD"/site_current.html ) -gt 0 ]]; then
				j=$(( j + 1 ))
			fi
			i=$(( i + 1 ))
		done

		v_CHECK_DURATION="$( awk "BEGIN {printf \"%.4f\",( ${v_CHECK_END} - ${v_CHECK_START} ) * 100}" 2> /dev/null || echo "error with awk 1" > /dev/stderr )"
		if [[ "$j" -lt "$i" && "$j" -gt 0 ]]; then
			fn_report_status "partial success" save
		elif [[ $( echo "$v_CHECK_DURATION" | cut -d "." -f1 ) -ge "$v_CHECK_TIME_PARTIAL_SUCCESS" && "$j" -gt 0 ]]; then
			fn_report_status "partial success"
		elif [[ "$i" -eq "$j" ]]; then
			fn_report_status success
		else
			fn_report_status failure save
		fi
		### if we're logging http response codes, and the response code has changed...
		if [[ "$v_CURL_VERBOSE" == true && "$v_LOG_HTTP_CODE" == true && "$v_HTML_RESPONSE_CODE" != "$v_LAST_HTML_RESPONSE_CODE" ]]; then
			echo "$v_DATE2 - [$v_CHILD_PID] - The HTML response code has changed to \"$v_HTML_RESPONSE_CODE\"." >> "$d_CHILD"/log
			v_LAST_HTML_RESPONSE_CODE="$v_HTML_RESPONSE_CODE"
		fi
		fn_child_checks
	done
}

function fn_load_child {
	fn_debug "fn_load_child"
	v_URL_OR_PING="Load on"
	unset -f fn_url_child fn_url_save_html fn_remove_old_html
	unset -f fn_ping_child
	unset -f fn_dns_child
	while [[ 1 == 1 ]]; do
		fn_child_start_loop
		if [[ "$v_DOMAIN" == "127.0.0.1" || "$v_DOMAIN" == "::1" ]]; then
		### If we're checking localhost, there's no need to use ssh
			v_CHECK_START="$( date +%s"."%N | head -c -6 )"
			v_LOAD_AVG="$( cat /proc/loadavg | cut -d " " -f1 )"
			v_CHECK_END="$( date +%s"."%N | head -c -6 )"
		else
			v_CHECK_START="$( date +%s"."%N | head -c -6 )"
			### Check to make sure that the control file is in place. If it's not, don't even try to connect.
			if [[ -e "$( echo "$v_SSH_CONTROL_PATH" | sed "s/%h/$v_DOMAIN/;s/%p/$v_SERVER_PORT/;s/%r/$v_SSH_USER/" )" ]]; then
				v_LOAD_AVG="$( ssh -t -q -o ConnectTimeout=$v_CHECK_TIMEOUT -o ConnectionAttempts=1 -o ControlPath="$v_SSH_CONTROL_PATH" $v_SSH_USER@$v_DOMAIN -p $v_SERVER_PORT "cat /proc/loadavg | cut -d \" \" -f1" 2> /dev/null )"
			else
				v_LOAD_AVG=""
			fi
			v_CHECK_END="$( date +%s"."%N | head -c -6 )"
		fi
		local v_MODIFIED_LOAD_AVERAGE
		if [[ -n "$v_LOAD_AVG" ]]; then
			v_MODIFIED_LOAD_AVERAGE="$( awk "BEGIN {printf \"%.0f\",${v_LOAD_AVG} * 100}" 2> /dev/null || echo "error with awk 2" > /dev/stderr )"
		fi
		v_CHECK_DURATION="$( awk "BEGIN {printf \"%.4f\",(${v_CHECK_END} - ${v_CHECK_START} ) * 100}" 2> /dev/null || echo "error with awk 3" > /dev/stderr )"
		if [[ -n "$v_LOAD_AVG" && "$v_MODIFIED_LOAD_AVERAGE" -lt "$v_MIN_LOAD_PARTIAL_SUCCESS" && "$v_MODIFIED_LOAD_AVERAGE" -lt "$v_MIN_LOAD_FAILURE" && $( echo "$v_CHECK_DURATION" | cut -d "." -f1 ) -ge "$v_CHECK_TIME_PARTIAL_SUCCESS" ]]; then
			fn_report_status "partial success"
		elif [[ -n "$v_LOAD_AVG" && "$v_MODIFIED_LOAD_AVERAGE" -lt "$v_MIN_LOAD_PARTIAL_SUCCESS" && "$v_MODIFIED_LOAD_AVERAGE" -lt "$v_MIN_LOAD_FAILURE" ]]; then
			fn_report_status success
		elif [[ -z "$v_LOAD_AVG" || "$v_MODIFIED_LOAD_AVERAGE" -ge "$v_MIN_LOAD_FAILURE" ]]; then
			fn_report_status failure
		else
			fn_report_status "partial success"
		fi
		fn_child_checks
	done
}

function fn_ping_child {
### The basic loop for a ping monitoring process
	fn_debug "fn_ping_child"
	v_URL_OR_PING="Ping of"
	unset -f fn_url_child fn_url_save_html fn_remove_old_html
	unset -f fn_load_child
	unset -f fn_dns_child
	while [[ 1 == 1 ]]; do
		fn_child_start_loop
		v_CHECK_START="$( date +%s"."%N | head -c -6 )"
		v_PING_RESULT="$( ping -W2 -c1 "$v_DOMAIN" 2> /dev/null | grep -E "icmp_[rs]eq" )"
		v_CHECK_END="$( date +%s"."%N | head -c -6 )"
		local v_WATCH="$( echo "$v_PING_RESULT" | grep -E -c "icmp_[rs]eq" )"
		if [[ "$v_WATCH" -ne 0 ]]; then
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
	fn_debug "fn_dns_child"
	v_URL_OR_PING="DNS for"
	unset -f fn_url_child fn_url_save_html fn_remove_old_html
	unset -f fn_load_child
	unset -f fn_ping_child
	while [[ 1 == 1 ]]; do
		fn_child_start_loop
		if [[ -n "$v_DNS_RECORD_TYPE" && -n "$v_DNS_CHECK_RESULT" ]]; then
			v_CHECK_START="$( date +%s"."%N | head -c -6 )"
			v_QUERY_RESULT="$( dig +tries=1 +short "$v_DNS_RECORD_TYPE" "$v_DNS_CHECK_DOMAIN" @"$v_DOMAIN" 2> /dev/null | grep -F -c "$v_DNS_CHECK_RESULT" )"
			v_CHECK_END="$( date +%s"."%N | head -c -6 )"
		elif [[ -n "$v_DNS_RECORD_TYPE" ]]; then
			v_CHECK_START="$( date +%s"."%N | head -c -6 )"
			v_QUERY_RESULT="$( dig +tries=1 +short "$v_DNS_RECORD_TYPE" "$v_DNS_CHECK_DOMAIN" @"$v_DOMAIN" 2> /dev/null | wc -l )"
			v_CHECK_END="$( date +%s"."%N | head -c -6 )"
		elif [[ -n "$v_DNS_CHECK_RESULT" ]]; then
			v_CHECK_START="$( date +%s"."%N | head -c -6 )"
			v_QUERY_RESULT="$( dig +tries=1 +short "$v_DNS_CHECK_DOMAIN" @"$v_DOMAIN" 2> /dev/null | grep -F -c "$v_DNS_CHECK_RESULT" )"
			v_CHECK_END="$( date +%s"."%N | head -c -6 )"
		else
			v_CHECK_START="$( date +%s"."%N | head -c -6 )"
			v_QUERY_RESULT="$( dig +tries=1 "$v_DNS_CHECK_DOMAIN" @"$v_DOMAIN" 2> /dev/null | grep -F -c "ANSWER SECTION" )"
			v_CHECK_END="$( date +%s"."%N | head -c -6 )"
		fi
		if [[ "$v_QUERY_RESULT" -ne 0 ]]; then
			fn_report_status success
		else
			fn_report_status failure
		fi
		fn_child_checks
	done
}

#============================================#
#== Additional Functions run while Looping ==#
#============================================#

function fn_child_start_loop {
### Check if the conf or params file have been updated, then get all of the necessary timestamps
	fn_debug "fn_child_start_loop"
	local v_PARAMS_CUR="$( stat --format=%Y "$d_CHILD"/params )"
	local v_MASTER_CUR="$( stat --format=%Y "$f_CONF" )"
	if [[ "$v_MASTER_CUR" -gt "$v_MASTER_RELOAD" ]]; then
		fn_read_master_conf
		v_MASTER_RELOAD="$v_MASTER_CUR"
		fn_read_child_params "$d_CHILD"/params
		v_PARAMS_CUR="$( stat --format=%Y "$d_CHILD"/params )"
	elif [[ "$v_PARAMS_CUR" -gt "$v_PARAMS_RELOAD" ]]; then
		fn_read_child_params "$d_CHILD"/params
		v_PARAMS_CUR="$( stat --format=%Y "$d_CHILD"/params )"
	fi
	if [[ "$v_PARAMS_CUR" -gt "$v_PARAMS_RELOAD" ]]; then
		v_PARAMS_RELOAD="$v_PARAMS_CUR"
		echo "$v_DATE2 - [$v_CHILD_PID] - Reloaded parameters for $v_URL_OR_PING $v_ORIG_JOB_NAME." >> "$v_LOG"
		echo "$v_DATE2 - [$v_CHILD_PID] - Reloaded parameters for $v_URL_OR_PING $v_ORIG_JOB_NAME." >> "$d_CHILD"/log
		if [[ ! -f "$d_WORKING"/no_output ]]; then
			echo "***Reloaded parameters for $v_URL_OR_PING $v_JOB_NAME.***"
		fi
	fi

	### Get the three varieties of timestamps we'll need
	v_DATE3_LAST="$v_DATE3"
	v_DATE="$( date +%m"/"%d" "%H":"%M":"%S )"
	v_DATE2="$( date +%F" "%T" "%Z )"
	v_DATE3="$( date +%s )"
}

function fn_child_checks {
	fn_debug "fn_child_checks"
	### Wait until the next loop to die so that the full status will be recorded
	### Generally all of the STUFF between the actual check and running sleep lasts 0.1 seconds-ish. No harm in calculating exactly how long it took and then subtracting that from the wait seconds.
	v_CHECK_END2="$( date +%s"."%N | head -c -6 )"
	v_SLEEP_SECONDS="$( awk "BEGIN {printf \"%.2f\",${v_WAIT_SECONDS} - ( ${v_CHECK_END2} - ${v_CHECK_END} )}" 2> /dev/null || echo "error with awk 4" > /dev/stderr )"
	if [[ "${v_SLEEP_SECONDS:0:1}" != "-" ]]; then
		sleep $v_SLEEP_SECONDS
	fi
}

function fn_convert_seconds {
### I really haven't wrapped my head around how this function I stole works, but it converts a number of seconds to hours, minutes, and seconds.
	fn_debug "fn_convert_seconds"
	((h=${1}/3600))
	### This is the part where it does some stuff.
	((m=(${1}%3600)/60))
	((s=${1}%60))
	### I'm really excited about this part here that does the thing.
	printf "%02d:%02d:%02d\n" "$h" "$m" "$s"
}

function fn_remove_old_html {
### Check if there are too many html files. If there are get rid of one or two
	local v_HTML="$( ls -1 "$d_CHILD"/ | grep -E "^site_" | grep -E -cv "current|previous" )"
	if [[ "$v_HTML" -gt "$v_HTML_FILES_KEPT" ]]; then
		### Remove the oldest
		rm -f "$d_CHILD"/site_"$( ls -1t "$d_CHILD"/ | grep -E "^site_" | grep -E -v "current|previous" | tail -n1 | sed "s/site_//" )"
		rm -f "$d_CHILD"/curl_verbose_"$( ls -1t "$d_CHILD"/ | grep -E "^curl_verbose_" | grep -E -v "current|previous" | tail -n1 | sed "s/curl_verbose_//" )"
		if [[ $(( v_HTML - 1 )) -gt "$v_HTML_FILES_KEPT" ]]; then
		### If there were two greater than the number we should keep (likely) remove the second oldest as well
			rm -f "$d_CHILD"/site_"$( ls -1t "$d_CHILD"/ | grep -E "^site_" | grep -E -v "current|previous" | tail -n1 | sed "s/site_//" )"
			rm -f "$d_CHILD"/curl_verbose_"$( ls -1t "$d_CHILD"/ | grep -E "^curl_verbose_" | grep -E -v "current|previous" | tail -n1 | sed "s/curl_verbose_//" )"
		fi
	fi
}

function fn_url_save_html {
### If we've changed statuses, backup the html output and the curl verbose output
	local v_LAST_STATUS="$1"
	local v_THIS_STATUS="$2"
	local v_SAVE="$3"

	### Rename the files as needed
	if [[ "$v_LAST_STATUS" == "success" || ( "$v_LAST_STATUS" == "partial success" && "$v_THIS_STATUS" == "failure" && "$v_SAVE" == "save" ) ]]; then
		local v_DESCRIP1="fail"
		local v_DESCRIP2="psuccess"
		if [[ "$v_THIS_STATUS" == "partial success" ]]; then
			v_DESCRIP1="psuccess"
		fi
		if [[ "$v_LAST_STATUS" == "success" ]]; then
			v_DESCRIP2="success"
		fi
		cp -a "$d_CHILD"/site_current.html "$d_CHILD"/site_"$v_DATE3"_"$v_DESCRIP1".html
		if [[ -f "$d_CHILD"/current_verbose_output.txt ]]; then
			cp -a "$d_CHILD"/current_verbose_output.txt "$d_CHILD"/curl_verbose_"$v_DATE3"_"$v_DESCRIP1".txt
		fi
		cp -a "$d_CHILD"/site_previous.html "$d_CHILD"/site_"$v_DATE3_LAST"_"$v_DESCRIP2".html
		if [[ -f "$d_CHILD"/previous_verbose_output.txt ]]; then
			cp -a "$d_CHILD"/previous_verbose_output.txt "$d_CHILD"/curl_verbose_"$v_DATE3_LAST"_"$v_DESCRIP2".txt
		fi
		fn_remove_old_html
	fi
}

#======================================#
#== Functions for Mathing Things Out ==#
#======================================#

function fn_more_verbose {
### Create the more verbose status if we need it
### This function is designed to be run in a subshell so that its output can be captured in a variable
### $1 is Whether or not we're writing to the status file
### $2 is the current status
	local v_DUMP_STATUS="$1"
	local v_THIS_STATUS="$2"

	local v_PERCENT_PARTIAL_SUCCESSES="$( awk "BEGIN {printf \"%.2f\",( ${v_TOTAL_PARTIAL_SUCCESSES} * 100 ) / ${v_TOTAL_CHECKS}}" 2> /dev/null || echo "error with awk 5" > /dev/stderr )"
	local v_PERCENT_FAILURES="$( awk "BEGIN {printf \"%.2f\",( ${v_TOTAL_FAILURES} * 100 ) / ${v_TOTAL_CHECKS}}" 2> /dev/null || echo "error with awk 6" > /dev/stderr )"

	local v_AVERAGE_SUCCESS_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_TOTAL_SUCCESS_DURATIONS} / ${v_TOTAL_SUCCESSES}}" 2> /dev/null || echo "error with awk 7" > /dev/stderr )"

	### Do the math for long hours
	local v_LONG_PERCENT_SUCCESS="$( awk "BEGIN {printf \"%.2f\",( ${v_LONG_SUCCESS} * 100 ) / ${v_LONG_COUNT}}" 2> /dev/null || echo "error with awk 8" > /dev/stderr )"
	local v_LONG_PERCENT_PARTIAL="$( awk "BEGIN {printf \"%.2f\",( ${v_LONG_PARTIAL} * 100 ) / ${v_LONG_COUNT}}" 2> /dev/null || echo "error with awk 9" > /dev/stderr )"
	local v_LONG_PERCENT_FAIL="$( awk "BEGIN {printf \"%.2f\",( ${v_LONG_FAIL} * 100 ) / ${v_LONG_COUNT}}" 2> /dev/null || echo "error with awk 10" > /dev/stderr )"	
	local v_LONG_AVERAGE_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_LONG_TOTAL_DURATION} / ${v_LONG_COUNT}}" 2> /dev/null || echo "error with awk 17" > /dev/stderr )"

	### Do the math for short hours
	local v_SHORT_PERCENT_SUCCESS="$( awk "BEGIN {printf \"%.2f\",( ${v_SHORT_SUCCESS} * 100 ) / ${v_SHORT_COUNT}}" 2> /dev/null || echo "error with awk 11" > /dev/stderr )"
	local v_SHORT_PERCENT_PARTIAL="$( awk "BEGIN {printf \"%.2f\",( ${v_SHORT_PARTIAL} * 100 ) / ${v_SHORT_COUNT}}" 2> /dev/null || echo "error with awk 12" > /dev/stderr )"
	local v_SHORT_PERCENT_FAIL="$( awk "BEGIN {printf \"%.2f\",( ${v_SHORT_FAIL} * 100 ) / ${v_SHORT_COUNT}}" 2> /dev/null || echo "error with awk 13" > /dev/stderr )"
	local v_SHORT_AVERAGE_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_SHORT_TOTAL_DURATION} / ${v_SHORT_COUNT}}" 2> /dev/null || echo "error with awk 19" > /dev/stderr )"

	local v_REPORT2="$v_DATE2 - [$v_CHILD_PID] - $v_URL_OR_PING $v_JOB_NAME\n  Check Status:                 $v_DESCRIPTOR1\n  Checking for:                 $v_RUN_TIME\n  "
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

	### Output to the status file
	if [[ -f "$d_CHILD"/status || "$v_DUMP_STATUS" == true ]]; then
		echo -e "$v_REPORT2""\n  Total duration:               $v_TOTAL_DURATIONS seconds\n  Total recent duration:        $v_TOTAL_RECENT_DURATION seconds\n  Total successful duration:    $v_TOTAL_SUCCESS_DURATIONS seconds\n  Last $v_LONG_HOURS hours:\n    Number of checks completed: $v_LONG_COUNT\n    #Success/#Partial/#Failure: $v_LONG_SUCCESS / $v_LONG_PARTIAL / $v_LONG_FAIL\n    %Success/%Partial/%Failure: $v_LONG_PERCENT_SUCCESS% / $v_LONG_PERCENT_PARTIAL% / $v_LONG_PERCENT_FAIL%\n    Average check:              $v_LONG_AVERAGE_DURATION seconds\n    Total duration:             $v_LONG_TOTAL_DURATION seconds\n  Last $v_SHORT_HOURS hours:\n    Number of checks completed: $v_SHORT_COUNT\n    #Success/#Partial/#Failure: $v_SHORT_SUCCESS / $v_SHORT_PARTIAL / $v_SHORT_FAIL\n    %Success/%Partial/%Failure: $v_SHORT_PERCENT_SUCCESS% / $v_SHORT_PERCENT_PARTIAL% / $v_SHORT_PERCENT_FAIL%\n    Average check:              $v_SHORT_AVERAGE_DURATION seconds\n    Total duration:             $v_SHORT_TOTAL_DURATION seconds" > "$d_CHILD"/status
		mv -f "$d_CHILD"/status "$d_CHILD/#status"
	fi

	### Output so it can be captured as a variable
	echo "$v_REPORT2"
}

function fn_long_short_dur {
### Do the math for long and short durations
	local v_THIS_STATUS="$1"

	### add the current values to the long array
	v_LONG_COUNT=$(( v_LONG_COUNT + 1 ))
	v_SHORT_COUNT=$(( v_SHORT_COUNT + 1 ))
	a_LONG_STAMPS[${#a_LONG_STAMPS[@]}]="$v_DATE3"
	if [[ "$v_THIS_STATUS" == "success" ]]; then
		a_LONG_STATUSES[${#a_LONG_STATUSES[@]}]="s"
		v_LONG_SUCCESS=$(( v_LONG_SUCCESS + 1 ))
		v_SHORT_SUCCESS=$(( v_SHORT_SUCCESS + 1 ))
	elif [[ "$v_THIS_STATUS" == "partial success" ]]; then
		a_LONG_STATUSES[${#a_LONG_STATUSES[@]}]="p"
		v_LONG_PARTIAL=$(( v_LONG_PARTIAL + 1 ))
		v_SHORT_PARTIAL=$(( v_SHORT_PARTIAL + 1 ))
	elif [[ "$v_THIS_STATUS" == "failure" ]]; then
		a_LONG_STATUSES[${#a_LONG_STATUSES[@]}]="f"
		v_LONG_FAIL=$(( v_LONG_FAIL + 1 ))
		v_SHORT_FAIL=$(( v_SHORT_FAIL + 1 ))
	fi
	a_LONG_DURATIONS[${#a_LONG_DURATIONS[@]}]="$v_CHECK_DURATION"

	### Get rid of entries from the long array, adjust the placement of the for the short hours
	if [[ -n "${a_LONG_STAMPS[0]}" ]]; then
		while [[ "${a_LONG_STAMPS[0]}" -le $(( v_DATE3 - $(( 3600 * v_LONG_HOURS )) )) ]]; do
			if [[ "${a_LONG_STAMPS[0]}" == "s" ]]; then
				v_LONG_SUCCESS=$(( v_LONG_SUCCESS - 1 ))
			elif [[ "${a_LONG_STAMPS[0]}" == "p" ]]; then
				v_LONG_PARTIAL=$(( v_LONG_PARTIAL - 1 ))
			elif [[ "${a_LONG_STAMPS[0]}" == "f" ]]; then
				v_LONG_FAIL=$(( v_LONG_FAIL - 1 ))
			fi
			v_LONG_TOTAL_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_LONG_TOTAL_DURATION} - ${a_LONG_DURATIONS[0]}}" 2> /dev/null || echo "error with awk 14" > /dev/stderr )"
			v_LONG_COUNT=$(( v_LONG_COUNT - 1 ))
			a_LONG_STAMPS=("${a_LONG_STAMPS[@]:1}")
			a_LONG_STATUSES=("${a_LONG_STATUSES[@]:1}")
			a_LONG_DURATIONS=("${a_LONG_DURATIONS[@]:1}")
			v_SHORT_PLACE=$(( v_SHORT_PLACE - 1 ))
		done
	fi

	### adjust placement for the short array
	if [[ -n "${a_LONG_STAMPS[0]}" ]]; then
		while [[ "${a_LONG_STAMPS[$v_SHORT_PLACE]}" -le $(( v_DATE3 - $(( 3600 * v_SHORT_HOURS )) )) ]]; do
			if [[ "${a_LONG_STAMPS[$v_SHORT_PLACE]}" == "s" ]]; then
				v_SHORT_SUCCESS=$(( v_SHORT_SUCCESS - 1 ))
			elif [[ "${a_LONG_STAMPS[$v_SHORT_PLACE]}" == "p" ]]; then
				v_SHORT_PARTIAL=$(( v_SHORT_PARTIAL - 1 ))
			elif [[ "${a_LONG_STAMPS[$v_SHORT_PLACE]}" == "f" ]]; then
				v_SHORT_FAIL=$(( v_SHORT_FAIL - 1 ))
			fi
			v_SHORT_TOTAL_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_SHORT_TOTAL_DURATION} - ${a_LONG_DURATIONS[$v_SHORT_PLACE]}}" 2> /dev/null || echo "error with awk 15" > /dev/stderr )"
			v_SHORT_COUNT=$(( v_SHORT_COUNT - 1 ))
			v_SHORT_PLACE=$(( v_SHORT_PLACE + 1 ))
		done
	fi

	v_LONG_TOTAL_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_LONG_TOTAL_DURATION} + ${v_CHECK_DURATION}}" 2> /dev/null || echo "error with awk 16" > /dev/stderr )"
	v_SHORT_TOTAL_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_SHORT_TOTAL_DURATION} + ${v_CHECK_DURATION}}" 2> /dev/null || echo "error with awk 18" > /dev/stderr )"
}

function fn_output {
### Output the status to the correct place
	local v_MESSAGE="$1"
	if [[ "$v_OUTPUT_FILE" == "/dev/stdout" ]]; then
		echo -e "$v_MESSAGE"
	elif [[ "$v_OUTPUT_FILE" == "/dev/stderr" ]]; then
		( >&2 echo -e "$v_MESSAGE" )
	else
		echo -e "$v_MESSAGE" >> "$v_OUTPUT_FILE"
	fi
}

#==================================================#
#== That one Big Function for Outputting Results ==#
#==================================================#

function fn_report_status {
### $1 is the status. $2 is whether or not to try to save the file
	fn_debug "fn_report_status"
	v_THIS_STATUS="$1"
	local v_SAVE="$2"

	#=========================#
	#== Check Test Statuses ==#
	#=========================#

	### This is present if, for testing purposes, we need to override the result of a check
	if [[ -f "$d_CHILD"/force_success ]]; then
		v_THIS_STATUS="success"
		rm -f "$d_CHILD"/force_success
	elif [[ -f "$d_CHILD"/force_failure ]]; then
		v_THIS_STATUS="failure"
		rm -f "$d_CHILD"/force_failure
	elif [[ -f "$d_CHILD"/force_partial ]]; then
		v_THIS_STATUS="partial success"
		rm -f "$d_CHILD"/force_partial
	fi

	#===================================#
	#== Set Specifics for Each Status ==#
	#===================================#

	local v_COLOR_START
	local v_COLOR_END
	if [[ "$v_THIS_STATUS" == "success" ]]; then
		v_TOTAL_SUCCESSES=$(( v_TOTAL_SUCCESSES + 1 ))
		v_LAST_SUCCESS="$v_DATE3"
		v_NUM_SUCCESSES_EMAIL=$(( v_NUM_SUCCESSES_EMAIL + 1 ))
		v_DESCRIPTOR1="Success"
		v_DESCRIPTOR2="Check succeeded"
		v_SUCCESS_CHECKS=$(( v_SUCCESS_CHECKS + 1 ))
		if [[ "$v_LAST_STATUS" == "success" ]]; then
			v_COLOR_START="$v_COLOR_SUCCESS"
			v_COLOR_END="$v_RETURN_SUCCESS"
		else
			v_COLOR_START="$v_COLOR_FIRST_SUCCESS"
			v_COLOR_END="$v_RETURN_FIRST_SUCCESS"
		fi
	elif [[ "$v_THIS_STATUS" == "partial success" ]]; then
		v_TOTAL_PARTIAL_SUCCESSES=$(( v_TOTAL_PARTIAL_SUCCESSES + 1 ))
		v_LAST_PARTIAL_SUCCESS="$v_DATE3"
		v_NUM_PARTIAL_SUCCESSES_EMAIL=$(( v_NUM_PARTIAL_SUCCESSES_EMAIL + 1 ))
		v_DESCRIPTOR1="Partial Success"
		v_DESCRIPTOR2="Partial success"
		v_PARTIAL_SUCCESS_CHECKS=$(( v_PARTIAL_SUCCESS_CHECKS + 1 ))
		if [[ "$v_LAST_STATUS" == "partial success" ]]; then
			v_COLOR_START="$v_COLOR_PARTIAL_SUCCESS"
			v_COLOR_END="$v_RETURN_PARTIAL_SUCCESS"
		else
			v_COLOR_START="$v_COLOR_FIRST_PARTIAL_SUCCESS"
			v_COLOR_END="$v_RETURN_FIRST_PARTIAL_SUCCESS"
		fi
	elif [[ "$v_THIS_STATUS" == "failure" ]]; then
		v_TOTAL_FAILURES=$(( v_TOTAL_FAILURES + 1 ))
		v_LAST_FAILURE="$v_DATE3"
		v_NUM_FAILURES_EMAIL=$(( v_NUM_FAILURES_EMAIL + 1 ))
		v_DESCRIPTOR1="Failure"
		v_DESCRIPTOR2="Check failed"
		v_FAILURE_CHECKS=$(( v_FAILURE_CHECKS + 1 ))
		if [[ "$v_LAST_STATUS" == "failure" ]]; then
			v_COLOR_START="$v_COLOR_FAILURE"
			v_COLOR_END="$v_RETURN_FAILURE"
		else
			v_COLOR_START="$v_COLOR_FIRST_FAILURE"
			v_COLOR_END="$v_RETURN_FIRST_FAILURE"
		fi
	fi
	if [[ "$v_JOB_TYPE" == "ssh-load" ]]; then
		v_DESCRIPTOR1="$v_LOAD_AVG"
	fi

	#=========================================#
	#== Statistics and Duration Information ==#
	#=========================================#

	### Figure out how long the script has run and what percent are successes, etc.
	local v_RUN_SECONDS="$(( v_DATE3 - v_START_TIME ))"
	v_RUN_TIME="$( fn_convert_seconds "$v_RUN_SECONDS" )"
	v_TOTAL_CHECKS=$(( v_TOTAL_CHECKS + 1 ))
	v_PERCENT_SUCCESSES="$( awk "BEGIN {printf \"%.2f\",( ${v_TOTAL_SUCCESSES} * 100 ) / ${v_TOTAL_CHECKS}}" 2> /dev/null || echo "error with awk 20" > /dev/stderr )"
	### How long did the check itself take?
	v_CHECK_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_CHECK_END} - ${v_CHECK_START}}" 2> /dev/null || echo "error with awk 21" > /dev/stderr )"
	v_TOTAL_DURATIONS="$( awk "BEGIN {printf \"%.4f\",${v_CHECK_DURATION} + ${v_TOTAL_DURATIONS}}" 2> /dev/null || echo "error with awk 22" > /dev/stderr )"
	v_AVERAGE_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_TOTAL_DURATIONS} / ${v_TOTAL_CHECKS}}" 2> /dev/null || echo "error with awk 23" > /dev/stderr )"

	### Subtract old values from the the total recent duration and add the new value
	if [[ -z "$v_TOTAL_RECENT_DURATION" ]]; then
		v_TOTAL_RECENT_DURATION=0
	fi
	while [[ "${#a_RECENT_DURATIONS[@]}" -ge "$v_NUM_DURATIONS_RECENT" && "${#a_RECENT_DURATIONS[@]}" -gt 0 ]]; do
		v_TOTAL_RECENT_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_TOTAL_RECENT_DURATION} - ${a_RECENT_DURATIONS[0]}}" 2> /dev/null || echo "error with awk 24" > /dev/stderr )"
		a_RECENT_DURATIONS=("${a_RECENT_DURATIONS[@]:1}")
	done
	a_RECENT_DURATIONS[${#a_RECENT_DURATIONS[@]}]="$v_CHECK_DURATION"
	v_TOTAL_RECENT_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_TOTAL_RECENT_DURATION} + ${v_CHECK_DURATION}}" 2> /dev/null || echo "error with awk 25" > /dev/stderr )"

	### Calculate the average recent duration
	v_AVERAGE_RECENT_DURATION="$( awk "BEGIN {printf \"%.4f\",${v_TOTAL_RECENT_DURATION} / ${#a_RECENT_DURATIONS[@]}}" 2> /dev/null || echo "error with awk 26" > /dev/stderr )"
	if [[ "$v_THIS_STATUS" == "success" ]]; then
		v_TOTAL_SUCCESS_DURATIONS="$( awk "BEGIN {printf \"%.4f\",${v_CHECK_DURATION} + ${v_TOTAL_SUCCESS_DURATIONS}}" 2> /dev/null || echo "error with awk 27" > /dev/stderr )"
	fi

	### Do all of the math necessary for long and short duration tracking
	fn_long_short_dur "$v_THIS_STATUS"

	#============================#
	#== Set the Status Strings ==#
	#============================#

	local v_LAST_LAST_STATUS
	if [[ "$v_LAST_STATUS" != "$v_THIS_STATUS" ]]; then
		v_LAST_LAST_STATUS="$v_LAST_STATUS"
	fi
	### Figure out when the last partial success and last failure were.
	local v_LAST_SUCCESS_STRING
	if [[ "$v_THIS_STATUS" != "success" ]]; then
		if [[ "$v_LAST_SUCCESS" == "never" || -z "$v_LAST_SUCCESS" ]]; then
			v_LAST_SUCCESS_STRING="never"
		else
			v_LAST_SUCCESS_STRING="$( fn_convert_seconds $(( v_DATE3 - v_LAST_SUCCESS )) ) ago"
		fi
	fi
	local v_LAST_PARTIAL_SUCCESS_STRING
	if [[ "$v_THIS_STATUS" != "partial success" ]]; then
		if [[ "$v_LAST_PARTIAL_SUCCESS" == "never" || -z $v_LAST_PARTIAL_SUCCESS ]]; then
			v_LAST_PARTIAL_SUCCESS_STRING="never"
		else
			v_LAST_PARTIAL_SUCCESS_STRING="$( fn_convert_seconds $(( v_DATE3 - v_LAST_PARTIAL_SUCCESS )) ) ago"
		fi
	fi
	local v_LAST_FAILURE_STRING
	if [[ "$v_THIS_STATUS" != "failure" ]]; then
		if [[ "$v_LAST_FAILURE" == "never" || -z "$v_LAST_FAILURE" ]]; then
			v_LAST_FAILURE_STRING="never"
		else
			v_LAST_FAILURE_STRING="$( fn_convert_seconds $(( v_DATE3 - v_LAST_FAILURE )) ) ago"
		fi
	fi

	#====================================================#
	#== Do we need to Dump the Status or Kill the Job? ==#
	#====================================================#

	local v_DUMP_STATUS=false
	if [[ "$v_RUN_SECONDS" -gt "$v_NEXT_STATUS_DUMP" ]]; then
		v_DUMP_STATUS=true
		v_NEXT_STATUS_DUMP="$(( v_NEXT_STATUS_DUMP + v_STATUS_DUMP_INC ))"
	fi

	### Check to see if the parent is still in place, and die if not.
	local v_DIE=false
	if [[ $( cat /proc/$v_MASTER_PID/cmdline 2> /dev/null | tr "\0" " " | grep -E -c "lwmon.sh[[:blank:]]" ) -eq 0 || -f "$d_CHILD"/die ]]; then
		v_DUMP_STATUS=true
		v_DIE=true
	fi

	### More verbose output is necessary if that's the verbosity, OR if it's time to dump the full status
	if [[ "$v_VERBOSITY" == "more verbose" || -f "$d_CHILD"/status || "$v_DUMP_STATUS" == true ]]; then
		local v_REPORT2="$( fn_more_verbose "$v_DUMP_STATUS" "$v_THIS_STATUS" )"
	fi

	### If we need to die, do so before the part where we output the status information
	if [[ "$v_DIE" == true ]]; then
		fn_child_exit 0
	fi

	#=========================#
	#== Finalize the Output ==#
	#=========================#

	### Set $v_REPORT based on where the verbosity is set
	local v_REPORT
	if [[ "$v_VERBOSITY" == "verbose" ]]; then
		### verbose
		v_REPORT="$v_DATE - [$v_CHILD_PID] - $v_URL_OR_PING $v_JOB_NAME: $v_DESCRIPTOR1 - Checking for $v_RUN_TIME."
		if [[ "$v_LAST_LAST_STATUS" == "success" ]]; then
			v_REPORT="$v_REPORT Last success: $v_LAST_SUCCESS_STRING."
		elif [[ "$v_LAST_LAST_STATUS" == "partial success" ]]; then
			v_REPORT="$v_REPORT Last partial success: $v_LAST_PARTIAL_SUCCESS_STRING."
		elif [[ "$v_LAST_LAST_STATUS" == "failure" ]]; then
			v_REPORT="$v_REPORT Last failed check: $v_LAST_FAILURE_STRING."
		fi
		v_REPORT="$v_REPORT $v_TOTAL_CHECKS checks completed. $v_PERCENT_SUCCESSES% success rate."
	elif [[ "$v_VERBOSITY" == "more verbose" || -f "$d_CHILD"/status ]]; then
		### more verbose
		v_REPORT="$v_REPORT2"
	else
		### other
		v_REPORT="$v_DATE - $v_URL_OR_PING $v_JOB_NAME: $v_DESCRIPTOR1"
	fi
	local v_LOG_MESSAGE="$v_DATE2 - [$v_CHILD_PID] - Status changed for $v_URL_OR_PING $v_ORIG_JOB_NAME: $v_DESCRIPTOR2"
	unset v_REPORT2

	#===========================#
	#== Output and Send Email ==#
	#===========================#

	### If the last status was the same as this status
	v_SENT=false
	if [[ "$v_THIS_STATUS" == "$v_LAST_STATUS" ]]; then
		if [[ "$v_VERBOSITY" != "change" && "$v_VERBOSITY" != "none" && ! -f "$d_WORKING"/no_output ]]; then
			fn_output "$v_COLOR_START""$v_REPORT""$v_COLOR_END"
		fi
		fn_start_email
	### If there was no last status
	elif [[ -z "$v_LAST_STATUS" ]]; then
		if [[ "$v_VERBOSITY" != "none" && ! -f "$d_WORKING"/no_output ]]; then
			fn_output "$v_COLOR_START""$v_REPORT""$v_COLOR_END"
		fi
		echo "$v_DATE2 - [$v_CHILD_PID] - Initial status for $v_URL_OR_PING $v_ORIG_JOB_NAME: $v_DESCRIPTOR2" >> "$v_LOG"
		echo "$v_DATE2 - [$v_CHILD_PID] - Initial status for $v_URL_OR_PING $v_ORIG_JOB_NAME: $v_DESCRIPTOR2" >> "$d_CHILD"/log
		### Mark the email type so that a message is not sent erroneously
		v_LAST_EMAIL_SENT="$v_THIS_STATUS"
	### If the last status was also successful
	elif [[ "$v_LAST_STATUS" == "success" ]]; then
		if [[ "$v_VERBOSITY" != "none" && ! -f "$d_WORKING"/no_output ]]; then
			fn_output "$v_COLOR_START""$v_REPORT""$v_COLOR_END"
		fi
		echo "$v_LOG_MESSAGE after $v_SUCCESS_CHECKS successful checks" >> "$v_LOG"
		echo "$v_LOG_MESSAGE after $v_SUCCESS_CHECKS successful checks" >> "$d_CHILD"/log
		v_SUCCESS_CHECKS=0
		if [[ "$v_JOB_TYPE" == "url" && "$v_HTML_FILES_KEPT" -gt 0 ]]; then
			fn_url_save_html "$v_LAST_STATUS" "$v_THIS_STATUS" "$v_SAVE"
		fi
		fn_start_email
	### If the last status was partial success
	elif [[ "$v_LAST_STATUS" == "partial success" ]]; then
		if [[ "$v_VERBOSITY" != "none" && ! -f "$d_WORKING"/no_output ]]; then
			fn_output "$v_COLOR_START""$v_REPORT""$v_COLOR_END"
		fi
		echo "$v_LOG_MESSAGE after $v_PARTIAL_SUCCESS_CHECKS partial successes" >> "$v_LOG"
		echo "$v_LOG_MESSAGE after $v_PARTIAL_SUCCESS_CHECKS partial successes" >> "$d_CHILD"/log
		v_PARTIAL_SUCCESS_CHECKS=0
		if [[ "$v_JOB_TYPE" == "url" && "$v_HTML_FILES_KEPT" -gt 0 ]]; then
			fn_url_save_html "$v_LAST_STATUS" "$v_THIS_STATUS" "$v_SAVE"
		fi
		fn_start_email
	### If the last status was failure
	elif [[ "$v_LAST_STATUS" == "failure" ]]; then
		if [[ "$v_VERBOSITY" != "none" && ! -f "$d_WORKING"/no_output ]]; then
			fn_output "$v_COLOR_START""$v_REPORT""$v_COLOR_END"
		fi
		echo "$v_LOG_MESSAGE after $v_FAILURE_CHECKS failed checks" >> "$v_LOG"
		echo "$v_LOG_MESSAGE after $v_FAILURE_CHECKS failed checks" >> "$d_CHILD"/log
		v_FAILURE_CHECKS=0
		fn_start_email
	fi
	### If we need to log the duration data, do so
	if [[ "$v_LOG_DURATION_DATA" == "true" ]]; then
		echo "$v_DATE2 - [$v_CHILD_PID] - Status: $v_DESCRIPTOR2 - Duration $v_CHECK_DURATION seconds" >> "$d_CHILD"/log
	fi

	#===============================#
	#== Prepare for the Next Loop ==#
	#===============================#

	### set the v_LAST_STATUS variable to what ever the current status is
	unset v_REPORT
	v_LAST_STATUS="$v_THIS_STATUS"
	a_RECENT_STATUSES[${#a_RECENT_STATUSES[@]}]="$v_THIS_STATUS"
	if [[ "${#a_RECENT_STATUSES[@]}" -gt "$v_NUM_STATUSES_RECENT" && "$v_SENT" == false ]]; then
		while [[ "${#a_RECENT_STATUSES[@]}" -gt "$v_NUM_STATUSES_RECENT" ]]; do
			a_RECENT_STATUSES=("${a_RECENT_STATUSES[@]:1}")
		done
		### If there are symptoms of intermittent failures, send an email regarding such.
		if [[ $( echo "${a_RECENT_STATUSES[@]}" | grep -E -o "failure|partial success" | wc -l ) -ge "$v_NUM_STATUSES_NOT_SUCCESS" && "$v_THIS_STATUS" == "success" ]]; then
			v_THIS_STATUS="intermittent failure"
			fn_start_email
		fi
	fi
	unset v_SENT
}

#====================================#
#== Functions for Processing Email ==#
#====================================#

function fn_start_email {
	fn_debug "fn_start_email"
	local v_MUTUAL_EMAIL="thus meeting your threshold for being alerted. Since the previous e-mail was sent (Or if none have been sent, since checks against this server were started) there have been a total of $v_NUM_SUCCESSES_EMAIL successful checks, $v_NUM_PARTIAL_SUCCESSES_EMAIL partially successful checks, and $v_NUM_FAILURES_EMAIL failed checks.\n\nChecks have been running for $v_RUN_TIME. $v_TOTAL_CHECKS checks completed. $v_PERCENT_SUCCESSES% success rate.\n\nThis check took $v_CHECK_DURATION seconds to complete. The last ${#a_RECENT_DURATIONS[@]} checks took an average of $v_AVERAGE_RECENT_DURATION seconds to complete. The average successful check has taken $v_AVERAGE_SUCCESS_DURATION seconds to complete. The average check overall has taken $v_AVERAGE_DURATION seconds to complete.\n\nLogs related to this check:\n\n$( cat "$d_CHILD"/log | grep -E -v "\] - (The HTML response code|Status: (Check (failed|succeeded)|Partial success) - Duration)" )"
	if [[ "$v_THIS_STATUS" == "intermittent failure" ]]; then
		fn_intermittent_failure_email "$v_MUTUAL_EMAIL"
	elif [[ "$v_THIS_STATUS" == "success" ]]; then
		fn_success_email "$v_MUTUAL_EMAIL"
	elif [[ "$v_THIS_STATUS" == "partial success" ]]; then
		fn_partial_success_email "$v_MUTUAL_EMAIL"
	elif [[ "$v_THIS_STATUS" == "failure" ]]; then
		fn_failure_email "$v_MUTUAL_EMAIL"
	fi
	if [[ "$v_SENT" == true ]]; then
	### Note the $v_SENT indicates any instance where an email WOULD HAVE BEEN sent whether or not it was sent
		### set the variables that prepare for the next message to be sent.
		v_NUM_SUCCESSES_EMAIL=0
		v_NUM_PARTIAL_SUCCESSES_EMAIL=0
		v_NUM_FAILURES_EMAIL=0
	fi
}

function fn_success_email {
### Determines if a success e-mail needs to be sent and, if so, sends that e-mail.
### In order for mail to be sent here
	### If the last message was an intermittent fail, we need to have seen exactly $v_NUM_STATUSES_RECENT consecutive successes
	### Otherwise, we only need to have seen exactly $v_MAIL_DELAY consecutive successes
	fn_debug "fn_success_email"
	local v_MUTUAL_EMAIL="$1"
	if [[ "$v_TOTAL_CHECKS" != "$v_MAIL_DELAY" && "$v_LAST_EMAIL_SENT" != "success" ]]; then
		local v_GO=false
		if [[ "$v_SUCCESS_CHECKS" -eq "$v_MAIL_DELAY" && "$v_LAST_EMAIL_SENT" != "intermittent" ]]; then
			v_GO=true
		elif [[ "$v_SUCCESS_CHECKS" -eq "$v_NUM_STATUSES_RECENT" && "$v_LAST_EMAIL_SENT" == "intermittent" ]]; then
			v_GO=true
		fi
		if [[ "$v_GO" == true ]]; then
			if [[ -n "$v_MAIL_COMMAND" && -n "$v_EMAIL_ADDRESS" ]]; then
				local v_MESSAGE="$( if [[ -n "$v_CUSTOM_MESSAGE" ]]; then echo "$v_CUSTOM_MESSAGE\n\n"; fi )$v_DATE2 - LWmon - $v_URL_OR_PING $v_JOB_NAME - Status changed: Appears to be succeeding.\n\nYou're recieving this message to inform you that $v_SUCCESS_CHECKS consecutive check(s) against $v_URL_OR_PING $( if [[ "$v_JOB_NAME" == "$v_ORIG_JOB_NAME" ]]; then echo "$v_JOB_NAME"; else echo "$v_JOB_NAME ($v_ORIG_JOB_NAME)"; fi ) have succeeded, $v_MUTUAL_EMAIL"
				local v_SUBJECT="LWmon - $v_URL_OR_PING $v_JOB_NAME - Check PASSED!"
				fn_send_email "$v_MESSAGE" "$v_SUBJECT" "success" &
			fi
			fn_run_script "success" &
			v_LAST_EMAIL_SENT="success"
			v_SENT=true
			a_RECENT_STATUSES=()
		fi
	fi
}

function fn_partial_success_email {
### Determines if a failure e-mail needs to be sent and, if so, sends that e-mail.
	fn_debug "fn_partial_success_email"
	local v_MUTUAL_EMAIL="$1"
	if [[ "$v_PARTIAL_SUCCESS_CHECKS" -eq "$v_MAIL_DELAY" && "$v_TOTAL_CHECKS" != "$v_MAIL_DELAY" && "$v_LAST_EMAIL_SENT" != "partial success" ]]; then
		if [[ -n "$v_MAIL_COMMAND" && -n "$v_EMAIL_ADDRESS" ]]; then
			local v_MESSAGE="$( if [[ -n "$v_CUSTOM_MESSAGE" ]]; then echo "$v_CUSTOM_MESSAGE\n\n"; fi )$v_DATE2 - LWmon - $v_URL_OR_PING $v_JOB_NAME - Status changed: Appears to be succeeding in some regards but failing in others.\n\nYou're recieving this message to inform you that $v_MAIL_DELAY consecutive check(s) against $v_URL_OR_PING $( if [[ "$v_JOB_NAME" == "$v_ORIG_JOB_NAME" ]]; then echo "$v_JOB_NAME"; else echo "$v_JOB_NAME ($v_ORIG_JOB_NAME)"; fi ) have only been partially successful, $v_MUTUAL_EMAIL"
			local v_SUBJECT="LWmon - $v_URL_OR_PING $v_JOB_NAME - Partial success"
			fn_send_email "$v_MESSAGE" "$v_SUBJECT" "partial success" &
		fi
		fn_run_script "psuccess" &
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
	fn_debug "fn_intermittent_failure_email"
	local v_MUTUAL_EMAIL="$1"
	if [[ "$v_LAST_EMAIL_SENT" == "success" && "$v_NUM_STATUSES_NOT_SUCCESS" -gt 0 ]]; then
		if [[ -n "$v_MAIL_COMMAND" && -n "$v_EMAIL_ADDRESS" ]]; then
			local v_MESSAGE="$( if [[ -n "$v_CUSTOM_MESSAGE" ]]; then echo "$v_CUSTOM_MESSAGE\n\n"; fi )$v_DATE2 - LWmon - $v_URL_OR_PING $v_JOB_NAME - Status changed: Appears to be failing intermittently.\n\nYou're recieving this message to inform you that $v_NUM_STATUSES_NOT_SUCCESS out of the last $v_NUM_STATUSES_RECENT checks against $v_URL_OR_PING $( if [[ "$v_JOB_NAME" == "$v_ORIG_JOB_NAME" ]]; then echo "$v_JOB_NAME"; else echo "$v_JOB_NAME ($v_ORIG_JOB_NAME)"; fi ) have not been fully successful, $v_MUTUAL_EMAIL\n\n"
			local v_SUBJECT="LWmon - $v_URL_OR_PING $v_JOB_NAME - Check failing intermittently!"
			fn_send_email "$v_MESSAGE" "$v_SUBJECT" "intermittent failure" &
		fi
		fn_run_script "intermittent" &
		v_LAST_EMAIL_SENT="intermittent"
		v_SENT=true
	fi
}

function fn_failure_email {
### Determines if a failure e-mail needs to be sent and, if so, sends that e-mail.
	fn_debug "fn_failure_email"
	local v_MUTUAL_EMAIL="$1"
	if [[ "$v_FAILURE_CHECKS" -eq "$v_MAIL_DELAY" && "$v_TOTAL_CHECKS" != "$v_MAIL_DELAY" && "$v_LAST_EMAIL_SENT" != "failure" ]]; then
		if [[ -n "$v_MAIL_COMMAND" && -n "$v_EMAIL_ADDRESS" ]]; then
			local v_MESSAGE="$( if [[ -n "$v_CUSTOM_MESSAGE" ]]; then echo "$v_CUSTOM_MESSAGE\n\n"; fi )$v_DATE2 - LWmon - $v_URL_OR_PING $v_JOB_NAME - Status changed: Appears to be failing.\n\nYou're recieving this message to inform you that $v_MAIL_DELAY consecutive check(s) against $v_URL_OR_PING $( if [[ "$v_JOB_NAME" == "$v_ORIG_JOB_NAME" ]]; then echo "$v_JOB_NAME"; else echo "$v_JOB_NAME ($v_ORIG_JOB_NAME)"; fi ) have failed, $v_MUTUAL_EMAIL"
			local v_SUBJECT="LWmon - $v_URL_OR_PING $v_JOB_NAME - Check FAILED!"
			fn_send_email "$v_MESSAGE" "$v_SUBJECT" "failure" &
		fi
		fn_run_script "failure" &
		v_LAST_EMAIL_SENT="failure"
		v_SENT=true
	fi
}

#====================================================#
#== Actually Sending the Email or Running a Script ==#
#====================================================#

function fn_send_email {
### Attempt to send the actual email and log the result
### This function is run with "&" so that the rest of LWmon will continue forward rather than wait for it
	fn_debug "fn_send_email"
	local v_MESSAGE="$1"
	local v_SUBJECT="$2"
	local v_TYPE="$3"
	local v_SENT=false
	eval "$v_MAIL_COMMAND" && v_SENT=true
	if [[ "$v_SENT" == true ]]; then
		echo "$v_DATE2 - [$v_CHILD_PID] - $v_URL_OR_PING $v_ORIG_JOB_NAME: $v_TYPE e-mail sent" >> "$v_LOG"
	else
		echo "$v_DATE2 - [$v_CHILD_PID] - $v_URL_OR_PING $v_ORIG_JOB_NAME: $v_TYPE e-mail failed to send" >> "$v_LOG"
	fi
}

function fn_run_script {
### Check if there is a script to run, and then run it
### This function is run with "&" so that the rest of LWmon will continue forward rather than wait for it
	local v_RESULT="$1"
	if [[ -n "$v_SCRIPT" ]]; then
		eval "$v_SCRIPT"
		local v_CODE="$?"
		if [[ "$v_CODE" == 0 ]]; then
			echo "$v_DATE2 - [$v_CHILD_PID] - $v_URL_OR_PING $v_ORIG_JOB_NAME: script ran successfully" >> "$v_LOG"
		else
			echo "$v_DATE2 - [$v_CHILD_PID] - $v_URL_OR_PING $v_ORIG_JOB_NAME: script ended with exit code \"$v_CODE\"" >> "$v_LOG"
		fi
	fi
}

#===================#
#== End Functions ==#
#===================#

fn_locate
source "$d_PROGRAM"/includes/mutual.shf
source "$d_PROGRAM"/includes/variables.shf

fn_start_script
if [[ -n "$1" ]]; then
	fn_child
fi
