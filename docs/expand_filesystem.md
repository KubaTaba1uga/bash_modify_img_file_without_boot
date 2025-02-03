# Expanding a Raspberry Pi OS Image File

## Overview
By default, Raspberry Pi OS `.img` files may be too small to accommodate additional software and modifications. This guide describes how to expand the image file by a few gigabytes using `parted`.

## Prerequisites
- A Linux system with root access
- The following utilities installed:
  - `parted`
  - `resize2fs`
  - `e2fsck`
- A Raspberry Pi OS image file

## Steps to Expand the Image

### 1. Increase the Image File Size
Expand the `.img` file by a desired amount (e.g., 5GB):

```bash
truncate -s +5G /path/to/image.img
```

Alternatively, you can use `dd`:

```bash
dd if=/dev/zero bs=1G count=5 >> /path/to/image.img
```

### 2. Run `sandbox.sh` Before Resizing
To properly operate within the image file, first run `sandbox.sh`:

```bash
sudo bash sandbox.sh /path/to/image.img
```

### 3. Identify Root Filesystem Device and Resize the Partition Using `parted`
Before using `parted`, identify the device where the root filesystem is mounted:

```bash
lsblk
```

Use `parted` inside the image:

```bash
sudo parted /dev/loop0
(parted) print
(parted) resizepart 2 100%
(parted) quit
```

This expands partition #2 to use the available space.

### 4. Check and Resize the Filesystem
After resizing the partition, check and expand the filesystem:

```bash
sudo e2fsck -f /dev/loop0p2
sudo resize2fs /dev/loop0p2
```

### 5. Verify Changes
To confirm the expansion check available space:

```bash
df -h /
```





