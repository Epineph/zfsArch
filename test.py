#!/usr/bin/env python3
import subprocess
import sys

def run_command(command):
    try:
        output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT)
        return output.decode()
    except subprocess.CalledProcessError as e:
        return e.output.decode()

def create_bootable_usb(iso_path, usb_device):
    # User input for partition sizes
    partition1_size = input("Enter the size (in MB) for the first partition: ").strip()
    partition2_size = input("Enter the size (in MB) for the second partition (optional, press Enter to skip): ").strip()


    # Partition the USB Drive
    partition_command_1 = f"echo -e 'o\\nn\\np\\n1\\n\\n+{partition1_size}M\\nw' | fdisk {usb_device}"
    print(f"Running command: {partition_command_1}")
    print(run_command(partition_command_1))

    if partition2_size:
        partition_command_2 = f"echo -e 'n\\np\\n2\\n\\n+{partition2_size}M\\nw' | fdisk {usb_device}"
        print(f"Running command: {partition_command_2}")
        print(run_command(partition_command_2))

    # Format the Partition(s)
    format_command_1 = f"mkfs.fat -F 32 {usb_device}1"
    print(f"Running command: {format_command_1}")
    print(run_command(format_command_1))

    if partition2_size:
        format_command_2 = f"mkfs.ext4 {usb_device}2"
        print(f"Running command: {format_command_2}")
        print(run_command(format_command_2))

    # Mount the first partition
    mount_command = f"mount {usb_device}1 /mnt"
    print(f"Running command: {mount_command}")
    print(run_command(mount_command))

    # Extract the ISO image
    extract_command = f"bsdtar -x -f {iso_path} -C /mnt"
    print(f"Running command: {extract_command}")
    print(run_command(extract_command))

    # Additional steps for copying files, unmounting, etc., can be added here.

    return "Bootable USB creation process complete!"

# Run the script
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 script.py [ISO_PATH] [USB_DEVICE]")
        sys.exit(1)
    create_bootable_usb(sys.argv[1], sys.argv[2])
