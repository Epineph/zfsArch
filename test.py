#!/usr/bin/env python3
import os
import subprocess
import sys
import glob

iso_dir = os.getenv('HOME')
# absolute path to search all text files inside a specific folder
path = 'iso_dir/ISOBUILD/zfsiso/ISOOUT/*.iso'
print(glob.glob(path))


def run_command(command):
    """Run a shell command and return its output"""
    try:
        output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT)
        return output.decode()
    except subprocess.CalledProcessError as e:
        return e.output.decode()

def create_bootable_usb():
    if len(sys.argv) > 1:
      iso_path = glob.glob(path)
    else:
        iso_path = input("Enter the path to the ISO file: ")
    print("Hello, World!")
    # Get user input
    usb_device = input("Enter the USB device path (e.g., /dev/sdx): ").strip()
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
    create_bootable_usb()
