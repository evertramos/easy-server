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

COMPOSE_VERSION=$(curl --silent "https://api.github.com/repos/docker/compose/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
AUTO_COMPLETE_COMPOSE_VERSION=1.29.2

# Download the latest release of docker
sudo curl -L https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose

# Apply permissions
sudo chmod +x /usr/local/bin/docker-compose

# Install command completion
sudo curl -L https://raw.githubusercontent.com/docker/compose/$AUTO_COMPLETE_COMPOSE_VERSION/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose

#---------------------------------------------------------------------------------
# Check versions
#---------------------------------------------------------------------------------
docker version
docker-compose version

exit 0
