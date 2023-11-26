Arch Linux install process


Getting ready
-------------

Stop raid arrays:
# mdadm -S /dev/md{x,y,z}
Erase superblocks:
# mdadm --zero-superblock /dev/sd{a,b}{1,2,3,4}
Wipe disk:
# dd if=/dev/zero of=/dev/sdX bs=1M count=100


GPT Partition Scheme
--------------------

Partition	Mount p.	Size		Type	Raid
--------------------------------------------------------------
/dev/sda1			2MiB		ef02	
/dev/sda2	/boot		100MiB	fd00	/dev/md1
/dev/sda3	/swap	2048MiB	fd00	/dev/md2
/dev/sda4	/		rest		fd00	/dev/md0 <-- OBS!

# sgdisk --backup=table /dev/sda
# sgdisk --load-backup=table /dev/sdb


RAID
----
(--assume-clean / watch -n .1 cat /proc/mdstat)

# mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sd[ab]4

# mdadm --create /dev/md1 --level=1 --raid-devices=2 --metadata=0.9 /dev/sd[ab]2

# mdadm --create /dev/md2 --level=1 --raid-devices=2 /dev/sd[ab]3

Further info: mdadm --misc --detail /dev/md[012] | less

LVM
---
# pvcreate /dev/md0

# vgcreate VolGroupArray /dev/md0

# lvcreate -L 20G VolGroupArray -n lvroot
# lvcreate -L 15G VolGroupArray -n lvvar
# lvcreate -L 640G VolGroupArray -n lvhome


File system
-----------
# mkfs.ext4 /dev/VolGroupArray/lvroot
# mkfs.ext4 /dev/VolGroupArray/lvvar
# mkfs.ext4 /dev/VolGroupArray/lvhome

# mkfs.ext4 /dev/md1

# mkswap /dev/md2
# swapon /dev/md2

# mount /dev/VolGroupArray/lvroot /mnt
# mkdir /mnt/{home,boot,var}
# mount /dev/md1 /mnt/boot
# mount /dev/VolGroupArray/lvvar /mnt/var
# mount /dev/VolGroupArray/lvhome /mnt/home


Base-system
-----------
Select mirror:
# vi /etc/pacman.d/mirrorlist
Install:
# pacstrap /mnt base base-devel
Update raid:
# mdadm --examine --scan > /mnt/etc/mdadm.conf
Generate fstab:
# genfstab -p /mnt >> /mnt/etc/fstab
and only / needs 1 in last field and remove "data=ordered":
# nano /mnt/etc/fstab
Chroot into system:
# arch-chroot /mnt
Configure locale:
# nano /etc/locale.gen
# locale-gen
# echo LANG=en_US.UTF-8 > /etc/locale.conf
Console font and keymap:
# nano /etc/vconsole.conf
	KEYMAP=no-latin1
	FONT=Lat2-Terminus16
	FONT_MAP=
Timezone:
# ln -s /usr/share/zoneinfo/Europe/Copenhagen /etc/localtime
Hardware clock to UTC:
# hwclock --systohc --utc
Hostname:
# echo myhostname > /etc/hostname
Edit hosts:
# nano /etc/hosts
	127.0.0.1	kroesus	localhost
	192.168.1.3	nas
	feks.
Configure network with static ip:
# pacman -S netcfg ifplugd
# cd /etc/network.d
# cp examples/ethernet-static .
# nano ethernet-static
# systemctl enable net-auto-wired.service
Uncomment repos in pacman:
# nano /etc/pacman.conf
Set root pwd:
# passwd
Add user:
# useradd -m -g users -s /bin/bash markus
# passwd markus


mkinitcpio.conf
---------------
MODULES=(... dm-mod raid1 ...)
HOOKS=(... mdadm lvm2 filesystems...)

Re-generate the initramfs image:
# mkinitcpio -p linux


GRUB2
-----
# pacman-db-upgrade
# pacman -Syy
# pacman -S grub-bios
# grub-install --target=i386-pc --recheck /dev/sda
# cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
# grub-mkconfig -o /boot/grub/grub.cfg
Modify menu.cfg:
# nano /boot/grub/grub.cfg >
	insmod lvm
	insmod raid
	set raid=(md1)
	
	
Finito
------
exit chroot, umount, reboot, pray

Mount into LVM
--------------
Info with pvs / # lvdisplay /dev/VolGroupArray 
# vgscan --mknodes
# lvchange -a y /dev/VolGroupArray/lvroot
# mount /dev/VolGroupArray/lvroot /mnt