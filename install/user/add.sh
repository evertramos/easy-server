#!/bin/bash

source .env

# Create the User
sudo useradd -c "$USER_FULL_NAME" -U -G $USER_GROUPS -m -s /bin/bash $NEW_USER

# Add New User to Sudoers
sudo -d 'echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/90-cloud-init-users'

# Set Password for the new User
echo
echo "Set a new password the user $NEW_USER"
echo
sudo passwd $NEW_USER

