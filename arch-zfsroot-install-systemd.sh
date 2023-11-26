#!/bin/bash
#Install ZFS rootfs on Arch Linux with systemd initrd
#JL20180619 revised JL20230729

# Parameters - adjust accordingly
ZPOOL=tank
RAIDZ=mirror
DISKS=( /dev/disk/by-id/ata-QEMU_HARDDISK_QM0000{1,2} )

# Ensure zpool offline
zpool list "$ZPOOL" &> /dev/null && zpool export "$ZPOOL" && zpool destroy "$ZPOOL"

# Zap disk partition tables
echo "${DISKS[@]}" | xargs -n 1 sgdisk -Z

# Create a new zpool; use -O to set default dataset preferences
# The altroot is non-persistent - just used during installation
zpool create -m none "$ZPOOL" "$RAIDZ" "${DISKS[@]}" \
	     -o altroot="/$ZPOOL" \
	     -O xattr=sa \
	     -O acltype=posix \
	     -O atime=off \
	     -O compression=lz4 \
	     -O recordsize=64k

# Create a dataset
zfs create -p "$ZPOOL"/ROOT/archlinux -o mountpoint=/

# Install OS to the zpool
echo installing...
pacstrap /"$ZPOOL"

# Build systemd ZFS hook
pacman --noconfirm -Sy make gcc fakeroot
cd /tmp
curl https://aur.archlinux.org/cgit/aur.git/snapshot/mkinitcpio-sd-zfs.tar.gz | tar zx
chown -R nobody: mkinitcpio-sd-zfs
cd mkinitcpio-sd-zfs
sudo -u nobody makepkg
cp /tmp/mkinitcpio-sd-zfs/mkinitcpio-sd-zfs-1.0.2-1-any.pkg.tar.zst "/$ZPOOL/"
arch-chroot "/$ZPOOL" pacman --noconfirm -U /mkinitcpio-sd-zfs-1.0.2-1-any.pkg.tar.zst
rm "/$ZPOOL/"mkinitcpio-sd-zfs-1.0.2-1-any.pkg.tar.zst
cd $OLDPWD

# Continue install inside chroot
# Add ZFS dependencies (including compatible Linux kernel) and rebuild the initramfs
arch-chroot "/$ZPOOL" << EOF
echo -e '[archzfs]\nSigLevel = Optional TrustAll\nServer = http://archzfs.com/\$repo/\$arch' >> /etc/pacman.conf
pacman -Sy --noconfirm
pacman -S  --noconfirm mkinitcpio
pacman -U --noconfirm "https://archive.archlinux.org/packages/l/linux/linux-$(uname -r | sed 's/-/./')-x86_64.pkg.tar.zst"
sed -i -e '/^HOOKS=(/s/udev/systemd/'                   \
       -e '/^HOOKS=/s/filesystems.*)/sd-zfs)/' \
           /etc/mkinitcpio.conf
pacman -S --noconfirm zfs-linux
cp /usr/lib/modules/\$(uname -r)/vmlinuz /boot/vmlinuz-linux
systemctl preset \$(tail -n +2 /usr/lib/systemd/system-preset/50-zfs.preset | cut -d ' ' -f 2)
mkinitcpio -p linux
zpool set cachefile=/etc/zfs/zpool.cache "$ZPOOL"
echo "root:root" | chpasswd
exit
EOF

#
# Essentials
# Optional setup below
# Configure network, ssh and the ubiquitous vim
#
arch-chroot "/$ZPOOL" << EOF
nic="$(basename /sys/class/net/en*)"
echo -e "[Match]\nName=\$nic\n[Network]\nDHCP=yes" > "/etc/systemd/network/20-\$nic-dhcp.network"
systemctl enable systemd-{network,resolve}d
pacman --noconfirm -S openssh vim
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
systemctl enable sshd
EOF

# add BIOS boot partition to the disks (required by Grub)
for disk in "${DISKS[@]}"
do
  sgdisk -n 2:34:2047 -t 2:EF02 "$disk" -c 2:"BIOS Boot Partition"
  partx -u "$disk"
done

# Install Grub
echo ${DISKS[@]} | ZPOOL_VDEV_NAME_PATH=1 xargs -n 1 grub-install --root-directory="/$ZPOOL"

# Write basic grub configuration to boot the zpool
cat > "/$ZPOOL/boot/grub/grub.cfg" << EOF
insmod part_gpt
menuentry 'Arch Linux ZFS' {
  insmod part_gpt
  echo 'Searching ...'
  search --set --label "$ZPOOL"
  echo 'Loading kernel ...'
  linux /ROOT/archlinux@/boot/vmlinuz-linux root="zfs:$ZPOOL/ROOT/archlinux" rw
  echo 'Loading initramfs ...'
  initrd /ROOT/archlinux@/boot/initramfs-linux.img
  echo 'Booting ...'
}
EOF

# Set mountpoint as expected by sd-zfs
zfs set mountpoint=none org.zol:mountpoint=/ "$ZPOOL"/ROOT/archlinux

# Export the pool so bootloader can import it
zpool export "$ZPOOL"
