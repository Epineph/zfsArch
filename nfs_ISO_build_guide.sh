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
        yes | sudo pacman -S "$package"
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

check_and_install_packages archiso git python-setuptools python-requests python-beautifulsoup4 base-devel pacman-contrib sof-firmware

check_and_AUR
sudo chmod u+rwx /etc/pacman.conf
sudo cp /etc/pacman.conf /etc/pacman.conf.backup


AUR_URL="https://aur.archlinux.org"

(for string ("zfs-dkms" "zfs-utils" "zfsbootmenu"
) git -C ~ clone $AUR_URL/$string)

(cd ~/zfs-utils && makepkg --skippgpcheck --noconfirm)
(cd ~/zfs-utils && makepkg --skippgpcheck --noconfirm)
(cd ~/zfsbootmenu && makepkg --skippgpcheck --noconfirm --nodeps)

sudo chmod u+rwx ~/ISOBUILD/zfsiso/pacman.conf

# Define the URL
url="https://archzfs.com/archzfs/x86_64/"

# Define the path to the pacman.conf file
pacman_conf="/home/$USER/ISOBUILD/zfsiso/pacman.conf"

# Export the URL so that it can be accessed as an environment variable in Python
export url

# Run the Python script and capture the formatted date
formatted_date=$(python3 << 'END_PYTHON'
import os
import requests
from bs4 import BeautifulSoup
import re
from datetime import datetime

# Access the URL from the environment variable
url = os.getenv('url')

# Fetch the HTML content from the URL
response = requests.get(url)

if response.status_code != 200:
    print(f"Failed to retrieve the page, status code: {response.status_code}", file=sys.stderr)
    sys.exit(1)

# Parse the HTML content using BeautifulSoup
soup = BeautifulSoup(response.text, 'html.parser')

# Define the regular expression pattern for the files we're looking for
file_pattern = re.compile(r'zfs-linux-\d+.*\.zst')

# Initialize an empty list to store the dates
dates = []

# Search for the files matching the pattern
for a_tag in soup.find_all('a', href=True):
    if file_pattern.search(a_tag['href']):
        sibling_text = a_tag.next_sibling
        if sibling_text:
            parts = sibling_text.strip().split()
            date = ' '.join(parts[:2])
            dates.append((a_tag['href'], date))

# Sort the dates
dates.sort(key=lambda x: x[1], reverse=True)

# Format the most recent date
if dates:
    filename, most_recent_date = dates[0]
    # Parse the date string and reformat it
    dt = datetime.strptime(most_recent_date, "%d-%b-%Y %H:%M")
    formatted_date = dt.strftime("%Y/%m/%d")
    print(formatted_date)
else:
    print("No matching files found.", file=sys.stderr)
    sys.exit(1)
END_PYTHON
)

# Check if Python script executed successfully
if [ $? -eq 0 ]; then
    echo "Formatted Date: $formatted_date"
else
    echo "The Python script failed."
    exit 1
fi

# Continue with your bash script...

# Make the changes for [core], [extra], and [community]
for repo in core extra community; do
    sed -i "/^\[$repo\]/,/Include/ s|Include = .*|Server = https://archive.archlinux.org/repos/${formatted_date}/\$repo/os/\$arch\nSigLevel = PackageRequired|" $pacman_conf
done

# Add the [archzfs] repository configuration if it doesn't exist
if ! grep -q "\[archzfs\]" "$pacman_conf"; then
    echo -e "\n[archzfs]\nServer = https://archzfs.com/\$repo/\$arch\nSigLevel = Optional TrustAll" >> $pacman_conf
fi

echo "pacman.conf has been updated."



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
sleep 2
cd ~/zfsbootmenu/*.zst .
#cp ~/zfs-linux-headers/*.zst .
#cp ~/zfs-linux/*.zst .
sleep 3
repo-add zfsrepo.db.tar.gz *.zst

sleep 1


#echo -e "\n[zfsrepo]" | sudo tee -a ~/ISOBUILD/zfsiso/pacman.conf
echo "SigLevel = Optional TrustAll" | sudo tee -a ~/ISOBUILD/zfsiso/pacman.conf
echo "Server = file:///home/$USER/ISOBUILD/zfsiso/zfsrepo" | sudo tee -a ~/ISOBUILD/zfsiso/pacman.conf

sed -i "/\ParallelDownloads = 5/"'s/^#//' ~/ISOBUILD/zfsiso/pacman.conf

sed -i "/\[multilib\]/,/Include/"'s/^#//' ~/ISOBUILD/zfsiso/pacman.conf

echo "linux-headers" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "zfs-dkms" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "zfs-utils" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "zfsbootmenu" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
#echo "zfs-linux-headers" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
#echo "zfs-linux" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64


# Define the URL
echo -e "\n[community]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a ~/ISOBUILD/zfsiso/pacman.conf


pacman_conf="/etc/pacman.conf"

for repo in core extra community; do
    sed -i "/^\[$repo\]/,/Include/ s|Include = .*|Server = https://archive.archlinux.org/repos/${formatted_date}/\$repo/os/\$arch\nSigLevel = PackageRequired|" $pacman_conf
done


cd ~/ISOBUILD/zfsiso
mkdir {WORK,ISOOUT}

# Create the gshadow file
#echo "root:$USER" | sudo tee ~/ISOBUILD/zfsiso/airootfs/etc/gshadow


# Modify the profile.sh file to include the gshadow permissions
#awk '/\["\/etc\/shadow"\]="0:0:400"/ { print; print "  [\"/etc/gshadow\"]=\"0:0:0400\""; next }1' ~/ISOBUILD/zfsiso/profiledef.sh > ~/ISOBUILD/zfsiso/profiledef.sh.tmp && mv ~/ISOBUILD/zfsiso/profiledef.sh.tmp ~/ISOBUILD/zfsiso/profiledef.sh


(cd ~/ISOBUILD/zfsiso && sudo mkarchiso -v -w WORK -o ISOOUT .)

sudo cp /etc/pacman.conf /home/$USER/pacman.conf.modified
sudo cp /etc/pacman.conf.backup /etc/pacman.conf
