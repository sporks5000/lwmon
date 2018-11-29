#! /bin/bash

d_INST=
b_INST=false
if [[ -n "$HOME" ]]; then
	d_INST="$HOME"/lwmon
fi
a_ARGS=( "$@" )
for (( c=0; c<=$(( ${#a_ARGS[@]} - 1 )); c++ )); do
	v_ARG="${a_ARGS[$c]}"
	if [[ -n "$v_ARG" && ${v_ARG:0:1} == "/" ]]; then
		### If an argument is given that appears to be a path, assume that that's the installation path
		d_INST="$v_ARG"
		b_INST=true
	else
		echo "I don't understand the argument '$v_ARG'"
		exit 1
	fi
done

### We don't want a trailing slash here
if [[ "${d_INST: -1}" == "/" ]]; then
	### Make sure it does not end in a slash
	d_INST="${d_INST:0:${#d_INST}-1}"
fi

if [[ -z "$d_INST" ]]; then
	echo "Please specify an installation directory by giving it as an argument to the install acript"
	exit 1
elif [[ "$d_INST" == "$HOME"/lwmon && "$b_INST" == false ]]; then
	read -ep "Install LWmon at '$d_INST'? (Y/n) " v_YN
	if [[ "${v_YN:0:1}" == "n" ||  "${v_YN:0:1}" == "N" ]]; then
		echo "Please specify an installation directory by giving it as an argument to the install acript"
		exit 1
	fi
fi

### Find out where we are
f_PROGRAM="$( readlink -f "${BASH_SOURCE[0]}" || true )"
if [[ -z $f_PROGRAM ]]; then
	f_PROGRAM="${BASH_SOURCE[0]}"
fi
d_PROGRAM="$( cd -P "$( dirname "$f_PROGRAM" )" && pwd )"

### Test that all of the variables are populated
if [[ -z "$d_PROGRAM" ]]; then
	echo "There appear to have been issues with setting variables correctly. Exiting."
	exit 1
fi

### Copy over the files
function fn_copy {
	local v_DIR="$1"/
	if [[ "$v_DIR" == "/" ]]; then
		v_DIR=
	fi
	local i
	for i in $( \ls -1A "$d_PROGRAM"/"$v_DIR" ); do
		if [[ -f "$d_PROGRAM"/"$v_DIR""$i" ]]; then
			mv -fv "$d_PROGRAM"/"$v_DIR""$i" "$d_INST"/"$v_DIR""$i"
		elif [[ -d "$d_PROGRAM"/"$v_DIR""$i" ]]; then
			mkdir -p "$d_INST"/"$v_DIR""$i"
			fn_copy "$v_DIR""$i"
		fi
	done
}

### If the directory the script is in is already the installation directory, we don't need to do this
if [[ "$d_PROGRAM" != "$d_INST" ]]; then
	### Update the configuration
	if [[ -f "$d_PROGRAM"/version/conf && -f "$d_INST"/version/conf && -f "$d_INST"/lwmon.conf && "$( cat "$d_PROGRAM"/version/conf 2> /dev/null )" -gt "$( cat "$d_INST"/version/conf 2> /dev/null )" ]]; then
		mv -f "$d_INST"/lwmon.conf "$d_INST"/lwmon.conf.old
		source "$d_PROGRAM"/includes/mutual.shf
		source "$d_PROGRAM"/includes/variables.shf
		source "$d_PROGRAM"/includes/create_config.shf
		fn_read_master_conf "$d_INST"/lwmon.conf.old
	fi
	### Copy over all of the relevant files
	fn_copy
fi

### Give the correct permissions
chmod 744 "$d_INST"/lwmon.sh
chmod 744 "$d_INST"/scripts/fold_out.pl
chmod 744 "$d_INST"/scripts/lwmon_child.sh
rm -f "$d_INST"/install.sh

### If there a .tar.gz file, we don't need tht anymore
if [[ -f "$d_PROGRAM"/../lwmon.tar.gz ]]; then
	rm -f "$d_PROGRAM"/../lwmon.tar.gz
fi
rm -rf "$d_PROGRAM"
