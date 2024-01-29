
#!/bin/bash

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
EFI_PARTITION_1="/dev/nvme1n1p1"; EFI_PARTITION_2="/dev/nvme0n1p1"; EFI_PARTITION_3="/dev/sda8"
BOOT_PARTITION_1="/dev/nvme1n1p7"; BOOT_PARTITION_2="/dev/nvme0n1p6"; BOOT_PARTITION_3="/dev/sda10"
DISK_NAME_1="/dev/nvme1n1"; DISK_NAME_2="/dev/nvme0n1"; DISK_NAME_3="/dev/sda"

DISK_ARRAY="/dev/nvme1n1p6 /dev/nvme0n1p4 /dev/sda4"

mdadm --create /dev/md/boot --level=0 --raid-disks=3 --metadata=1.0 $BOOT_PARTITION_1 $BOOT_PARTITION_2 $BOOT_PARTITION_3

#sgdisk -N 1 -t 1:8300 -c 1:"Linux filesystem" /dev/md0
mkfs.ext4 /dev/md/boot



IFS=' ' read -r -a DISK_ARRAY <<< "$DISK_ARRAY"

for i in "${!DISK_ARRAY[@]}"; do
    eval "DISK$((i+1))=${DISK_ARRAY[$i]}"
done

DISK1="/dev/nvme1n1p6"
DISK2="/dev/nvme0n1p4"
DISK3="/dev/sda4"

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
    -R /mnt $ZFS_POOL_NAME $DISK1 $DISK2 $DISK3


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

zfs allow heini create,mount,mountpoint,snapshot ${SYS_ROOT}/${SYSTEM_NAME}/home/heini

zfs allow ${SYS_ROOT}/${SYSTEM_NAME}/home/heini


zfs create -V 16G -b $(getconf PAGESIZE) -o compression=off \
    -o logbias=throughput -o sync=always -o primarycache=metadata \
    -o secondarycache=none -o com.sun:auto-snapshot=false \
    $ZFS_POOL_NAME/swap
mkswap $SWAP_VOL
swapon $SWAP_VOL


zpool export zroot

zfs umount -a

cd /mnt


rm -rf ./*


zpool import -d /dev/nvme0n1p4 -R /mnt zroot -N

# zpool import zroot -R /mnt


zfs mount -a

df -k

zpool set bootfs="${SYS_ROOT}/${SYSTEM_NAME}/ROOT/default zroot"
zpool set cachefile=/etc/zfs/zpool.cache zroot

mkdir -p /mnt/{etc/zfs,boot/efi}

cp /etc/zfs/zpool.cache /mnt/etc/zfs/zpool.cache

mkdir -p /mnt/boot
mount /dev/md/boot /mnt/boot

mdadm --detail --scan --verbose  >> /mnt/etc/mdadm.conf

arch-chroot /mnt

sudo sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block keyboard mdadm_udev zfs filesystem)/' \
    /etc/mkinitcpio.conf
#/sbin/mdmon


groupadd -g 1234 group
useradd -g group -u 1234 -d /home/$USER_NAME -s /bin/bash $USER_NAME
cp /etc/skel/.bash* /home/$USER_NAME
chown -R $USER_NAME:group /home/$USER_NAME && chmod 700 /home/$USER_NAME

grub-install --boot-directory=/boot --bootloader-id=ArchLinux --target=x86_64-efi --efi-directory=/boot --recheck
grub-mkconfig -o /boot/grub/grub.cfg

    # Duplicate boot partition to second drive    
umount $DISK1
dd if=$EFI_PARTITION_1 of=$EFI_PARTITION_2 status=progress; dd if=$EFI_PARTITION_1 of=$EFI_PARTITION_3 status=progress

    # Add second drive to UEFI boot list
efibootmgr -c -g -d $EFI_PARTITION_2 -p 1 -L "ArchLinux #2" -l '\EFI\ArchLinux\grubx64.efi'
efibootmgr -c -g -d $EFI_PARTITION_3 -p 1 -L "ArchLinux #3" -l '\EFI\ArchLinux\grubx64.efi'


systemctl enable NetworkManager sshd zfs-import-cache zfs-import-scan enable zfs-mount 
systemctl enable zfs-share zfs-zed zfs.target zfs-import.target

touch /etc/modprobe.d/zfs.conf && echo "options scdi_mod scan=sync" >> /etc/modprobe.d/zfs.conf

mkdir -p /boot/EFI/zbm

wget https://get.zfsbootmenu.org/latest.EFI -O /boot/EFI/zbm/zfsbootmenu.EFI

efibootmgr --disk $DISK_NAME_1 --part 1 --create --label "ZFSBootMenu" --loader '\EFI\zbm\zfsbootmenu.EFI' \
    --unicode "spl_hostid=$(hostid) zbm.timeout=3 zbm.prefer=zroot zbm.import_policy=hostid" --verbose

zfs set org.zfsbootmenu:commandline="noresume init_on_alloc=0 rw spl.spl_hostid=$(hostid)" \
    ${SYS_ROOT}/${SYSTEM_NAME}/ROOT/default

bootctl --path=/boot install

echo -e "default arch\ntimeout 10" | tee -a /boot/loader/loader.conf 

touch /boot/loader/entries/arch.conf

echo -e "title Arch Linux\nlinux /vmlinuz-linux\ninitrd /amd-ucode.img\n\
initrd /initramfs-linux.img\noptions zfs=rpool/ROOT/default rw" \
    >> /boot/loader/entries/arch.conf



mkdir -p /etc/pacman.d/hooks/

touch /etc/pacman.d/hooks/100-systemd-boot.hook

echo -e "[Trigger]\nType = Package\nOperation = Upgrade\nTarget = systemd"\
    >> /etc/pacman.d/hooks/100-systemd-boot.hook

echo -e "\n[Action]\nDescription = update systemd-boot\nWhen = PostTransaction"\
    >> /etc/pacman.d/hooks/100-systemd-boot.hook

echo -e "Exec = /usr/bin/bootctl update" >> /etc/pacman.d/hooks/100-systemd-boot.hook
