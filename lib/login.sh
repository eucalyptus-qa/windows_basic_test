#!/bin/bash
NUM_TRIAL=2
# login.sh [-h hostname] [-p password]
if [ -z "$1" ]; then
	echo "usage: login.sh [-h hostname] [-p password]"
	exit 1
fi

proxy=$(cat proxy)
if [ -z proxy ]; then
	echo "Proxy file is missing"
	exit 1
fi

while [ -n "$(echo $1 | grep '-')" ]; do
	case $1 in
	    -h ) hostname=$2; shift;;
	    -p ) password=$2; shift;;
	esac
	shift
done 
if [ -z "$hostname" ]; then
	echo "hostname is missing"; exit 1
fi
if [ -z "$password" ]; then
	echo "password is missing"; exit 1
fi

cmdline="powershell \"&{New-Euca-QA -hostname $hostname | out-null; Test-Euca-Login -hostname $hostname -password $password;}\""
echo $cmdline
i=0
output=""
while [ $i -lt $NUM_TRIAL ]; do
	((i++))
	ssh -o StrictHostKeyChecking=no -i ./id_rsa.proxy Administrator@$proxy "$cmdline" > login.out 2>&1 &

	while true; do
		sleep 1	
		jobs > status 2>&1
		if cat status | grep "Running" > /dev/null; then continue; else break; fi
	done
	output=$(cat login.out);
    	if echo $output | grep "SUCCESS" > /dev/null; then
        	break;
    	fi
    	sleep 10;
done

if echo $output | grep "SUCCESS" > /dev/null; then
	echo "$hostname" > hostname; 
	echo "$password" > password; 
else 
	rm -f hostname; 
	rm -f password; 
fi
echo $output
