#!/bin/bash

[[ -z "${INSIDE_ELWORK}" ]] && { echo "FATAL ERROR: This function cannot be executed on its own."; exit 1; }

# Welcome! It's very good to have you in the source code =D
banner_success "WELCOME TO ELWORK (encrypted luks workspace)!"

# Arrays to store parameter / command line arguments
declare -A params=()
declare -A documentation=()

# Use --sudo to enable sudo to be appended before each command executed
SUDO=""

# Use --debug to set DEBUG="--debug" into various external script executions as well as enable set -x on runtime
DEBUG=""

# Catch errors with debug information
traperr() {
    local i=0
    local funcname=""
    local lineno=""
    local srcfile=""
    
    # Print a header for the error trace
    error "Error trace:"
    
    # Iterate over the stack trace
    while caller $i; do
        funcname="${FUNCNAME[$i]}"
        lineno="${BASH_LINENO[$i]}"
        srcfile="${BASH_SOURCE[$i]}"
        
        # Print the details of each level in the stack trace
        error "  at ${funcname}() in ${srcfile}:${lineno}"
        
        ((i++))
    done
    
    # Print a general error message
    fatal "An error occurred in the script."
}

set -o errtrace
trap traperr ERR

# Command Line Argument Registration
params[log]="./$(basename $0).$(date +"%Y-%m-%d").log"
documentation[log]="Path to log file"

params[size]="650"
documentation[size]="Size of the workspace. Valid options include: cd (650 MB), dvd (4500 MB), dvddl (8500 MB), bd (24000 MB), bddl (48000 MB) or any ### MB or ### GiB or ### TiB."

params[name]="$(whoami)_workspace_$(date +"%Y-%m")"
documentation[name]="Name of the workspace to manage."

params[action]="list"
documentation[action]="Perform an action on the workspace name. Valid options include: list, new|create, rotate|schedule, unschedule, mount, unmount, passwd, remove|uninstall, archive, replace, change"

params[password]="T3stP@ssw0rd!"
documentation[password]="Password to encrypt/decrypt the luks workspace"

params[parent]="${HOME}/.elwork"
documentation[parent]="Path to store workspaces and index of elwork."

params[encrypt]=false
documentation[encrypt]="Flag to enable luks encryption"

params[sudo]=false
documentation[sudo]="Flag to enable sudo before running commands"

params[type]="xfs"
documentation[type]="Type of filesystem to use. Valid options include: xfs, ext4"
