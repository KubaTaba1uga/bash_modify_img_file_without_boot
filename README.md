# Modify IMG file without boot

## Overview
This script allows you to mount and chroot into a Raspberry Pi OS image file. It automates the process of attaching the image to a loop device, mounting partitions, and entering a chroot environment for modifications.

## Requirements
- A Linux system with root access
- The following utilities installed:
  - `losetup`
  - `fdisk`
  - `mount`
  - `chroot`
  - `awk`
- A Raspberry Pi OS image file

## Usage

Run the script with root privileges, providing the path to the image file as an argument:

```bash
sudo bash sandbox.sh /path/to/image.img [--arm64]
```

If you are running the script on x86 architecture remember to include `--arm64` flag. 

### Flashing the Image to an SD Card
To write the `.img` file to an SD card, use the following command:

```bash
sudo dd if=<.img file path> of=<sd card path> bs=4M status=progress conv=fsync
```

**Example:**
```bash
sudo dd if=/path/to/image.img of=/dev/sdX bs=4M status=progress conv=fsync
```
*(Replace `/dev/sdX` with your actual SD card device path. Be careful, as this operation is destructive.)*


## Script Functionality
1. **Checks for Root Privileges**
   - Ensures the script is run as root.

2. **Accepts Image File as an Argument**
   - Requires the user to provide a valid `.img` file.

3. **Creates a Temporary Mount Directory**
   - A randomly generated directory is used for mounting.

4. **Attaches Image to a Loop Device**
   - Uses `losetup` to map the image partitions.

5. **Extracts and Mounts Partitions**
   - The boot and root partitions are identified and mounted.
   - A `tmpfs` is used for temporary files.

6. **Enters the Chroot Environment**
   - Allows modifications to the mounted filesystem.

7. **Automatic Cleanup**
   - Ensures unmounting and removal of the temporary directory upon script exit.

## Example Output
```
Loop Device: /dev/loop0
Boot Partition: /dev/loop0p1
Root Partition: /dev/loop0p2
Entering chroot...
Sandbox session complete.
```

## Troubleshooting
- **Mount point does not exist:** Ensure the image is valid and contains expected partitions.
- **Permission denied:** Ensure the script is run with `sudo`.

## Testing
This script has been tested on Raspberry Pi OS.

## License
This script is licensed under the MIT License. Modify and distribute as needed.

