#!/usr/bin/env bash

# Color palette
COLOUR_RESET='\033[0m'
COLOUR_GREEN='\033[38;5;2m'
COLOUR_RED='\033[38;5;1m'
COLOUR_YELLOW='\033[38;5;3m'

exit_if_no_aws_credentials () {
	if [ ! -s ${HOME}/.aws/credentials ]; then echo "$(basename ${0}): missing AWS credentials file" >&2; exit 1; fi
}

exit_if_no_getopt () {
	! getopt --test > /dev/null 
	if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
		echo "$(basename ${0}): enhanced GNU getopt required" >&2; exit 1
	fi
}

# check to see if the calling user is root, and exit if not
exit_if_not_root () {
	if [ ${EUID} -ne 0 ]; then echo "$(basename ${0}): must be run with sudo or as root" >&2; exit 1; fi
}

# check for a command in the path, and exit if not found
check_command_in_path () {
    which "${1}" >/dev/null 2>&1 || ( echo "$(basename "${0}"): can't find ${1} in path; please ensure it is installed"; exit 1 )
}

# check for multiple commands in the path, and exit if one is not found
check_commands_in_path () {
	# shellcheck disable=SC2068
	for COMMAND_CHECK in $@
	do
		set -e ; check_command_in_path "${COMMAND_CHECK}" ; set +e
	done
}

# check for a command in the path, and exit if not found
check_folder_exists () {
    [ -d "${1}" ] >/dev/null 2>&1 || ( echo "$(basename "${0}"): can't find directory ${1}"; exit 1 )
}

# check for multiple commands in the path, and exit if one is not found
check_folders_exist () {
	# shellcheck disable=SC2068
	for COMMAND_CHECK in $@
	do
		set -e ; check_folder_exists "${COMMAND_CHECK}" ; set +e
	done
}

# validate if an AWS region reference
validate_aws_region () {
	# shellcheck disable=SC2086
	aws ec2 describe-regions --region-names ${1} >/dev/null 2>&1 || ( echo "$(basename ${0}): ${1} is not a valid AWS region" >&2; exit 1 )
}