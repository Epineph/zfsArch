# Need to do this on a previous arch installation
# the goal is to install arch on a nfs system

# first we make an .iso file by following the commands below (remember to
# to change the username so that it matches yours)

#pkg needed to make custom arch iso
sudo pacman -S archiso

mkdir ISOBUILD

#this is the dir we create to make the .iso file in

cp -r /usr/share/archiso/configs/releng ISOBUILD/

# copies files from the archiso recursively into our build dir

cd ISOBUILD

#rename the dir to zfsiso
mv /releng/ zfsiso

cd

# executing "cd" alone takes us back to the home dir where we will need to
# clone 2 packages from the AUR, which we will need to build the custom
# arch zfs-iso

# if you don't have any AUR helped such as yay or paru, 
# if you do, ignore this step, then do the following:

cd /opt

sudo git clone https://aur.archlinux.org/yay.git
sudo git clone https://aur.archlinux.org/paru-bin.git

sudo chmod -R u+rwx /opt
cd /yay
makepkg -si PKGBUILD
cd ..
cd /paru-bin
makepkg -si PKGBUILD

cd ~
# skip to here if you do have yay/paru or if you are done with these steps

#now we clone zfs-dkms and zfs-utils which we will need
git clone https://aur.archlinux.org/zfs-dkms.git

cd zfs-dkms/

#you should probably not pass --skippgpcheck for security, but here it is
# if the laziness of saving some time prevails
makepkg --skippgpcheck

cd

#we do the same for this package
git clone https://aur.archlinux.org/zfs-utils.git

cd zfs-utils/

makepkg --skippgpcheck

cd

# now we go back to the build dir
cd /ISOBUILD/zfsiso

# create a dir for the zfs repo
mkdir zfsrepo

cd zfsrepo

# next, we copy all the .zst filles from then two packages we built
# which we will need for the iso creation
cp ~/zfs-dkms/*.zst .

cp ~/zfs-utils/*.zst .

ls -al

# Create the database

repo-add zfsrepo.db.tar.gz *.zst

cd ..

sudo nano packages.x86_64

# add this in the bottom:

# ZFS Custom  Repo

linux-headers
zfs-dkms
zfs-utils

#alternatively, use tee to append these lines
echo "linux-headers" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64
echo "zfs-dkms" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64
echo "zfs-utils" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64

# edit pacman.configs

sudo nano pacman.conf

# add this custom repository in the buttom like this:

[zfsrepo]
SigLevel = Optional TrustAll
Server = file:///home/heini/ISOBUILD/zfsiso/zfsrepo
#remember to swap heini with your username


#next, we create two additiional directories
mkdir {WORK,ISOOUT}

#change to root
#do not change dir. If you are lost, go back to /home/heini/ISOBUILD/zfsiso

su root

#this will build this custom .iso
mkarchiso -v -w WORK -o ISOOUT .

# create bootable usb medium from the custom arch .iso we just created

cp /home/heini/ISOBUILD/zfsiso/ISOOUT/archlinux-2023.10.31-x86_64.is
o /dev/sda

reboot

## now the .iso file is complete.
## the next bit is done after rebooting and booting from the custom
## .iso arch file above

#from the arch wiki
#Partition the destination drive

loadkeys dk
# change keyboard layout as seems fit to you

setfont ter-128n
# increasing font size, which may be especially helpful when using
# certain monitors (the package is called terminus-font), and is
# is usually not on a filesystem after installation,
# unless installed on your filesystem - it can be useful
# if you boot up in a destopless environment after installation
# and is pre-installed on most official arch .iso files

#Here is an example of a basic partition scheme that could be employed for your ZFS root install on a BIOS/MBR installation using GRUB:

#Part     Size   Type
#----     ----   -------------------------
#   1     XXXG   Solaris Root (bf00)

#using GRUB on a BIOS (or UEFI machine in legacy boot mode) machine but using a GPT partition table:

#Part     Size   Type
#----     ----   -------------------------
#   1       2M   BIOS boot partition (ef02)
#   2     XXXG   Solaris Root (bf00)


#Another example, this time using a UEFI-specific bootloader (such as rEFInd) with an GPT partition table:

#Part     Size   Type
#----     ----   -------------------------
#   1     100M   EFI boot partition (ef00)
#   2     XXXG   Solaris Root (bf00)



#if modules do not load correctly, try:

#curl -s https://raw.githubusercontent.com/eoli3n/archiso-zfs/master/init | bash


modprobe zfs

lsmod | grep i zfs

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

wwwwøøææ##00°0000@@@11		@a11	1						ÅÅPÅPP# 1. 
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
consider the factors given below since they are extremely important with regards
to informing your decision, both copy your system on two partitions and thus
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
#Ensure you have good backups if you go this route!

# 2. Create the mirrored ZFS pool with `grub2` compatibility:
```bash
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
rpool mirror /dev/nvme0nX /dev/nvme1nX # x being the partition number
# this may in your case look like /dev/sdba or /dev/sdbb, use
lsblk -l
# if you are uncertain with regards to the labelling used on your 
# system
```

#You've combined the grub2 compatibility with the other options and 
#created a mirrored pool using two devices `/dev/sda2` and `/dev/sdb2` 
# offeering maximum performance benefits in terms of read and write speed.

#3. Now, proceed with your dataset creations:

#zfs create -o mountpoint=none rpool/data
#zfs create -o mountpoint=none rpool/ROOT
#zfs create -o mountpoint=/ -o canmount=noauto rpool/ROOT/default
#zfs create -o mountpoint=/home rpool/data/home
#zfs create -o mountpoint=/var -o canmount=off rpool/var

# 4. Continue with your Arch installation and other ZFS configurations 
#as you did before.

# In summary, you're only using a single `zpool create` command, 
#but modifying it to combine the features you want (in this case, `grub2` 
# compatibility as whell as offering the maximum in performance gained,.).
# zfs create -o mountpoint=none zroot/data
# zfs create -o mountpoint=none zroot/ROOT
# zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/default
# zfs create -o mountpoint=/home zroot/data/home
# zfs create -o mountpoint=/var -o canmount=off zroot/var

zfs create zroot/var/log
zfs create -o mountpoint=/var/lib -o canmount=off zroot/var/lib
zfs create zroot/var/lib/libvirt
zfs create zroot/var/lib/docker


zpool export zroot

zpool import -d /dev/nvme0n1p4 -R /mnt zroot -N

zfs mount zroot/ROOT/default
zfs mount -a

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


