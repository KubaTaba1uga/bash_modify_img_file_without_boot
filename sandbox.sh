#!/bin/bash
set -euo pipefail  # Exit on error

IMG_FILE="/tmp/2024-11-19-raspios-bookworm-arm64-lite.img"  # Change this to your actual image file
MNT_DIR="/mnt/sandbox"
BOOT_DIR="/mnt/sandbox/boot"
LOOP_DEV=""
ROOT_PART=""
BOOT_PART=""

# Create mount directories
mkdir -p "$MNT_DIR"
mkdir -p "$BOOT_DIR"
mkdir -p "$MNT_DIR/run/user/0"

# Attach the .img file to a loopback device with partition scanning
LOOP_DEV=$( losetup --find --show --partscan "$IMG_FILE")

# Get partition details using fdisk
PART_INFO=$(fdisk -l "$IMG_FILE")

# Extract partition offsets
BOOT_START=$(echo "$PART_INFO" | awk '/W95 FAT32/{print $2}' | head -n 1)
ROOT_START=$(echo "$PART_INFO" | awk '/Linux/{print $2}' | head -n 1)

# Determine partition paths
BOOT_PART="${LOOP_DEV}p1"
ROOT_PART="${LOOP_DEV}p2"

# Debug Output
echo "Loop Device: $LOOP_DEV"
echo "Boot Partition Offset: $BOOT_START"
echo "Root Partition Offset: $ROOT_START"
echo "Boot Partition: $BOOT_PART"
echo "Root Partition: $ROOT_PART"

if [[ -z "$ROOT_PART" || -z "$BOOT_PART" ]]; then
    echo "Error: Could not find required partitions. Check the image file."
     losetup -d "$LOOP_DEV"
    exit 1
fi

mount "$ROOT_PART" "$MNT_DIR"
mount "$BOOT_PART" "$BOOT_DIR"

# Use tmpfs instead of binding host directories
mount -t tmpfs -o "size=99%" tmpfs "$MNT_DIR/tmp"
mount -t tmpfs -o "size=99%" tmpfs "$MNT_DIR/var/tmp"
mkdir -p "$MNT_DIR/run/"
mkdir -p "$MNT_DIR/run/user"
mount -t tmpfs -o "size=99%" tmpfs "$MNT_DIR/run/user/0"


# Mount essential system directories
 mount -t proc chproc "$MNT_DIR/proc"
 mount -t sysfs chsys "$MNT_DIR/sys"
 mount --bind /dev "$MNT_DIR/dev"
 mount -t devpts chpts "$MNT_DIR/dev/pts" ||  mount --bind /dev/pts "$MNT_DIR/dev/pts"

# Enter the chroot environment
 chroot "$MNT_DIR" /bin/bash || true

# Cleanup after exit
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
 losetup -d "$LOOP_DEV"

echo "Sandbox session complete."
