#!/bin/bash

# rdp.sh 
hostname=$(cat hostname)
password=$(cat password)

if [ -z "$hostname" ]; then
	echo "hostname is missing"; exit 1
fi
if [ -z "$password" ]; then
	echo "password is missing"; exit 1
fi

proxy=$(cat proxy)
if [ -z proxy ]; then
        echo "Proxy file is missing"
        exit 1
fi

cmdline="powershell -command \"&{New-Euca-QA -hostname $hostname | out-null; Test-Euca-Login -hostname $hostname -password $password | out-null; Get-Euca-Log}\""
echo $cmdline
ssh -o StrictHostKeyChecking=no -i ./id_rsa.proxy Administrator@$proxy $cmdline > eucalog.out 2>&1 &

while true; do
	sleep 1	
	jobs > status 2>&1
	if cat status | grep "Running" > /dev/null; then continue; else break; fi
done
cat eucalog.out
