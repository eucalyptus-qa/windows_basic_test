#!/bin/bash

# rdp.sh 
hostname=$(cat hostname)
if [ -z "$hostname" ]; then
	echo "hostname is missing"; exit 1
fi
echo "hostname: $hostname"
rm -f telnet.3389.out
telnet $hostname 3389 > telnet.3389.out 2>&1 &
sleep 2
pid=$(jobs -p)
kill -9 $pid > /dev/null 2>&1
if cat telnet.3389.out | grep "Escape character is '^]'." > /dev/null; then 
	ret="SUCCESS"
else
	ret="port 3389 not opened"
fi
echo $ret
