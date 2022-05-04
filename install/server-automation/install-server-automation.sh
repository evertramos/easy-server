#!/bin/bash

SERVER_AUTOMATION_BASE_FOLDER="/home/$USER/server/server-automation"

# Create server-automation base path if it does not exists
[[ ! -d "$SERVER_AUTOMATION_BASE_FOLDER" ]] && mkdir -p $SERVER_AUTOMATION_BASE_FOLDER && echo "The server-automation base path '$SERVER_AUTOMATION_BASE_FOLDER' was created sucessfuly!"

# Clone server-automation latest version
cd $SERVER_AUTOMATION_BASE_FOLDER
git clone --recurse-submodules https://github.com/evertramos/server-automation.git .

# @todo - automate the server-automation initial setup
if [ -f "${SERVER_AUTOMATION_BASE_FOLDER}/README.md" ]; then
  echo
  echo "Success! Please create the .env file from the sample at ${SERVER_AUTOMATION_BASE_FOLDER}, and update at lease the BASE_SERVER_PATH variable."
  echo 
else
  echo 
  echo "It seems something went wrong... please try to clone server-automation manually, please access:" 
  echo "https://github.com/evertramos/server-automation"
  echo
fi

exit 0

