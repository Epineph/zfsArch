#  install btrfs filesystem for ArchLinux
# No script

This is the selected layout for the UEFI/GPT system:

Mount point	Partition	Partition type	FS Type	Bootable flag	Size
/boot/efi	/dev/sda1	EFI System Partition	FAT32	Yes	512 MiB
[SWAP]	/dev/sda2	Linux swap	SWAP	No	16 GiB
/	/dev/sda3	Linux	BTRFS	No	222 GiB
Removd # before #parallel downloads #[multilib] and #Includes under multilib. Use nano/vim or:

sudo sed -i '/#ParallelDownloads/s/^#//g' /etc/pacman.conf
sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf


If you need a new partition table write:

gdisk /dev/nvme0n1 # change it so that it fits your drive or partition

# then press g if you want a new partition table. If you already
# have a gpt table and a efi partition, just skip

# otherwise:

n #press n for a new partition

# press enter once when it askes about first section

# now press

+600M # followed by enter
If asked about clde flr GUID, write:
ef00
should change it to EFI

# you can always change if you wanf
t # changes tyle

# Now press

n
# enter to use default

