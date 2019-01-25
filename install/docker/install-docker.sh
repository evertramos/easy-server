#!/usr/bin/env bash

# Uninstall old versions
sudo apt-get remove docker docker-engine docker.io

# Update the Ubuntu Repo
sudo apt-get update

# Install packages to allow apt to use a repository over HTTPS
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add Docker repository for Ubuntu
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# Update the Ubuntu Repo (again)
sudo apt-get update

# Install Docker
sudo apt-get install -y docker-ce

# Create a docker group
sudo groupadd docker

# Add current user to group
sudo usermod -aG docker $USER


#---------------------------------------------------------------------------------
#
# Install Docker Compose
#
#---------------------------------------------------------------------------------

# Download the latest release of docker
sudo curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose

# Apply permissions
sudo chmod +x /usr/local/bin/docker-compose

# Install command completion
sudo curl -L https://raw.githubusercontent.com/docker/compose/1.21.2/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose

# Check version
docker-compose --version

exit 0
