#!/bin/bash

bootctl --path=/boot install

echo -e "default arch\ntimeout 10" | tee -a /boot/loader/loader.conf 

touch /boot/loader/entries/arch.conf

echo -e "title Arch Linux\nlinux /vmlinuz-linux\ninitrd /amd-ucode.img\n\
initrd /initramfs-linux.img\noptions zfs=rpool/ROOT/default rw" \
    >> /boot/loader/entries/arch.conf

mkdir -p /etc/pacman.d/hooks/

touch /etc/pacman.d/hooks/100-systemd-boot.hook

echo -e "[Trigger]\nType = Package\nOperation = Upgrade\nTarget = systemd"\
    >> /etc/pacman.d/hooks/100-systemd-boot.hook

echo -e "\n[Action]\nDescription = update systemd-boot\nWhen = PostTransaction"\
    >> /etc/pacman.d/hooks/100-systemd-boot.hook

echo -e "Exec = /usr/bin/bootctl update" >> /etc/pacman.d/hooks/100-systemd-boot.hook