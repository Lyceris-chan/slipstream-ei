#!/bin/bash

# Exit immediately if any command exits with a non-zero status
set -e

# Array to hold background process IDs
declare -a bg_pids=()

# Function to execute a command in the background and store its PID
function bg_execute() {
    "$@" &
    bg_pids+=($!)
}

# Function to wait for all background processes and check their exit statuses
function wait_all() {
    for pid in "${bg_pids[@]}"; do
        wait "$pid" || exit 1
    done
}

# Function to extract files from ISO
function extract_files() {
    iso_file="$1"
    mount_dir=$(mktemp -d)
    extract_dir="$(basename "$iso_file" .iso)"

    sudo mount -o loop,ro "$iso_file" "$mount_dir"
    mkdir -p "$extract_dir"
    cp -r "$mount_dir"/* "$extract_dir"
    sudo umount "$mount_dir"
    rm -rf "$mount_dir"

    echo "Extracted files from $iso_file to $extract_dir"
}

# Function to create ei.cfg file
function create_ei_cfg() {
    echo "[Channel]" >> "ei.cfg"
    echo "_Default" >> "ei.cfg"
    echo "[VL]" >> "ei.cfg"
    echo "0" >> "ei.cfg"

    dos2unix -k "ei.cfg"

    echo "Created ei.cfg in '$(pwd)'"
}

# Function to add ei.cfg file to source
function add_ei_cfg() {
    for folder in */; do
        folder_name=${folder%/}

        if [[ -d "$folder_name/Source" ]]; then
            cp ei.cfg "$folder_name/Source"
        fi
    done

    echo "Added ei.cfg file to source"
}

# Function to repackage source contents back into bootable ISO
function create_iso() {
    mkdir -p "modified_iso"

    for dir in */; do
        extracted_iso=${dir%/}
        iso_name="${extracted_iso}.iso"

        mkisofs \
            -no-emul-boot \
            -b "boot/etfsboot.com" \
            -boot-load-seg 0 \
            -boot-load-size 8 \
            -eltorito-alt-boot \
            -eltorito-platform efi \
            -no-emul-boot \
            -b "efi/microsoft/boot/efisys.bin" \
            -boot-load-size 1 \
            -iso-level 4 \
            -UDF \
            -o "modified_iso/${iso_name}" \
            "${dir}"
    done
}

# Main script starts here

# Install dependencies
sudo apt-get update && sudo apt install -y dos2unix genisoimage

# Extract files in parallel
for iso in *.iso; do
    bg_execute extract_files "$iso"
done

wait_all

# Create ei.cfg in parallel
for dir in */; do
    bg_execute create_ei_cfg "$dir"
done

wait_all

# Add ei.cfg in parallel
for dir in */; do
    bg_execute add_ei_cfg "$dir"
done

wait_all

# Repackage ISO in parallel
for dir in */; do
    bg_execute create_iso "$dir"
done

wait_all

echo "Done!"
