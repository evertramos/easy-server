# shellcheck shell=sh

# Expand $PATH to include the directory where golang applications go.
go_bin_path="/usr/local/go/bin"
if [ -n "${PATH##*${go_bin_path}}" -a -n "${PATH##*${go_bin_path}:*}" ]; then
    export PATH=$PATH:${go_bin_path}
fi
