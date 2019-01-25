#!/bin/bash

echo "You must be root to run this command"

source .env

# Create the User
useradd -c "$USER_FULL_NAME" -U -G $GROUPS -m -s /bin/bash $NEW_USER

# Add New User to Sudoers
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/90-cloud-init-users


# Set Password for the new User
echo
echo "Set a new password the user $NEW_USER"
echo
passwd $NEW_USER

