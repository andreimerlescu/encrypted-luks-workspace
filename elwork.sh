#!/bin/bash

#set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.

# Early parsing of debug flag
for arg in "$@"; do
  case $arg in
    --debug)
      DEBUG=true
      set -x
      ;;
  esac
done

# Required for any dependency to load
declare INSIDE_ELWORK=true 

# Load dependencies
files=("functions.sh" "header.sh" "validations.sh" "actions.sh")
for file in "${files[@]}"; do
    found_file=$(find . -maxdepth 1 -name "$file" -print -quit)
    { [[ -n "$found_file" ]] && source "$found_file"; } || { echo "$file not found in the current directory."; exit 1; }
done

function main() {
    parse_arguments "$@" || fatal "Failed to parse arguments"

    for p in "${!params[@]}"; do
        debug "${p} = ${params[$p]}"
    done

    create_workspaces_storage_directory || fatal "Failed to create workspaces directory."

    case "${params[action]}" in
        um|unmount|umount) action_unmount ;;
        remove|delete|destroy|purge|obliterate) action_remove ;; 
        ar|archive) action_archive ;;
        re|replace) action_replace ;; 
        ch|change) action_change ;;
        li|list) action_list ;;
        ne|new|cr|create|st|start) action_new ;;
        ro|rotate|schedule) action_rotate ;;
        un|unschedule) action_unschedule ;;
        mo|mount) action_mount ;; 
        pa|pass|passwd|password) action_passwd ;;
        *) fatal "unsupported action chosen $1" ;;
    esac

    info "Correcting permissions on --parent..."
    $SUDO chown -R $(whoami):$(whoami) "${params[parent]}"
    [[ -n "${params[log]}" ]] && [[ -f "${params[log]}" ]] && $SUDO chown -R $(whoami):$(whoami) "${params[log]}"
    success "Script has completed execution!"

}

main "$@"
