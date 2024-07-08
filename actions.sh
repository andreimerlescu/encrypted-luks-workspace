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
    validate_action_new || fatal "Failed to validate action."

    is_duplicate_workspace_name && fatal "Another workspace already exists by the name: ${params[name]}"

    create_disk_image || fatal "Failed to create disk image."

    if encrypted; then
        info "Formatting the disk image with LUKS..."
        format_new_encrypted_disk || fatal "Failed to create the encrypted disk image."
        open_encrypted_disk || fatal "Failed to open the encrypted disk image."
    fi

    info "Creating filesystem on disk image..."
    create_filesystem || fatal "Failed to create the filesystem"

    info "Mounting drive to your system..."
    mount_drive

    info "Creating workspace symbolic link..."
    create_workspace_symlink

    success "Created new workspace ${params[name]} of $(drive_size)MB accessible at $(home_alias_path)!"

    add_to_index || fatal "Failed to add the workspace to the index"
    log "action_new() created new workspace called ${params[name]}"
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
    validate_action_remove || fatal "Failed to validate action."

    local device_name
    device_name="$(device_name)"

    if [[ "${params[duplicates]}" == false ]]; then
        ! is_duplicate_workspace_name && fatal "No such workspace recognized."
    fi

    info "Unmounting filesystem..."
    unmount_filesystem 

    if encrypted; then
        info "Closing LUKS device..."
        close_encrypted_disk
    fi

    info "Detaching loop device..."
    detach_loop_device

    info "Removing disk image..."
    remove_disk_image

    info "Removing mount directory..."
    remove_mount_directory

    info "Removing symlink..."
    remove_symbolic_link

    info "Cleaning up system..."
    clear_blkid_cache

    success "Removed workspace ${params[name]}"
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
    [[ -z "${workspace}" ]] && fatal "Require path to be defined. Got: '${workspace}'"

    # Actions
    set +C
    $SUDO mkdir -p "$workspace" || fatal "Failed to create directory: ${workspace}"
    set -C
    [[ -n $DEBUG ]] && tree -a -L 3 "${params[parent]}"
    ! [[ -d "$workspace" ]] && fatal "Failed to create directory: $workspace"
    log "Created directory ${workspace}"
    true
}

# Function to create a new disk image
# create_disk_image # returns:""
function create_disk_image(){
    # Properties
    local din
    local size

    din="$(workspace_drive_path)"
    size=$(drive_size)

    info "Creating disk image at ${din} with a size of ${size}MB..."

    # Validations
    [[ -z "${din}" ]] && fatal "create_disk_image() requires disk_image_name() to return something. Got: '${din}'" && return
    [[ -z "${size}" ]] && fatal "create_disk_image() requires --size to be defined. Got: '${size}'" && return
    [[ -f "${din}" ]] && fatal "create_disk_image() failed because ${din} already exists." && return
    
    # Actions
    SECONDS=0
    set +C
    $SUDO dd if=/dev/zero of="${din}" bs=1M count="${size}"
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
    local mount

    mount="$(mount_path)"

    # Validations
    [[ -z "${mount}" ]] && fatal "mount_drive() requires valid mount path. Got: '${mount}'" && return

    # Actions
    SECONDS=0
    set +C
    $SUDO mkdir -p "${mount}" 
    set -C
    
    # Validations
    [[ ! -d "${mount}" ]] && { fatal "Failed to create directory: ${mount}"; return; }
    
    # Debugging
    [[ -n $DEBUG ]] && tree -a -L 3 "${params[parent]}"
    [[ -n $DEBUG ]] && ls -la "${params[parent]}"
    
    # Handle encrypted drives differently
    if encrypted; then
        local device_name
        device_name="$(device_name)"
        $SUDO mount /dev/mapper/"${device_name}" "${mount}"
        log "mount_drive() created /dev/mapper/${device_name} for ${mount}"
    else
        local loop_device
        loop_device=$($SUDO losetup --find --show "$(workspace_drive_path)")
        [[ -z "${loop_device}" ]] && fatal "Failed to mount ${mount} to ${loop_device}" && return
        $SUDO mount "${loop_device}" "${mount}"
        log "mount_drive() created loop device ${loop_device} for ${mount}"
    fi
    log "mount_drive() took $SECONDS to complete"
    true
}

# Function to create a filesystem on the new workspace
# create_filesystem "${params[type]}"
function create_filesystem(){
    # Properties
    local type
    local image

    type="${params[type]}"

    # Assign encrypted drives differently
    if encrypted; then
        image="/dev/mapper/encrypted-elwork-${params[name]}-$(date +"%Y-%m")"
    else
        image="$(workspace_drive_path)"
    fi

    # Validations
    [[ -z "${type}" ]] && fatal "Require valid filesystem type. Got: ${type}"
    [[ -z "${image}" ]] && fatal "Require disk image path with valid name. Got: ${image}"

    # Actions
    SECONDS=0
    [[ -n $DEBUG ]] && tree -a -L 3 "${params[parent]}"
    [[ -n $DEBUG ]] && ls -lah "${params[parent]}"
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
        *) fatal "Unsupported filesystem selected: $type" ;; 
    esac
    log "create_filesystem() took $SECONDS to complete"
    true
}

# Function to encrypt using luks a new drive image
# format_new_encrypted_disk 
function format_new_encrypted_disk(){
    # Properties
    local image="$(workspace_drive_path)"
    local pass="$(password)"
    
    # Validations 
    [[ -z "${image}" ]] && fatal "format_new_encrypted_disk() requires image to be defined. Got: '${image}'"
    [[ -z "${pass}" ]] && fatal "format_new_encrypted_disk() requires --password to be defined. Got: '$(mask $pass)'"

    # Actions
    SECONDS=0
    info "Creating disk ${image}..."
    set +C
    echo -n "${pass}" | $SUDO cryptsetup luksFormat "${image}" - 
    set -C
    log "format_new_encrypted_disk() formatted image ${image} with password $(mask $pass)"
    log "format_new_encrypted_disk() took $SECONDS to complete"
    true
}

# Function to close an encrypted disk
# close_encrypted_disk # returns:""
function close_encrypted_disk(){
    # Properties
    local device_name="$(device_name)"

    # Actions
    SECONDS=0
    set +C
    $SUDO cryptsetup luksClose "${device_name}"
    set -C
    log "close_encrypted_disk() sealed encrypted luks volume ${device_name}"
    log "close_encrypted_disk() took $SECONDS to complete"
    true
}

# Function to umount filesystem
function unmount_filesystem {
    local mount_path
    mount_path=$(mount_path)
    if mountpoint -q "$mount_path"; then
        $SUDO umount "$mount_path" || fatal "Please add --sudo"
        log "unmount_filesystem() unmounted filesystem at $mount_path"
    fi
}

# Function to detach unencrypted drive
function detach_loop_device {
    local loop_device
    loop_device=$($SUDO losetup --find --show "$(workspace_drive_path)")
    [[ -z "${loop_device}" ]] && fatal "Failed to mount ${mount} to ${loop_device}" && return
    $SUDO losetup -d "$loop_device" || fatal "Failed to detach loop device $loop_device"
    log "detach_loop_device() detached loop device $loop_device"
}

# Function to remove the disk image
function remove_disk_image {
    local din
    din="$(workspace_drive_path)"
    $SUDO rm -f "$din" || fatal "Failed to remove disk image $din"
    log "remove_disk_image() removed disk image $din"
}

# Function to clean out blkid
function clear_blkid_cache {
    $SUDO blkid -c /dev/null &> /dev/null
    log "Cleared blkid cache"
}

# Function to remove mount directory
function remove_mount_directory(){
    local mount_path
    mount_path=$(mount_path)
    $SUDO rm -rf "${mount_path}"
    log "remove_mount_directory() removed directory ${mount_path}"
}

# Function to remove symbolic link
function remove_symbolic_link {
    local symlink
    symlink="$(home_alias_path)"
    $SUDO rm -rf "${symlink}"
    log "remove_symbolic_link() deleted symlink at ${symlink}"
}

# Function to open an encrypted disk
# open_encrypted_disk # returns:""
function open_encrypted_disk(){
    # Properties
    local device_name
    local image_path
    local pass
    device_name="$(device_name)"
    image_path="$(workspace_drive_path)"
    pass="$(password)"

    # Validations 
    [[ -z "${image_path}" ]] && fatal "open_encrypted_disk() requires image_path to be defined. Got: '${image_path}'"
    [[ -z "${pass}" ]] && fatal "--password is required to open_encrypted_disk(). Got: '$(masked_password)'"

    # Actions
    SECONDS=0
    set +C
    echo -n "${pass}" | $SUDO cryptsetup luksOpen "${image_path}" "${device_name}"
    set -C
    log "open_encrypted_disk() unsealed encrypted luks volume ${device_name}"
    log "open_encrypted_disk() took $SECONDS to complete"
    true
}

# Function to create a workspace symlink
function create_workspace_symlink(){
    # Properties
    local mount="$(mount_path)"

    # Validations
    [[ -z "${mount}" ]] && fatal "Require a mount value from --parent and --name. Got: '${mount}'"

    # Actions
    set +C
    $SUDO ln -s "$(home_alias_path)" "${mount}"
    set -C
    [[ -n $DEBUG ]] && ls -la "${params[parent]}"
    log "create_workspace_symlink() created symbolic link at $(home_alias_path) pointing to ${mount}"
    true
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
    [[ -z "${path}" ]] && fatal "Require path to be defined. Got: '${path}'"
    [[ -d "${path}" ]] && return 0

    # Actions
    set +C
    $SUDO mkdir -p "${path}"
    set -C
    ! [[ -d "${path}" ]] && fatal "Directory could not be created: ${path}"
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

    # Actions
    echo "${params[name]}@@@${mount}@@@${size}@@@${status}@@@${disk_usage}" | $SUDO tee -a "$index_file" > /dev/null
    log "add_to_index() appended $index_file for ${mount}"
    true
}

# Function to check disk utilization and create warnings if necessary
function check_disk_utilization {
    local index_file="$1"
    while IFS='@@@' read -r name mount size encrypt disk_usage; do
        utilization=$(df --output=pcent "$mount" | tail -n 1 | tr -d '% ')
        if (( utilization >= 90 )); then
            warning_file="${HOME}/ELWORK-WORKSPACE-${name^^}-WARNING-DISK-UTILIZATION-${utilization}"
            echo "Disk utilization for ${name} is at ${utilization}%." > "$warning_file"
            chattr +i "$warning_file"  # Make the file immutable
            log "check_disk_utilization() created warning file ${warning_file} for ${name} in ${mount}"
        fi
    done < "$index_file"
}

# Function to remove warnings when disk is rotated
function remove_old_warnings {
    local name="${params[name]}"
    local warning_files=(${HOME}/WORKSPACE-${name^^}-DISK-UTILIZATION-*)
    for warning_file in "${warning_files[@]}"; do
        chattr -i "$warning_file"  # Make the file mutable
        rm -f "$warning_file"
        log "remove_old_warnings() removed file ${warning_file}"
    done
}

# Function to check if workspace is already used
function is_duplicate_workspace_name(){
    local index_file=$(index_path)
    $SUDO touch "${index_file}"
    log "is_duplicate_workspace_name() touched index file ${index_file}"
    local mount_path=$(mount_path)
    local exists=false
    while IFS='@@@' read -r name mount size encrypt disk_usage; do
        if [[ "${name,,}" == "${params[name],,}" ]] && [[ "${mount,,}" == "${mount_path,,}" ]]; then
            warning "Found duplicate entry in index: ${name} ${mount} ${size} ${encrypt}"
            exists=true
        fi
    done < "$index_file"
    $exists
}

# Function to sync the elwork disks directory to the index file
function sync_index(){
    local index=$(index_path)
    $SUDO touch "${index_file}"
    log "sync_index() touched index file ${index_file}"

    check_disk_utilization "$index"
    manage_full_disks "$index"

    # Update the .index file
    > "$index"
    for dir in $(ls -d ${parent}/.disks/*/); do
        name=$(basename "$dir")
        mount="$dir"
        size=$(du -sh "$mount" | cut -f1)
        encrypt_status=$(lsblk -o NAME,TYPE,MOUNTPOINT | grep "$mount" | awk '{print $2}')
        disk_usage=$(df --output=pcent "$mount" | tail -n 1 | tr -d '% ')
        echo "${name}@@@${mount}@@@${size}@@@${encrypt_status}@@@${disk_usage}" >> "$index"
    done
}

