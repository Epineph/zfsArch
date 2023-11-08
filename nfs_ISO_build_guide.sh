#!/bin/bash

check_and_install_package() {
  local package="$1"
  # Check if the package is already installed
  if ! pacman -Qi "$package" &> /dev/null; then
    echo "Package '$package' is not installed."
    read -p "Do you want to install $package? (Y/n) " -n 1 -r
    echo    # Move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
      # The user wants to install the package
      sudo pacman -S "$package"
      if [ $? -ne 0 ]; then
        echo "Failed to install $package. Aborting."
        exit 1
      fi
    else
      # The user does not want to install the package
      echo "Package $package is required to continue. Aborting."
      exit 1
    fi
  else
    echo "Package '$package' is already installed."
  fi
}



check_and_AUR() {
  local package="$1"
  local aur_helper

  # Check for AUR helper
  if type yay &>/dev/null; then
    aur_helper="yay"
  elif type paru &>/dev/null; then
    aur_helper="paru"
  else
    echo "No AUR helper found. You will need one to install AUR packages."
    read -p "Do you want to install yay? (Y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
      echo "Installing yay into ~/AUR-helpers..."
      mkdir -p ~/AUR-helpers && git -C ~/AUR-helpers clone https://aur.archlinux.org/yay.git && (cd ~/AUR-helpers/yay && makepkg -si)
      cd -  # Return to the previous directory
      if [ $? -ne 0 ]; then
        echo "Failed to install yay. Aborting."
        exit 1
      else
        aur_helper="yay"
      fi
    else
      echo "An AUR helper is required to install AUR packages. Aborting."
      exit 1
    fi
  fi
}

check_and_install_package archiso
check_and_install_package git
check_and_AUR

git -C ~/ clone https://aur.archlinux.org/zfs-dkms.git
git -C ~/ clone https://aur.archlinux.org/zfs-utils.git


(cd ~/zfs-dkms && makepkg --skippgpcheck)
(cd ~/zfs-utils && makepkg --skippgpcheck)

mkdir -p ~/ISOBUILD

cp -r /usr/share/archiso/configs/releng ~/ISOBUILD/

sleep 1

cd ~/ISOBUILD

mv releng/ zfsiso



cd zfsiso

mkdir zfsrepo

cd zfsrepo

cp ~/zfs-dkms/*.zst .
sleep 2
cp ~/zfs-utils/*.zst .

repo-add zfsrepo.db.tar.gz *.zst

sleep 1

echo -e "\n[zfsrepo]" | sudo tee -a ~/ISOBUILD/zfsiso/pacman.conf
echo "SigLevel = Optional TrustAll" | sudo tee -a ~/ISOBUILD/zfsiso/pacman.conf
echo "Server = file:///home/$USER/ISOBUILD/zfsiso/zfsrepo" | sudo tee -a ~/ISOBUILD/zfsiso/pacman.conf

sed -i "/\ParallelDownloads = 5/"'s/^#//' ~/ISOBUILD/zfsiso/pacman.conf

sed -i "/\[multilib\]/,/Include/"'s/^#//' ~/ISOBUILD/zfsiso/pacman.conf

echo "linux-headers" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "zfs-dkms" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "zfs-utils" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64



cd ~/ISOBUILD/zfsiso
mkdir {WORK,ISOOUT}

# Create the gshadow file
echo "root:$USER" | sudo tee ~/ISOBUILD/zfsiso/airootfs/etc/gshadow
sudo chmod 0400 ~/ISOBUILD/zfsiso/airootfs/etc/gshadow

# Modify the profile.sh file to include the gshadow permissions
awk '/\["\/etc\/shadow"\]="0:0:400"/ { print; print "  [\"/etc/gshadow\"]=\"0:0:0400\""; next }1' ~/ISOBUILD/zfsiso/profiledef.sh > ~/ISOBUILD/zfsiso/profiledef.sh.tmp && mv ~/ISOBUILD/zfsiso/profiledef.sh.tmp ~/ISOBUILD/zfsiso/profiledef.sh


(cd ~/ISOBUILD/zfsiso && sudo mkarchiso -v -w WORK -o ISOOUT .)
