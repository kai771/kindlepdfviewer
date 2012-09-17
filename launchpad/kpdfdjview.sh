#!/bin/sh
export LC_ALL="en_US.UTF-8"

echo unlock > /proc/keypad
echo unlock > /proc/fiveway

# we're always starting from our working directory
cd /mnt/us/kpdfdjview/

# check if we are supposed to shut down the Amazon framework
if test "$1" == "--framework_stop"; then
	shift 1
	/etc/init.d/framework stop
fi

# stop cvm
killall -stop cvm

# finally call reader
./reader.lua "$1" > /mnt/us/kpdfdjview/crash.log 2>&1 || cat /mnt/us/kpdfdjview/crash.log

# always try to continue cvm
killall -cont cvm || /etc/init.d/framework start

# cleanup hanging process
killall lipc-wait-event
