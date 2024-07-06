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

    info "Creating the directory required for elwork to live..."
    create_workspaces_storage_directory || fatal "Failed to create workspaces directory."
    success "Created $(workspaces_storage_path)!"

    case "${params[action]}" in
        unmount|umount) action_unmount ;;
        rm|remove|uninstall) action_remove ;; 
        archive) action_archive ;;
        replace) action_replace ;; 
        change) action_change ;;
        list) action_list ;;
        new|create) action_new ;;
        rotate|schedule) action_rotate ;;
        unschedule) action_unschedule ;;
        mount) action_mount ;; 
        pass|passwd|password) action_passwd ;;
        *) fatal "unsupported action chosen $1" ;;
    esac

}

main "$@"