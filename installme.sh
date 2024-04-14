#!/bin/bash

echo "Creating ZFS pool and filesystem structure..."
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

# Create the root filesystem
zfs create -o mountpoint=none zfsroot/sys

# Create intermediate node for archzfs
zfs create -o canmount=off -o mountpoint=none zfsroot/sys/archzfs

# Create the ROOT dataset
zfs create -o mountpoint=/ -o canmount=noauto zfsroot/sys/archzfs/ROOT

# Create the default sub-dataset under ROOT
zfs create zfsroot/sys/archzfs/ROOT/default

# Create home dataset
zfs create -o mountpoint=/home zfsroot/sys/archzfs/home

# Create system directories under ROOT
system_datasets=('var/lib/systemd/coredump' 'var/log' 'var/log/journal' 'var/lib/lxc' 'var/lib/lxd' 'var/lib/machines' 'var/lib/libvirt' 'var/cache' 'usr/local')
for ds in ${system_datasets[@]}; do
    zfs create -o mountpoint=/$ds zfsroot/sys/archzfs/ROOT/$ds
done

# Setup user datasets
user_datasets=("${user_name}" "${user_name}/.local" "${user_name}/.config" "${user_name}/.cache")
for ds in ${user_datasets[@]}; do
    zfs create -o mountpoint=/home/$ds zfsroot/sys/archzfs/home/$ds
done

# Set permissions for the user
zfs allow "$user_name" create,mount,mountpoint,snapshot zfsroot/sys/archzfs/home/$user_name

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

