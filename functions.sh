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
        *) echo ${1} ;;
    esac
}

# Function to return MB value of --size
function drive_size(){
    echo "$(get_size_in_mb "${params[size]}")"
}

function workspace_drive_path(){
    echo "$(workspaces_storage_path)/$(disk_image_name)"
}

# Function to use --parent and return the .disks path
function workspaces_storage_path(){
    echo "$(realpath "${params[parent]}")/.disks"
}

# Function to return the luks device name
function device_name(){
    local device_name
    if [[ -z "${params[date]}" ]]; then
        device_name="encrypted-elwork-${params[name]}-$(date +"%Y-%m")"
    else
        device_name="encrypted-elwork-${params[name]}-${params[date]}"
    fi
    echo $device_name
}

# Function to return the path to the workspace directory
# workspace_directory 
function workspace_directory(){
    local name="${params[name]}"
    echo "$(workspaces_storage_path)/${name}_$(date +"%Y-%m")"
}

# Function to return the name of the disk image based on --mount
function disk_image_name(){
    echo "$(basename "$(workspace_directory)").img"
}

function encrypted(){
    [[ "${params[encrypt]}" == true ]]
}

function mount_path(){
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
    if [[ -z "${params[password]}" ]]; then 
        retrieve_password
    fi
    echo "${params[password]}"
}

# Function to assign the symbolic link
function home_alias_path(){
    echo "${HOME}/el-${params[name]}"
}

function index_path(){
    echo "$(workspaces_storage_path)/.index"
}

function masked_password(){
    echo "$(mask "$(password)")"
}

# Function to prompt user for Y/N response
# confirm_action_prompt <question> [<timeout=369>]
# confirm_action_prompt "Are you sure you want to do this?" 45
function confirm_action_prompt(){
    local response
    local status=false # assume no
    local -i tries=0
    while true; do 
        read -r -t "${2:-369}" -p "${1} (y/n): " response
        echo
        if [[ "${response}" =~ ^([Yy]|[Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Tt])$ ]]; then
            status=true
        elif [[ "${response}" =~ ^([Nn]|[Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Ff])$ ]]; then
            status=false
        else
            warning "Invalid response: '${response}'"
            continue
        fi
        break
    done
    { $status && return 0; } || return 1
}

# Function to retrieve password
function retrieve_password {
    local p=""
    local go=true
    local -i tries=0
    while [[ "${go}" == true ]]; do 
        read -s -p "Enter password: " p
        echo
        if [[ ${#p} -le 3 ]]; then
            warning "Cannot accept ${p} as the password. Please try again."
            ((tries++))
            if (( tries < 17 )); then
                continue
            else
                go=false
                break
            fi
        else
            local c
            read -s -p "Confirm password: " c
            echo
            if [[ "${c}" != "${p}" ]] || [[ ${#c} -le 3 ]]; then
                warning "Passwords did not match! First was ${#p} chars, confirmation was ${#c} chars. Please try again."
                ((tries++))
                if (( tries < 17 )); then
                    continue
                fi
            fi
            success "We've accepted your password! This will be used for encrypting your new workspace."
            go=false
            break
        fi
    done
    [[ ${#p} -le 3 ]] && fatal "Invalid password provided. Cannot continue."
    params[password]=$p
    true
}

# Function to parse CLI arguments
function parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            debug|--debug) 
                DEBUG="--debug"
                params[debug]=true
                set -x
                shift
                continue 
                ;;

            sudo|--sudo)
                SUDO="sudo"
                params[sudo]=true
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

# Function to inform the user of something important
function banner_info {
    printf "${BOLD}${WHITE_BG}${BLACK}%s${NORMAL}\n" "$1"
}

# Function for when things may go wrong
function banner_warning {
    printf "${BOLD}${YELLOW_BG}${BLACK}%s${NORMAL}\n" "$1"
}

# Function for when major errors happen
function banner_error {
    printf "${BOLD}${RED_BG}${WHITE}%s${NORMAL}\n" "$1"
}

# Function for when major success happens
function banner_success {
    printf "${BOLD}${GREEN_BG}${BLACK}%s${NORMAL}\n" "$1"
}

# Info function: bold white text on no background
function info() {
    printf "${BOLD}${WHITE}%s${NORMAL}\n" "[INFO] ${1}"
}

# Error function: bold red text on no background
function error() {
    printf "${BOLD}${RED}%s${NORMAL}\n" "[ERROR] $1"
}

# Warning function: bold yellow text on no background
function warning() {
    printf "${BOLD}${YELLOW}%s${NORMAL}\n" "[WARNING] ${1}"
}

# Success function: bold green text on no background
function success() {
    printf "${BOLD}${GREEN}%s${NORMAL}\n" "[SUCCESS] ${1}"
}

# Debug function: bold white text on no background
function debug() {
    set +x
    [[ -n "${DEBUG:-}" ]] && printf "${WHITE}%s${NORMAL}\n" "[DEBUG] ${1}"
    [[ -n "${DEBUG:-}" ]] && set -x
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
    # Properties
    local i=0
    local funcname=""
    local lineno=""
    local srcfile=""
    local msg="${1:-UnexpectedError}"

    # Actions
    error "[FATAL] ${msg}"
    if [[ "${params[trace]}" == true ]]; then
        error "Stack trace:"
        while caller $i 1> /dev/null; do
            ((i++))
            funcname="${FUNCNAME[$i]}"
            lineno="${BASH_LINENO[$i-1]}"
            srcfile="${BASH_SOURCE[$i]}"
            error "  at ${funcname}() in ${srcfile}:${lineno}"
        done
    fi
    exit 1
}

# Function to calculate the width of a column
# get_column_width <column values>
function get_column_width() {
    local max_length=0
    for value in "$@"; do
        if [[ ${#value} -gt $max_length ]]; then
            max_length=${#value}
        fi
    done
    echo $max_length
}

# Function to create a markdown table row
# create_table_row <column widths> <values>
function create_table_row() {
    local widths=("${!1}")
    shift
    local values=("$@")
    local row="|"
    for i in "${!values[@]}"; do
        row+=" $(printf "%-${widths[$i]}s" "${values[$i]}") |"
    done
    echo "$row"
}

# Function to log to a file
function log(){
    [[ ! -d "$(dirname "${params[log]}")" ]] && mkdir -p "$(dirname "${params[log]}")" && log "log() created $(dirname "${params[log]}")"
    [[ ! -d "$(dirname "${params[log]}")" ]] && fatal "Cannot write to the --log directory ${params[log]}."
    # Properties
    local msg
    local caller_info
    local lineno
    local srcfile

    caller_info=$(caller 0)
    lineno=$(echo "$caller_info" | awk '{print $1}')
    srcfile=$(echo "$caller_info" | awk '{print $3}')

    msg="[$(date +"%Y-%m-%d %H:%M:%S")] [$srcfile:$lineno] ${1}"

    # Validations
    [[ -z "${msg}" ]] && return

    # Actions
    echo $msg | $SUDO tee -a "${params[log]}" > /dev/null
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
    repeat "*" "${#what}"
}

