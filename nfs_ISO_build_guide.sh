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

tee /home/<username>/ISOBUILD/zfsiso/ISOOUT/archlinux-2023.10.30-x86_64.iso /dev/disk/by-id/usb-Verbatim_STORE_N_GO_21071153040493-0\:0


