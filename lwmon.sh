#! /bin/bash

### determine where we're located
function fn_locate {
	f_PROGRAM="$( readlink "${BASH_SOURCE[0]}" )"
	if [[ -z "$f_PROGRAM" ]]; then
		f_PROGRAM="${BASH_SOURCE[0]}"
	fi
	d_PROGRAM="$( cd -P "$( dirname "$f_PROGRAM" )" && pwd )"
	f_PROGRAM="$( basename "$f_PROGRAM" )"
}
fn_locate
source "$d_PROGRAM"/includes/mutual.shf

#================================#
#== Functions that create jobs ==#
#================================#



#=====================#
#== Child Functions ==#
#=====================#

### Here's an example to test the logic being used for port numbers:
### v_CURL_URL="https://sporks5000.com:4670/index.php"; v_DOMAIN="sporks5000.com"; v_SERVER_PORT=8080; v_IP_ADDRESS="10.30.6.88"; if [[ $( echo $v_CURL_URL | grep -E -c "^(http://|https://)*$v_DOMAIN:[0-9][0-9]*" ) -eq 1 ]]; then echo "curl $v_CURL_URL --header 'Host: $v_DOMAIN'" | sed "s/$v_DOMAIN:[0-9][0-9]*/$v_IP_ADDRESS:$v_SERVER_PORT/"; else echo "curl $v_CURL_URL --header 'Host: $v_DOMAIN'" | sed "s/$v_DOMAIN/$v_IP_ADDRESS:$v_SERVER_PORT/"; fi

#===================================#
#== Success and Failure Functions ==#
#===================================#


#======================#
#== Master Functions ==#
#======================#



#=============================#
#== Other Control Functions ==#
#=============================#



#============================================#
#== Functions related to the configuration ==#
#============================================#

##### Is this still the best way to parse command line arguments?
function fn_parse_cl_argument {
	### Function Version 1.1.0
	### For this function, $1 is the flag that was passed (without trailing equal sign), $2 is "num" or "int" if it's a number, "float" if it's a number with the potential of having a decimal point, "string" if it's a string, "bool" if it's true or false, "date" if it's a date, "file" if it's a file, "directory" if it's a directory, and "none" if nothing follows it, and $3 is an alternate flag with the same functionality. If $2 is bool, then $4 determines the behavior for a boolean flags if no argument is passed for them: "true" sets them to true, "false" sets them to "false" and "exit" tells the script to exit with an error. If $2 is "file" or "directory", then $4 can be "create" if the file should be created, and "error" if the file needs to have existed previously.
	### This function will prompt for responses if the variable "$v_CL_PROMPT" is set to "true".
	### This function makes use of, but does not rely on the function "fn_fix_home".
	### Currently scrub.sh has the prettiest implimentation of passing data to this function.
	unset v_RESULT
	if [[ "$2" == "none" ]]; then
		v_RESULT="true"
	##### If I'm going to be using regex interpretation here, then I should be consistant and use it everywhere
	elif [[ "$v_ARG" =~ ^$1$ && "$2" != "none" ]]; then
	### If there is no equal sign, the next argument is the modifier for the flag
		if [[ -n "${a_ARGS[$(( $c + 1 ))]}" && ! "${a_ARGS[$(( $c + 1 ))]}" =~ ^- ]]; then
		### If the next argument doesn't begin with a dash.
			if [[ "$2" != "bool" || ( "$2" == "bool" && $( echo "${a_ARGS[$(( $c + 1 ))]}" | grep -E -c "^([Tt]([Rr][Uu][Ee])*|[Ff]([Aa][Ll][Ss][Ee])*)$" ) -eq 1 ) ]]; then
			### If it's not bool, or if it is bool, but the next argument is neither true nor false
				c=$(( $c + 1 ))
				v_RESULT="${a_ARGS[$c]}"
			fi
		elif [[ "$2" != "bool" && $v_CL_PROMPT == true ]]; then
			read -ep "The \"$v_ARG\" flag requires an argument: " v_RESULT
		elif [[ "$2" != "bool" && $v_CL_PROMPT != true ]]; then
			echo "The flag \"$1\" needs to be followed by an argument. Exiting."
			exit 1
		fi
	elif [[ "$v_ARG" =~ ^$1[0-9]*$ && ( $2 == "int" || $2 == "num" ) ]]; then
	### If the argument doesn't have an equal sign, has a number on the end, and it's type is "int" or "num", then the number is the modifier (example "-n1")
		v_RESULT="$( echo "$v_ARG" | sed "s/^$1//" )"
	elif [[ "$v_ARG" =~ ^$1= && "$2" != "none" ]]; then
	### If the argument has an equal sign, then the modifier for the flag is within this argument
		v_RESULT="$( echo "$v_ARG" | cut -d "=" -f2- )"
		if [[ -z "$v_RESULT" && "$2" != "bool" && $v_CL_PROMPT == true ]]; then
			read -ep "The \"$v_ARG\" flag requires an argument: " v_RESULT
		elif [[ -z "$v_RESULT" && "$2" != "bool" && $v_CL_PROMPT != true ]]; then
			echo "The flag \"$1\" needs to be followed by an argument. Exiting."
			exit 1
		fi
	elif [[ -n "$3" && "$v_ARG" =~ ^$3$ && "$2" != "none" ]]; then
	### If there is no equal sign, the next argument is the modifier for the alternate flag
		if [[ -n "${a_ARGS[$(( $c + 1 ))]}" && ! "${a_ARGS[$(( $c + 1 ))]}" =~ ^- ]]; then
			if [[ "$2" != "bool" || ( "$2" == "bool" && $( echo "${a_ARGS[$(( $c + 1 ))]}" | grep -E -c "^([Tt]([Rr][Uu][Ee])*|[Ff]([Aa][Ll][Ss][Ee])*)$" ) -eq 1 ) ]]; then
				c=$(( $c + 1 ))
				v_RESULT="${a_ARGS[$c]}"
			fi
		elif [[ "$2" != "bool" && $v_CL_PROMPT == true ]]; then
			read -ep "The \"$v_ARG\" flag requires an argument: " v_RESULT
		elif [[ "$2" != "bool" && $v_CL_PROMPT != true ]]; then
			echo "The flag \"$3\" needs to be followed by an argument. Exiting."
			exit 1
		fi
	elif [[ "$v_ARG" =~ ^$3[0-9]*$ && ( $2 == "int" || $2 == "num" ) ]]; then
	### If the argument has a number on the end, and it's type is "int" or "num", then the number is the modifier
		v_RESULT="$( echo "$v_ARG" | sed "s/^$3//" )"
	elif [[ -n "$3" && "$v_ARG" =~ ^$3= && "$2" != "none" ]]; then
	### If the argument has an equal sign, then the modifier for the alternate flag is within this argument
		v_RESULT="$( echo "$v_ARG" | cut -d "=" -f2- )"
		if [[ -z "$v_RESULT" && "$2" != "bool" && $v_CL_PROMPT == true ]]; then
			read -ep "The \"$v_ARG\" flag requires an argument: " v_RESULT
		elif [[ -z "$v_RESULT" && "$2" != "bool" && $v_CL_PROMPT != true ]]; then
			echo "The flag \"$3\" needs to be followed by an argument. Exiting."
			exit 1
		fi
	fi
	if [[ ( "$2" == "num" || "$2" == "int" ) && ! "$v_RESULT" =~ ^[0-9]+$ ]]; then
		echo "The flag \"$1\" needs to be followed by an integer. Exiting."
		exit 1
	elif [[ "$2" == "date" ]]; then
		### Dates are validated by ensuring that they can be passed to the "date" command,so things like "yesterday" also work.
		date --date="$v_RESULT" > /dev/null 2>&1
		if [[ "$?" -ne 0 ]]; then
			echo "The flag \"$1\" needs to be followed by a date. Exiting."
			exit 1
		fi
		v_RESULT="$( date --date="$v_RESULT" +%F )"
	elif [[ "$2" == "float" && ! "$v_RESULT" =~ ^[0-9.]+$ ]]; then
		echo "The flag \"$1\" needs to be followed by a number. Exiting."
		exit 1
	elif [[ "$2" == "file" ]]; then
		if [[ "$( type -t fn_fix_home )" == "function" ]]; then
			v_RESULT="$( fn_fix_home "$v_RESULT" )"
		fi
		if [[ "$4" == "error" && ! -f "$v_RESULT" ]]; then
			echo "File \"$v_RESULT\" does not appear to exist. Exiting."
			exit 1
		elif [[ "$4" == "create" ]]; then
			touch "$v_RESULT"
			v_EXIT_CODE="$?"
			if [[ "$v_EXIT_CODE" -ne 0 ]]; then
				echo "Error creating file \"$v_RESULT\". Exiting."
				exit 1
			fi
		fi
	elif [[ "$2" == "directory" ]]; then
		if [[ "$( type -t fn_fix_home )" == "function" ]]; then
			v_RESULT="$( fn_fix_home "$v_RESULT" --directory )"
		fi
		if [[ "$4" == "error" && ! -d "$v_RESULT" ]]; then
			echo "Directory \"$v_RESULT\" does not appear to exist. Exiting."
			exit 1
		elif [[ "$4" == "create" ]]; then
			mkdir -p "$v_RESULT"
			v_EXIT_CODE="$?"
			if [[ "$v_EXIT_CODE" -ne 0 ]]; then
				echo "Error creating directory \"$v_RESULT\". Exiting."
				exit 1
			fi
		fi
		##### Is there any reason why I'm adding slashes to the end of directories?
		if [[ "$v_RESULT" =~ /$ ]]; then
			v_RESULT="$v_RESULT/"
		fi
	elif [[ "$2" == "bool" ]]; then
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

#================================#
#== Help and Version Functions ==#
#================================#



#===================#
#== END FUNCTIONS ==#
#===================#

fn_start_script

### If there's a no-output file from the previous session, remove it.
rm -f "$d_WORKING"/no_output

### If any of the arguments are asking for help, output help and exit
a_ARGS=( "$@" )
for (( c=0; c<=$(( ${#a_ARGS[@]} - 1 )); c++ )); do
	v_ARG="${a_ARGS[$c]}"
	if [[ "$v_ARG" == "-h" || "$v_ARG" == "--help" ]]; then
		if [[ "${a_ARGS[$c + 1]}" == "process-types" ]]; then
			"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/help_header.txt "$d_PROGRAM"/texts/help_process_types.txt "$d_PROGRAM"/texts/help_feedback.txt
		elif [[ "${a_ARGS[$c + 1]}" == "params-file" ]]; then
			"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/help_header.txt "$d_PROGRAM"/texts/help_params_file.txt "$d_PROGRAM"/texts/help_feedback.txt
		elif [[ "${a_ARGS[$c + 1]}" == "files" ]]; then
			"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/help_header.txt "$d_PROGRAM"/texts/help_files.txt "$d_PROGRAM"/texts/help_feedback.txt
		elif [[ "${a_ARGS[$c + 1]}" == "flags" ]]; then
			"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/help_header.txt "$d_PROGRAM"/texts/help_flags.txt "$d_PROGRAM"/texts/help_feedback.txt
		elif [[ "${a_ARGS[$c + 1]}" == "notes" ]]; then
			"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/help_header.txt "$d_PROGRAM"/texts/help_notes.txt "$d_PROGRAM"/texts/help_feedback.txt
		else
			"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/help_header.txt "$d_PROGRAM"/texts/help_basic.txt "$d_PROGRAM"/texts/help_feedback.txt
		fi
		exit
	elif [[ "$v_ARG" == "--version" || "$v_ARG" == "--changelog" ]]; then
		echo -n "Current Version: "
		grep -E -m1 "^[0-9]" "$d_PROGRAM"/texts/changelog.txt | sed -r "s/\s*-\s*$//"
		if [[ "${a_ARGS[$c + 1]}" == "--full" || "$v_ARG" == "--changelog" ]]; then
			"$d_PROGRAM"/scripts/fold_out.pl "$d_PROGRAM"/texts/changelog.txt
		fi
		exit
	fi
done

### Make sure that ping, and dig are installed
### curl, wget, and mail are being checked elsewhere within the script.
for i in dig ping stat ssh; do
	if [[ -z "$( which $i 2> /dev/null )" ]]; then
		echo "The \"$i\" binary needs to be installed for LWmon to perform some of its functions. Exiting."
		exit 1
	fi
done

### Determine the running state
if [[ -f "$d_WORKING"/lwmon.pid && $( cat /proc/$( cat "$d_WORKING"/lwmon.pid )/cmdline 2> /dev/null | tr "\0" " " | grep -E -c "$f_PROGRAM[[:blank:]]" ) -gt 0 ]]; then
	if [[ "$PPID" == $( cat "$d_WORKING"/lwmon.pid ) ]]; then
		### Child processes monitor one thing only they are spawned only by the master process and when the master process is no longer present, they die.
		v_RUNNING_STATE="child"
		fn_child 
		##### If we're directing everything at the child script, there's no reason why this should need to be here.
	else
		### Control processes set up the parameters for new child processes and then exit.
		v_RUNNING_STATE="control"
	fi
else
	### The master process (which typically starts out functioning as a control process) waits to see if there are waiting jobs present in the "new/" directory, and then spawns child processes for them.
	v_RUNNING_STATE="master"
	### Create some necessary configuration files and directories
	mkdir -p "$d_WORKING"/"new/"
	echo -n "$$" > "$d_WORKING"/lwmon.pid
	if [[ -f "$d_WORKING"/no_output ]]; then
		rm -f "$d_WORKING"/no_output
	fi
fi

### More necessary configuration files.
if [[ ! -f "$f_CONF" ]]; then
	source "$d_PROGRAM"/includes/create_config.shf
	fn_create_config
fi

### Turn the command line arguments into an array.
a_ARGS=( "$@" )
v_CURL_STRING_COUNT=0

### For each command line argument, determine what needs to be done.
for (( c=0; c<=$(( $# - 1 )); c++ )); do
	v_ARG="${a_ARGS[$c]}"
	if [[ $( echo "$v_ARG" | grep -E -c "^(--((c?url|dns|ping|kill|(ssh-)*load)(=.*)*|list|master|modify)|[^-]*-[mpudl])$" ) -gt 0 ]]; then
		### These flags indicate a specific action for the script to take. Two actinos cannot be taken at once.
		if [[ -n "$v_RUN_TYPE" ]]; then
			### If another of these actions has already been specified, end.
			echo "Cannot use \"$v_RUN_TYPE\" and \"$v_ARG\" simultaneously. Exiting."
			exit 1
		fi
		v_RUN_TYPE="$( echo "$v_ARG" | cut -d "=" -f1 )"
		if [[ $( echo "$v_ARG" | grep -E -c "^-(u|-c?url)($|=)" ) -eq 1 ]]; then
			fn_parse_cl_argument "$v_RUN_TYPE" "string" "-u"; v_CURL_URL="$v_RESULT"
			v_RUN_TYPE="--url"
		elif [[ $( echo "$v_ARG" | grep -E -c "^-(d|-dns)($|=)" ) -eq 1 ]]; then
			fn_parse_cl_argument "--dns" "string" "-d"; v_DOMAIN="$v_RESULT"
			v_RUN_TYPE="--dns"
		elif [[ $( echo "$v_ARG" | grep -E -c "^-(p|-ping)($|=)" ) -eq 1 ]]; then
			fn_parse_cl_argument "--ping" "string" "-p"; v_DOMAIN="$v_RESULT"
			v_RUN_TYPE="--ping"
		elif [[ $( echo "$v_ARG" | grep -E -c "^--(ssh-)*load($|=)" ) -eq 1 ]]; then
			fn_parse_cl_argument "--ssh-load" "string" "--load"; v_DOMAIN="$v_RESULT"
			v_RUN_TYPE="--ssh-load"
		elif [[ $( echo "$v_ARG" | grep -E -c "^--kill($|=)" ) -eq 1 ]]; then
			if [[ $( echo "$v_ARG" | grep -E -c "^--kill=" ) -eq 1 || ( -n ${a_ARGS[$(( $c + 1 ))]} && $( echo ${a_ARGS[$(( $c + 1 ))]} | grep -E -c "^-" ) -eq 0 ) ]]; then
				fn_parse_cl_argument "--kill" "num"; v_CHILD_PID="$v_RESULT"
			fi
		fi
	### All other flags modify or contribute to one of the above actions.
	elif [[ "$v_ARG" == "--control" ]]; then
		v_RUNNING_STATE="control"
	elif [[ "$v_ARG" == "--save" ]]; then
		v_SAVE_JOBS=true
	elif [[ "$v_ARG" == "--testing" ]]; then
		v_TESTING=true
		v_NUM_ARGUMENTS=$(( $v_NUM_ARGUMENTS - 1 ))
	elif [[ $( echo "$v_ARG" | grep -E -c "^--user-agent($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--user-agent" "bool" "--user-agent" "true"; v_USER_AGENT="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--(ldd|log-duration-data)($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--ldd" "bool" "--log-duration-data" "true"; v_LOG_DURATION_DATA="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--wget($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--wget" "bool" "--wget" "false"; v_USE_WGET="$v_RESULT"
		if [[ $v_USE_WGET == "true" ]]; then
			fn_use_wget
		fi
		v_NUM_ARGUMENTS=$(( $v_NUM_ARGUMENTS - 1 ))
	elif [[ $( echo "$v_ARG" | grep -E -c "^--(e)*mail($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--mail" "string" "--email"; v_EMAIL_ADDRESS="$v_RESULT"
		if [[ -z "$v_EMAIL_ADDRESS" || $( echo "$v_EMAIL_ADDRESS" | grep -E -c "^[^@]+@[^.@]+\.[^@]+$" ) -lt 1 ]]; then
			echo "The flag \"--mail\" needs to be followed by an e-mail address. Exiting."
			exit 1
		fi
	elif [[ $( echo "$v_ARG" | grep -E -c "^--seconds($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--seconds" "float"; v_WAIT_SECONDS="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--ctps($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--ctps" "float"; v_CHECK_TIME_PARTIAL_SUCCESS="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--check-timeout($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--check-timeout" "float"; v_CHECK_TIMEOUT="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--mail-delay($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--mail-delay" "num"; v_MAIL_DELAY="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--load-ps($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--load-ps" "float"; v_MIN_LOAD_PARTIAL_SUCCESS="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--load-fail($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--load-fail" "float"; v_MIN_LOAD_FAILURE="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--port($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--port" "num"; v_CL_PORT="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--(ndr|num-durations-recent)($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--ndr" "num" "--num-durations-recent"; v_NUM_DURATIONS_RECENT="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--(nsr|num-statuses-recent)($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--nsr" "num" "--num-statuses-recent"; v_NUM_STATUSES_RECENT="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--(nsns|num-statuses-not-success)($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--nsns" "num" "--num-statuses-not-success"; v_NUM_STATUSES_NOT_SUCCESS="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--(ident|ticket)($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--ident" "num" "--ticket"; v_IDENT="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--ip(-address)*($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--ip" "string" "--ip-address"; v_IP_ADDRESS="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--string($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--string" "string"; a_CURL_STRING[${#a_CURL_STRING[@]}]="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--(check-)*domain($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--domain" "string" "--check-domain"; v_DNS_CHECK_DOMAIN="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--check-result($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--check-result" "string"; v_DNS_CHECK_RESULT="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--record-type($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--record-type" "string"; v_DNS_RECORD_TYPE="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--(ssh-)*user($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--user" "string" "--ssh-user"; v_SSH_USER="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--job-name($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--job-name" "string"; v_JOB_NAME="$v_RESULT"
	elif [[ $( echo "$v_ARG" | grep -E -c "^--verbos(e|ity)($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--verbosity" "string" "--verbose"; v_VERBOSITY="$v_RESULT"
		if [[ "$v_VERBOSITY" == "more" && "${a_ARGS[$(( $c + 1 ))]}" == "verbose" ]]; then
			c=$(( $c + 1 ))
			v_VERBOSITY="more verbose"
		elif [[ "$v_VERBOSITY" == "more" ]]; then
			v_VERBOSITY="more verbose"
		fi
		if [[ $( echo "$v_VERBOSITY" | grep -E -c "^(verbose|more verbose|standard|change|none)$" ) -eq 0 ]]; then
			echo "The flag \"--verbosity\" needs to be followed by either \"verbose\", \"more verbose\", \"standard\", \"change\", or \"none\". Exiting."
			exit 1
		fi
	elif [[ $( echo "$v_ARG" | grep -E -c "^--out(put-)*file($|=)" ) -eq 1 ]]; then
		fn_parse_cl_argument "--outfile" "string" "--output-file"; v_OUTPUT_FILE="$v_RESULT"
		fn_test_file "$v_OUTPUT_FILE" false true; v_OUTPUT_FILE="$v_RESULT"
		if [[ -z "$v_OUTPUT_FILE" ]]; then
			echo "The flag \"--outfile\" needs to be followed by a file with write permissions referenced by its full path. Exiting."
			exit 1
		fi
	else
		if [[ $( echo "$v_ARG "| grep -E -c "^-" ) -eq 1 ]]; then
			echo "There is no such flag \"$v_ARG\". Exiting."
		else
			echo "I don't understand what flag the argument \"$v_ARG\" is supposed to be associated with. Exiting."
		fi
		exit 1
	fi
	v_NUM_ARGUMENTS=$(( $v_NUM_ARGUMENTS + 1 ))
done

### Some of these flags need to be used alone.
if [[ "$v_RUN_TYPE" == "--master" || "$v_RUN_TYPE" == "--version" || "$v_RUN_TYPE" == "--help-files" || "$v_RUN_TYPE" == "--help-flags" || "$v_RUN_TYPE" == "--help-process-types" || "$v_RUN_TYPE" == "--help-params-file" || "$v_RUN_TYPE" == "--help" || "$v_RUN_TYPE" == "--modify" || "$v_RUN_TYPE" == "-h" || "$v_RUN_TYPE" == "-m" ]]; then
	if [[ "$v_NUM_ARGUMENTS" -gt 1 ]]; then
		echo "The flag \"$v_RUN_TYPE\" cannot be used with other flags. Exiting."
		exit 1
	fi
fi
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
		if [[ $v_NUM_ARGUMENTS -gt 2 ]]; then
			echo "The \"--kill\" flag can only used alone, with the \"--save\" flag, or in conjunction with the ID number of a child process. Exiting."
			exit 1
		fi
		touch "$d_WORKING"/save
	else
		if [[ "$v_NUM_ARGUMENTS" -gt 1 ]]; then
			echo "The \"--kill\" flag can only used alone, with the \"--save\" flag, or in conjunction with the ID number of a child process. Exiting."
			exit 1
		fi
	fi
	touch "$d_WORKING"/die
	exit 0
elif [[ "$v_RUN_TYPE" == "--modify" || "$v_RUN_TYPE" == "-m" ]]; then
	source "$d_PROGRAM"/includes/modify.shf
	fn_modify
elif [[ "$v_RUN_TYPE" == "--list" || "$v_RUN_TYPE" == "-l" ]]; then
	source "$d_PROGRAM"/includes/modify.shf
	fn_list
	echo
	exit 0
elif [[ "$v_RUN_TYPE" == "--master" ]]; then
	source "$d_PROGRAM"/includes/master.shf
	fn_master
elif [[ -z "$v_RUN_TYPE" ]]; then
	if [[ "$v_NUM_ARGUMENTS" -ne 0 ]]; then
		echo "Some of the flags you used didn't make sense in context. Here's a menu instead."
	fi
	source "$d_PROGRAM"/includes/modify.shf
	fn_modify
fi

echo "The script should not get to this point. Exiting"
exit 1




### End of Script
