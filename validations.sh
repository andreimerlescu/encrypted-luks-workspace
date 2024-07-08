#!/bin/bash

[[ -z "${INSIDE_ELWORK}" ]] && { echo "FATAL ERROR: This function cannot be executed on its own."; exit 1; }

function validate_action_list(){
    echo
}

function validate_action_new(){
    if [[ "${params[sudo]}" != true ]] && [ `id -u` -ne 0 ]; then
        fatal "Root permission required to modify or create workspaces. Please add --sudo"
    fi
    param_required "name" || fatal "--name required"
    param_required "parent" || fatal "--parent required"
    param_required "size" || fatal "--size required"
    param_required "type" || fatal "--type required"
    flag_required "sudo" || fatal "--sudo required"
    require_param_if_flag_true "password" "encrypt" || fatal "--password required for --encrypt"
    log "validate_action_new() passed all validations!"
}

function validate_action_rotate(){
    echo

}

function validate_action_unschedule(){
    echo

}

function validate_action_mount(){
    echo

}

function validate_action_unmount(){
    echo

}

function validate_action_passwd(){
    echo

}

function validate_action_remove(){
    if [[ "${params[sudo]}" != true ]] && [ `id -u` -ne 0 ]; then
        fatal "Root permission required to modify or create workspaces. Please add --sudo"
    fi
    param_required "name" || fatal "--name required"
    log "validate_action_remove() passed all validations!"
}

function validate_action_archive(){
    echo

}

function validate_action_replace(){
    echo

}

function validate_action_change(){
    echo

}

# Function to ensure directory is writable
# is_writable_dir "$(mktemp -d)" # returns:""
function is_writable_dir() {
    local dir=$1
    { [[ ! -w "$(dirname "$dir")" ]] && fatal "Directory is not writable: $dir"; } || true
}

# Function to ensure that provided param is not empty
# param_required "parent" # returns:""
function param_required(){
    local p=$1
    [[ "${p}" == "password" ]] && [[ ${#params[$p]} -le 3 ]] && retrieve_password
    { [[ -z "${p}" ]] && fatal "--${p} required"; } || true
}

# Function to ensure provided param is a boolean flag
# flag_required "sudo" # returns:""
function flag_required(){
    local f=$1
    { [[ "${f}" == false ]] && fatal "--${f} must be true"; } || true
}

# Function to require a provided param given the true set flag
# require_param_if_flag_true "password" "encrypt"
function require_param_if_flag_true() {
    local p=$1
    local f=$2
    [[ "${f}" == "encrypt" ]] && encrypted && [[ ${#params[$p]} -le 3 ]] && retrieve_password
    { [[ "${params[$f]}" == true ]] && param_required $p; } || true
}
