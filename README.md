# zfs-filsystem based Arch-linux installaion

This started out as my own notes, but once that I figured out how 
complex the installation process can be, especially since one has 
to understand that the information provided to you by commands 
such as `lsblk -l`, can seem to be at odds with what actually 
is happening. 

So, for example, when you are ready to run:

```
pacstrap /mnt
```

You might normally run the commmand:

```
lsblk
```

Usually, you would be able to re-confirm everythimg has been mounted correctly.
However, if you run it prior to `pacstrp`, it would show that nothing is mounted to /mnt. 
Nevertheless, running `pacstrap /mnt base...` would not return an error,
and `chroot /mn` would change root into your new system. However, you would
need to check /mnt/etc/fstab or /etc/mnt if you akready chrooted into it, and make
sure that the uncommented lines are commented out. Generally, the reverse would
be true.

It is important to keep in mind that zfs handles
many things as a layered abstraction, you can trust that zfs is handling
it as if that was the case, given that you haven't made a mistake,
or that I haven't misguided you - remember, in certain sections, 
you have to make some important descisions, like choosing whether or not
to use a mirrored setup, and whether you would like to be striping or
mirroring two physical drives, or perhaps you only install it into
one hard-drive/single partition of a hard drive. Therefore, pay extra attention
to parts where decisions brnch out. Always assume if you follow the instruction, 
not necessarily the same decisions, that if nothing else is indicated, you can
proceed, (there are points at which decisions run in parallel, and where possible 
the aim of the guide is to allow for that).

## the guide is purposefully made to keep flexibility in mind

There will be points at which you cann choose one of several branches (because
they are important to zfs and what you want to gain from it, for example when choosing
whether to be mirroring or striping two physical hard-drives). There will be certain
points at which an option is forced and that choosing a different route means that 
you must be comfortable knowimg how it, and whether it, affects other options. 
This is only done when there are countless options, and one of them allows for as much
flexibility for the user and, when possible, being none-restrictive with respect to 
how it affects options that are completely unrelated to the installation,
i.e., choosing another option would affect options that are completely unrelated
to this installation, implying dependence between options with no obvious corretion. 
Such noise will be avoided when possible.

I will try to indicate where those decisions are made, and while I will
only go with one of them for consitency, you should be able to follow
along regardless and, if nothing else is indicated, presume that you can proceed
to use the following lines of code regardless of what decision you made,
if you followed the insturctions at points where they branch out (though
remember to use the labelling of, for example, hard-drives are they appear
to you), which may differ from how it appears to me, then you should be able
to continue regardless if you choose another option than provided here, given
that you do not deviate in any other significant way.

This guide takes into consideration that users might have partitions containing
other linux filesystems as well as windows, and hence is made to be
**grub compatible** for dual booting. **This means that the guide is made to
be compatible with that option**, but whether or not you are dual booting has
no impact on anything **it doesn't force any option**. Often there can be a dozen of
ways to configure it, which can cause several unique ways to proceed at that point. However,
the option of making it grub-compatible is forced. A guide that listed every option at every point
would not be a guide, but something more closly resembling the documentation of linux. this
would defeat the entire poimt of making a guide, which necessarily means that
the user is restricted to certain information useful, since the usefulness of a guide
is not only the information presented to you, but also what is not presented
to you, and the point if following the guide is that what is included and relevant, but
also that that the guide consists of everything that is mentioned as well as everything 
else not mentioned in the guide. By leaving out what isn't relevant is what carves out the
path of the guide, and therefore it is necessary to make decisions to restrict options.

Therefore, I try to make make some decisions for simplicity
that allow or otherwise do not restrict other options or considerations that 
are not specific to this guide, but it doesn't mean that you have to do it
(I suppose that using systemd can be used as bootloader if you choose to do
that), just trust that you know and take into consideration how the points at
which you deviate from my structions affect, if at all, any subsequent actions,
so be mindful of both the operations as well as the order of operationa, which
potentially can be important and inform you as they can be dependent on eachother.
That means that I do at some points force or restrict the user to use a certain command
at a specific place, and that you cannot continue without knowing how not choosing
the same option affects what you do next. But such decisiins are purpossefully made
to be as none-restrictive as possible (with regards to both the installation
and how it affects things you might need to use the hard-drive for, but
have mothing to do with this guide). Otherwise, the guide risks being for confusinf
rather than guiding you. 

ZFS is an advanced filesystem created by Sun Mircosystems which 
has been acquired by Oracle and was relased for OpenSolaris in 2005. 
Hence, the filesystem architecture is also known as a *Solaris OS Structure*, 
which includes several advanced and beneficial features such as pooled storage
(integrated volume management or `zpool`, Copy-on-write (COW), 
Snapshots, RAID-Z  (Redundant Array of Independent Disks) which is similar
to RAID-5 etc., in that it provides increased write buffering for performance, 
but is different in that it is even faster and eliminiates what is known 
as write-hole error. Furthermore, unlike RAID-5, it does not rely on special 
hardware for reliabiliry or write buffering for performance.

Therefore, in additon to sharing some of the advantageous features provided 
by the linux **btrfs** filesystem, it provides some unique features what 
can best be exploited by having more than one disks. You can install zfs 
even if you only have one hard-drive, and many of the useful features of zfs 
can still be enjoyed, but having more than one disk will allow you to, 
for example, benefit from having better performance and data redundancy
or *mirroriing*, but you can also opt to just maxizing performance
using *striping*, which however comes at the cost of no additional data 
redundancy. Therefore, there is also left room for decisions based on your 
own preferences.

# Prerequisites

**The official arch-iso cannot** be used to install an arch-linux based zfs/Solaris OS architecture. **However**, if you already have an Arch installation (regardless of what filesystem type you are using), then you can start following the instructions given here, since I include the process of making the custom arch iso file file you will need. So, the first part deals with creating iso subsequently used as the **bootable installation medium for Arch based on zfs**.
 
I will not include a guide on installing arch on one of the typically used and officially supported filesystems, i.e,, if you don't have arch linux, then you must first install it using a filesystem which is available when using the official .iso image.
One popular choice is ext4. Btrfs is also quite popular (provides similar
features to zfs, like logical volume management, compression and more, though,
zfs can do all of those too, but even faster, and includes additinal features)
.

If you have never installed arch, or if you are very new to it and unfortable 
doing the installation without relying entirely on a script, then it is
probably a good idea to not use btrfs the first time you do it, but rather ext4,
which isn't that different and mostly differs in setting up the drives. If
installing it without a script seems unconfortable, you should probably
reconsider and not start out by using zfs. Nevertheless, You don't need 
to an arch enthusiast or know a great deal about arch itself if 
you have a good understanding of linux in general. 

One of the distinguising aspects of arch that can make it seem very different
than other linux distributions is that less is pre-decided and hence requires the user 
to configure it, which requires a bit more attention to the filesystem structure 
and functions, which ironically is mostly the same irrespective of which linux distribution
you are using. Therefore, things that are perceived to be very different between distributions
may reflect small differences in the philosophy guiding their respective develooment
teams, and may therefore not reflect any actual significant difference inherently
different. Therefore, I would not argue that much or any experience is needed using
arch if you have a solid grasp on the fundamental concepts in linux, and if you want
a zfs filesytem-based sytem, this would important than being able to memorise
how to install arch without a script.

This is important, because if you choose to use zfs for a long-term installation,
you need to consider that it isn't officially supported by arch, and there
are not guides on each problem you may face and therefore be comfortable
when you find that stackoverflow rarely has a relevant answer to you,
and maybe sometimes get lucky finding an extremely user-unfriendly find
in one of the obscure corners of the internet. Be comfortable doing a lot of
problem-solving yourself. If so, this may be a fine choice even if you have
never used arch. 

In theory, if this seems comfortable and acceptable risk to you,
it doesn't really matter if you are new to arch, since the only reason you need 
it here is to access the AUR (Arch Linux Distribution). You can therefore cheat
a bit if you want a quick installation, since manjaro is installed in a similar
fasion to most linux distributions, by that I mean a user-friendly .iso,
and also an arch based derivative and provides access to the AUR. Therefore,
using it to make iso and continue should not be an issue. 

Though keep in mind that in manjaro you do not use:

```
sudo pacman -S packag
```

Instead, if using manjaro, use:

```
sudo pamac -S package
```

Otherwise I think it should work. If not, then you have to jnstall arch.

# Why do this?

Again, since zfs is neither officially supported by arch nor available as a filesystem 
available on the officially supported images of any linux distribution!
Although a few projects currently exist using zfs OS architectureand and actively
developed, it is not publicallly avaiable as the os on computers.
Therefore, arch wiki or guides to do certain sections may not be applicable,
despite the vastness of the arch wiki. 

So why this sacrifise? remember, the goal is to get the zfs-filesystem, 
which is, like linux, based on unix. Therefore, the outcome is to get the
zfs OS architecture and its great and attractive features, and since we 
install it on arch, you will additionally get access to great features such
as the AUR as a bonus. This comeas at the cost of not always having
the answer readily available at your fingertios. Although zfs was relased 
in 2005 as the OS system on computers available to the public and was
upported as OpenSolaris, active development stopped in 2010 after Oracle 
acquired it, so the zfs-filesystem hasn't been a part of any 
officially supported project available for the public for over a decade. 


However, active development has never stopped since 2010, and and is being 
used by Oracle and officially in the sense that the zfs-filesystem architecture 
but it is nevertheless not available as the os on computers officially. In fact, 
the original codebase began in the early 1980's and was released by 
Sun Microsystems as operating system on computers for the first time in 1991. So, 
the zfs-filesystem has been actively developed for around 42 years and despite early development starting only a few years after Windows was founded, and is being praised for being extremely well developed, which is hardly surprising for a file-system that has been under development, in some form or another, for around 40 years. One could argue that this should be ecpected for a operating system whose active development timeframe next big milestone is reaching a half century.

Therefore, this guide assumes that you already have arch installed and device such as a usb on which the .iso will 

```bash
sudo pacman -S archiso # important package that we need to build the customized arch iso image

cd ~ # this is important if you want to just copy and paste from this guide (since the home folder will be used as reference

mkdir ISOBUILD

cp -r /usr/share/archiso/configs/releng ISOBUILD/
```
This copies files from the archiso recursively into our build dir

```bash
cd ISOBUILD # this should be located in ~/ISOBUILD or /home/<yourusername>/ISOBUILD

#rename the dir to zfsiso
mv /releng/ zfsiso

cd # when executed alone should take you back to the previous folder, which in this case is the ~
```

I you don't have any AUR helped such as yay or paru, then you need to get one or youc can follow these steps. Just skip if you already have. Futhermore, you do not have to put the AUR's in `/opt` and put them where you like. Just remember go back to the home directory `~` before you continue if you do so, unless you use another location as reference.
```bash
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

# Whereas changing permissions at /opt is safe, changing permissions
# at locations that have restricted permissions can be problematic
# and in some cases wreak havoc on your system. In many cases, problems
# caused by changed permissions are reversible, but it can be challenging
# or, and I can confirm from experience, it can lead to you finding yourself
# re-installing linux. Therefore, in situations where you are prevented from
# doing something due to restricted permissions, despite it being safe more 
# often than not to change permission, there may be a good reason for those 
# restrictions being there, and it is advisable to check before doing so, and
# this is especially if you pass the -R argument, since you may not know
# if a subdirectory or a subdirectory has a subdirectory whose subdirectory
# has a subdirectory which causes problems to its subdirectories or your 
# entire system. 

# When you choose to do something recursively like chmod,
# you need to consider that you may not know about all of the files you are 
# affecting, or that your just changed or affected 100 or 10.000 files
# you had no clue were there in the first place.


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

cd ~ # to go back to your home directory if you are /opt or anywhere else 
# than ~
```
If you do have yay/paru or if you are done with these steps, you can continue from here.

Now we need to get 2 important packages for our custom .iso file. We need to get the `zfs-dkms` and `zfs-utils` from the AUR (Arch User Repository).

It may take a few minutes to build both packages.

```bash
sudo pacman -S git # if you do not have git installed already

git clone https://aur.archlinux.org/zfs-dkms.git

cd zfs-dkms/

You should probably not pass --skippgpcheck for security reasons, but if saving time where you can is your cup of tea you can do so like this

makepkg --skippgpcheck

cd # should take you back to ~

git clone https://aur.archlinux.org/zfs-utils.git

cd zfs-utils/

makepkg --skippgpcheck

cd
```

Now we have built the important packages needed to build the iso,
so we go back to building it

```bash

cd /ISOBUILD/zfsiso # if you use the same directories, then you should be at ~/ISOBUILD/zfsiso

# Next, we need to make a directory for the zfs repository

mkdir zfsrepo

cd zfsrepo

# next, we copy all the .zst filles from then two packages we built to this location

# copies the .zst files from the directories we built them in, i.e., `~`,
# to the location we are currently in, specified by ` .`

cp ~/zfs-dkms/*.zst . # which here is equivalent to 
# writing cp ~/zfs-dkmt/*.zst ~/ISOBUILD/zfsiso/zfsrepo

cp ~/zfs-utils/*.zst .

ls -al
```

```bash
# Create the database

repo-add zfsrepo.db.tar.gz *.zst

cd ..

# should take you to ~/ISOBUILD/zfsiso

sudo nano packages.x86_64
```

add the following in the bottom of /etc/pacman.conf
you can use sudo nano/vim /etc/pacman.conf

```bash
[zfsrepo]
SigLevel = Optional TrustAll
Server = file:///home/heini/ISOBUILD/zfsiso/zfsrepo
```

or

```bash
echo "[zfsrepo]" | sudo tee -a /etc/pacman.conf
echo "SigLevel = Optional TrustAll" | sudo tee -a /etc/pacman.conf
echo "Server = file:///home/heini/ISOBUILD/zfsiso/zfsrepo" | sudo tee -a /etc/pacman.conf
```

We need to include the packages we built in the custom .iso

add these lines to ~/ISOBUIKD/zfsiso/packages.x86_64

```bash
# [ZFS Custom  Repo]
linux-headers
zfs-dkms
zfs-utils

#alternatively, use tee to append these lines

echo "# [ZFS Custom Repo]" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64
echo "linux-headers" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64
echo "zfs-dkms" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64
echo "zfs-utils" | sudo tee -a /home/heini/ISOBUILD/zfsiso/packages.x86_64
```

```bash
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

```

Lastly, we create two additiional directories to be created for our
custom .iso

```bash
# you are expected to be at ~/ISOBUILD/zfsiso

mkdir {WORK,ISOOUT}

Trhat is to say, mkfs ~/ISOBUILD/zfsisi/{WORK,ISOOUT}
```

Before changin to root (and do not change location prior to this)

Ensure that you do not lack any permissions iso

```bash
chmod -R +rw ~/ISOBUILD/

```

#change to root


#do not change directory beforw going to root. If you are lost, go back to /home/heini/ISOBUILD/zfsiso

su root

#this will build this custom .iso
mkarchiso -v -w WORK -o ISOOUT .

# create bootable usb medium from the custom arch .iso we just created

cp /home/heini/ISOBUILD/zfsiso/ISOOUT/archlinux-2023.10.31-x86_64.is
o /dev/sda

reboot

# Part II - Installation of zfs


loadkeys dk
# change keyboard layout as seems fit to you, default is usually us

setfont ter-128n # if you find the font to be too small

# if still too small, try:


setfont ter-132b
# increasing font size, which may be especially helpful when using
# certain monitors (the package is called terminus-font), and is
# is usually not on a filesystem after installation,
# unless installed on your filesystem - it can be useful
# if you boot up in a destopless environment after installation
# and is pre-installed on most official arch .iso files

# as during a normal arch installation, if you have a wired
# connection you should already be online and you can skip
# the following command. if you have wifi, use:

iwctl

# this command should put you into a new prompt [iwd]:
# and is already provided by the .iso from the iwd package
# so if you want to be able to use it post-installation
# consider adding it amongst the packages when ypu execute the
# pacstrap /mnt command later, or just install as you would
# normally after chrooting into the sytem, i.e. pacman -S iwd

# check device list for if other terms are used

station wlan0 connect WifiDD10 # check your wifi name by: station wlan0 get-networks

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

zfs create -o mountpoint=none rpool/data
zfs create -o mountpoint=none rpool/ROOT
zfs create -o mountpoint=/ -o canmount=noauto rpool/ROOT/default
zfs create -o mountpoint=/home rpool/data/home
zfs create -o mountpoint=/var -o canmount=off rpool/var


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

At this point, we create and and enable the swap

# Now we create a swap partition


genfstab -U -p /mnt >> /mnt/etc/fstab

cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist.backup

arch-chroot /mnt


cat /etc/fstab

# comment-out all zroot entries

nano /etc/pacman.conf
# go to the bottom and add the following:
[archzfs]
Server = https://archzfs.com/$repo/x86_64

or do it like this:

echo -e "[archzfs]\nServer = https://archzfs.com/\$repo/\$arch\nSigLevel = Optional TrustAll" >> /etc/pacman.conf

# ArchZFS GPG keys (see https://wiki.archlinux.org/index.php/Unofficial_user_repositories#archzfs)
pacman-key -r DDF7DB817396A49B2A2723F7403BD972F75D9D76
pacman-key --lsign-key DDF7DB817396A49B2A2723F7403BD972F75D9D76

#then you can choose either zfs-dkms or zfs-linux:


pacman -S zfs-dkms

# or
pacman -S zfs-linux zfs-linux-headers


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


