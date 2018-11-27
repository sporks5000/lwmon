#! /bin/bash

#===============================#
#== Declare Initial Variables ==#
#===============================#

### Debugging variables
b_DEBUG=false
b_DEBUG_FUNCTIONS=false

### Command Line Arguments
a_ARGS=( "$@" )
a_ARGS2=()

### lobal variables set within this file
v_RUNNING_STATE=
v_RUN_TYPE=
d_PROGRAM=

### Variables related to starting a new job
v_CURL_URL=
v_DOMAIN=
v_CHILD_PID=
v_USER_AGENT=
v_LOG_DURATION_DATA=
v_USE_WGET=
v_EMAIL=
v_WAIT_SECONDS=
v_CHECK_TIME_PARTIAL_SUCCESS=
v_CHECK_TIMEOUT=
v_MAIL_DELAY=
v_MIN_LOAD_PARTIAL_SUCCESS=
v_MIN_LOAD_FAILURE=
v_CL_PORT=
v_NUM_DURATIONS_RECENT=
v_NUM_STATUSES_RECENT=
v_NUM_STATUSES_NOT_SUCCESS=
v_IDENT=
v_IP_ADDRESS=
a_CURL_STRING=()
v_DNS_CHECK_DOMAIN=
v_DNS_CHECK_RESULT=
v_DNS_RECORD_TYPE=
v_SSH_USER=
v_JOB_NAME=
v_VERBOSITY=
v_OUTPUT_FILE=

#=====================#
#== Begin Functions ==#
#=====================#

function fn_locate {
### determine where the script is located
	if [[ "$b_DEBUG_FUNCTIONS" == true ]]; then echo "$$: fn_locate" > /dev/stderr; fi
	local f_PROGRAM="$( readlink -f "${BASH_SOURCE[0]}" )"
	if [[ -z "$f_PROGRAM" ]]; then
		f_PROGRAM="${BASH_SOURCE[0]}"
	fi
	d_PROGRAM="$( cd -P "$( dirname "$f_PROGRAM" )" && pwd )"
}

#========================================#
#== Functions for Processing Arguments ==#
#========================================#

function fn_assign_run_type {
### Make sure that we only have one running type
	fn_debug "fn_assign_run_type"
	if [[ -n "$v_RUN_TYPE" ]]; then
		echo "Cannot use flags \"$v_RUN_TYPE\" and \"$1\" simultaneously. Exiting."
		exit 1
	else
		v_RUN_TYPE="$1"
	fi
}

function fn_process_args {
### reformats the arguments so that they are easier to parse
	fn_debug "fn_process_args"
	local v_VALUE=
	local v_ARG="$1"
	if [[ "${v_ARG:0:1}" == "-" && "${v_ARG:0:2}" != "--" ]]; then
		local v_INDEX="$( expr index "$v_ARG" "=" )"
		if [[ "$v_INDEX" -gt 0 ]]; then
			v_VALUE="${v_ARG:$v_INDEX}"
			v_ARG="${v_ARG:1:$v_INDEX-2}"
		else
			v_ARG="${v_ARG:1}"
		fi
		local c
		for (( c=0; c<=$(( ${#v_ARG} - 1 )); c++ )); do
			a_ARGS2[${#a_ARGS2[@]}]="-${v_ARG:$c:1}"
		done
	elif [[ "${v_ARG:0:2}" != "--" ]]; then
		if [[ "$v_INDEX" -gt 0 ]]; then
			v_VALUE="${v_ARG:$v_INDEX}"
			v_ARG="${v_ARG:0:$v_INDEX-1}"
		fi
		a_ARGS2[${#a_ARGS2[@]}]="$v_ARG"
	else
		a_ARGS2[${#a_ARGS2[@]}]="$v_ARG"
	fi
	if [[ -n "$v_VALUE" ]]; then
		a_ARGS2[${#a_ARGS2[@]}]="$v_VALUE"
	fi
}

#=====================================#
#== Functions for Testing Arguments ==#
#=====================================#

function fn_test_string {
### $1 is the argument that we're testing whether or not exists
### $2 is the flag that was used
### $3 is a noun to describe what the argument should be starting with "a" or "an"
	fn_debug "fn_test_string"
	if [[ ! -n "$1" ]]; then
		echo "Argument \"$2\" must be followed by $3"
		exit 1
	fi
}

function fn_test_integer {
### $1 is the argument that we're testing to see if it's a number
### $2 is the flag
	fn_debug "fn_test_integer"
	if [[ $( echo "$1" | grep -Ec "^[0-9]+$" ) -lt 1 ]]; then
		echo "Argument \"$2\" must be followed by a whole number"
		exit 1
	fi
}

function fn_test_float {
	fn_debug "fn_test_float"
	if [[ $( echo "$1" | grep -Ec "^[0-9.]+$" ) -lt 1 ]]; then
		echo "Argument \"$2\" must be followed by a number (with or without decimal places)"
		exit 1
	fi
}

function fn_test_child_pid {
	fn_debug "fn_test_child_pid"
	if [[ $( echo "$1" | grep -Ec "^[0-9]+$" ) -lt 1 && -d "$d_WORKING"/"$1" ]]; then
		echo "Argument \"$2\" must be followed by the ID of a child process"
		exit 1
	fi
}

function fn_test_email {
	fn_debug "fn_fn_test_email"
	if [[ $( echo "$1" | grep -E -c "^[^@ ]+@[^.@ ]+\.[^@ ]+$" ) -lt 1 ]]; then
		echo "Argument \"$2\" must be followed by an email address"
		exit 1
	fi
}

function fn_test_ip {
	fn_debug "fn_test_ip"
	if [[ $( echo "$1" | grep -E -c "^((([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))$" ) -lt 1 ]]; then
		echo "Argument \"$2\" must be followed by an IP address"
		exit 1
	fi
}

function fn_test_flag_with_run {
### This function compares the run type to the flags that are used and assesses if they are not compatible
### $1" is the flag we're verifying will work with this run type
	fn_debug "fn_test_flag_with_run"
	if [[ "$v_RUN_TYPE" == "$1" ]]; then
		return
	fi
	if [[ "$v_RUN_TYPE" == "--url" ]]; then
		if [[ "$1" == "--curl" || "$1" == "-u" ]]; then
			return
		fi
		if [[ $( echo "$1" | grep -Ec "^--(check-result|(check-)?domain|load-(fail|ps)|port|record-type|(ssh-)?user)$" ) -gt 0 ]]; then
			echo "The only flags that can be used with \"$v_RUN_TYPE\" are the following:"
			echo "--check-timeout, --control, --ctps, --ident, --ip, --job-name, --ldd, --mail, --mail-delay, --ndr, --nsns, --nsr, --outfile, --seconds, --user-agent, --verbosity, --wget"
			exit 1
		fi
	elif [[ "$v_RUN_TYPE" == "--dns" ]]; then
		if [[ "$1" == "-d" ]]; then
			return
		fi
		if [[ $( echo "$1" | grep -Ec "^--(check-time(out|-partial-success)|ctps|ip(-address)?|load-(fail|ps)|port|string|(ssh-)?user|user-agent|wget)$" ) -gt 0 ]]; then
			echo "The only flags that can be used with \"$v_RUN_TYPE\" are the following:"
			echo "--check-result, --control, --domain, --ident, --job-name, --ldd, --mail, --mail-delay, --ndr, --nsns, --nsr, --outfile, --record-type, --seconds, --verbosity"
			exit 1
		fi
	elif [[ "$v_RUN_TYPE" == "--ping" ]]; then
		if [[ "$1" == "-p" ]]; then
			return
		fi
		if [[ $( echo "$1" | grep -Ec "^--(check-(time(out|-partial-success)|result)|ctps|(check-)?domain|ip(-address)?|load-(fail|ps)|port|record-type|string|(ssh-)?user|user-agent|wget)$" ) -gt 0 ]]; then
			echo "The only flags that can be used with \"$v_RUN_TYPE\" are the following:"
			echo "--control, --ident, --job-name, --ldd, --mail, --mail-delay, --ndr, --nsns, --nsr, --outfile, --seconds, --verbosity"
			exit 1
		fi
	elif [[ "$v_RUN_TYPE" == "--ssh-load" ]]; then
		if [[ "$1" == "--load" ]]; then
			return
		fi
		if [[ $( echo "$1" | grep -Ec "^--(check-result|(check-)?domain|ip(-address)?|port|record-type|string|user-agent|wget)$" ) -gt 0 ]]; then
			echo "The only flags that can be used with \"$v_RUN_TYPE\" are the following:"
			echo "--check-timeout, --control, --ctps, --ident, --job-name, --ldd, --load-ps, --load-fail, --mail, --mail-delay, --ndr, --nsns, --nsr, --outfile, --port, --seconds, --verbosity"
			exit 1
		fi
	elif [[ "$v_RUN_TYPE" == "--kill" ]]; then
		if [[ "$1" != "--save" ]]; then
			echo "Flag \"$v_RUN_TYPE\" cannot be used with any other flags except \"--save\""
			exit 1
		fi
	elif [[ "$v_RUN_TYPE" == "--list" ]]; then
		if [[ "$1" == "-l" ]]; then
			return
		fi
		echo "Flag \"$v_RUN_TYPE\" cannot be used with any other flags"
		exit 1
	elif [[ "$v_RUN_TYPE" == "--master" ]]; then
		echo "Flag \"$v_RUN_TYPE\" cannot be used with any other flags"
		exit 1
	elif [[ "$v_RUN_TYPE" == "--modify" ]]; then
		if [[ "$1" == "-m" ]]; then
			return
		fi
		echo "Flag \"$v_RUN_TYPE\" cannot be used with any other flags"
		exit 1
	fi
}

#======================================#
#== Parse the Command Line Arguments ==#
#======================================#

function fn_parse_cl_and_go {
	fn_debug "fn_parse_cl_and_go"

	### Separate out any instances where we have multiple single letter arguments, or arguments followed by an "="
	local c
	for (( c=0; c<=$(( ${#a_ARGS[@]} - 1 )); c++ )); do
		fn_process_args "${a_ARGS[$c]}"
	done
	unset a_ARGS

	### If any of the arguments are asking for help, output help and exit. Otherwise, find the run type
	local v_ARG
	for (( c=0; c<=$(( ${#a_ARGS2[@]} - 1 )); c++ )); do
		v_ARG="${a_ARGS2[$c]}"
		if [[ "$v_ARG" == "-h" || "$v_ARG" == "--help" ]]; then
			##### There should be a way to output these if perl is not present
			if [[ "${a_ARGS2[$c + 1]}" == "process-types" ]]; then
				"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/help_header.txt "$d_PROGRAM"/texts/help_process_types.txt "$d_PROGRAM"/texts/help_feedback.txt
			elif [[ "${a_ARGS2[$c + 1]}" == "params-file" ]]; then
				"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/help_header.txt "$d_PROGRAM"/texts/help_params_file.txt "$d_PROGRAM"/texts/help_feedback.txt
			elif [[ "${a_ARGS2[$c + 1]}" == "files" ]]; then
				"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/help_header.txt "$d_PROGRAM"/texts/help_files.txt "$d_PROGRAM"/texts/help_feedback.txt
			elif [[ "${a_ARGS2[$c + 1]}" == "flags" ]]; then
				"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/help_header.txt "$d_PROGRAM"/texts/help_flags.txt "$d_PROGRAM"/texts/help_feedback.txt
			elif [[ "${a_ARGS2[$c + 1]}" == "notes" ]]; then
				"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/help_header.txt "$d_PROGRAM"/texts/help_notes.txt "$d_PROGRAM"/texts/help_feedback.txt
			else
				"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/help_header.txt "$d_PROGRAM"/texts/help_basic.txt "$d_PROGRAM"/texts/help_feedback.txt
			fi
			exit
		elif [[ "$v_ARG" == "--version" || "$v_ARG" == "--changelog" ]]; then
			echo -n "Current Version: "
			grep -E -m1 "^[0-9]" "$d_PROGRAM"/texts/changelog.txt | sed -r "s/\s*-\s*$//"
			if [[ "${a_ARGS2[$c + 1]}" == "--full" || "$v_ARG" == "--changelog" ]]; then
				"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/changelog.txt
			fi
			exit
		elif [[ "$v_ARG" == "-u" || "$v_ARG" == "--url" || "$v_ARG" == "--curl" ]]; then
			fn_assign_run_type "--url"
		elif [[ "$v_ARG" == "-d" || "$v_ARG" == "--dns" ]]; then
			fn_assign_run_type "--dns"
		elif [[ "$v_ARG" == "-p" || "$v_ARG" == "--ping" ]]; then
			fn_assign_run_type "--ping"
		elif [[ "$v_ARG" == "--ssh-load" || "$v_ARG" == "--load" ]]; then
			fn_assign_run_type "--ssh-load"
		elif [[ "$v_ARG" == "--kill" ]]; then
			fn_assign_run_type "--kill"
		elif [[ "$v_ARG" == "--list" || "$v_ARG" == "-l" ]]; then
			fn_assign_run_type "--list"
		elif [[ "$v_ARG" == "--master" ]]; then
			fn_assign_run_type "--master"
		elif [[ "$v_ARG" == "--modify" || "$v_ARG" == "-m" ]]; then
			fn_assign_run_type "--modify"
		fi
	done

	### Make sure that ping, and dig are installed
	local i
	for i in 'dig' 'ping' 'stat' 'ssh' 'awk'; do
		if [[ -z "$( which $i 2> /dev/null )" ]]; then
			echo "The \"$i\" binary needs to be installed for LWmon to perform some of its functions. Exiting."
			exit 1
		fi
	done

	### Determine the running state
	if [[ -f "$d_WORKING"/lwmon.pid && $( cat /proc/$( cat "$d_WORKING"/lwmon.pid )/cmdline 2> /dev/null | tr "\0" " " | grep -c "lwmon.sh[[:blank:]]" ) -gt 0 ]]; then
	### This tests if the master process exists
		if [[ "$v_RUN_TYPE" == "--master" ]]; then
			echo "Master Process is already running"
			exit 1
		else
			### Control processes set up the parameters for new child processes and then exit.
			v_RUNNING_STATE="control"
		fi
	else
		### The master process (which typically starts out functioning as a control process) waits to see if there are waiting jobs present in the "new/" directory, and then spawns child processes for them.
		v_RUNNING_STATE="master"
	fi

	### If it was run with no flags, lets just go straight to the modify process
	if [[ -z "$v_RUN_TYPE" || "$v_RUN_TYPE" == "--modify" ]]; then
		source "$d_PROGRAM"/includes/modify.shf
		fn_modify
		exit
	fi

	### Go through the command line arguments again, this time gathering all the data
	local v_SAVE_JOBS=false
	local v_CHILD_PID
	for (( c=0; c<=$(( ${#a_ARGS2[@]} - 1 )); c++ )); do
		v_ARG="${a_ARGS2[$c]}"

		### Flags for Run Type
		if [[ "$v_ARG" == "-u" || "$v_ARG" == "--url" || "$v_ARG" == "--curl" ]]; then
			c=$(( c + 1 ))
			v_CURL_URL="${a_ARGS2[$c]}"
			fn_test_string "$v_CURL_URL" "$v_ARG" "a website url"
		elif [[ "$v_ARG" == "-d" || "$v_ARG" == "--dns" || "$v_ARG" == "-p" || "$v_ARG" == "--ping" || "$v_ARG" == "--ssh-load" || "$v_ARG" == "--load" ]]; then
			c=$(( c + 1 ))
			v_DOMAIN="${a_ARGS2[$c]}"
			fn_test_string "$v_DOMAIN" "$v_ARG" "a hostname or IP address"
		elif [[ "$v_ARG" == "--kill" ]]; then
			if [[ -n "${a_ARGS2[$c + 1]}" && "${a_ARGS[$c + 1]}" != "--save" ]]; then
				c=$(( c + 1 ))
				v_CHILD_PID="${a_ARGS2[$c]}"
				fn_test_child_pid "$v_CHILD_PID" "$v_ARG"
			fi
		elif [[ "$v_ARG" == "--list" || "$v_ARG" == "-l" || "$v_ARG" == "--master" ]]; then
			if [[ -n "${a_ARGS2[$c + 1]}" || "$c" -gt 0 ]]; then
				echo "Argument \"$v_ARG\" should not be used with other flags or arguments"
				exit 1
			fi

		### Flags that don't require arguments
		elif [[ "$v_ARG" == "--control" ]]; then
			v_RUNNING_STATE="control"
		elif [[ "$v_ARG" == "--save" ]]; then
			v_SAVE_JOBS=true

		### Flags with boolean arguments
		elif [[ "$v_ARG" == "--user-agent" ]]; then
			v_USER_AGENT=true
			if [[ "${a_ARGS2[$c + 1]}" == "true" || "${a_ARGS2[$c + 1]}" == "false" ]]; then
				c=$(( c + 1 ))
				v_USER_AGENT="${a_ARGS2[$c]}"
			fi
		elif [[ "$v_ARG" == "--ldd" || "$v_ARG" == "--log-duration-data" ]]; then
			v_LOG_DURATION_DATA=true
			if [[ "${a_ARGS2[$c + 1]}" == "true" || "${a_ARGS2[$c + 1]}" == "false" ]]; then
				c=$(( c + 1 ))
				v_LOG_DURATION_DATA="${a_ARGS2[$c]}"
			fi
		elif [[ "$v_ARG" == "--wget" ]]; then
			v_USE_WGET=true
			if [[ "${a_ARGS2[$c + 1]}" == "true" || "${a_ARGS2[$c + 1]}" == "false" ]]; then
				c=$(( c + 1 ))
				v_USE_WGET="${a_ARGS2[$c]}"
			fi

		### Flags that require other arguments
		elif [[ "$v_ARG" == "--mail" || "$v_ARG" == "--email" ]]; then
			c=$(( c + 1 ))
			v_EMAIL="${a_ARGS2[$c]}"
			fn_test_email "$v_EMAIL" "$v_ARG"
		elif [[ "$v_ARG" == "--seconds" ]]; then
			c=$(( c + 1 ))
			v_WAIT_SECONDS="${a_ARGS2[$c]}"
			fn_test_integer "$v_WAIT_SECONDS" "$v_ARG"
		elif [[ "$v_ARG" == "--ctps" || "$v_ARG" == "--check-time-partial-success" ]]; then
			c=$(( c + 1 ))
			v_CHECK_TIME_PARTIAL_SUCCESS="${a_ARGS2[$c]}"
			fn_test_float "$v_CHECK_TIME_PARTIAL_SUCCESS" "$v_ARG"
		elif [[ "$v_ARG" == "--check-timeout" ]]; then
			c=$(( c + 1 ))
			v_CHECK_TIMEOUT="${a_ARGS2[$c]}"
			fn_test_float "$v_CHECK_TIMEOUT" "$v_ARG"
		elif [[ "$v_ARG" == "--mail-delay" ]]; then
			c=$(( c + 1 ))
			v_MAIL_DELAY="${a_ARGS2[$c]}"
			fn_test_integer "$v_MAIL_DELAY" "$v_ARG"
		elif [[ "$v_ARG" == "--load-ps" ]]; then
			c=$(( c + 1 ))
			v_MIN_LOAD_PARTIAL_SUCCESS="${a_ARGS2[$c]}"
			fn_test_float "$v_MIN_LOAD_PARTIAL_SUCCESS" "$v_ARG"
		elif [[ "$v_ARG" == "--load-fail" ]]; then
			c=$(( c + 1 ))
			v_MIN_LOAD_FAILURE="${a_ARGS2[$c]}"
			fn_test_float "$v_MIN_LOAD_FAILURE" "$v_ARG"
		elif [[ "$v_ARG" == "--port" ]]; then
			c=$(( c + 1 ))
			v_CL_PORT="${a_ARGS2[$c]}"
			fn_test_integer "$v_CL_PORT" "$v_ARG"
		elif [[ "$v_ARG" == "--ndr" || "$v_ARG" == "--num-durations-recent" ]]; then
			c=$(( c + 1 ))
			v_NUM_DURATIONS_RECENT="${a_ARGS2[$c]}"
			fn_test_integer "$v_NUM_DURATIONS_RECENT" "$v_ARG"
		elif [[ "$v_ARG" == "--nsr" || "$v_ARG" == "--num-statuses-recent" ]]; then
			c=$(( c + 1 ))
			v_NUM_STATUSES_RECENT="${a_ARGS2[$c]}"
			fn_test_integer "$v_NUM_STATUSES_RECENT" "$v_ARG"
		elif [[ "$v_ARG" == "--nsns" || "$v_ARG" == "--num-statuses-not-success" ]]; then
			c=$(( c + 1 ))
			v_NUM_STATUSES_NOT_SUCCESS="${a_ARGS2[$c]}"
			fn_test_integer "$v_NUM_STATUSES_NOT_SUCCESS" "$v_ARG"
		elif [[ "$v_ARG" == "--ident" || "$v_ARG" == "--ticket" ]]; then
			if [[ -n "${a_ARGS2[$c + 1]}" ]]; then
				c=$(( c + 1 ))
				v_IDENT="${a_ARGS2[$c]}"
			fi
		elif [[ "$v_ARG" == "--ip" || "$v_ARG" == "--ip-address" ]]; then
			c=$(( c + 1 ))
			v_IP_ADDRESS="${a_ARGS2[$c]}"
			fn_test_ip "$v_IP_ADDRESS" "$v_ARG"
		elif [[ "$v_ARG" == "--string" ]]; then
			c=$(( c + 1 ))
			a_CURL_STRING[${#a_CURL_STRING[@]}]="${a_ARGS2[$c]}"
			fn_test_string "${a_CURL_STRING[${#a_CURL_STRING[@]} - 1]}" "$v_ARG" "a string of text that the curl output must contain"
		elif [[ "$v_ARG" == "--domain" || "$v_ARG" == "--check-domain" ]]; then
			c=$(( c + 1 ))
			v_DNS_CHECK_DOMAIN="${a_ARGS2[$c]}"
			fn_test_string "$v_DNS_CHECK_DOMAIN" "$v_ARG" "a domain name to dig for at the remote host"
		elif [[ "$v_ARG" == "--check-result" ]]; then
			c=$(( c + 1 ))
			v_DNS_CHECK_RESULT="${a_ARGS2[$c]}"
			fn_test_string "$v_DNS_CHECK_RESULT" "$v_ARG" "a string of text that the dig output must contain"
		elif [[ "$v_ARG" == "--record-type" ]]; then
			c=$(( c + 1 ))
			v_DNS_RECORD_TYPE="${a_ARGS2[$c]}"
			fn_test_string "$v_DNS_RECORD_TYPE" "$v_ARG" "a DNS record type"
		elif [[ "$v_ARG" == "--user" || "$v_ARG" == "--ssh-user" ]]; then
			c=$(( c + 1 ))
			v_SSH_USER="${a_ARGS2[$c]}"
			fn_test_string "$v_SSH_USER" "$v_ARG" "an SSH user"
		elif [[ "$v_ARG" == "--job-name" ]]; then
			c=$(( c + 1 ))
			v_JOB_NAME="${a_ARGS2[$c]}"
			fn_test_string "$v_JOB_NAME" "$v_ARG" "a name for the LWmon job"
		elif [[ "$v_ARG" == "--verbose" || "$v_ARG" == "--verbosity" ]]; then
			c=$(( c + 1 ))
			v_VERBOSITY="${a_ARGS2[$c]}"
			if [[ "$v_VERBOSITY" == "more" && "${a_ARGS2[$c + 1]}" == "verbose" ]]; then
				c=$(( $c + 1 ))
				v_VERBOSITY="more verbose"
			elif [[ "$v_VERBOSITY" == "more" || "$v_VERBOSITY" == "more-verbose" || "$v_VERBOSITY" == "moreverbose" ]]; then
				v_VERBOSITY="more verbose"
			fi
			if [[ $( echo "$v_VERBOSITY" | grep -E -c "^((more )?verbose|standard|change|none)$" ) -eq 0 ]]; then
				echo "The flag \"--verbosity\" needs to be followed by either \"verbose\", \"more verbose\", \"standard\", \"change\", or \"none\". Exiting."
				exit 1
			fi
		elif [[ "$v_ARG" == "--output-file" || "$v_ARG" == "--outfile" ]]; then
			c=$(( $c + 1 ))
			v_OUTPUT_FILE="${a_ARGS2[$c]}"
			if [[ -z "$v_OUTPUT_FILE" ]]; then
				echo "The flag \"--outfile\" needs to be followed by a file with write permissions referenced by its full path. Exiting."
				exit 1
			fi
		elif [[ -n "$v_ARG" ]]; then
			if [[ $( echo "$v_ARG "| grep -E -c "^-" ) -eq 1 ]]; then
				echo "There is no such flag \"$v_ARG\". Exiting."
			else
				echo "I don't understand what flag the argument \"$v_ARG\" is supposed to be associated with. Exiting."
			fi
			exit 1
		fi
		fn_test_flag_with_run "$v_ARG"
	done


	### Tells the script where to go with the type of job that was selected.
	if [[ "$v_RUN_TYPE" == "--url" || "$v_RUN_TYPE" == "-u" ]]; then
		source "$d_PROGRAM"/includes/create.shf
		fn_url_cl
	elif [[ "$v_RUN_TYPE" == "--ping" || "$v_RUN_TYPE" == "-p" ]]; then
		source "$d_PROGRAM"/includes/create.shf
		fn_ping_cl
	elif [[ "$v_RUN_TYPE" == "--dns" || "$v_RUN_TYPE" == "-d" ]]; then
		source "$d_PROGRAM"/includes/create.shf
		fn_dns_cl
	elif [[ "$v_RUN_TYPE" == "--ssh-load" ]]; then
		source "$d_PROGRAM"/includes/create.shf
		fn_load_cl
	elif [[ "$v_RUN_TYPE" == "--kill" ]]; then
		if [[ -n "$v_CHILD_PID" ]]; then
			if [[ ! -f  "$d_WORKING"/"$v_CHILD_PID"/params ]]; then
				echo "Child ID provided does not exist."
				exit 1
			fi
			touch "$d_WORKING"/$v_CHILD_PID/die
			echo "The child process will exit shortly."
			exit 0
		elif [[ "$v_SAVE_JOBS" == true ]]; then
			touch "$d_WORKING"/save
		fi
		touch "$d_WORKING"/die
		exit 0
	elif [[ "$v_RUN_TYPE" == "--list" || "$v_RUN_TYPE" == "-l" ]]; then
		source "$d_PROGRAM"/includes/modify.shf
		fn_list
		echo
		exit 0
	fi
}

#===================#
#== END FUNCTIONS ==#
#===================#

fn_locate
source "$d_PROGRAM"/includes/mutual.shf

fn_start_script
fn_parse_cl_and_go

### If it's the master process, run that
if [[ "$v_RUNNING_STATE" == "master" ]]; then
	unset a_ARGS2
	source "$d_PROGRAM"/includes/master.shf
	fn_master
fi

echo "The script should not get to this point. Exiting"
exit 1




### End of Script
