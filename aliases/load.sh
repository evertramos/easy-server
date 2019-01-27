#!/bin/bash

# Get Current server Environmet Settings
SCRIPT_PATH="$(dirname "$(readlink -f "$0")" )"

if [ -e "$SCRIPT_PATH""/.env" ]; then
    source "$SCRIPT_PATH""/.env"

    if [ ! -z ${WORK_DIRECTORY+X} ]; then

       # Go to WorkDirectory
        /bin/bash remove_work_dir.sh
        echo "Adding workdir alias!"
        echo "alias gg='cd "$WORK_DIRECTORY"'" >> "$SCRIPT_PATH""/.bash_aliases" " # WORKDIR"
    fi    
fi

DATA="$(date '+%Y-%m-%d_%H-%M-%S')"

#
# Function to Load the SymLink
#
loadsymlink() {

    # Check if symlink exists and remove it
    if [ -L "$HOME""/""$1" ]; then
        rm "$HOME""/""$1"
    fi

    # Check file exists and rename it
    if [ -e "$HOME""/""$1" ]; then
        if [ -e "$HOME""/""$1"".""$DATA" ]; then
            rm "$HOME""/""$1"".""$DATA"
        fi
        mv $HOME/$1 $HOME/$1.$DATA
    fi

    # Create symlink for new bash aliases
    ln -s $SCRIPT_PATH/$1 $HOME/$1
}

# Load aliases
loadsymlink ".bash_aliases"

echo "Remember to reload your current bash"

# Load vimrc
loadsymlink ".vimrc"



exit 0
