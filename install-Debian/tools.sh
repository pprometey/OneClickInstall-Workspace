#!/bin/bash

set -e

make_swap () {
	DISK_REQUIREMENTS=6144; #6Gb free space
	MEMORY_REQUIREMENTS=11000; #RAM ~12Gb

	AVAILABLE_DISK_SPACE=$(df -m /  | tail -1 | awk '{ print $4 }');
	TOTAL_MEMORY=$(free -m | grep -oP '\d+' | head -n 1);
	EXIST=$(swapon -s | awk '{ print $1 }' | { grep -x '/app_swapfile' || true; });

	if [[ -z $EXIST ]] && [ ${TOTAL_MEMORY} -lt ${MEMORY_REQUIREMENTS} ] && [ ${AVAILABLE_DISK_SPACE} -gt ${DISK_REQUIREMENTS} ]; then
		fallocate -l 6G /app_swapfile
		chmod 600 /app_swapfile
		mkswap /app_swapfile
		swapon /app_swapfile
		echo "/app_swapfile none swap sw 0 0" >> /etc/fstab
	fi
}

vercomp () {
    if [[ $1 == $2 ]]
    then
        echo 0
		return
    fi
    local IFS=.
    local i ver1=($1) ver2=($2) ver3=($3)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            echo 1
			return			
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            if [[ ${ver3%%.*} = 10 ]]; then
                echo 3
            else 
                echo 2
            fi
			return
        fi
    done
    echo 0
}

command_exists () {
	type "$1" &> /dev/null;
}

check_hardware () {
    DISK_REQUIREMENTS=40960;
    MEMORY_REQUIREMENTS=5500;
    CORE_REQUIREMENTS=2;

	AVAILABLE_DISK_SPACE=$(df -m /  | tail -1 | awk '{ print $4 }');

	if [ ${AVAILABLE_DISK_SPACE} -lt ${DISK_REQUIREMENTS} ]; then
		echo "Minimal requirements are not met: need at least $DISK_REQUIREMENTS MB of free HDD space"
		exit 1;
	fi

	TOTAL_MEMORY=$(free -m | grep -oP '\d+' | head -n 1);

	if [ ${TOTAL_MEMORY} -lt ${MEMORY_REQUIREMENTS} ]; then
		echo "Minimal requirements are not met: need at least $MEMORY_REQUIREMENTS MB of RAM"
		exit 1;
	fi

	CPU_CORES_NUMBER=$(cat /proc/cpuinfo | grep processor | wc -l);

	if [ ${CPU_CORES_NUMBER} -lt ${CORE_REQUIREMENTS} ]; then
		echo "The system does not meet the minimal hardware requirements. CPU with at least $CORE_REQUIREMENTS cores is required"
		exit 1;
	fi
}

if [ "$SKIP_HARDWARE_CHECK" != "true" ]; then
	check_hardware
fi

REV=`cat /etc/debian_version`
DIST='Debian'
if [ -f /etc/lsb-release ] ; then
        DIST=`cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }'`
        REV=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }'`
        DISTRIB_CODENAME=`cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }'`
        DISTRIB_RELEASE=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }'`
elif [ -f /etc/lsb_release ] || [ -f /usr/bin/lsb_release ] ; then
        DIST=`lsb_release -a 2>&1 | grep 'Distributor ID:' | awk -F ":" '{print $2 }'`
        REV=`lsb_release -a 2>&1 | grep 'Release:' | awk -F ":" '{print $2 }'`
        DISTRIB_CODENAME=`lsb_release -a 2>&1 | grep 'Codename:' | awk -F ":" '{print $2 }'`
        DISTRIB_RELEASE=`lsb_release -a 2>&1 | grep 'Release:' | awk -F ":" '{print $2 }'`
elif [ -f /etc/os-release ] ; then
        DISTRIB_CODENAME=$(grep "VERSION=" /etc/os-release |awk -F= {' print $2'}|sed s/\"//g |sed s/[0-9]//g | sed s/\)$//g |sed s/\(//g | tr -d '[:space:]')
        DISTRIB_RELEASE=$(grep "VERSION_ID=" /etc/os-release |awk -F= {' print $2'}|sed s/\"//g |sed s/[0-9]//g | sed s/\)$//g |sed s/\(//g | tr -d '[:space:]')
fi

DIST=`echo "$DIST" | tr '[:upper:]' '[:lower:]' | xargs`;
DISTRIB_CODENAME=`echo "$DISTRIB_CODENAME" | tr '[:upper:]' '[:lower:]' | xargs`;
REV=`echo "$REV" | xargs`;

if [ "$DISTRIB_CODENAME" = "kinetic" ]; then DISTRIB_CODENAME="jammy" && REV="22.04"; fi
