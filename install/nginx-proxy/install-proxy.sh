#!/bin/bash

NGINX_PROXY_EMAIL_ADDRESS=your.email@example.com
NGINX_PROXY_BASE_PATH=~/server/proxy/
NGINX_PROXY_AUTOMATION_PATH=compose
NGINX_PROXY_DATA_FILES=data

# Create nginx-proxy base path if it does not exists
[[ ! -d "$NGINX_PROXY_BASE_PATH" ]] && mkdir -p $NGINX_PROXY_BASE_PATH && echo "The nginx-proxy base path '$NGINX_PROXY_BASE_PATH' was created sucessfuly!"

# Clone nginx-proxy latest version
cd $NGINX_PROXY_BASE_PATH
git clone --recurse-submodules https://github.com/evertramos/nginx-proxy-automation.git $NGINX_PROXY_AUTOMATION_PATH
cd $NGINX_PROXY_AUTOMATION_PATH

# Get current IP Address
NET_INTERFACES=( eth0 ens3 )
for i in "${NET_INTERFACES[@]}"; do
  NET_IP=$(ip address show $i | grep "inet\b" | head -n 1 | awk '{print $2}' | cut -d/ -f1)
  if [[ $NET_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    break
  fi
done

# If we were able to identify the IP Address we will update the .env file
if [[ ! $NET_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "We could not identify your IP Address, please update the .env and restart the nginx-proxy!"
fi

# Create the nginx-proxy data path
NGINX_NGINX_PROXY_DATA_PATH=${NGINX_PROXY_BASE_PATH%/}/${NGINX_PROXY_DATA_FILES%/}
[[ ! -d "$NGINX_NGINX_PROXY_DATA_PATH" ]] && mkdir -p $NGINX_NGINX_PROXY_DATA_PATH && echo "The nginx-proxy data path '$NGINX_NGINX_PROXY_DATA_PATH' was created sucessfuly!"

# Start nginx-proxy with basic configuration
cd ${NGINX_PROXY_BASE_PATH%/}/${NGINX_PROXY_AUTOMATION_PATH%/}/bin
./fresh-start.sh --data-files-location=$NGINX_NGINX_PROXY_DATA_PATH --default-email=$NGINX_PROXY_EMAIL_ADDRESS --ip-address=$NET_IP --skip-docker-image-check --use-nginx-conf-files --update-nginx-template --yes --silent

exit 0
