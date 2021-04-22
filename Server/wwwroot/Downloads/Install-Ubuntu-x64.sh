#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
HostName=

Organization=
GUID=$(cat /proc/sys/kernel/random/uuid)
ETag=
installdir="/usr/local/bin/Remotely"
servicefile="/etc/systemd/system/remotely-agent.service"
ostype=""


Args=( "$@" )
ArgLength=${#Args[@]}

for (( i=0; i<${ArgLength}; i+=2 ));
do
    if [ "${Args[$i]}" = "--uninstall" ]; then
        systemctl stop remotely-agent
        rm -r -f "${installdir}"
        rm -f "${servicefile}"
        systemctl daemon-reload
        exit
    elif [ "${Args[$i]}" = "--path" ]; then
        UpdatePackagePath="${Args[$i+1]}"
    fi
done


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
# Function: installubuntu
# Purpose:
#			installation specific to ubuntu
# --------------------------------------------------------------------------
installubuntu () {
	UbuntuVersion=$(lsb_release -r -s)
	
	wget -q https://packages.microsoft.com/config/ubuntu/$UbuntuVersion/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
	dpkg -i packages-microsoft-prod.deb
	apt-get update
	apt-get -y install apt-transport-https
	apt-get update
	apt-get -y install dotnet-runtime-5.0
	rm packages-microsoft-prod.deb
	
	apt-get -y install libx11-dev
	apt-get -y install unzip
	apt-get -y install libc6-dev
	apt-get -y install libgdiplus
	apt-get -y install libxtst-dev
	apt-get -y install xclip
	apt-get -y install jq
	apt-get -y install curl
}
# --------------------------------------------------------------------------
# Function: installmanjaro
# Purpose:
#			installation specific to manjaro
# --------------------------------------------------------------------------
installmanjaro () {
	pacman -Sy
	pacman -S dotnet-runtime-5.0 --noconfirm
	pacman -S libx11 --noconfirm
	pacman -S unzip --noconfirm
	pacman -S libc6 --noconfirm
	pacman -S libgdiplus --noconfirm
	pacman -S libxtst --noconfirm
	pacman -S xclip --noconfirm
	pacman -S jq --noconfirm
	pacman -S curl --noconfirm

}


# --------------------------------------------------------------------------
# Function: mymain
# Purpose:
#			actual code that needs to be executed
# --------------------------------------------------------------------------
mymain () {

	# This should be re-written to, based on what is found is os-release, to run the appropriate function to install the pre-reqs.
	installubuntu;

	if [ -f "/usr/local/bin/Remotely/ConnectionInfo.json" ]; then
	    GUID=`cat "/usr/local/bin/Remotely/ConnectionInfo.json" | jq -r '.DeviceID'`
	fi
	
	rm -r -f "${installdir}"
	rm -f "${servicefile}"
	
	mkdir -p "${installdir}"
	cd "${installdir}"
	
	if [ -z "$AppRoot" ]; then
	    echo  "Downloading client..."
	    wget $HostName/Downloads/Remotely-Linux.zip
	else
	    echo  "Copying install files..."
	    cp "$AppRoot" "${installdir}"/Remotely-Linux.zip
	fi
	
	unzip ./Remotely-Linux.zip
	chmod +x ./Remotely_Agent
	chmod +x ./Desktop/Remotely_Desktop
	
	connectionInfo="{
	    \"DeviceID\":\"$GUID\", 
	    \"Host\":\"$HostName\",
	    \"OrganizationID\": \"$Organization\",
	    \"ServerVerificationToken\":\"\"
	}"
	
	echo "$connectionInfo" > ./ConnectionInfo.json
	
	curl --head "$HostName"/Downloads/Remotely-Linux.zip | grep -i "etag" | cut -d' ' -f 2 > ./etag.txt
	
	echo "Creating service..."
	
	serviceConfig="[Unit]
Description=The Remotely agent used for remote access.

[Service]
WorkingDirectory=${installdir}/
ExecStart=${installdir}/Remotely_Agent
Restart=always
StartLimitIntervalSec=0
RestartSec=10

[Install]
WantedBy=graphical.target"

	echo "$serviceConfig" > "${servicefile}"

	systemctl enable remotely-agent
	systemctl restart remotely-agent
	
	echo "Install complete."
}


CheckSanity "${servicefile}" "${ostype}"
mymain "${servicefile}" "${githuborigin}";
