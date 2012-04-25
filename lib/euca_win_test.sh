#!/bin/bash
#
# global variables
# emi, keyfile, keyname, ipaddr, passwd, hypervisor, zone, winqa
#
function printVerbose {
        echo "euca_win_test.sh [-emi emi_name] [-key key_file] [-kvm] [-xen] [-vmware]";
        return 1
}

function testLogin
{
        if [ -z $ipaddr ] || [ -z $keyfile ]; then
                echo "address or keyfile is null"
                return 1
        fi
	cmd="euca-get-password -k $keyfile $instance"
	echo $cmd
        passwd=$($cmd)
	if [ -z "$passwd" ]; then
		echo "password is null"
		return 1
	fi
	echo "Password: $passwd"

	ret=$(./login.sh -h $ipaddr -p $passwd)
	
	if [ -n "$(echo $ret | tail -n 1 | grep 'SUCCESS')" ]; then
		return 0
	else
		echo "$ret"
		return 1
	fi
}

function testEBS {
	# create volume or find an available volume
	ret=$(euca-describe-volumes | grep 'available')
	if [ -n "$ret" ]; then
		set -- $ret
		volume=$2
	else
		ret=$(euca-create-volume -s 2 -z "$zone")
		if !(echo $ret | grep "vol" > /dev/null;) then
			echo "volume was not created"; return 1
		fi	
		volume=$(echo "$ret")
	fi
		
	if [ -z "$volume" ] || [ -z "$(echo $volume | grep 'vol-')" ]; then
		echo "No available volue" return 1
	fi
 	# attach the volume to the instance
	dev="NULL"	
	if [ $hypervisor = "kvm" ]; then
		dev="/dev/vdb"
	elif [ $hypervisor = "xen" ]; then
		dev="/dev/sdb"
	elif [ $hypervisor = "vmware" ]; then
		dev="/dev/sdb"
	else
		echo "Unknown hypervisor"; return 1
	fi
	ret=$(euca-attach-volume -i $instance -d $dev $volume)

	timeout=10	
	i=0
	attached=1
	while !(euca-describe-volumes $volume | grep "in-use" > /dev/null); do
		sleep 1
		((i++))		
		if [ $i -gt $timeout ]; then
			attached=0
			break;
		fi
	done
	if [ $attached -eq 0 ]; then
		echo "Couldn't attach the volume"; return 1
	fi
	# call ebs.sh
	sleep 30; # wait enough time to Windows to see the attached device	
	ret=$(./ebs.sh)
	
	if [ -z "$(echo $ret | tail -n 1 | grep 'SUCCESS')" ]; then
		echo "EBS test failed";
	else	
		echo "EBS test passed";
	fi
	
	# detach the volume from the instance
	ret=$(euca-detach-volume $volume)
	detached=1
	i=0
        while !(euca-describe-volumes $volume | grep "available" > /dev/null); do
                sleep 1
                ((i++))
                if [ $i -gt $timeout ]; then
                        detached=0
                        break;
                fi
        done
	
	if [ $detached -eq 0 ]; then
		echo "Couldn't detach the volume"; return 1
	fi

        # remove volume
	ret=$(euca-delete-volume $volume)
	deleted=1
	i=0
  	while !(euca-describe-volumes $volume | grep "deleted" > /dev/null); do
                sleep 1
                ((i++))
                if [ $i -gt $timeout ]; then
                        deleted=0
                        break;
                fi
        done	
	if [ $deleted -eq 0 ]; then
		echo "Couldn' delete the volume"; return 1
	fi
		
	return 0
}

function createGroup {
	if euca-describe-groups | grep 'winqa' > /dev/null; then return 0; fi	
	
	ret=$(euca-add-group -d "windows testing" winqa)
	if [ -z "$(echo $ret | grep 'winqa')" ]; then
		echo "securty group was  not created"
		return 1
	fi
	sleep 3	
	ret=$(euca-authorize -P tcp -p 1-65535 -s 0.0.0.0/0 winqa)
	if [ -z "$(echo $ret | grep 'PERMISSION')" ]; then
		echo "could not authorize to the group"
		return 1
	fi
   
	ret=$(euca-authorize -P icmp -p 1-65535 -s 0.0.0.0/0 winqa)
	if [ -z "$(echo $ret | grep 'PERMISSION')" ]; then
                echo "could not authorize to the group"
                return 1
        fi
	
	
        ret=$(euca-authorize -P udp -p 1-65535 -s 0.0.0.0/0 winqa)
        if [ -z "$(echo $ret | grep 'PERMISSION')" ]; then
                echo "could not authorize to the group"
                return 1
        fi
	
	return 0
}

function deleteGroup {
	ret=$(euca-delete-group winqa)
	if [ -z "$(echo $ret | grep 'winqa')" ]; then
		echo "security group was not deleted"
		return 1
	fi
	return 0
}
             
while [ -n "$(echo $1 | grep '-')" ]; do
        case $1 in
            -emi ) emi=$2; shift;;
	    -key ) keyfile=$2; shift;;
	    -kvm ) hypervisor="kvm"; shift;;
	    -xen ) hypervisor="xen"; shift;;
            -vmware ) hypervisor="vmware"; shift;;
        esac
        shift
done

if [ -z "$emi" ] || [ -z "$keyfile" ] || [ -z "$hypervisor" ] ; then
	printVerbose
	exit 1
fi

if [ $hypervisor = "kvm"  ] || [ $hypervisor = "xen" ] || [ $hypervisor = "vmware" ] ; then
	echo "Hypervisor: $hypervisor"
else
	echo "Unknown hypervisor: $hypervisor"; exit 1
fi

tmp=$(head -n 1 "$keyfile")
set -- $tmp
keyname=$2

if [ -z $keyname ]; then
	echo "Cannot find a keyname in the keyfile $keyfile"
	exit 1
fi
echo "Keyname: $keyname"


if !(echo $(euca-describe-images $emi) | grep "$emi" > /dev/null;) then echo "Image not found"; exit 1; fi


# create a security group with name = winqa
if !(createGroup;) then echo "Couldn't create a security group"; exit 1; fi

output=$(euca-run-instances -k $keyname -g winqa -t m1.xlarge $emi)
#output=$(euca-describe-instances)
if !(echo $output | grep INSTANCE > /dev/null;); then
	echo "Instance not created"
	exit 1
fi 

tmp=$(echo -e ${output//*INSTANCE/})
set -- $tmp
instance=$1
echo "Instance $instance created"

while echo $(euca-describe-instances $instance) | grep "pending" > /dev/null; do
	sleep 5
	echo "instance pending"	
done

state=$(euca-describe-instances "$instance")
if !(echo $state | grep running > /dev/null;); then
	echo "Instance is not running"	
	echo "$state"
	exit 1
fi 

#detect IP address of the instance
tmp=${state#*INSTANCE}
set -- $tmp
ipaddr=$4
zone=${10}

if [ -z "$ipaddr" ]; then
	echo "IP address is null"
	exit 1
fi

if [ -z "$zone" ]; then
	echo "Availability zone is null"
	exit 1
fi

echo "Instance $instance (ip: $ipaddr, zone: $zone)"

# wait sufficient amount of time
sleep 300  # 5 min.

if !(testLogin;) then exit 1; fi
echo "passed login test"

ret=$(./rdp.sh)
if [ -z "$(echo $ret | tail -n 1 | grep 'SUCCESS')" ]; then
	echo "RDP test failed"; exit 1
fi
echo "passed RDP test"

ret=$(./hostname.sh)
if [ -z "$(echo $ret | tail -n 1 | grep 'SUCCESS')" ]; then
	echo "Hostname setting test failed"; exit 1
fi
echo "passed hostname test"

if [ $hypervisor = "kvm" ]; then
	ret=$(./virtio.sh);
elif [ $hypervisor = "xen" ]; then
	ret=$(./xenpv.sh);
elif [ $hypervisor = "vmware" ]; then
	ret="SUCCESS"
else
	echo "Unknown hypervisor"; exit 1
fi

if [ -z "$(echo $ret | tail -n 1 | grep 'SUCCESS')" ]; then
	echo "Paravirtuzliation driver test failed"; exit 1
fi
echo "passed parav driver test"

ret=$(./admembership.sh)
if [ -z "$ret" ]; then
	echo "Instance is not a domain member"
else
	echo "Instance's domain: $ret"
fi

if !(testEBS;) then exit 1; fi

exit 0
