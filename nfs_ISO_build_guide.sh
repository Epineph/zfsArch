# Need to do this on a previous arch installation

sudo pacman -S archiso

mkdir ISOBUILD

cp -r /usr/share/archiso/configs/releng ISOBUILD/

cd ISOBUILD

mv /releng/ zfsiso

cd

git clone https://aur.archlinux.org/zfs-dkms.git

cd zfs-dkms/

makepkg --skippgpcheck

cd

git clone https://aur.archlinux.org/zfs-utils.git

cd zfs-utils/

makepkg --skippgpcheck

cd

cd /ISOBUILD/zfsiso

mkdir zfsrepo

cd zfsrepo

cp ~/zfs-dkms/*.zst .

cp ~/zfs-utils/*.zst .

ls -al

# Create the database

repo-add zfsrepo.db.tar.gz *.zst

cd ..

sudo nano packages.x86_64

# add this in the bottom

# ZFS Custom  Repo

linux-headers
zfs-dkms
zfs-utils

# edit pacman.configs

sudo nano pacman.configs

# add this custom repository in the buttom like this:

[zfsrepo]
SigLevel = Optional TrustAll
Server = file:///home/<username>/ISOBUILD/zfsiso/zfsrepo

mkdir {WORK,ISOOUT}

#change to root

su root

#this will build this custom .iso
mkarchiso -v -w WORK -o ISOOUT .

# create bootable usb medium

cp /home/heini/ISOBUILD/zfsiso/ISOOUT/archlinux-2023.10.31-x86_64.is
o /dev/sda

reboot


Partition the destination drive

Here is an example of a basic partition scheme that could be employed for your ZFS root install on a BIOS/MBR installation using GRUB:

Part     Size   Type
----     ----   -------------------------
   1     XXXG   Solaris Root (bf00)

Using GRUB on a BIOS (or UEFI machine in legacy boot mode) machine but using a GPT partition table:

Part     Size   Type
----     ----   -------------------------
   1       2M   BIOS boot partition (ef02)
   2     XXXG   Solaris Root (bf00)


Another example, this time using a UEFI-specific bootloader (such as rEFInd) with an GPT partition table:

Part     Size   Type
----     ----   -------------------------
   1     100M   EFI boot partition (ef00)
   2     XXXG   Solaris Root (bf00)



#if modules do not load correctly, try:

curl -s https://raw.githubusercontent.com/eoli3n/archiso-zfs/master/init | bash


modprobe zfs

lsmod | grep i zfs

zpool create -f -o ashift=12 \
-O acltype=posixacl \
-O relatime=on \
-O xattr=sa \
-O dnodesize=legacy \
-O normalization=formD \
-O mountpoint=none \
-O canmount=off \
-O devices=off \
-R /mnt \
zroot /dev/nvme0n1p4


#Compression and native encryption

#This will enable compression and native encryption by default on all datasets:

zpool create -f -o ashift=12         \
             -O acltype=posixacl       \
             -O relatime=on            \
             -O xattr=sa               \
             -O dnodesize=legacy       \
             -O normalization=formD    \
             -O mountpoint=none        \
             -O canmount=off           \
             -O devices=off            \
             -R /mnt                   \
             -O compression=lz4        \
             -O encryption=aes-256-gcm \
             -O keyformat=passphrase   \
             -O keylocation=prompt     \
             zroot /dev/disk/by-id/id-to-partition-partx

#GRUB-compatible pool creation

#By default, zpool create enables all features on a pool. If /boot resides on ZFS when using GRUB #you must only enable features supported by GRUB otherwise GRUB will not be able to read the #pool. ZFS includes compatibility files (see /usr/share/zfs/compatibility.d) to assist in creating #pools at specific feature sets, of which grub2 is an option.

#You can create a pool with only the compatible features enabled:

zpool create -o compatibility=grub2 $POOL_NAME $VDEVS




#check status
zpool status


zfs create -o mountpoint=none zroot/data
zfs create -o mountpoint=none zroot/ROOT
zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/default
zfs create -o mountpoint=/home zroot/data/home
zfs create -o mountpoint=/var -o canmount=off zroot/var

zfs create zroot/var/log
zfs create -o mountpoint=/var/lib -o canmount=off zroot/var/lib
zfs create zroot/var/lib/libvirt
zfs create zroot/var/lib/docker


zpool export zroot

zpool import -d /dev/nvme0n1p4 -R /mnt zroot -N

zfs mount zroot/ROOT/default
zfs mount .a

df -k


zpool set bootfs=zroot/ROOT/default zroot
zpool set cachefile=/etc/zfs/zpool.cache zroot

mkdir -p /mnt/{etc/zfs,boot/efi}

cp /etc/zfs/zpool.cache /mnt/etc/zfs/zpool.cache

mount /dev/nvme0n1p1 /mnt/boot/efi


pacman -Syy

pacstrap /mnt base base-devel amd-ucode git linux linux-headers linux-firmware linux-firmware-whence dkms sudo nano vim grub efibootmgr networkmanager reflector mtools dosfstools wpa_supplicant

genfstab -U -p /mnt >> /mnt/etc/fstab

cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist.backup

arch-chroot /mnt


cat /etc/fstab

# comment-out all zroot entries

nano pacman.conf
# add
[archzfs]
SigLevel = Optional TrustAll
Server = https://zxcvfdsa.com/archzfs/$arch

or

echo "[archzfs]" | tee -a /etc/pacman.conf
echo "SigLevel = Optional TrustAll" | tee -a /etc/pacman.conf
echo "Server = https://zxcvfdsa.com/archzfs/$arch" | tee -a /etc/pacman.conf

consider adding:

[archzfs]
Include = /etc/pacman.d/archzfs_mirrorlist

nano /etc/pacman.d/archzfs_mirrorlist

Server = https://archzfs.com/$repo/$arch
Server = https://mirror.sum7.eu/archlinux/archzfs/$repo/$arch
Server = https://mirror.biocrafting.net/archlinux/archzfs/$repo/$arch
Server = https://mirror.in.themindsmaze.com/archzfs/$repo/$arch
Server = https://zxcvfdsa.com/archzfs/$repo/$arch

#if it doesn't exist
mkdir -p /usr/share/pacman/keyrings

touch /usr/share/pacman/keyrings/archzfs-trusted
echo "DDF7DB817396A49B2A2723F7403BD972F75D9D76:4:" | tee -a /usr/share/pacman/keyrings/archzfs-trusted

pacman -S zfs-linux


# edit /etc/pacman.conf

HOOKS= (base udev autodetect modconf block keyboard zfs filesystem)

pacman -S base-devel efibootmgr grub networkmanager network-manager-applet openssh os-prober reflector rsync terminus-font wpa_supplicant xdg-user-dirs xdg-utils zsh grml-zsh-configs  refind

#edit /etc/default/grub

GRUB_CMDLINE_LINUX="root=ZFS=zroot/ROOT/default"
#potentially
GRUB_CMDLINE_LINUX_DEFAULT="loglevel 3 quiet video=1920x1080"


grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux

grub-mkconfig -o /boot/grub/grub.cfg


systemctl enable NetworkManager

systemctl enable sshd

systemctl enable reflector.timer

systemctl enable zfs-import-cache

systemctl enable zfs-import-scan

systemctl enable zfs-mountpoint

systemctl enable zfs-share

systemctl enable zfs-zed

ssystemctl enable zfs.target

ln -sf /usr/share/zoneinfo/Europe/Copenhagen /etc/localtime
hwclock --systohc

sed -i 's/#en_DK.UTF-8/en_DK.UTF-8' /etc/locale.gen && locale-gen

echo "LANG=en_DK.UTF-8" >> /etc/locale.conf

echo "zfs-arch" >> /etc/hostname


echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1             localhost" >> /etc/hosts
echo "127.0.1.1 zfs-arch.localdomain zfs-arch" >> /etc/hosts

useradd -mU -s /bin/zsh -G \
sys,log,network,floppy,scanner,power,rfkill,users,video,storage,optical,lp,audio,wheel,adm \
heini

passwd

passwd heini

EDITOR=nano visudo

#uncomment this line
%wheel ALL=(ALL) ALL

cd /etc/xdg/reflector

mv reflector.conf reflector.conf.orig
cp reflector.conf.orig reflector.conf
nano reflector.conf

#/etc/xdg/reflector/reflector.conf
--country Denmark,Germany,United Kingdom,Sweden,Norway,Iceland,Netherlands,France
--protocol https
--latest 5
--sort rate
--save /etc/pacman.d/mirrorlist


