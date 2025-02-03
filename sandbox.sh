#!/bin/bash
set -euo pipefail  # Exit on error

# Ensure script is run with an image file argument
if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $0 <path-to-image-file> [--arm64]"
    exit 1
fi

# Define global variables
IMG_FILE="$1"
MNT_DIR="$(mktemp -d)"
BOOT_DIR="$MNT_DIR/boot"
LOOP_DEV=""
ROOT_PART=""
BOOT_PART=""
USE_ARM64=false

# Check for optional --arm64 flag
if [[ $# -eq 2 && "$2" == "--arm64" ]]; then
    USE_ARM64=true
fi

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

    # Unregister QEMU from binfmt_misc if needed
    if [[ -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]]; then
        echo -1 > /proc/sys/fs/binfmt_misc/qemu-aarch64
    fi

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

# Setup QEMU for ARM64 if flag is enabled
setup_qemu_arm64() {
    if [[ "$USE_ARM64" == true ]]; then
        echo "Setting up QEMU for ARM64..."

        systemctl restart systemd-binfmt

        # Ensure qemu-user-static is installed
        if ! command -v qemu-aarch64-static &> /dev/null; then
            echo "qemu-user-static not found. Installing..."
            apt update && apt install -y qemu-user-static
        fi

        # Ensure qemu-aarch64 entry exists in binfmt_misc
        if [[ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]]; then
            echo "Error: qemu-aarch64 is not registered in binfmt_misc. Exiting."
            exit 1
        fi

        # Extract QEMU interpreter path from /proc/sys/fs/binfmt_misc/qemu-aarch64
        QEMU_PATH=$(awk '/interpreter/{print $2}' /proc/sys/fs/binfmt_misc/qemu-aarch64)

        # Validate extracted path
        if [[ -z "$QEMU_PATH" || ! -f "$QEMU_PATH" ]]; then
            echo "Error: Could not extract valid QEMU interpreter path from binfmt_misc. Exiting."
            exit 1
        fi

        echo "Using QEMU interpreter: $QEMU_PATH"

        # Copy QEMU into the chroot environment
        cp "$QEMU_PATH" "$MNT_DIR/usr/bin/"

        echo "QEMU setup complete."
    fi
}

enter_chroot() {
    chroot "$MNT_DIR" /bin/bash
}

# Main function
main() {
    ensure_root
    setup_mount_dirs
    attach_image
    mount_partitions
    setup_qemu_arm64
    enter_chroot
    echo "Sandbox session complete."
}

# Run main function
main

