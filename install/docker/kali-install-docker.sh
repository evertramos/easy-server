#!/bin/bash

#---------------------------------------------------------------------------------
# Installing Docker on Kali Linux
#---------------------------------------------------------------------------------

# Add Docker's official GPG key:
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
# Note: Kali is based on Debian, so we use Debian's repository
# Using bookworm (Debian 12) which is the current stable base for Kali
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: bookworm
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl status docker

sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Create docker group if it doesn't exist
sudo groupadd docker 2>/dev/null || true

# Add current user to docker group
sudo usermod -aG docker $USER

#---------------------------------------------------------------------------------
# Install Docker Compose bash completion
#---------------------------------------------------------------------------------

# Dependencies
sudo apt install -y bash-completion

# Add bash-completion to .bashrc if not already present
if ! grep -q "/etc/bash_completion" ~/.bashrc; then
    cat <<EOT >> ~/.bashrc
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi
EOT
fi

#---------------------------------------------------------------------------------
# Check versions
#---------------------------------------------------------------------------------
echo ""
echo "==> Docker installation completed!"
echo ""
docker version
docker compose version

echo ""
echo "==> IMPORTANT: You need to log out and log back in for group changes to take effect!"
echo "==> Or run: newgrp docker"
echo ""

exit 0
