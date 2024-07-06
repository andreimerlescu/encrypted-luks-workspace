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
    validate_action_new

    info "Creating workspace directory..."
    create_workspace_directory
    success "Created workspace directory!"

    info "Creating disk image..."
    create_disk_image
    success "Created disk image!"

    if encrypted; then
        info "Encrypting the disk image..."
        encrypt_disk_image 
        success "Encrypted the disk image with password $(masked_password)"
    fi

    info "Creating filesystem on disk image..."
    create_filesystem
    success "New filesystem ${params[type]} created on disk image!"

    info "Mounting drive to your system..."
    mount_drive
    success "Mounted '${params[name]}' to $(mount_path)!"

    add_to_index
    log "Added ${params[name]} to the index."
}

function action_rotate(){
    banner_info "ROTATE"
    validate_action_rotate
}

function action_unschedule(){
    banner_info "UNSCHEDULE"
    validate_action_unschedule
}

function action_mount(){
    banner_info "MOUNT"
    validate_action_mount
}

function action_unmount(){
    banner_info "UNMOUNT"
    validate_action_unmount
}

function action_passwd(){
    banner_info "PASSWD"
    validate_action_passwd
}

function action_remove(){
    banner_info "REMOVE"
    validate_action_remove
}

function action_archive(){
    banner_info "ARCHIVE"
    validate_action_archive
}

function action_replace(){
    banner_info "REPLACE"
    validate_action_replace
}

function action_change(){
    banner_info "CHANGE"
    validate_action_change
}

# Function to create workspace directory
# create_workspace_directory # returns:""
function create_workspace_directory(){
    # Validations
    param_required "name"

    # Properties
    local workspace="$(workspace_directory "${params[name]}")"

    # Validations
    [[ -z "${workspace}" ]] && fatal "Require path to be defined. Got: '${workspace}'"

    # Actions
    $SUDO mkdir -p "$workspace" || fatal "Failed to create directory: ${workspace}"
    log "Created directory ${workspace}"
}

# Function to create a new disk image
# create_disk_image # returns:""
function create_disk_image(){
    # Validations
    param_required "mount"

    # Properties
    local din="$(disk_image_name)"
    local size=$(drive_size)

    # Validations
    [[ -z "${din}" ]] && fatal "create_disk_image() requires disk_image_name() to return something"
    
    # Actions
    SECONDS=0
    $SUDO dd if=/dev/zero of="${din}" bs=1M count="${size}"
    log "create_disk_image() created a new file ${din} (${size}MB)"
    log "create_disk_image() took $SECONDS to complete"
}

# Function to mount a drive to the system
# mount_drive # returns:""
function mount_drive(){
    # Validations
    require_param_if_flag_true "password" "encrypt"
    param_required "parent"
    param_required "name"

    # Properties
    local mount="$(mount_path)"
    local name="${params[name]}"

    # Validations
    [[ -z "${mount}" ]] && fatal "mount_drive() requires valid mount path. Got: '${mount}'"
    [[ -z "${name}" ]] && fatal "mount_drive() requires argument to be defined as the device path. Got: '${name}'"

    # Actions
    SECONDS=0
    $SUDO mkdir -p "${mount}" || fatal "Failed to create directory: ${mount}"
    if encrypted; then
        $SUDO mount /dev/mapper/"${name}" "${mount}" || fatal "Failed to mount /dev/mapper/${name} to ${mount}"
        log "mount_drive() created /dev/mapper/${name} for ${mount}"
    else
        $SUDO mount -o loop "${name}" "${mount}" || fatal "Failed to mount loop ${name} to ${mount}"
        log "mount_drive() created loop ${name} for ${mount}"
    fi
    log "mount_drive() took $SECONDS to complete"
}

# Function to create a filesystem on the new workspace
# create_filesystem "${params[type]}"
function create_filesystem(){
    # Validations
    param_required "type"
    param_required "name"

    # Properties
    local type="${params[type]}"
    local image
    if encrypted; then
        image="/dev/mapper/encrypted-elwork-${params[name]}-$(date +"%Y-%m")"
    else
        image="$(mount_path).img"
    fi

    # Validations
    [[ -z "${type}" ]] && fatal "Require valid filesystem type. Got: ${type}"
    [[ -z "${image}" ]] && fatal "Require disk image path with valid name. Got: ${image}"

    # Actions
    SECONDS=0
    case "$type" in
        xfs)
            $SUDO mkfs.xfs "$image"
            log "create_filesystem() created an XFS filesystem on ${image}"
            ;;
        ext4)
            $SUDO mkfs.ext4 "$image"
            log "create_filesystem() created an EXT4 filesystem on ${image}"
            ;;
        *) fatal "Unsupported filesystem selected: $type" ;; 
    esac
    log "create_filesystem() took $SECONDS to complete"
}

# Function to encrypt using luks a new drive image
# encrypt_disk_image 
function encrypt_disk_image(){
    # Validations
    param_required "password"
    
    # Properties
    local image="$(disk_image_name)"
    local pass="$(password)"
    
    # Validations 
    [[ -z "${image}" ]] && fatal "encrypt_disk_image() requires image to be defined. Got: '${image}'"
    [[ -z "${pass}" ]] && fatal "encrypt_disk_image() requires --password to be defined. Got: '$(mask $pass)'"

    # Actions
    SECONDS=0
    echo -n "${pass}" | $SUDO cryptsetup luksFormat "${image}" - || fatal "Failed to format image: ${image}"
    log "encrypt_disk_image() formatted image ${image} with password $(mask $pass)"
    log "encrypt_disk_image() took $SECONDS to complete"
}

# Function to open an encrypted disk
# open_encrypted_disk # returns:""
function open_encrypted_disk(){
    # Validations
    param_required "password"
    
    # Properties
    local pass="$(password)"

    # Validations 
    [[ -z "${pass}" ]] && fatal "--password is required to open_encrypted_disk(). Got: '$(mask $pass)'"
    
    # Actions
    SECONDS=0
    echo -n "${pass}" | $SUDO cryptsetup luksOpen "${image}" "encrypted-elwork-$(basename "${image}")" || fatal "Failed to open ${image}"
    log "open_encrypted_disk() unsealed encrypted luks volume ${image} as encrypted-elwork-$(basename "${image}")"
    log "open_encrypted_disk() took $SECONDS to complete"
}

# Function to create a workspace symlink
function create_workspace_symlink(){
    # Validation
    param_required "parent"
    param_required "name"

    # Properties
    local workspace="$(workspace_directory)"
    local name="${params[parent]}/${params[name]}"

    # Validations
    [[ -z "${workspace}" ]] && fatal "Required path to be defined. Got: '${workspace}'"
    [[ -z "${name}" ]] && fatal "Require a name value from --parent and --name. Got: '${name}'"
    ! is_writable_dir "${params[parent]}" && fatal "Cannot write to --parent directory: ${params[parent]}"

    # Actions
    $SUDO ln -s "$workspace" "${name}"
    log "create_workspace_symlink() created symlink $workspace -> ${name}"
}

# Function to create the workspace storage directory
function create_workspaces_storage_directory(){
    # Validations
    ensure_parent_exists

    # Properties
    local path="$(workspace_path_storage)"

    # Validations
    [[ -z "${path}" ]] && fatal "Require path to be defined. Got: '${path}'"

    # Actions
    $SUDO mkdir -p "${path}" || fatal "Failed to create directory: ${path}"
    log "create_workspaces_storage_directory() created directory ${path}"
}

# Function to add workspace to index
# add_to_index # returns:""
function add_to_index(){
    # Properties
    local mount=$(mount_path)
    local size=$(drive_size)
    local index_file="$(workspace_path_storage)/.index"
    local disk_usage=$(sudo du -sh "$mount" | cut -f1)
    local status
    { encrypted && status="encrypted"; } || status="unencrypted"

    # Validations
    ! [[ -w "${index_file}" ]] && fatal "Index is not writable."

    # Actions
    echo "${mount}@@@${size}@@@${status}@@@${disk_usage}" | $SUDO tee -a "$index_file" > /dev/null
    log "add_to_index() appended $index_file for ${mount}"
}

