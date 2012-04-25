#!/bin/bash
source ../lib/winqa_util.sh

eucaroot=$(whereis_eucalyptus)
if [ -z "$1" ]; then
        echo "usage: update_eucaconf.sh [-h clc hostname] [-p property] [-v value]"
        exit 1
fi


while [ -n "$(echo $1 | grep '-')" ]; do
        case $1 in
            -p ) property=$2; shift;;
            -v ) value=$2; shift;;
	    -h ) hostname=$2; shift;;
        esac
        shift
done
if [ -z "$hostname" ]; then
        echo "clc hostname is missing"; exit 1
fi
if [ -z "$property" ]; then
        echo "property is missing"; exit 1
fi
if [ -z "$value" ]; then
        echo "value is missing"; exit 1
fi

echo "Updating $property=$value"
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa root@$hostname "cat $eucaroot/etc/eucalyptus/eucalyptus.conf" > ./eucalyptus.conf

if [ ! -s ./eucalyptus.conf ]; then
	echo "eucalyptus.conf file is not found"
	exit 1;
fi
if [ -s ./eucalyptus.conf.new ]; then
	rm -f ./eucalyptus.conf.new;
fi
updated=0
function replaceLine {
	#line=$(tty)
	while read tmp; do	
		if echo $tmp | grep $property > /dev/null; then 
			if echo $tmp | grep '#' > /dev/null; then
				echo $tmp >> ./eucalyptus.conf.new;
			else
				#echo "UPDATED ($property=$value)"
				echo "$property=\"$value\"" >> ./eucalyptus.conf.new;
				updated=1
			fi			
		else
			echo $tmp >> ./eucalyptus.conf.new	
		fi		
	done
}

replaceLine < ./eucalyptus.conf
if [ $updated -eq 1 ]; then
	cat ./eucalyptus.conf.new | ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa root@$hostname "cat > $eucaroot/etc/eucalyptus/eucalyptus.conf"
fi
exit 0
