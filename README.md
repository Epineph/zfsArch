# zfs-filsystem based Arch-linux installaion (work-in-progress)

This started out as my own notes, but once that I figured out how 
complex the installation process can be, especially since one has 
to understand that the information provided to you by commands 
such as `lsblk -l`, can seem to be at odds with what actually 
is happening. 

Usually, you would be able to re-confirm that everything has been mounted correctly.
However, if you run `lsblk` prior to `pacstrap`, it would show that nothing is mounted to /mnt. 
Nevertheless, running `pacstrap /mnt base...` would not return an error,
and `chroot /mnt` would, in fact, change root into your new system, despite
no partition is displayed to have /mnt as mountpoint.

It is important to keep in mind that zfs handles
many things as a layered abstraction, you can trust that zfs is handling
it as if that was the case, given that you haven't made a mistake,
or that I haven't misguided you - remember, in certain sections, 
**you have to make some important descisions**, like choosing whether or not
to use a *mirrored setup*, and whether you would like to be *striping* or
*mirroring* two physical drives, or perhaps you only install it into
one hard-drive/single partition of a hard drive. 

Therefore, **pay extra attention to parts where decisions branch out**.
Always assume if you follow the instruction, not necessarily the same decisions, 
that if nothing else is indicated, you can proceed, (there are points at which
decisions run in parallel, and where possible the aim of the guide is to allow for that).

## the guide is purposefully made to keep flexibility in mind

There will be points at which you cann choose one of several branches (because
they are important to zfs and what you want to gain from it, for example when choosing
whether to be mirroring or striping two physical hard-drives). There will be certain
points at which an option is forced and that choosing a different route means that 
you must be comfortable knowing how it, and whether it, affects other options.

This is only done when there are **countless** options, and one of them allows for as much
flexibility for the user and, when possible, being none-restrictive with respect to 
how it affects options that are completely unrelated to the installation,
i.e., choosing another option would affect options that are completely unrelated
to this installation, implying dependence between options with no obvious corretion. 
Such noise will be avoided when possible.

I will try to indicate where those decisions are made, and while I will
only go with one of them for consitency, you should be able to follow
along regardless and, if nothing else is indicated, presume that you can proceed
to use the following lines of code regardless of what decision you made,
if you followed the instructions at points where they branch out (though
remember to use the labelling of, for example, hard-drives are they appear
to you), which may differ from how it appears to me, then you should be able
to continue regardless if you choose another option than provided here, given
that you do not deviate in any other significant way.

# Installation is grub-compatible

This guide takes into consideration that users might have partitions containing
other linux filesystems as well as windows, and hence is made to be
**grub compatible** for dual booting. **This means that the guide is made to
be compatible with that option**, but whether or not you are dual booting has
no impact on anything **it doesn't force any option**. Often there can be a dozen of
ways to configure it, which can cause several unique ways to proceed at that point. However,
the option of making it grub-compatible is forced. But if you or someone else has windows
and/or other linux partitions that you want to keep when installing zfs-based Arch linux,
then it would be much more forced or restrictive to at least not allow for that option.
Seeminly an oxymoron, forcing the least-restrictive option is arguably okay.
If you won't want to install grub and use systemd or some other bootloader, that is fine.
Making zfs grub-compatible does come at the cost of some, but very few, features of
zfs not being available, but the trade-off is small.

# Why do this, and what is so special about zfs?

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
can still be enjoyed, but having more than one disk will allow you to
best exploit the advantages that zfs offers.

The guide is designed to allow your preferences to be relevant, and this is
mostly relevant if you have more than one hard-drive (in theory an external hard-drive
could be used if you don't have 2 harddrives in your computer) since your
decisions have an effect on, whether, for example, you will get mostly
a extra data-redundancy, or whether you get a performance increase. 
This increase in performance is mostly related to Disk I/O, which includes
read or write or input/output operations (defined in KB/s) involving a physical disk.
In simple words, it is the speed with which the data transfer takes place
between the hard disk drive and RAM, or basically it measures active disk I/O time.


For example, benefit from having better performance and data redundancy
or *mirroriing*, but you can also opt to just maxizing performance
using *striping*, which however comes at the cost of no additional data 
redundancy. Therefore, there is also left room for decisions based on your 
own preferences. Whenever the guide branches out, i.e., there will be choices
where you can decide what fits your needs the best, just read closely at those
sections and check if you should do something else given that you have just
chosen x, y or z. 

# Prerequisites

## Creating your own custom image (.iso file)

**The official arch-iso cannot** be used to install an arch-linux based zfs/Solaris OS architecture. 
**However**, if you already have an Arch installation (regardless of what filesystem type you are using), 
then you can start following the instructions given here, since I include the process of making the
custom arch iso file file you will need. So, the first part deals with creating iso subsequently 
used as the **bootable installation medium for Arch based on zfs**.
 
I will not include a guide on installing arch on one of the typically used and officially supported filesystems, 
i.e,, if you don't have arch linux, then you must first install it on a none-zfs based filsystem. Typical
choices are .ext4 and btrfs, but if you have limited experience installing arch, then just use .ext, which is
a bit simpler.

If installing it without a script seems unconfortable, you should probably
reconsider and not start out by using zfs. Nevertheless, You don't need 
to an arch enthusiast or know a great deal about arch itself if 
you have a good understanding of linux in general

One of the distinguising aspects of arch that can make it seem very different
than other linux distributions is that less is pre-decided and hence requires the user 
to configure it, which requires a bit more attention to the filesystem structure 
and functions, which ironically is mostly the same irrespective of which linux distribution
you are using. Therefore, things that are perceived to be very different between distributions
may reflect small differences in the philosophy guiding their respective develooment
teams, and may therefore not reflect any actual significant difference inherently
different. Therefore, I would not argue that much or any experience is needed using
arch if you have a solid grasp on the fundamental concepts in linux, and if you want
a zfs filesytem-based sytem, a solid understanding of linux on a broader level is more
important than being able to memorise how to install arch without a script, even 
if this is the first arch installation.


# Feel comfortable relying on your own problem-solving abilities most of the time

This is important, because if you choose to use zfs for a long-term installation,
you need to consider that it isn't officially supported by arch or any other linux distribution,
and don't expect guides on each problem you may face and therefore be comfortable
when you find that stackoverflow rarely has a relevant answer to you,
and maybe sometimes get lucky finding an extremely user-unfriendly guide
written by a russian hacker in one of the mosto obscure corners of the internet.
If you comfortable potentially relying most of the time doing the problem-solving 
yourself, then this should be a fine choice. 

In theory, if this seems comfortable and acceptable risk to you,
it doesn't really matter if you are new to arch, since the only reason you need 
it here is to access the AUR (Arch Linux Distribution). You can therefore **cheat**
a bit if you want a **quick installation**, since *manjaro* is installed in a similar
fasion to most linux distributions, by that I mean a user-friendly .iso,
and **Manjaro is also an arch based derivative and provides access to the AUR**. Therefore,
using it to make iso and continue should not be an issue. I haven't tried that, but I cannot see
why it wouldn't work.

Though keep in mind that in manjaro you do not use:

```
sudo pacman -S packag
```

Instead, if using manjaro, use:

```
sudo pamac -S package
```

Otherwise I think it should work using Manjaro (I haven't checked, but in theory
I cannot see what it shouldn't). If not, then you have to install arch, which basically
is also what we do here, as well as a lot more. 

# Make ISO on windows with ArchLinux with WSL2

I have tried using the windows features **wsl2** to install archlinux (which you can find in the windows store) and it works to use to make the iso. In order to be able to use wsl2, if you haven't already done this, press the windows + x (or search for run) and choose run, and then write optionalFeatures and check the box for **Windows Subsystem for Linux** and reboot. I would recommend using the newest terminal for windows, e.g., windows terminal preview on windows store, and powershell 7 preview. Open powershell and write `wsl --update` and set wsl default version as 2 if you haven't already, e.g., `wsl --set-default-version 2`. After setting up arch, you should be able to make the ISO.


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
the zfs-filesystem has been actively developed for around 42 years and despite early
development starting only a few years after Windows was founded, and is being praised 
for being extremely well developed, which is hardly surprising for a file-system that
has been under development, in some form or another, for around 40 years.

so why else go through all this to get a zfs OS archistechture on Arch linux?
As just mentioned, zfs is extremely well developed and has 40 years of work behind it.
Remember, if you have several hard-disks you can get substantialt performance increase in
disc I/O speed, i.e., faster disc read and write operations, and faster data
transfer between the physical hard-drives and RAM. Even if you only have one hard-drive, 
you can still enjoy zfs and its many other features.

# Script automating building the ISO

I have made a script to automate building the arch zfs .iso file. To use  the script, you need to first to give it permission to execute, read and write, i.e., you need to first write `sudo chmod u+rwx nfs_ISO_build_guide.sh` or just `sudo chmod +rwx nfs_ISO_build_guide.sh`. The script needs you to use sudo and needs you password to work. If you are uncomfortable about that, you can just check the script. Alternatively, you can execute the commands youself, but a part of the script executes a nested python script that checks the latest zfs update, and then feeds the information to bash or zsh (or whatever you are using, just don't use fish as your terminal shell) to update the pacman.conf file in order to change the repos so that they align. Otherwise, you may experience issued with incompatible linux kernels with respect to zfs. The script changes the pacman.conf so that packages from the arch archive from the same date the latest zfs release was made are installed. So if you want to do it manually, I would suggest making a bash script that starts with the part that changes the /etc/pacman.conf permissions and ends with `echo "pacman.conf has been updated."`. It might still work even you ignore this part, but I have experienced problems where it doesn't because after the iso was made some new linux kernel has been released, thus the iso will not necessarily be stable over time.
