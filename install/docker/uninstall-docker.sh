#!/usr/bin/env bash

# Uninstall docker compose
sudo rm /usr/local/bin/docker-compose

# Uninstall docker
sudo apt-get purge docker-ce

# Remove all docker files
sudo rm -rf /var/lib/docker

exit 0
