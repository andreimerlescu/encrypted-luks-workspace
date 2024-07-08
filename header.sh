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

# Define color and style codes
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
WHITE=$(tput setaf 7)
BLACK=$(tput setaf 0)

WHITE_BG=$(tput setab 7)
YELLOW_BG=$(tput setab 3)
RED_BG=$(tput setab 1)
GREEN_BG=$(tput setab 2)

SELF="$(basename $0)"
APP="${SELF/.sh/}"

# Command Line Argument Registration
params[log]="./logs/${APP,,}.$(date +"%Y-%m-%d").log"
documentation[log]="Path to log file"

params[size]="650"
documentation[size]="Size of the workspace. Valid options include: cd (650 MB), dvd (4500 MB), dvddl (8500 MB), bd (24000 MB), bddl (48000 MB) or any #[M|G|T]B."

params[name]="$(whoami)_workspace_$(date +"%Y-%m")"
documentation[name]="Name of the workspace to manage."

params[action]="list"
documentation[action]="Perform an action on the workspace name. Valid options include: list, new, rotate, unschedule, mount, unmount, passwd, remove, archive, replace, change"

params[password]=""
documentation[password]="Password to encrypt/decrypt the luks workspace"

params[parent]="${HOME}/.elwork"
documentation[parent]="Path to store workspaces and index of elwork."

params[encrypt]=false
documentation[encrypt]="Flag to enable luks encryption"

params[sudo]=false
documentation[sudo]="Flag to enable sudo before running commands"

params[type]="xfs"
documentation[type]="Type of filesystem to use. Valid options include: xfs, ext4"

params[date]=""
documentation[date]="YYYY-mm (2024-07, 2025-12, 2033-3) that isolates a workspace by created on"

params[trace]=false
documentation[trace]="Flag to enable stack traces in console output"

params[duplicates]=false
documentation[duplicates]="Flag to ignore duplicate workspace check"
