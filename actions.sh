#!/bin/bash

[[ -z "${INSIDE_ELWORK}" ]] && { echo "FATAL ERROR: This function cannot be executed on its own."; exit 1; }

# Action LIST
function action_list(){
    banner_info "LIST"
    validate_action_list
}

# Action NEW
# Creates a new workspace
function action_new(){
    banner_info "NEW"
    validate_action_new || fatal "Failed to validate action."

    info "Creating disk image..."
    create_disk_image || fatal "Failed to create disk image."
    success "Created disk image!"

    if encrypted; then
        info "Encrypting the disk image..."
        encrypt_disk_image || fatal "Failed to encrypt the disk image."
        success "Encrypted the disk image with password $(masked_password)"
    fi

    info "Creating filesystem on disk image..."
    create_filesystem || fatal "Failed to create the filesystem"
    success "New filesystem ${params[type]} created on disk image!"

    info "Mounting drive to your system..."
    mount_drive || fatal "Failed to mount the drive"
    success "Mounted '${params[name]}' to $(mount_path)!"

    add_to_index || fatal "Failed to add the workspace to the index"
    log "Added ${params[name]} to the index."
}

function action_rotate(){
    banner_info "ROTATE"
    validate_action_rotate || fatal "Failed to validate action."
}

function action_unschedule(){
    banner_info "UNSCHEDULE"
    validate_action_unschedule || fatal "Failed to validate action."
}

function action_mount(){
    banner_info "MOUNT"
    validate_action_mount || fatal "Failed to validate action."
}

function action_unmount(){
    banner_info "UNMOUNT"
    validate_action_unmount || fatal "Failed to validate action."
}

function action_passwd(){
    banner_info "PASSWD"
    validate_action_passwd || fatal "Failed to validate action."
}

function action_remove(){
    banner_info "REMOVE"
    validate_action_remove || fatal "Failed to validate action."
}

function action_archive(){
    banner_info "ARCHIVE"
    validate_action_archive || fatal "Failed to validate action."
}

function action_replace(){
    banner_info "REPLACE"
    validate_action_replace || fatal "Failed to validate action."
}

function action_change(){
    banner_info "CHANGE"
    validate_action_change || fatal "Failed to validate action."
}

# Function to create workspace directory
# create_workspace_directory # returns:""
function create_workspace_directory(){
    # Properties
    local workspace=$(workspace_directory)

    # Validations
    [[ -z "${workspace}" ]] && fatal "Line: ${LINENO} Require path to be defined. Got: '${workspace}'"

    # Actions
    set +C
    $SUDO mkdir -p "$workspace" || fatal "Line: ${LINENO} Failed to create directory: ${workspace}"
    set -C
    [[ -n $DEBUG ]] && tree -a -L 3 "${params[parent]}"
    ! [[ -d "$workspace" ]] && fatal "Line: ${LINENO} Failed to create directory: $workspace"
    log "Created directory ${workspace}"
    true
}

# Function to create a new disk image
# create_disk_image # returns:""
function create_disk_image(){
    # Properties
    local din="$(workspace_drive_path)"
    local size=$(drive_size)

    info "Creating disk image at ${din} with a size of ${size}MB"

    # Validations
    [[ -z "${din}" ]] && fatal "Line: ${LINENO} create_disk_image() requires disk_image_name() to return something. Got: '${din}'" && return
    [[ -z "${size}" ]] && fatal "Line: ${LINENO} create_disk_image() requires --size to be defined. Got: '${size}'" && return
    [[ -f "${din}" ]] && fatal "Line: ${LINENO} create_disk_image() failed because ${din} already exists." && return
    
    # Actions
    SECONDS=0
    set +C
    $SUDO dd if=/dev/zero of="${din}" bs=1M count="${size}" || fatal "Failed to create disk image ${din} of size ${size}MB"
    set -C
    [[ -n $DEBUG ]] && tree -a -L 3 "${params[parent]}"
    log "create_disk_image() created a new file ${din} (${size}MB)"
    log "create_disk_image() took $SECONDS to complete"
    true
}

# Function to mount a drive to the system
# mount_drive # returns:""
function mount_drive(){
    # Properties
    local mount="$(mount_path)"
    local name="${params[name]}"

    # Validations
    [[ -z "${mount}" ]] && fatal "Line: ${LINENO} mount_drive() requires valid mount path. Got: '${mount}'"
    [[ -z "${name}" ]] && fatal "Line: ${LINENO} mount_drive() requires argument to be defined as the device path. Got: '${name}'"

    # Actions
    SECONDS=0
    set +C
    $SUDO mkdir -p "${mount}" || fatal "Line: ${LINENO} Failed to create directory: ${mount}"
    set -C
    [[ -n $DEBUG ]] && tree -a -L 3 "${params[parent]}"
    if encrypted; then
        $SUDO mount /dev/mapper/"${name}" "${mount}" || fatal "Line: ${LINENO} Failed to mount /dev/mapper/${name} to ${mount}"
        log "mount_drive() created /dev/mapper/${name} for ${mount}"
    else
        $SUDO mount -o loop "$(workspace_drive_path)" "${mount}" || fatal "Line: ${LINENO} Failed to mount loop ${name} to ${mount}"
        log "mount_drive() created loop ${name} for ${mount}"
    fi
    log "mount_drive() took $SECONDS to complete"
}

# Function to create a filesystem on the new workspace
# create_filesystem "${params[type]}"
function create_filesystem(){
    # Properties
    local type="${params[type]}"
    local image
    if encrypted; then
        image="/dev/mapper/encrypted-elwork-${params[name]}-$(date +"%Y-%m")"
    else
        image="$(workspace_drive_path)"
    fi

    # Validations
    [[ -z "${type}" ]] && fatal "Line: ${LINENO} Require valid filesystem type. Got: ${type}"
    [[ -z "${image}" ]] && fatal "Line: ${LINENO} Require disk image path with valid name. Got: ${image}"

    # Actions
    SECONDS=0
    [[ -n $DEBUG ]] && tree -a -L 3 "${params[parent]}"
    case "$type" in
        xfs)
            set +C
            $SUDO mkfs.xfs "$image"
            set -C
            log "create_filesystem() created an XFS filesystem on ${image}"
            ;;
        ext4)
            set +C
            $SUDO mkfs.ext4 "$image"
            set -C
            log "create_filesystem() created an EXT4 filesystem on ${image}"
            ;;
        *) fatal "Line: ${LINENO} Unsupported filesystem selected: $type" ;; 
    esac
    log "create_filesystem() took $SECONDS to complete"
    true
}

# Function to encrypt using luks a new drive image
# encrypt_disk_image 
function encrypt_disk_image(){
    # Properties
    local image="$(disk_image_name)"
    local pass="$(password)"
    
    # Validations 
    [[ -z "${image}" ]] && fatal "Line: ${LINENO} encrypt_disk_image() requires image to be defined. Got: '${image}'"
    [[ -z "${pass}" ]] && fatal "Line: ${LINENO} encrypt_disk_image() requires --password to be defined. Got: '$(mask $pass)'"

    # Actions
    SECONDS=0
    set +C
    echo -n "${pass}" | $SUDO cryptsetup luksFormat "${image}" - || fatal "Line: ${LINENO} Failed to format image: ${image}"
    set -C
    log "encrypt_disk_image() formatted image ${image} with password $(mask $pass)"
    log "encrypt_disk_image() took $SECONDS to complete"
}

# Function to open an encrypted disk
# open_encrypted_disk # returns:""
function open_encrypted_disk(){
    # Properties
    local pass="$(password)"

    # Validations 
    [[ -z "${pass}" ]] && fatal "Line: ${LINENO} --password is required to open_encrypted_disk(). Got: '$(mask $pass)'"
    
    # Actions
    SECONDS=0
    set +C
    echo -n "${pass}" | $SUDO cryptsetup luksOpen "${image}" "encrypted-elwork-$(basename "${image}")" || fatal "Line: ${LINENO} Failed to open ${image}"
    set -C
    log "open_encrypted_disk() unsealed encrypted luks volume ${image} as encrypted-elwork-$(basename "${image}")"
    log "open_encrypted_disk() took $SECONDS to complete"
}

# Function to create a workspace symlink
function create_workspace_symlink(){
    # Properties
    local workspace="$(workspace_directory)"
    local mount="$(mount_path)"

    # Validations
    [[ -z "${workspace}" ]] && fatal "Line: ${LINENO} Required path to be defined. Got: '${workspace}'"
    [[ -z "${mount}" ]] && fatal "Line: ${LINENO} Require a mount value from --parent and --name. Got: '${mount}'"
    ! is_writable_dir "${params[parent]}" && fatal "Line: ${LINENO} Cannot write to --parent directory: ${params[parent]}"

    # Actions
    set +C
    $SUDO ln -s "$workspace" "${mount}"
    set -C
    [[ -n $DEBUG ]] && ls -la "${params[parent]}"
    log "create_workspace_symlink() created symlink $workspace -> ${mount}"
}

# Function to ensure that --parent is a writable directory that exists
# ensure_parent_exists # returns:""
function ensure_parent_exists(){
    param_required "parent"
    local p="${params[parent]}"
    set +C
    $SUDO mkdir -p "${p}" || fatal "failed to create directory: ${p}"
    set -C
    log "ensure_parent_exists() created directory ${p}"
    { ! is_writable_dir "${p}" && fatal "--parent not writable"; } || true
}

# Function to create the workspace storage directory
function create_workspaces_storage_directory(){
    # Validations
    ensure_parent_exists || fatal "--parent is required"

    # Properties
    local path="$(workspaces_storage_path)"

    # Validations
    [[ -z "${path}" ]] && fatal "Line: ${LINENO} Require path to be defined. Got: '${path}'"
    [[ -d "${path}" ]] && fatal "Line: ${LINENO} Directory already exists: ${path}"

    # Actions
    set +C
    $SUDO mkdir -p "${path}" || fatal "Line: ${LINENO} Failed to create directory: ${path}"
    set -C
    [[ -n $DEBUG ]] && stat "${path}"
    [[ -n $DEBUG ]] && ls -la "${path}"
    [[ -n $DEBUG ]] && tree -a -L 3 "${params[parent]}"
    log "create_workspaces_storage_directory() created directory ${path}"
    true
}

# Function to add workspace to index
# add_to_index # returns:""
function add_to_index(){
    # Properties
    local mount=$(mount_path)
    local size=$(drive_size)
    local index_file="$(workspaces_storage_path)/.index"
    local disk_usage=$(sudo du -sh "$mount" | cut -f1)
    local status
    { encrypted && status="encrypted"; } || status="unencrypted"

    # Validations
    ! [[ -w "${index_file}" ]] && fatal "Line: ${LINENO} Index is not writable."

    # Actions
    echo "${mount}@@@${size}@@@${status}@@@${disk_usage}" | $SUDO tee -a "$index_file" > /dev/null
    log "add_to_index() appended $index_file for ${mount}"
}

