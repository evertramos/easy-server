#!/usr/bin/env bash

#---------------------------------------------------------------------------------
#
# Install Docker Compose
#
#---------------------------------------------------------------------------------

COMPOSE_VERSION=1.28.4

# Download the latest release of docker
sudo curl -L https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose

# Apply permissions
sudo chmod +x /usr/local/bin/docker-compose

# Install command completion
sudo curl -L https://raw.githubusercontent.com/docker/compose/$COMPOSE_VERSION/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose

# Check version
docker-compose --version

exit 0

