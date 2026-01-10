#!/bin/bash

#
# This script sets up shared directories with appropriate permissions
#

source .env

# Load local variables
LOCAL_SHARED_GROUP=${SHARED_GROUP:-users}
LOCAL_USER=${NEW_USER}
LOCAL_SHARED_PATH=${SERVICE_PATH:-/opt/services}

groupadd $LOCAL_SHARED_GROUP
usermod -aG $LOCAL_SHARED_GROUP $LOCAL_USER

mkdir -p $LOCAL_SHARED_PATH
chown -R root:$LOCAL_SHARED_GROUP $LOCAL_SHARED_PATH
chmod 2775 $LOCAL_SHARED_PATH

setfacl -R -m g:$LOCAL_SHARED_GROUP:rwx $LOCAL_SHARED_PATH
setfacl -d -m g:$LOCAL_SHARED_GROUP:rwx $LOCAL_SHARED_PATH

getfacl $LOCAL_SHARED_PATH
ls -ld $LOCAL_SHARED_PATH


exit 0
