#!/bin/bash
clc=$(cat ../input/2b_tested.lst | grep 'CLC');
if [ -z "$clc" ]; then
    echo "Can't find CLC line in the machine list"
    exit 1
fi
unset IFS
set -- $clc 
ipaddr=$(echo "$1")
if [ -z "$ipaddr" ]; then
    echo "CLC's ipaddress is not found"
    exit 1
fi
echo "CLC's ip address: $ipaddr"

#copy dblookup.sh into "/root/euca_builder/eee/devel"
if ! scp ./dbLookup.sh root@$ipaddr:/root/euca_builder/eee/devel/; then
    echo "Couldn't copy dbLookup.sh to the CLC host";
    exit 1;
fi

#invoke series of SQL command lines

if ssh root@$ipaddr "export EUCALYPTUS=/opt/eucalyptus; cd /root/euca_builder/eee/devel; ./dbLookup.sh \"update cloud_vm_types set metadata_vm_type_cpu=1 where metadata_vm_type_name='m1.large'\" eucalyptus_cloud ; ./dbLookup.sh \"update cloud_vm_types set metadata_vm_type_cpu=1, metadata_vm_type_memory=1024, metadata_vm_type_disk=20 where metadata_vm_type_name='m1.xlarge'\" eucalyptus_cloud" | grep "ERROR"; then
	echo "database update failed";
	exit 1;
fi

echo "database updated"

exit 0;


