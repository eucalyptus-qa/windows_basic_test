#!/bin/bash

echo "$1;" | mysql -u eucalyptus -P 8777 --protocol=TCP --password=`./dbPass.sh` $2

