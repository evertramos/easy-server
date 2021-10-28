#!/bin/bash

#SWAP_SIZE=1G
SWAP_SIZE=4G

# Test swap only create if there is no swap... or confirm with the user
sudo swapon --show

# Allocate file with specified size
sudo fallocate -l $SWAP_SIZE /swapfile

# Fix swap permissions
sudo chmod 600 /swapfile

# Create swap particion
sudo mkswap /swapfile

# Create the swap
sudo swapon /swapfile

# Save the swap at fstab to load when server restarts
sudo echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

# Show the swap and memory
sudo swapon --show
sudo free -h

# Update swappiness [?]
# cat /proc/sys/vm/swappiness
# sudo sysctl vm.swappiness=10
# cat /proc/sys/vm/swappiness

# In order to make persistent we need to update on /etc/sysctl.conf file
# option vm.swappiness=10

exit 0
