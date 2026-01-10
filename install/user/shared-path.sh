#!/bin/bash

#
# This script sets up shared directories with appropriate permissions
#

source .env

# Load local variables
LOCAL_SHARED_GROUP=${SHARED_GROUP:-users}
LOCAL_USER=${NEW_USER}
LOCAL_SHARED_PATH=${SERVICE_PATH:-/opt/services}

sudo groupadd $LOCAL_SHARED_GROUP
sudo usermod -aG $LOCAL_SHARED_GROUP $LOCAL_USER

sudo mkdir -p $LOCAL_SHARED_PATH
sudo chown -R root:$LOCAL_SHARED_GROUP $LOCAL_SHARED_PATH
sudo chmod 2775 $LOCAL_SHARED_PATH

sudo apt install -y acl
sudo setfacl -R -m g:$LOCAL_SHARED_GROUP:rwx $LOCAL_SHARED_PATH
sudo setfacl -d -m g:$LOCAL_SHARED_GROUP:rwx $LOCAL_SHARED_PATH

getfacl $LOCAL_SHARED_PATH
ls -ld $LOCAL_SHARED_PATH


exit 0
