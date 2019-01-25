#!/bin/bash

#SWAP_SIZE=1G
SWAP_SIZE=4G
#SWAP_SIZE=1048576
#SWAP_SIZE=4194304

# Test swap only create if there is no swap... or confirm with the user
sudo swapon --show

# Remove swapfile
#sudo swapoff -v /swapfile
# remove from /etc/fstab as well
#sudo rm /swapfile

sudo fallocate -l $SWAP_SIZE /swapfile
#sudo dd if=/dev/zero of=/swapfile bs=1024 count=$SWAP_SIZE

sudo chmod 600 /swapfile

sudo mkswap /swapfile

sudo swapon /swapfile

sudo echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

sudo swapon --show
sudo free -h


cat /proc/sys/vm/swappiness
#sudo sysctl vm.swappiness=10
#cat /proc/sys/vm/swappiness

# In order to make persistent we need to update on /etc/sysctl.conf file
# option vm.swappiness=10

exit 0
