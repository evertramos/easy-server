#!/bin/bash

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow ssh
#sudo ufw allow ssh

# Allow ssh on specific port
sudo ufw allow 2222

# Allow access from specific IP address
#sudo ufw allow from 192.168.0.1
#sudo ufw allow from 192.168.0.1 to any port 22
#sudo ufw allow from 192.168.0.1/24
#sudo ufw allow from 192.168.0.1/24 to any port 22

# Specify network interface
#sudo ufw allow in on eth0 to any port 80
#sudo ufw allow in on eth1 to any port 3306

# Deny incomming connections
#sudo ufw deny http
#sudo ufw deny from 192.168.0.1

# Deny outgoing connections
#sudo ufw deny out 25

# Show added
sudo ufw show added

# Enable ufw
sudo ufw enable

# UFW status
sudo ufw status verbose

# List rules
#sudo ufw status numbered

# To delete a rule
#sudo ufw delete 12
#sudo ufw delete allow http
#sudo ufw delete allow 80

# Disable UFW
#sudo ufw disable

# Reset UFW
#sudo ufw reset


exit 0

