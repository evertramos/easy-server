#!/bin/bash

# Load local vatiables
SCRIPT_PATH="$(dirname "$(readlink -f "$0")" )"
LOCAL_DATA="$(date '+%Y-%m-%d_%H-%M-%S')"

# Get Current server Environmet Settings
if [ -e "$SCRIPT_PATH""/.env" ]; then
    source "$SCRIPT_PATH""/.env"

    if [ ! -z ${WORK_DIRECTORY+X} ]; then

       # Go to WorkDirectory
        /bin/bash remove_work_dir.sh
        echo "Adding workdir alias!"
        echo "alias gg='cd "$WORK_DIRECTORY"'" >> "$SCRIPT_PATH""/.bash_aliases" " # WORKDIR"
    fi    
fi


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
        if [ -e "$HOME""/""$1"".""$LOCAL_DATA" ]; then
            rm "$HOME""/""$1"".""$LOCAL_DATA"
        fi
        mv $HOME/$1 $HOME/$1.$LOCAL_DATA
    fi

    # Create symlink for new bash aliases
    ln -s $SCRIPT_PATH/$1 $HOME/$1
    echo "Symlink for $1 created"
}

#
# Function to add .bash_aliases if does not exist
#
add_if_not_exist() {
    local ALIAS_BLOCK="if [ -f ~/.bash_aliases ]; then\n  source ~/.bash_aliases\nfi"

    # Check if file exist
    if [ ! -f "$HOME""/""$1" ]; then
        echo "File $1 does not exist. Creating an empty file..."
        touch "$HOME/$1"
    fi

    # Check if .bash_aliases is already set in rc file
    if grep -qE 'source\s+\~?/?\.?bash_aliases|\. .*\.bash_aliases' "$HOME/$1"; then
        echo ".bash_aliases is already being loaded in $1."
    else
        echo -e "\n# Include .bash_aliases if it exists\n$ALIAS_BLOCK" >> "$HOME""/""$1"
        echo "source .bash_aliases added in $1..."
    fi
}

# Load aliases
loadsymlink ".bash_aliases"
add_if_not_exist ".bashrc"
add_if_not_exist ".zshrc"

echo "Remember to reload your current bash"

# Load vimrc
loadsymlink ".vimrc"


exit 0

