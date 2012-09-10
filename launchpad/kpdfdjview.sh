#!/bin/sh
export LC_ALL="en_US.UTF-8"

echo unlock > /proc/keypad
echo unlock > /proc/fiveway

# we're always starting from our working directory
cd /mnt/us/kpdfdjview/

# bind-mount system fonts
if ! grep /mnt/us/kpdfdjview/fonts/host /proc/mounts; then
	mount -o bind /usr/java/lib/fonts /mnt/us/kpdfdjview/fonts/host
fi

# check if we are supposed to shut down the Amazon framework
if test "$1" == "--framework_stop"; then
	shift 1
	/etc/init.d/framework stop
fi

# stop cvm
killall -stop cvm

# finally call reader
./reader.lua "$1" 2> /mnt/us/kpdfdjview/crash.log || cat /mnt/us/kpdfdjview/crash.log

# unmount system fonts
if grep /mnt/us/kpdfdjview/fonts/host /proc/mounts; then
	umount /mnt/us/kpdfdjview/fonts/host
fi

# always try to continue cvm
killall -cont cvm || /etc/init.d/framework start

# cleanup hanging process
killall lipc-wait-event
