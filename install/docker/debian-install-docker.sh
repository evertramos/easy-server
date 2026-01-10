#!/bin/bash

#---------------------------------------------------------------------------------
# Installing Docker
#---------------------------------------------------------------------------------

# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl status docker

sudo systemctl enable docker.service
sudo systemctl enable containerd.service

sudo groupadd docker

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
