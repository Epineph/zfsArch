#!/bin/bash

# Section I - Creating the custom zfs-based Arch Linux image
# If you wonder why, then it is because the officially supported
# Arch linux image or .iso file cannot be used to install zfs OS
# Architecture

# Follow along building at the same location if you want to copy
# and paste, but you can install anywhere. Just keep an eye on
# where the things are located in the ISOBUILD folder so everything
# is located correctly relative to it.

sudo pacman -S archiso # important package that we need to build the customized arch iso image

cd ~ # 
mkdir ISOBUILD

cp -r /usr/share/archiso/configs/releng ISOBUILD/

# This copies files from the archiso recursively into our build dir


cd ISOBUILD # this should be located in ~/ISOBUILD or /home/<yourusername>/ISOBUILD

#rename the dir to zfsiso
mv /releng/ zfsiso

cd 
```

# I you don't have any AUR helped such as yay or paru, 
# then you need to get one or youc can follow these steps. 
# Just skip if you already have. Futhermore, you do not have to put 
# the AUR's in `/opt` and put them where you like. Just remember go 
# back to the home directory `~` before you continue
# if you do so, unless you use another location as reference.

cd /opt

sudo pacman -S git # if git isn't already installed on your system


sudo git clone https://aur.archlinux.org/yay.git
sudo git clone https://aur.archlinux.org/paru-bin.git

# users generally have restricted permissions at /opt 
# you can therefore most likely not allowed clone packages
# to this clone packages to this location without using sudo. 
# To give the user 'u' read 'r' and 'write', you can:

sudo chmod u+rw /path/to/file

# to change permission to read and write more than one file, or
# indeed to all files residing in /opt you can pass -R to resursively change
# permission for all files in this folder and all subdirectories within it:

sudo chmod -R u+rw /opt

# Generally be cautious changing permissions for folders and files,
# especially when doing it recursively. That said, doing it in /opt
# is safe


cd /yay

# to install yay which is a popular AUR helper, then

makepkg -si PKGBUILD # or simply 'makepkg -si'

# another popular option paru. Since you do not need several
# AUR helpers, you can just skip the next three commands
# If you want paru instead or if you want both (you are not required
# have more than one, but you are not restricted to having 
# two or more either):

cd .. # to put you back to /opt or cd to directory you cloned it in

cd /paru-bin

makepkg -si PKGBUILD


# if you are done installing your preferred AUR helper, both
# or already had an AUR helper installed, then proceed from here and

cd ~

# If you do have yay/paru or if you are done with these steps, 
# you can continue from here.

# Now we need to get 2 important packages for our custom .iso file. 
# We need to get the `zfs-dkms` and `zfs-utils` from the 
# AUR (Arch User Repository).

# It may take a few minutes to build both packages.


sudo pacman -S git # if you do not have git installed already

git clone https://aur.archlinux.org/zfs-dkms.git

cd zfs-dkms/


makepkg --skippgpcheck # I would generally not recommend skip pgp check
# but doing so can save time if you trust the source

cd # should take you back to ~

git clone https://aur.archlinux.org/zfs-utils.git

cd zfs-utils/

makepkg --skippgpcheck

cd

# Now we have built the important packages needed to build the iso,
# so we go back to building it


cd /ISOBUILD/zfsiso # if you use the same directories, then you should be at ~/ISOBUILD/zfsiso

# Next, we need to make a directory for the zfs repository

mkdir zfsrepo

cd zfsrepo

# next, we copy all the .zst filles from then two packages we built to this location

# copies the .zst files from the directories we built them in, i.e., `~`,
# to the location we are currently in, specified by ` .`

cp ~/zfs-dkms/*.zst . # which here is equivalent to 
# cp ~/zfs-dkmt/*.zst ~/ISOBUILD/zfsiso/zfsrepo

cp ~/zfs-utils/*.zst .

ls -al
# Create the database

repo-add zfsrepo.db.tar.gz *.zst

cd ..

# should take you to ~/ISOBUILD/zfsiso

sudo nano packages.x86_64

# add the following in the bottom of /etc/pacman.conf
# you can use sudo nano/vim /etc/pacman.conf


[zfsrepo]
SigLevel = Optional TrustAll
Server = file:///home/heini/ISOBUILD/zfsiso/zfsrepo


# or

echo "[zfsrepo]" | sudo tee -a /etc/pacman.conf
echo "SigLevel = Optional TrustAll" | sudo tee -a /etc/pacman.conf
echo "Server = file:///home/heini/ISOBUILD/zfsiso/zfsrepo" | sudo tee -a /etc/pacman.conf


# We need to include the packages we built in the custom .iso

# add these lines to ~/ISOBUIKD/zfsiso/packages.x86_64


# [ZFS Custom  Repo]
linux-headers
zfs-dkms
zfs-utils

#alternatively, use tee to append these lines

echo "# [ZFS Custom Repo]" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64
echo "linux-headers" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64
echo "zfs-dkms" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64
echo "zfs-utils" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64


# edit custom repository

sudo nano /etc/pacman.conf

# add this custom repository in the buttom like this:

[zfsrepo]
SigLevel = Optional TrustAll
Server = file:///home/heini/ISOBUILD/zfsiso/zfsrepo

#remember to change /home/heini/ with your username
# to make sure, then:

cd /ISOBUID/zfsiso/zfsrepo
pwd # should return the path of location

echo "[zfsrepo]" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64
echo "SigLevel = Optional TrustAll" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64
echo "Server = file:///home/heini/ISOBUILD/zfsiso/zfsrepo" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64


# Lastly, we create two additiional directories to be created for our
# custom .iso

# you are expected to be at ~/ISOBUILD/zfsiso

mkdir {WORK,ISOOUT}

# that is to say, ~/ISOBUILD/zfsiso/{WORK,ISOOUT} or the folders WORK
# and ISOOUT are subdirectories of ~/ISOBUILD/zfsiso

# Before changin to root (and do not change location prior to this)

# Ensure that you do not lack any permissions iso

chmod -R +rwx ~/ISOBUILD/ # rwx gives read, write and execute permissions

# we want to do the same for root, so before changing
# assign the location if the iso to a variable since "~" means
# /root for root. So first we store the value as user

cd ~/ISOBUILD/zfsiso

ISO_dir=$(pwd)
#change to root

su root


chmod -R +rwx ISO_dir


#this will build this custom .iso
mkarchiso -v -w WORK -o ISOOUT .

# create bootable usb medium from the custom arch .iso we just created

lsblk

cp ~/ISOBUILD/zfsiso/ISOOUT/archlinux-2023.10.31-x86_64.is /dev/sdX
# X is a placeholder for what your usb is called. 

reboot

# Part II - Installation of zfs


loadkeys dk
# change keyboard layout as seems fit to you, default is usually us

setfont ter-128n # if you find the font to be too small

# if still too small, try setfont ter-132b
# increasing font size, which may be especially helpful when using
# certain monitors (the package is called terminus-font), and is
# is usually not on a filesystem after installation,
# unless installed on your filesystem - it can be useful
# if you boot up in a destopless environment after installation
# and is pre-installed on most official arch .iso files

# as during a normal arch installation, if you have a wired
# connection you should already be online and you can skip
# the following command. 

# if you need wifi, use:

iwctl

# this command should put you into a new prompt [iwd]:
# and is already provided by the .iso from the iwd package
# if you want it post-install (not needed, but good to have)

# wait installing before you have reached and executed arch-chroot /mnt 
# and you are inside your system
# pacman -S iwd

# check device list for if other terms are used
# device and adapters are usually on, if yours are called
# something else run

device list #wlan0 for me
adapter list #phy0 for me

# If you need to turn device and adapter on

device wlan0 set-property on
adapter phy0 set-property on

# connect to wifi

station wlan0 connect <yourWiFiname> # check your wifi name by: station wlan0 get-networks

# if you don't remember wifi name

station wlan0 scan
station wlan0 get-networks

# if the command works:
station wlan0 connect <yourWiFiname>

# then you get asked to write paraphrase (password)
# after hitting enter hold ctrl and press c
# should put you back to the terminal

#Here is an example of a basic partition scheme that could be employed for your ZFS root install on a BIOS/MBR installation using GRUB:

# here you can use:

gdisk /dev/nvme0nX #or /dev/sdX where the letter X is # placeholder
# and should be replaced with what appears on your
# own hard-drive

# remember to check the labelling of hard-drives and partitions
# on your own system using:

lsblk -l 

# or use your preferred package to set up your hard-drive
# and partitions, e.g., fdisk or cfdisk /dev/nvme1nX

# according to the official arch wiki, many different configuration
# can be used for a zfs installation, e.g.,

#Part     Size   Type
#----     ----   -------------------------
#   1     XXXG   Solaris Root (bf00)

# here, here (bf00) indicates the code used when changing
# partition type using the command 't' in gfisk or fdisk
# followed by the number of the partiton after which you
# execute use execute: bf00 which creates a solaris
# root partition. Note that isn't necessary and 'type' in
# this context is not important and is only the labelling
# and the the installation should work regardless of
# whether the the partition is formatted as something different
# and zfa handles it differently and you don't have to format
# the partition using (skip this bit):
mkfs.ext4 /dev/nvme0nX # or as you would using btrfs:
mkfs.btrfs /dev/nvme0nX
# it makes no difference and has no impact in the context of
# this installation. However, whether you use a MBR or GPT
# partition table, i.e., a Master Boot Record or GUID Partition
# Table, respectively, (I will use the latter during this installation)
# 


# using GRUB on a BIOS (or UEFI machine in legacy boot mode) machine 
# but using a GPT partition table:

#Part     Size   Type
#----     ----   -------------------------
#   1       2M   BIOS boot partition (ef02)
#   2     XXXG   Solaris Root (bf00)


#Another example, this time using a UEFI-specific bootloader
# (such as rEFInd) with an GPT partition table:

#Part     Size   Type
#----     ----   -------------------------
#   1     600M   EFI boot partition (ef00)
#   2     XXXG   Solaris Root (bf00)

# I will use a table that has a form like the one
# above, using grub as bootloader (making it compatible with
# dual booting it together with other linux as well as windows 
# installations)

# as will be highlighted later, you may want to choose using
# mirroring or striping and in those cases you should have another
# partition on another physical hard drive as well
# in theory you can use 2 partitions on the same physical
# hard-drive, but in that case the benefits that will be discussed
# later are no longer applicable, leaving only con's and no pro's
# and hence not feasible option. Just keep in mind
# that you do not have to have a EFI partition
# on the other physical hard drive, and a single bootloader is enough


#if modules do not load correctly, try:

#curl -s https://raw.githubusercontent.com/eoli3n/archiso-zfs/master/init | bash


modprobe zfs

lsmod | grep -i zfs

# if you do not plan to use a mirrored partition, which may improve
# write and read speed by increasing the bandwith, but at the cost of
# space, hence consider that id you are using a large hard-drive,
# the amount of space used it twice as big, and therefore consider
# the pro's and con's with respect to the size of the mirrored partition,
# and hence the trade-off with respect to this variable.

# if you do not want mirrored partitions, and you want to ensure that it
# works if you use grub to boot up your system, then consider using the
# following command

zpool create -o compatibility=grub2 zroot /dev/nvme0n1pX #X indicating the
# the label on your harddrive, run lsblk or lsblk -l to see your
# current set-up, if you are using a partitioned hard-drive. If using this,
# then skip the following commands until you reach the bit starting with
# "zfs create"

# otherwise, these options are listed on the arch wiki, but I can confirm
# that, if you are using grub, you may experience issues with running
# grub-install ... with grub complaining about not recognizing your
# file-system. The command above circumvents that, at least in my case, 
# assuming that you haven't done anything else differently to what
# is presented here

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


zpool create -o ashift=12 -d \
-o compatibility=grub2 \
-R /mnt /dev/sdx1 /dev/sdy1


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

#According to the official arch wiki:
#GRUB-compatible pool creation

#By default, zpool create enables all features on a pool. If /boot resides on ZFS 
# when using GRUB #you must only enable features supported by GRUB otherwise,
# GRUB will not be able to read the #pool. ZFS includes compatibility
#  files (see /usr/share/zfs/compatibility.d) to assist
# in creating #pools at specific feature sets, of which grub2 is an option.

#You can create a pool with only the compatible features enabled:

zpool create -o compatibility=grub2 $POOL_NAME $VDEVS

# if you want to see an example of this, please refer to the
# example demonstrated previously above (a few lines above from here)


#check status
zpool status



# If you want to create a mirrored ZFS pool with `grub2` compatibility"
# Here's a step-by-step guide:
				ÅÅPÅPP# 1. 
# Load the ZFS module (if you haven't already)
# remember the information provided here is not, and to my
# my understanding, the official arch .iso file cannot be used
# to install zfs, as of November 1. 2023, and might or might not
# have changed since then, though no public plans of this have
# been released, so it is probable that this is true in the forseeable
# future.

bash
modprobe zf	

# before deciding to mirrror your filesystem and execute the commands bellow, please
# consider the factors given below since they are extremely important with regards
# to informing your decision, both copy your system on two partitions and thus
# require twice as much space, but rather than mirrorring your filesystem on two seperate physical devices
# which offers data redundancy and therefore protection,

zpool create -o compatibility=grub2 -o ashift=12 \
-O acltype=posixacl \
-O relatime=on \
-O xattr=sa \
-O dnodesize=legacy \
-O normalization=formD \
-O mountpoint=none \
-O canmount=off \
-O devices=off \
-R /mnt \
rpool mirror /dev/sda2 /dev/sdb2
# if you want your filesystem to be one two rather than one partition (and there
are good reasons for doing this, despite it sounding like nothing but a 
significant drawback and question not worth asking. You may be forgiven for thinking this,
but there are ultimately several factors important to consider it.


# further, if you have 2 hard drives (which may offer you more space than you need 
# making the drawbacks of this option less important, since the degree of
# of constraint imposed on you is quite limited. Depending on factors such as 
# this, as well as your preferences and current hardware, you would further 
# benefit from consdering whether to mirror or whether to stripe your filesystem. 
# This is explained in more detail below.

# definitions

# .1. **Mirroring (RAID 1)**: Data is duplicated across two or more drives. 
# This means that if you have two drives, each drive contains an identical 
# copy of the data. It provides redundancy. If one drive fails, the other 
# still has all the data. 

# Importantly, Read performance can be improved because data can
# be read from both drives, but write performance is the same as a single 
# drive because the same data must be written to both drives.

# 2. **Striping (RAID 0)**: Data is divided into blocks and each block 
# is written to a separate disk drive. For example, with two drives, the 
# first block goes to the first drive, the second block to the second drive, 
# the third block back to the first drive, and so on. 

# Importantly, striping provides improved performance since data is 
# read/written from/to both drives simultaneously. However, there's no 
# mredundancy; if one drive fails, all the data is lost because half of the 
# data blocks are on each drive.

# Therefore, if you have two hard-drives, i.e. two different physical devices that you
# use to store you data on, you experience more benefits from sacricing 
# half of your available space! Depending on thr degree to which performance 
# is the parameter of interest and hence also the variable or factor most 
# imoortant with respect to informing your decision to sacrifice space for 
# mostly security reasons as well as some limited performance benefits.
# Therefore, depending on your preferences weighing security with some limited
# performance benefits your file system, which on one hand doesn't doesn't 
# offer any protection , but on the other hand, gives you the max benefit 
#in both read and write speed.

#For ZFS, the commands are similar. Here's how you would create a striped 
#pool using ZFS:

```bash
zpool create -o ashift=12 \
             -O acltype=posixacl \
             -O relatime=on \
             -O xattr=sa \
             -O dnodesize=legacy \
             -O normalization=formD \
             -O mountpoint=none \
             -O canmount=off \
             -O devices=off \
             -R /mnt \
             zroot /dev/sda2 /dev/sdb2
```

#This command stripes the data between `/dev/sda2` and `/dev/sdb2`.

#Just remember that while striping will give you the best performance of the
# two, it comes with the significant drawback of no data redundancy. 
#If either SSD fails, you'll lose all the data in the ZFS pool. 
#Ensure you have good backups if you go 

#3. Now, proceed with your dataset creations:

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

# zpool import zroot -R /mnt

zfs mount zroot/ROOT/default
zfs mount -a

df -k


zpool set bootfs=zroot/ROOT/default zroot
zpool set cachefile=/etc/zfs/zpool.cache zroot

mkdir -p /mnt/{etc/zfs,boot/efi}

cp /etc/zfs/zpool.cache /mnt/etc/zfs/zpool.cache

# mount the /mnt/boot/efi

```bash
mount /dev/nvme0n1p1 /mnt/boot/efi

pacman -Syy

pacstrap /mnt base base-devel amd-ucode git linux linux-headers linux-firmware linux-firmware-whence dkms sudo nano vim grub efibootmgr networkmanager reflector mtools dosfstools wpa_supplicant

```
At this point, we create and it is important to note that since I chose to stripe root partition, the swap
will be as well. pay attention to that we haven't made a swap partition, or indeed 2 8gb swap partitions, with 8gb being striped
from each physical device.  but that is fine, since you can in your imagination think that manages this by using 8gb from each root partition for swiping. Again, these layers of abstraction work differently on zfs and just truat if you have installed it correctly,
you will find that everything is handled properly by zfs.

```bash
zfs create -V 16G -b $(getconf PAGESIZE) -o logbias=throughput -o sync=always -o primarycache=metadata -o com.sun:auto-snapshot=false sroot/swap
mkswap -f /dev/zvol/zroot/swap
swapon /dev/zvol/zroot/swap
```

then as usual:

```bash
genfstab -U -p /mnt >> /mnt/etc/fstab

cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist.backup

arch-chroot /mnt
```

cat /etc/fstab

# comment-out all zroot entries except boot

nano /etc/pacman.conf
# go to the bottom and add the following:

```
[archzfs]
Server = https://archzfs.com/$repo/x86_64
```


or do it like this:

```bash
echo -e "[archzfs]\nServer = https://archzfs.com/\$repo/\$arch\nSigLevel = Optional TrustAll" >> /etc/pacman.conf
```

Then import and sign this key:

```bash
# ArchZFS GPG keys (see https://wiki.archlinux.org/index.php/Unofficial_user_repositories#archzfs)
pacman-key -r DDF7DB817396A49B2A2723F7403BD972F75D9D76
pacman-key --lsign-key DDF7DB817396A49B2A2723F7403BD972F75D9D76
```
For your kernel, then you can choose either zfs-dkms or zfs-linux:

For example:

```bash
pacman -S zfs-linux zfs-linux-headers
```

Alternatively:

```bash
pacman -S zfs-dkms

# if you have nvidia, you can use it together with

pacman -S nvidia-dkms
```

Next, edit the comfiguration file located at: /etc/pacman.conf
Here you want to add `zfs` to your hooks.

You can configure your hooks in the following way:

`HOOKS = (base udev autodetect modconf block keyboard zfs filesystem)`

Just use your favorite editor (e.g., nano or vim) or, for example:

```bash
sudo sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block keyboard zfs filesystem)/' /etc/mkinitcpio.conf
```

Here are some important packages (you have have installed some of them already):

```bash
pacman -S base-devel efibootmgr grub networkmanager network-manager-applet openssh os-prober reflector rsync terminus-font wpa_supplicant xdg-user-dirs xdg-utils zsh grml-zsh-configs  refind
```

For grub to work we also need to configure `/etc/default/grub`

Find the line (using nano or vim) and edit it accordingly:

`GRUB_CMDLINE_LINUX="root=ZFS=zroot/ROOT/default"`

Or

```bash
sudo sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="root=ZFS=zroot\/ROOT\/default"/' /etc/default/grub
```

This part is important. Before when we created the zpool, we included
`compatibility=grub2`

If you haven't included this or made some other configuration, grub
may not recognize the filesystem. If everything is in order, there
should be no error:

```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux

grub-mkconfig -o /boot/grub/grub.cfg
```

systemctl enable NetworkManager

systemctl enable sshd

systemctl enable reflector.timer

systemctl enable zfs-import-cache

systemctl enable zfs-import-scan

systemctl enable zfs-mount

systemctl enable zfs-share

systemctl enable zfs-zed

ssystemctl enable zfs.target

ln -sf /usr/share/zoneinfo/Europe/Copenhagen /etc/localtime
hwclock --systohcno

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

