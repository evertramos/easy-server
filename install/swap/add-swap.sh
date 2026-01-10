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

# Update swappiness for better performance
sudo sysctl vm.swappiness=10

# Make it persistent
echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl --system

exit 0
