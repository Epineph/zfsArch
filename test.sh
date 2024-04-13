#!/bin/bash


USER_NAME="heini"
ZFS_POOL_NAME="zfsroot"
ZFS_DATA_POOL_NAME="zfsdata"
ZFS_SYS="sys"
SYS_ROOT="${ZFS_POOL_NAME}/${ZFS_SYS}"
SYSTEM_NAME="archzfs"
DATA_STORAGE="data"
DATA_ROOT="${ZFS_POOL_NAME}/${DATA_STORAGE}"
ZVOL_DEV="/dev/zvol"
SWAP_VOL="${ZVOL_DEV}/${ZFS_POOL_NAME}/swap"

#sgdisk --zap-all /dev/disk/by-id/<disk0>
#sgdisk -n1:0:+512M -t1:ef00 /dev/disk/by-id/<disk0>
#sgdisk -n2:0:+8G -t2:8200 /dev/disk/by-id/<disk0>
#sgdisk -n3:0:+210G -t3:bf00 /dev/disk/by-id/<disk0>

#sgdisk --zap-all /dev/disk/by-id/<disk1>
#sgdisk -n1:0:+512M -t1:ef00 /dev/disk/by-id/<disk1>
#sgdisk -n2:0:+8G -t2:8200 /dev/disk/by-id/<disk1>
#sgdisk -n3:0:+210G -t3:bf00 /dev/disk/by-id/<disk1>



# Prompt user for partition inputs and convert them into arrays
read -p "Enter EFI partition: " -a EFI_PARTITIONS
read -p "Enter ROOT partitions separated by space: " -a ROOT_PARTITIONS

# zfs set acltype=posixacl <nameofzpool>/<nameofdataset>
# zfs set xattr=sa <nameofzpool>/<nameofdataset>


# zfs set aclinherit=passthrough <nameofzpool>
# zfs set acltype=posixacl <nameofzpool>
# 



# Now you can use $DISK1, $DISK2, etc.

zpool create -f -o ashift=12 \
    -O acltype=posixacl \
    -O relatime=on \
    -O xattr=sa \
    -O dnodesize=auto \
    -O normalization=formD \
    -O mountpoint=none \
    -O canmount=off \
    -O devices=off \
    -R /mnt $ZFS_POOL_NAME "${ROOT_PARTITIONS[@]}"


zfs create -o mountpoint=none -p ${SYS_ROOT}/${SYSTEM_NAME}
zfs create -o canmount=off -o mountpoint=none ${SYS_ROOT}/${SYSTEM_NAME}/ROOT
zfs create -o mountpoint=/ -o canmount=noauto ${SYS_ROOT}/${SYSTEM_NAME}/ROOT/default
zfs create -o mountpoint=/home ${SYS_ROOT}/${SYSTEM_NAME}/home
zfs create -o mountpoint=none ${SYS_ROOT}/${SYSTEM_NAME}/ROOT
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

zfs create -o mountpoint=/var/log/journal -o acltype=posixacl ${SYS_ROOT}/${SYSTEM_NAME}/var/log/journal

USER_DATASETS='heini heini/.local heini/.config heini/.cache'
for ds in ${USER_DATASETS}; do 
    zfs create -o mountpoint=/${ds} \
    ${SYS_ROOT}/${SYSTEM_NAME}/home/"${ds}"
done



#zfs create -o mountpoint=/${SYS_ROOT}/${SYSTEM_NAME}/home/heini/.local/share -o canmount=off ${SYS_ROOT}/${SYSTEM_NAME}/home/heini/.local/share
zfs create -o mountpoint=/home/heini/.local/share \
    -o canmount=off ${SYS_ROOT}/${SYSTEM_NAME}/home/heini/local/share

#zfs create -o mountpoint=/home/heini/.local/share/Steam \
#   ${SYS_ROOT}/${SYSTEM_NAME}/home/heini/local/share/Steam
#zfs create -o mountpoint=/${SYS_ROOT}/${SYSTEM_NAME}/home/heini/.local/share/Steam ${SYS_ROOT}/${SYSTEM_NAME}/home/heini/.local/share/Steam

zfs create -o mountpoint=none ${DATA_ROOT}

DATA_DATASETS='Books Computer Personal Pictures University Workspace Reference'

for ds in ${DATA_DATASETS}; do
    zfs create -o mountpoint=/${DATA_ROOT}/${ds} ${DATA_ROOT}/"${ds}"
done

zfs allow heini create,mount,mountpoint,snapshot ${SYS_ROOT}/${SYSTEM_NAME}/home/heini

zfs allow ${SYS_ROOT}/${SYSTEM_NAME}/home/heini


zfs create -V 16G -b $(getconf PAGESIZE) -o compression=off \
    -o logbias=throughput -o sync=always -o primarycache=metadata \
    -o secondarycache=none -o com.sun:auto-snapshot=false \
    $ZFS_POOL_NAME/swap
mkswap $SWAP_VOL
swapon $SWAP_VOL

zfs umount -a
zpool export $ZFS_POOL_NAME

zfs import ${SYS_ROOT}/${SYSTEM_NAME}/ROOT/default
zfs mount -a


(cd /mnt && rm -rf ./*)

zpool import -d "${ROOT_PARTITIONS[0]}" -R /mnt $ZFS_POOL_NAME -N

zfs import

mkdir -p /mnt/{boot/efi,etc/zfs}
mount $EFI_PARTITION /mnt/boot/efi

zpool set cachefile=/etc/zfs/zpool.cache $ZFS_POOL_NAME
cp /etc/zfs/zpool.cache /mnt/etc/zpool.cache

genfstab -U /mnt >> /mnt/etc/fstab
echo "${SWAP_VOL}    none       swap  discard                    0  0" >> /mnt/etc/fstab
