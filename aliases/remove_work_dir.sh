#!/bin/bash

# Remove "workdir" from bash aliases file
sed -i '/WORKDIR/d' ./.bash_aliases

exit 0
