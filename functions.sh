#!/bin/bash

[[ -z "${INSIDE_ELWORK}" ]] && { echo "FATAL ERROR: This function cannot be executed on its own."; exit 1; }

# Function to generate the disk image size in MB
function get_size_in_mb {
    case $1 in
        cd|cdr|cdrw|crdrom) echo 650 ;;
        dvd|dvdr|dvdrw|dvdrom) echo 4500 ;;
        dvddl|dvddlr|dvddlrw|dvddlrom) echo 8500 ;;
        bd|bdr|bdrw|bdrom) echo 24000 ;;
        bddl|bddlr|bddlrw|bddlrom) echo 48000 ;;
        *[M|m]B) echo ${1%[M|m]B} ;;
        *[G|g]B) echo $((${1%[G|g]B} * 1024)) ;;
        *[T|t]B) echo $((${1%[T|t]B} * 1024 * 1024)) ;;
        *) fatal "Invalid --size" ;;
    esac
}

# Function to return MB value of --size
function drive_size(){
    param_required "size"
    echo "$(get_size_in_mb "$1")"
}

# Function to use --parent and return the .disk-workspaces path
function workspace_storage_path(){
    param_required "parent"
    echo "$(realpath "${params[parent]}")/.disk-workspaces"
}

# Function to return the path to the workspace directory
# workspace_directory "${params[name]}"
function workspace_directory(){
    local name=$1
    echo "$(workspace_storage_path)/${name}_$(date +"%Y-%m")"
}

# Function to return the name of the disk image based on --mount
function disk_image_name(){
    param_required "name"
    echo "${params[name]}.img"
}

function encrypted(){
    [[ "${params[encrypt]}" == true ]]
}

function mount_path(){
    # Validations
    param_required "parent"
    param_required "name"
    
    # Arguments
    local p="${params[parent]}"
    local n="${params[name]}"

    # Properties
    [[ -z "${p}" ]] && fatal "--parent is undefined. Got: '${p}'"
    ! is_writable_dir "${p}" && fatal "--parent is not writable"
    [[ -z "${n}" ]] && fatal "--name is undefined. Got: '${n}'"

    # Action
    echo "${params[parent]}/${params[name]}"
}

function password(){
    [[ -z "${params[password]}" ]] && params[$p]=$(retrieve_password)
    echo "${params[password]}"
}

function masked_password(){
    echo "$(mask "$(password)")"
}

# Function to retrieve password
function retrieve_password {
    local p=""
    if command -v pinentry-curses > /dev/null; then
        p=$(echo "GETPIN" | pinentry-curses | awk '/^D /{print $2}')
    else
        read -s -p "Enter password: " p
        echo
    fi
    echo $p
}

function log(){
    local msg=$1
    [[ -z "${msg}" ]] && return
    ! [[ -f "${params[log]}" ]] && echo $msg | $SUDO tee -a "${params[log]}" > /dev/null
}

# Function to parse CLI arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            debug|--debug) 
                DEBUG="--debug"
                set -x
                shift
                continue 
                ;;

            sudo|--sudo)
                SUDO="sudo"
                shift
                continue
                ;;

            --help|-h|help)
                print_usage
                exit 0
                ;;

            --*)
                key="${1/--/}" # Remove '--' prefix
                key="${key//-/_}" # Replace '-' with '_' to match params[key]
                if [[ -n "${2}" && "${2:0:1}" != "-" ]]; then
                    params[$key]="$2"
                    shift 2
                    continue
                else
                    params[$key]=true
                    shift
                    continue
                fi
                ;;

            *)
                echo "Unknown option: $1" >&2
                print_usage
                fatal "Cannot continue while $1 exists..."
                ;;
        esac
    done
}

# Function to print the usage table from params and documentation
function print_usage(){
    echo "Usage: ${0} [OPTIONS]"
    mapfile -t sorted_keys < <(for param in "${!params[@]}"; do echo "$param"; done | sort)
    local -i padSize=3;
    for param in "${sorted_keys[@]}"; do
        local -i len="${#param}"
        (( len > padSize )) && padSize=len
    done
    ((padSize+=3)) # add right buffer
    for param in "${sorted_keys[@]}"; do
        local d
        local p
        p="${params[$param]}"
        if [[ -n "${p}" ]] && [[ "${#p}" != 0 ]]; then
            d=" (default = '${p}')"
        else
            d=""
        fi
        echo "       --$(pad "$padSize" "${param}") ${documentation[$param]}${d}"
    done
}

# Function that adds an element to the history
function add_history() {
  local host=$1
  local h=$2

  if (( ${#h} < 1 )); then
    return
  fi

  if [[ -z "${history["$host"]}" ]]; then
    history["$host"]="$h"
  else
    history["$host"]="${history["$host"]}|$h"
  fi
}

# Function that prints the history array
function print_history() {
  for host in "${!history[@]}"; do
    banner_info "Execution History: $host"
    echo "Execution History: $host" | tee -a "${params[log]}" > /dev/null
    local -i i=0
    IFS='|' read -r -a commands <<< "${history[$host]}"
    for cmd in "${commands[@]}"; do
      if (( ${#cmd} < 3 )); then
        continue
      fi
      ((i++))
      echo "$(prepend $i 3): $cmd"
      echo "$(prepend $i 3): $cmd" | tee -a "${params[log]}" > /dev/null
    done
  done
}

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

# Function to inform the user of something important
function banner_info {
    printf "${BOLD}${WHITE_BG}${BLACK_TEXT}\n\n%s\n\n${NORMAL}\n" "$1"
}

# Function for when things may go wrong
function banner_warning {
    printf "${BOLD}${YELLOW_BG}${BLACK_TEXT}\n\n%s\n\n${NORMAL}\n" "$1"
}

# Function for when major errors happen
function banner_error {
    printf "${BOLD}${RED_BG}${WHITE_TEXT}\n\n%s\n\n${NORMAL}\n" "$1"
}

# Function for when major success happens
function banner_success {
    printf "${BOLD}${GREEN_BG}${WHITE_TEXT}\n\n%s\n\n${NORMAL}\n" "$1"
}

# Info function: bold white text on no background
function info() {
    printf "${BOLD}${WHITE}\n%s\n${NORMAL}\n" "[INFO] ${1}"
}

# Error function: bold red text on no background
function error() {
    printf "${BOLD}${RED}\n%s\n${NORMAL}\n" "[ERROR] ${1}"
}

# Warning function: bold yellow text on no background
function warning() {
    printf "${BOLD}${YELLOW}\n%s\n${NORMAL}\n" "[WARNING] ${1}"
}

# Success function: bold green text on no background
function success() {
    printf "${BOLD}${GREEN}\n%s\n${NORMAL}\n" "[SUCCESS] ${1}"
}

# Debug function: bold white text on no background
function debug() {
    [[ -n "${DEBUG:-}" ]] && printf "${BOLD}${WHITE}\n%s\n${NORMAL}\n" "[DEBUG] ${1}"
}

# Replaces line with error message
function rerror() {
    replace "$(error "${1}")"
}

# Replaces line with warning message
function rwarning() {
    replace "$(warning "${1}")"
}

# Replaces line with info message
function rinfo() {
    replace "$(info "${1}")"
}

# Replaces line with debug message
function rdebug() {
    [[ -n "${DEBUG:-}" ]] && replace "$(info "${1}")"
}

# Replaces line with success message
function rsuccess() {
    replace "$(success "${1}")"
}

# Prints an error message then exits
function fatal() { 
    local msg="${1:-UnexpectedError}"
    error "[FATAL] ${msg}"
    exit 1
}

# Adds first argument of spaces to the 2nd argument
# pad(3, "-") # returns:"   -"
function pad() { 
    printf "%-${1}s\n" "${2}"
}

# Function to add text after first argument
# append("abc", "cde") # returns:"abccde"
function append() { 
    pad "${1}" "${2}"
}

# Function to add text before first argument
# prepend("abc", "cde") # returns:"cdeabc"
function prepend() { 
    printf "%*s\n" $2 "${1}"
}

# Function to replace line in terminal with fitted new line
function replace(){ 
    printf "\r%s%s" "${1}" "$(printf "%-$(( $(tput cols) - ${#1} ))s")"
}

# Function to repeat a string multiple times
# repeat "abc ", 3 # returns: "abc abc abc "
function repeat() {
    local string=$1
    local count=$2
    local result=""

    for ((i = 0; i < count; i++)); do
        result+="$string"
    done

    echo "$result"
}

# Function to mask a string
# mask "pass" # returns:"****"
function mask(){
    local what=$1
    repeat "*", "${#what}"
}

