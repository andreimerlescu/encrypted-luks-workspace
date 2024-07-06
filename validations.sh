#!/bin/bash

[[ -z "${INSIDE_ELWORK}" ]] && { echo "FATAL ERROR: This function cannot be executed on its own."; exit 1; }


function validate_action_list(){

}

function validate_action_new(){
    param_required "name"
    param_required "parent"
    param_required "size"
    param_required "type"
    flag_required "sudo"
    require_param_if_flag_true "password" "encrypt"
    log "validate_action_new() passed all validations!"
}

function validate_action_rotate(){

}

function validate_action_unschedule(){

}

function validate_action_mount(){

}

function validate_action_unmount(){

}

function validate_action_passwd(){

}

function validate_action_remove(){

}

function validate_action_archive(){

}

function validate_action_replace(){

}

function validate_action_change(){

}

# Function to ensure directory is writable
# is_writable_dir "$(mktemp -d)" # returns:""
function is_writable_dir() {
    local dir=$1
    [[ ! -w "$(dirname "$dir")" ]] && fatal "Directory is not writable: $dir"
}

# Function to ensure that --parent is a writable directory that exists
# ensure_parent_exists # returns:""
function ensure_parent_exists(){
    param_required "parent"
    local p="${params[parent]}"
    is_writable_dir "${p}" || $SUDO mkdir -p "${p}" || fatal "--parent must be writable: ${p}"
}

# Function to ensure that provided param is not empty
# param_required "parent" # returns:""
function param_required(){
    local p=$1
    [[ "${p}" == "password" ]] && [[ -z "${params[$p]}" ]] && params[$p]=$(retrieve_password)
    [[ -z "${p}" ]] && fatal "--${p} required"
}

# Function to ensure provided param is a boolean flag
# flag_required "sudo" # returns:""
function flag_required(){
    local f=$1
    [[ "${f}" == false ]] && fatal "--${f} must be true"
}

# Function to require a provided param given the true set flag
# require_param_if_flag_true "${params[password]}" "${params[encrypt]}"
function require_param_if_flag_true() {
    local p=$1
    local f=$2
    [[ "${f}" == "encrypt" ]] && [[ -z "${params[$p]}" ]] && params[password]=$(retrieve_password)
    { [[ "${f}" == true ]] && param_required $p; } || true
}
