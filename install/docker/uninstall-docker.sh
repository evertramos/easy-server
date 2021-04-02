#!/bin/bash

# Uninstall docker compose
sudo rm /usr/local/bin/docker-compose

# Uninstall docker
sudo apt-get purge docker-ce docker-ce-cli containerd.io

# Remove all docker files
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

exit 0

