#!/bin/bash
set -euo pipefail  # Exit on error

# Ensure script is run with an image file argument
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <path-to-image-file>"
    exit 1
fi

# Define global variables
IMG_FILE="$1"
MNT_DIR="$(mktemp -d)"
BOOT_DIR="$MNT_DIR/boot"
LOOP_DEV=""
ROOT_PART=""
BOOT_PART=""

# Ensure script is run as root
ensure_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "This script must be run as root. Exiting."
        exit 1
    fi
}

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    umount "$MNT_DIR/dev/pts" || true
    umount --recursive "$MNT_DIR/dev" || true
    umount "$MNT_DIR/proc" || true
    umount "$MNT_DIR/sys" || true
    umount "$MNT_DIR/tmp" || true
    umount "$MNT_DIR/var/tmp" || true
    umount "$MNT_DIR/run/user/0" || true
    umount -l "$BOOT_DIR" || true
    umount -l "$MNT_DIR" || true
    [[ -n "$LOOP_DEV" ]] && losetup -d "$LOOP_DEV"
    rm -rf "$MNT_DIR"
    echo "Cleanup complete."
}
trap cleanup EXIT

# Setup mount directories
setup_mount_dirs() {
    mkdir -p "$MNT_DIR" "$BOOT_DIR" "$MNT_DIR/run/user/0"
}

# Attach image and extract partitions
attach_image() {
    LOOP_DEV=$(losetup --find --show --partscan "$IMG_FILE")
    PART_INFO=$(fdisk -l "$IMG_FILE")
    BOOT_START=$(echo "$PART_INFO" | awk '/W95 FAT32/{print $2}' | head -n 1)
    ROOT_START=$(echo "$PART_INFO" | awk '/Linux/{print $2}' | head -n 1)
    BOOT_PART="${LOOP_DEV}p1"
    ROOT_PART="${LOOP_DEV}p2"
    echo "Loop Device: $LOOP_DEV"
    echo "Boot Partition: $BOOT_PART"
    echo "Root Partition: $ROOT_PART"
    if [[ -z "$ROOT_PART" || -z "$BOOT_PART" ]]; then
        echo "Error: Could not find required partitions. Check the image file."
        exit 1
    fi
}

# Mount partitions
mount_partitions() {
    mount "$ROOT_PART" "$MNT_DIR"
    mount "$BOOT_PART" "$BOOT_DIR"
    mount -t tmpfs -o "size=99%" tmpfs "$MNT_DIR/tmp"
    mount -t tmpfs -o "size=99%" tmpfs "$MNT_DIR/var/tmp"
    mkdir -p "$MNT_DIR/run/" "$MNT_DIR/run/user" "$MNT_DIR/run/user/0"
    mount -t tmpfs -o "size=99%" tmpfs "$MNT_DIR/run/user/0"
    mount -t proc chproc "$MNT_DIR/proc"
    mount -t sysfs chsys "$MNT_DIR/sys"
    mount --bind /dev "$MNT_DIR/dev"
    mount -t devpts chpts "$MNT_DIR/dev/pts" || mount --bind /dev/pts "$MNT_DIR/dev/pts"
}

# Enter chroot environment
enter_chroot() {
    chroot "$MNT_DIR" /bin/bash || true
}

# Main function
main() {
    ensure_root
    setup_mount_dirs
    attach_image
    mount_partitions
    enter_chroot
    echo "Sandbox session complete."
}

# Run main function
main
