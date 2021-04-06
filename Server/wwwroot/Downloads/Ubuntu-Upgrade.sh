#!/bin/bash

# Set the shell to fail when commands fail, do not dynamically create variables.
set -euo pipefail
IFS=$'\n\t'
servicefile="/etc/systemd/system/remotely.service"
githuborigin="https://github.com/lucent-sea/Remotely/releases/latest/download/Remotely_Server_Linux-x64.zip"
ostype="";

# --------------------------------------------------------------------------
# Function: CheckSanity
# Purpose:
#			Confirm that our expectations are correct about files and programs that this script may execute.
# --------------------------------------------------------------------------
CheckSanity() {

	# pipe separated list of valid ID's from /etc/os-release
	distrolist="ubuntu|manjaro"

	# Files are going to be overwritten. Ideally, the user running this script should be in the same group as the group that owns the files.
	# This code should be re-written to verify that case. In the meantime, let's assume that root must execute the script.

	if [[ $EUID -ne 0 ]]; then
	   echo "This script must be run as root" 1>&2
	   exit 1
	fi
	if [ ! -f "${servicefile}" ]; then
		echo "***ERROR**" >&2;
		echo "The file (${servicefile}) does not exist. Perhaps the server is not installed or the file is in a different location?"
		exit 1;
	fi
	# Attempt to determine the OS-Release Distribution:
	if [ ! -f "/etc/os-release" ]; then
		echo "***ERROR**" >&2;
		echo "The file (/etc/os-release) does not exist. We are not sure if the commands we execute will properly upgrade this release. Please inform us of this error and what distribution you are running."
		exit 1;
	fi
	ostype=$(cat /etc/os-release | egrep -i "^ID=" | awk -F "=" '{print $2}')
	if [ ! $(echo "${ostype}" | egrep -i "(${distrolist})" | wc -l) -gt 0 ]; then
		echo "***ERROR**" >&2;
		echo "The file (/etc/os-release) claims that your distribution is not in the list of supported distributions (${distrolist}). We are not sure if the commands we execute will properly upgrade this release. Please inform us of this error and what distribution you are running."
		exit 1;
	fi
}
# --------------------------------------------------------------------------
# Function: installcentos
# Purpose:
#			installation specific to centos
# --------------------------------------------------------------------------
installcentos () {
	# verify prerequisites and install if necessary:
	dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	dnf -y install yum-utils
	yum-config-manager --enable rhui-REGION-rhel-server-extras rhui-REGION-rhel-server-optional
	dnf -y install unzip
	dnf -y install acl
}


# --------------------------------------------------------------------------
# Function: installubuntu
# Purpose:
#			installation specific to ubuntu
# --------------------------------------------------------------------------
installubuntu () {
	# verify prerequisites and install if necessary:
	apt-get -y install unzip
	apt-get -y install acl
}

# --------------------------------------------------------------------------
# Function: mymain
# Purpose:
#			actual code that needs to be executed
# --------------------------------------------------------------------------
mymain () {
	local servicefile=${1};
	shift
	local githuborigin=${1};
	shift
	
	local AppRoot=$(cat "${servicefile}" | grep -i "execstart" | cut -d' ' -f 2 | sed -e 's/\/[^\/]*$/\//')
	local filename=$(echo "${githuborigin}" | sed -e 's/^.*\//')
	
	echo "Remotely server upgrade started."
	
	echo "Target path: $AppRoot"
	
	read -p "If this is not correct, press Ctrl + C now to abort! Else hit continue."
	
	echo "Ensuring dependencies are installed."

	case "${ostype}" in
		ubuntu)
			installubuntu
			;;
		manjaro)
			# This needs to be tested
			echo "This needs testing."
			installmanjaro
			;;
		centos)
			# This needs to be tested
			echo "This needs testing."
			installcentos
			;;
		*)
			echo "Nothing was changed: Your system (${ostype}) was not found"
			exit 1
			;;
	esac
	
	echo "Downloading latest Remotely package."
	# Download and install Remotely files.
	mkdir -p "${AppRoot}"
	wget "${githuborigin}"
	unzip -o "${filename}" -d "${AppRoot}"
	rm ./"${filename}"
	setfacl -R -m u:www-data:rwx "${AppRoot}"
	chown -R "${USER}":www-data "${AppRoot}"
	
	# Restart service.
	systemctl restart remotely.service
	
	echo "Update complete."
}

CheckSanity "${servicefile}" "${ostype}"
mymain "${servicefile}" "${githuborigin}";
