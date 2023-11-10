#!/bin/bash
# WORK IN PROGRESS - DO NOT RUN YET 
check_and_install_packages() {
  local missing_packages=()
  
  # Check which packages are not installed
  for package in "$@"; do
    if ! pacman -Qi "$package" &> /dev/null; then
      missing_packages+=("$package")
    else
      echo "Package '$package' is already installed."
    fi
  done

  # If there are missing packages, ask the user if they want to install them
  if [ ${#missing_packages[@]} -ne 0 ]; then
    echo "The following packages are not installed: ${missing_packages[*]}"
    read -p "Do you want to install them? (Y/n) " -n 1 -r
    echo    # Move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
      for package in "${missing_packages[@]}"; do
        sudo pacman -S "$package"
        if [ $? -ne 0 ]; then
          echo "Failed to install $package. Aborting."
          exit 1
        fi
      done
    else
      echo "The following packages are required to continue: ${missing_packages[*]}. Aborting."
      exit 1
    fi
  fi
}

check_and_install_packages ruby vim neofetch

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

pacman -S python-setuptools python-beautifulsoup4 python-requests --needed

# inline Python script
python3 << 'END_PYTHON'
import requests
from bs4 import BeautifulSoup

url = 'http://example.com/archzfs/x86_64/'

# Fetch the HTML content
response = requests.get(url)
html_content = response.text

# Parse the HTML content
soup = BeautifulSoup(html_content, 'html.parser')

# Find the elements that contain the last modified dates
# (This will depend on the HTML structure of your page)
for element in soup.find_all('zfs-linux'):
    # Extract and print the last modified date
    last_modified_date = element.text
    print(last_modified_date)

END_PYTHON

# more bash commands ...

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


# Modify the profile.sh file to include the gshadow permissions
awk '/\["\/etc\/shadow"\]="0:0:400"/ { print; print "  [\"/etc/gshadow\"]=\"0:0:0400\""; next }1' ~/ISOBUILD/zfsiso/profiledef.sh > ~/ISOBUILD/zfsiso/profiledef.sh.tmp && mv ~/ISOBUILD/zfsiso/profiledef.sh.tmp ~/ISOBUILD/zfsiso/profiledef.sh


(cd ~/ISOBUILD/zfsiso && sudo mkarchiso -v -w WORK -o ISOOUT .)
