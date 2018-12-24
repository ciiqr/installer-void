#!/usr/bin/env bash

# TODO: add param checks/usage notes
# ie. ./test.sh "$(basename $(realpath ./))" mklive/installer-void-x86_64-2018-12-24.iso

# set -x

# declarations
readonly NAME="$1"
readonly ISO_PATH="$2"

# Create a 32GB “dynamic” disk.
VBoxManage createhd --filename "${NAME}.vdi" --size 32768 >/dev/null 2>&1

# Create vm
VBoxManage createvm --name "$NAME" --ostype 'Ubuntu_64' --register >/dev/null 2>&1

# Add a SATA controller with the dynamic disk attached.
VBoxManage storagectl "$NAME" --name 'SATA Controller' --add sata \
	--controller IntelAHCI 2>/dev/null
VBoxManage storageattach "$NAME" --storagectl 'SATA Controller' --port 0 \
	--device 0 --type hdd --medium "${NAME}.vdi" 2>/dev/null

# Add an IDE controller with a DVD drive attached, and the install ISO inserted into the drive:
VBoxManage storagectl "$NAME" --name 'IDE Controller' --add ide 2>/dev/null
VBoxManage storageattach "$NAME" --storagectl 'IDE Controller' --port 0 \
	--device 0 --type dvddrive --medium "$ISO_PATH" 2>/dev/null

# Misc system settings.
VBoxManage modifyvm "$NAME" --ioapic on
VBoxManage modifyvm "$NAME" --boot1 dvd --boot2 disk --boot3 none --boot4 none
VBoxManage modifyvm "$NAME" --memory 1024 --vram 128
dpi="$(xrdb -query | grep dpi | cut -d':' -f 2)"
VBoxManage setextradata "$NAME" GUI/ScaleFactor "$((dpi / 96))"

echo '==> vm created'

# Configuration is all done, boot it up!
VBoxManage startvm "$NAME" >/dev/null 2>&1

echo '==> vm started'

# Pause
trap ' ' INT
echo 'Press Ctrl-C to continue'
cat

# Shutdown
VBoxManage controlvm "$NAME" poweroff >/dev/null 2>&1

echo '==> vm shutting down'

# Destroy
# TODO: I'd like a way of checking if it's locked... haven't found anything that works yet
until VBoxManage unregistervm "$NAME" --delete >/dev/null 2>&1; do
	sleep 1
done

echo '==> vm destroyed'
