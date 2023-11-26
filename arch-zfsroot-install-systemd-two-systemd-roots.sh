#!/bin/bash
#Install ZFS rootfs on Arch Linux with systemd initrd
#
# This is an example that creates two rootfs to demonstrate
# the problem caused by having multiple datasets with their
# mountpoint set to / (plus alternative config to fix it)
#
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
	     -O xattr=sa \
	     -O acltype=posix \
	     -O atime=off \
	     -O compression=lz4 \
	     -O recordsize=64k

# Create a dataset
zfs create -p "$ZPOOL"/ROOT/root1 -o mountpoint=/root1
zfs create -p "$ZPOOL"/ROOT/root2 -o mountpoint=/root2

# Install OS to the zpool
echo installing...
pacstrap /root1
pacstrap /root2

# Build systemd ZFS hook
pacman --noconfirm -Sy make gcc fakeroot
cd /tmp
curl https://aur.archlinux.org/cgit/aur.git/snapshot/mkinitcpio-sd-zfs.tar.gz | tar zx
chown -R nobody: mkinitcpio-sd-zfs
cd mkinitcpio-sd-zfs
sudo -u nobody makepkg
cp /tmp/mkinitcpio-sd-zfs/mkinitcpio-sd-zfs-1.0.2-1-any.pkg.tar.zst /root1
arch-chroot /root1 pacman --noconfirm -U /mkinitcpio-sd-zfs-1.0.2-1-any.pkg.tar.zst
cp /tmp/mkinitcpio-sd-zfs/mkinitcpio-sd-zfs-1.0.2-1-any.pkg.tar.zst /root2
arch-chroot /root2 pacman --noconfirm -U /mkinitcpio-sd-zfs-1.0.2-1-any.pkg.tar.zst
cd $OLDPWD

# Continue install inside chroot
# Add ZFS dependencies (including compatible Linux kernel) and rebuild the initramfs
for r in 1 2; do
arch-chroot "/root$r" << EOF
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
done

#
# Essentials
# Optional setup below
# Configure network, ssh and the ubiquitous vim
#
for r in 1 2; do
arch-chroot "/root$r" << EOF
nic="$(basename /sys/class/net/en*)"
echo -e "[Match]\nName=\$nic\n[Network]\nDHCP=yes" > "/etc/systemd/network/20-\$nic-dhcp.network"
systemctl enable systemd-{network,resolve}d
pacman --noconfirm -S openssh vim
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
systemctl enable sshd
echo "root$r.example.com" > /etc/hostname
EOF
done

# add BIOS boot partition to the disks (required by Grub)
for disk in "${DISKS[@]}"
do
  sgdisk -n 2:34:2047 -t 2:EF02 "$disk" -c 2:"BIOS Boot Partition"
  partx -u "$disk"
done

# Install Grub
echo ${DISKS[@]} | ZPOOL_VDEV_NAME_PATH=1 xargs -n 1 grub-install --root-directory="/root1"
echo ${DISKS[@]} | ZPOOL_VDEV_NAME_PATH=1 xargs -n 1 grub-install --root-directory="/root2"

# Write basic grub configuration to boot the zpool
for r in 1 2; do
cat > "/root$r/boot/grub/grub.cfg" << EOF
insmod part_gpt
menuentry 'Arch Linux ZFS root1' {
  echo 'Searching ...'
  search --set --label "$ZPOOL"
  echo 'Loading kernel ...'
  linux /ROOT/root1@/boot/vmlinuz-linux root="zfs:$ZPOOL/ROOT/root1" rw
  echo 'Loading initramfs ...'
  initrd /ROOT/root1@/boot/initramfs-linux.img
  echo 'Booting ...'
}
menuentry 'Arch Linux ZFS root2' {
  echo 'Searching ...'
  search --set --label "$ZPOOL"
  echo 'Loading kernel ...'
  linux /ROOT/root2@/boot/vmlinuz-linux root="zfs:$ZPOOL/ROOT/root2" rw
  echo 'Loading initramfs ...'
  initrd /ROOT/root2@/boot/initramfs-linux.img
  echo 'Booting ...'
}
EOF
done

#
# UNCOMMENT THE BELOW TWO zfs set COMMANDS TO ALLOW BOOT TO WORK
# BOOT DOES NOT WORK IF MULTIPLE DATASETS HAVE "mountpoint=/"
#
#zfs set mountpoint=none org.zol:mountpoint=/ "$ZPOOL"/ROOT/root1
#zfs set mountpoint=none org.zol:mountpoint=/ "$ZPOOL"/ROOT/root2

# Export the pool so bootloader can import it
zpool export "$ZPOOL"
