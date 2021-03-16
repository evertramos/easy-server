#!/usr/bin/env bash

echo "This script must be updated to the latest version of nginx-proxy-automation"

exit 0 

# Create a User Home root folder for webproxy
mkdir ~/proxy
cd ~/proxy

# Clone repo
git clone https://github.com/evertramos/docker-compose-letsencrypt-nginx-proxy-companion.git nginx-proxy

# Enter the cloned folder
cd nginx-proxy

# Copy .env.sample to .env
cp .env.sample .env

# Busca o IP da máquina
NET_IP=$(ip addr show ens3 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
#NET_IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

# Substitute IP address in env file
sed -i -e "s/0.0.0.0/$NET_IP/g" ~/proxy/nginx-proxy/.env

# return to webproxy folder
cd ..

# Create path for Webproxy files
mkdir nginx-data
cd nginx-data

# Get path
NGINX_DATA_PATH=$(pwd)

# Substitue nginx files in .env
sed -i -e "s%/path/to/your/nginx/data%$NGINX_DATA_PATH%g" ~/proxy/nginx-proxy/.env

# Start nginx-proxy
cd ../nginx-proxy
#./start.sh


exit 0
