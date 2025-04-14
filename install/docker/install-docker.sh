#!/bin/bash

#---------------------------------------------------------------------------------
# Installing Docker
#---------------------------------------------------------------------------------

# Create temporary folder (will not be deleted)
mkdir -p ./temp && cd temp

# Get the latest version of get-docker.sh script
curl -fsSL https://get.docker.com -o get-docker.sh

# Run get-docker (as sudo)
sudo sh get-docker.sh

# Add current user to group
sudo usermod -aG docker $USER

#---------------------------------------------------------------------------------
# Install Docker Compose
#---------------------------------------------------------------------------------

# Dependencies 
sudo apt install bash-completion

# Add bash-completion to .bashrc
cat <<EOT >> ~/.bashrc
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi
EOT

#---------------------------------------------------------------------------------
# Check versions
#---------------------------------------------------------------------------------
docker version
docker compose version

exit 0
