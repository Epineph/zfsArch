#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Display available disks
echo "Available disks:"
lsblk -d --output NAME,SIZE,MODEL

# Ask user for disks to use
read -p "Enter disk IDs for installation separated by space (e.g., sda sdb nvme0n1): " -a disk_ids

echo "You have selected: ${disk_ids[@]}"
read -p "Proceed with these disks? This will remove existing data. [y/N] " confirmation
if [[ $confirmation != "y" ]]; then
    echo "Exiting installation."
    exit 1
fi

# Ensure disks are ready and exist
for disk in "${disk_ids[@]}"; do
    if [ ! -b "/dev/$disk" ]; then
        echo "Error: Disk /dev/$disk does not exist."
        exit 2
    fi
done

# Ask if the EFI partition should be formatted
read -p "Do you want to format the EFI partition? This will remove existing bootloaders. [y/N] " format_efi

# Create partitions on each disk
for disk in "${disk_ids[@]}"; do
    echo "Creating partitions on /dev/$disk..."
    sgdisk --zap-all "/dev/$disk"  # Clear existing partition table

    # Optionally format the EFI partition
    efi_part_suffix="1"
    swap_part_suffix="2"
    zfs_part_suffix="3"
    if [[ $disk == nvme* ]]; then
        efi_part_suffix="p1"
        swap_part_suffix="p2"
        zfs_part_suffix="p3"
    fi

    if [[ $format_efi == "y" ]]; then
        sgdisk -n1:0:+512M -t1:ef00 "/dev/${disk}${efi_part_suffix}"  # EFI
    fi

    sgdisk -n2:0:+2G -t2:8200 "/dev/${disk}${swap_part_suffix}"  # Swap
    sgdisk -n3:0:+210G -t3:bf00 "/dev/${disk}${zfs_part_suffix}"  # ZFS
done

# Allow the system to recognize new partitions
sleep 5

echo "Partition creation complete."

# Construct root and swap partition identifiers
root_partitions=()
swap_partitions=()
for disk in "${disk_ids[@]}"; do
    if [[ $disk == nvme* ]]; then
        root_partitions+=("/dev/${disk}p3")
        swap_partitions+=("/dev/${disk}p2")
    else
        root_partitions+=("/dev/${disk}3")
        swap_partitions+=("/dev/${disk}2")
    fi
done

# Create ZFS pool with RAID0
echo "Creating ZFS pool..."
zpool create -f -o ashift=12 \
    -O acltype=posixacl \
    -O relatime=on \
    -O xattr=sa \
    -O dnodesize=auto \
    -O normalization=formD \
    -O mountpoint=none \
    -O canmount=off \
    -O devices=off \
    -R /mnt zfsroot "${root_partitions[@]}"

# Create ZFS filesystem structure
zfs create -o mountpoint=none zfsroot/sys
zfs create -o canmount=off -o mountpoint=none zfsroot/sys/archzfs
zfs create -o mountpoint=/ -o canmount=noauto zfsroot/sys/archzfs/ROOT/default
zfs create -o mountpoint=/home zfsroot/sys/archzfs/home

# More ZFS and system configuration...
# More ZFS and system configuration...
# Apply ZFS settings for system directories
system_datasets=('var/lib/systemd/coredump' 'var/log' 'var/log/journal' 'var/lib/lxc' 'var/lib/lxd' 'var/lib/machines' 'var/lib/libvirt' 'var/cache' 'usr/local')
for ds in ${system_datasets[@]}; do 
    zfs create -o mountpoint=/${ds} "zfsroot/sys/archzfs/${ds}"
done

# Setup user datasets
# Define user datasets array
user_datasets=("${user_name}" "${user_name}/.local" "${user_name}/.config" "${user_name}/.cache")

# Create ZFS datasets for the user
for ds in "${user_datasets[@]}"; do 
    zfs create -o mountpoint=/home/${ds} "zfsroot/sys/archzfs/home/${ds}"
done


# Set permissions
zfs allow "$user_name" create,mount,mountpoint,snapshot "zfsroot/sys/archzfs/home/$user_name"

# Create and activate swap
echo "Creating a ZFS swap volume of size ${swap_size_gb}GB..."
zpool create -f swapzpool -o ashift=12 -O compression=zle -O devices=off -O sync=always -m none -R /mnt "${swap_partitions[@]}"
zfs create -V "${swap_size_mb}M" -b $(getconf PAGESIZE) -o logbias=throughput -o primarycache=metadata -o secondarycache=none -o com.sun:auto-snapshot=false swapzpool/swap
mkswap /dev/zvol/swapzpool/swap
swapon /dev/zvol/swapzpool/swap

# Final steps and cleanup
echo "Finalizing setup..."
zfs set canmount=noauto zfsroot/sys/archzfs/ROOT/default
zfs mount zfsroot/sys/archzfs/ROOT/default
zfs umount -a
zpool export zfsroot
zpool import -d /dev/disk/by-id -R /mnt zfsroot -N
zfs mount zfsroot/sys/archzfs/ROOT/default
mkdir -p /mnt/{boot/efi,etc}
mount "/dev/${disk_ids[0]}1" /mnt/boot/efi

# Configure mkinitcpio.conf
sed -i 's/^HOOKS.*/HOOKS=(base udev autodetect modconf block keyboard zfs filesystems)/' /etc/mkinitcpio.conf
cp /etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf

# Configure pacman.conf
echo -e "\n[archzfs]\nServer = http://archzfs.com/\$repo/x86_64" >> /mnt/etc/pacman.conf
curl -O https://archzfs.com/archzfs.gpg
pacman-key -a archzfs.gpg
pacman-key --lsign-key DDF7DB817396A49B2A2723F7403BD972F75D9D76
pacman -Syy

# Ask for CPU and GPU type
read -p "Enter your CPU type (AMD/Intel): " cpu_type
read -p "Do you have an NVIDIA graphics card? (y/N): " nvidia

# Prepare package installation
base_packages="base base-devel linux linux-headers sudo nano vim linux-firmware"
case $cpu_type in
    AMD|amd) cpu_ucode="amd-ucode" ;;
    Intel|intel) cpu_ucode="intel-ucode" ;;
    *) echo "Invalid CPU type entered, defaulting to AMD"; cpu_ucode="amd-ucode" ;;
esac

zfs_packages="zfs-dkms"
nvidia_packages=""
if [[ $nvidia =~ [yY] ]]; then
    nvidia_packages="nvidia-dkms nvidia-utils nvidia-settings"
fi

# Confirm package installation
recommended_packages="$base_packages $cpu_ucode $zfs_packages $nvidia_packages"
echo "Recommended packages to install: $recommended_packages"
read -p "Do you want to proceed with these packages? (Y/n): " proceed
if [[ $proceed =~ [nN] ]]; then
    read -p "Enter packages to install or type 'a' to abort: " custom_packages
    if [[ $custom_packages == "a" ]]; then
        echo "Aborting installation."
        exit 1
    fi
    pacstrap /mnt -P -K $custom_packages
else
    pacstrap /mnt -P -K $recommended_packages
fi

# Final steps and cleanup
genfstab -U /mnt >> /mnt/etc/fstab
echo "Installation setup complete. Please continue with system configuration."

# Adding ZFS swap to fstab
echo "/dev/zvol/swapzpool/swap none swap defaults 0 0" >> /mnt/etc/fstab

