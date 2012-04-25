#!/bin/bash
NUM_TRIAL=2
# rdp.sh 
hostname=$(cat hostname)
password=$(cat password)

if [ -s "./iname" ]; then
	iname=$(cat iname);
fi

if [ -z "$hostname" ]; then
	echo "hostname is missing"; exit 1
fi
if [ -z "$password" ]; then
	echo "password is missing"; exit 1
fi

proxy=$(cat proxy)
if [ -z proxy ]; then
        echo "Proxy file is missing"
        exit 1;
fi
if [ -z "$iname" ]; then
	cmdline="powershell -command \"&{New-Euca-QA -hostname $hostname | out-null; Test-Euca-Login -hostname $hostname -password $password | out-null ; Test-Euca-Hostname}\"";
else
	cmdline="powershell -command \"&{New-Euca-QA -hostname $hostname | out-null; Test-Euca-Login -hostname $hostname -password $password | out-null ; Test-Euca-Hostname -hostname $iname}\"";
fi
echo $cmdline
i=0
output=""
while [ $i -lt $NUM_TRIAL ]; do
	((i++))
	ssh -o StrictHostKeyChecking=no -i ./id_rsa.proxy Administrator@$proxy $cmdline > hostname.out 2>&1 &

	while true; do
		sleep 1	
		jobs > status 2>&1
		if cat status | grep "Running" > /dev/null; then continue; else break; fi
	done
	output=$(cat hostname.out);
    	if echo $output | grep "SUCCESS" > /dev/null; then
        	break;
    	fi
    	sleep 10;
done
echo $output
