#!/bin/bash
swap_partitions=("nvme1n1p3" "nvme0n1p2")
root_partition=("nvme1n1p4" "nvme0n1p3")
USER_NAME="heini"
ZFS_POOL_NAME="zroot"
ZFS_DATA_POOL_NAME="zfsdata"
ZFS_SYS="sys"
SYS_ROOT="${ZFS_POOL_NAME}/${ZFS_SYS}"
SYSTEM_NAME="archzfs"
DATA_STORAGE="data"
DATA_ROOT="${ZFS_POOL_NAME}/${DATA_STORAGE}"
ZVOL_DEV="/dev/zvol"
SWAP_VOL="${ZVOL_DEV}/${ZFS_POOL_NAME}/swap"


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

zfs create -o mountpoint=none -p ${SYS_ROOT}/${SYSTEM_NAME}
zfs create -o mountpoint=none ${SYS_ROOT}/${SYSTEM_NAME}/ROOT
zfs create -o mountpoint=/ ${SYS_ROOT}/${SYSTEM_NAME}/ROOT/default
zfs create -o mountpoint=/home ${SYS_ROOT}/${SYSTEM_NAME}/home
zfs create -o canmount=off -o mountpoint=/var -o xattr=sa ${SYS_ROOT}/${SYSTEM_NAME}/var
zfs create -o canmount=off -o mountpoint=/var/lib ${SYS_ROOT}/${SYSTEM_NAME}/var/lib
zfs create -o canmount=off -o mountpoint=/var/lib/systemd ${SYS_ROOT}/${SYSTEM_NAME}/var/lib/systemd
zfs create -o canmount=off -o mountpoint=/usr ${SYS_ROOT}/${SYSTEM_NAME}/usr


SYSTEM_DATASETS='var/lib/systemd/coredump var/log var/log/journal '
SYSTEM_DATASETS+='var/lib/lxc var/lib/lxd var/lib/machines var/lib/libvirt var/cache usr/local'

# for ds in ${SYSTEM_DATASETS}; do 
#     zfs create -o mountpoint=${ds} ${SYS_ROOT}/${SYSTEM_NAME}/${ds};
# done

for ds in ${SYSTEM_DATASETS}; do 
  zfs create -o mountpoint=/${SYS_ROOT}/${SYSTEM_NAME}/${ds} \
  ${SYS_ROOT}/${SYSTEM_NAME}/"${ds}"
done

#zfs create -o mountpoint=/var/log/journal -o acltype=posixacl ${SYS_ROOT}/${SYSTEM_NAME}/var/log/journal

USER_DATASETS='heini heini/local heini/config heini/cache'
for ds in ${USER_DATASETS}; do 
    zfs create -o mountpoint=/${SYS_ROOT}/${SYSTEM_NAME}/${ds} \
    ${SYS_ROOT}/${SYSTEM_NAME}/home/"${ds}"
done

#zfs create -o mountpoint=/${SYS_ROOT}/${SYSTEM_NAME}/home/heini/.local/share -o canmount=off ${SYS_ROOT}/${SYSTEM_NAME}/home/heini/.local/share
zfs create -o mountpoint=/home/heini/.local/share \
    -o canmount=off ${SYS_ROOT}/${SYSTEM_NAME}/home/heini/local/share

zfs create -o mountpoint=/home/heini/local/share/Steam \
    ${SYS_ROOT}/${SYSTEM_NAME}/home/heini/local/share/Steam
#zfs create -o mountpoint=/${SYS_ROOT}/${SYSTEM_NAME}/home/heini/.local/share/Steam ${SYS_ROOT}/${SYSTEM_NAME}/home/heini/.local/share/Steam

zfs create -o mountpoint=none ${DATA_ROOT}

DATA_DATASETS='Books Computer Personal Pictures University Workspace Reference'

for ds in ${DATA_DATASETS}; do
    zfs create -o mountpoint=/${DATA_ROOT}/${ds} ${DATA_ROOT}/"${ds}"
done


# Set permissions for the user
zfs allow "$user_name" create,mount,mountpoint,snapshot zfsroot/sys/archzfs/home/$user_name

# Create and activate swap
echo "Creating a ZFS swap volume of size $GB..."
zpool create -f swapzpool -o ashift=12 -O compression=zle -O devices=off -O sync=always -m none -R /mnt "${swap_partitions[@]}"
zfs create -V "24G" -b $(getconf PAGESIZE) -o logbias=throughput -o primarycache=metadata -o secondarycache=none -o com.sun:auto-snapshot=false swapzpool/swap
mkswap /dev/zvol/swapzpool/swap
swapon /dev/zvol/swapzpool/swap

# Final steps and cleanup
echo "Finalizing setup..."
zfs set canmount=noauto zfsroot/sys/archzfs/ROOT/default
zfs mount zfsroot/sys/archzfs/ROOT/default
zfs umount -a
zpool export zfsroot
zpool import -d /dev/nvme1n1p4 -R /mnt zfsroot -N
zfs mount zfsroot/sys/archzfs/ROOT/default
zfs mount -a
mkdir -p /mnt/{boot/efi,etc/zfs}
mount /dev/nvme1n1p1 /mnt/boot/efi

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

