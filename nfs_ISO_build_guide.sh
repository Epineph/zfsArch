#!/bin/bash

# GLOBAL VARIABLES
#################################################################################
USER_DIR="/home/$USER"								#
BUILD_DIR="$USER_DIR/builtPackages"						#
PY_URL="https://raw.githubusercontent.com/Epineph/zfsArch/main/test.py"		#
ISO_HOME="$USER_DIR/ISOBUILD/zfsiso"						#
ISO_LOCATION="$ISO_HOME/ISOOUT/"						#
ISO_FILES="$ISO_LOCATION/archlinux-*.iso"					#
AUR_HELPER_DIR="$AUR_HELPER_DIR"						#
ZFS_REPO_DIR="$ISO_HOME/zfsrepo"						#
GITHUB_REPOSITORY="$git_author/$repo_name"					#
AUR_URL="https://aur.archlinux.org"						#
#################################################################################


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


(


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
      echo "Installing yay into $USER_DIR/AUR-helpers..."
      mkdir -p $USER_DIR/AUR-helpers && git -C $USER_DIR/AUR-helpers clone https://aur.archlinux.org/yay.git && (cd $USER_DIR/AUR-helpers/yay && makepkg -si)
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

check_and_install_packages archiso git python-setuptools curl python-requests python-beautifulsoup4 base-devel pacman-contrib gcc-libs ncurses util-linux-libs popt git

check_and_AUR

clone() {
    # Ensure the build directory exists
    mkdir -p "$BUILD_DIR"

    # Check if the first argument is an HTTP URL
    if [[ $1 == http* ]]; then
        # Handle AUR links
        if [[ $1 == *aur.archlinux.org* ]]; then
            # Clone the repository
            git -C "$BUILD_DIR" clone "$1"
            # Change to the repository's directory
            repo_name=$(basename "$1" .git)
            cd "$BUILD_DIR/$repo_name"

            # Build or install based on the second argument
            if [[ $2 == build ]]; then
                makepkg --skippgpcheck --noconfirm
            elif [[ $2 == install ]]; then
                makepkg -si
            fi
        else
            # Clone non-AUR links
            if [[ $1 != *".git" ]]; then
                git clone "$1.git"
            else
                git clone "$1"
            fi
        fi
    else
        # Clone GitHub repos given in the format username/repository
        git clone "https://github.com/$1.git"
    fi
}



(clone https://aur.archlinux.org/ms-sys.git build clone https://aur.archlinux.org/zfs-dkms.git build && clone https://aur.archlinux.org/zfs-utils.git build)

mkdir -p $USER_DIR/ISOBUILD

cp -r /usr/share/archiso/configs/releng $USER_DIR/ISOBUILD/

sleep 1

cd $USER_DIR/ISOBUILD

mv releng/ zfsiso

cd $ISO_HOME

sleep 1

mkdir -p $ZFS_REPO_DIR

cd $ZFS_REPO_DIR

cp $BUILD_DIR/zfs-dkms/*.zst .
sleep 2
cp $BUILD_DIR/zfs-utils/*.zst .
sleep 2
cp $BUILD_DIR/ms-sys/*.zst .

sleep 2

repo-add zfsrepo.db.tar.gz *.zst

sleep 1


sed -i "/\ParallelDownloads = 5/"'s/^#//' $ISO_HOME/pacman.conf

sed -i "/\[multilib\]/,/Include/"'s/^#//' $ISO_HOME/pacman.conf

echo -e "\n\n#Custom Packages\nlinux-headers\nzfs-dkms\nzfs-utils" | sudo tee -a $ISO_HOME/packages.x86_64


# Define the URL
#
sudo chmod u+rwx $ISO_HOME/pacman.conf

url="https://archzfs.com/archzfs/x86_64/"

# Define the path to the pacman.conf file
pacman_conf="$ISO_HOME/pacman.conf"

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

cd $ISO_HOME

if ! grep -q "\[community\]" "$pacman_conf"; then
        sed -i "/^\[$repo\]/,/Include/ s|Include = .*|Server = https://archive.archlinux.org/repos/${formatted_date}/\$repo/os/\$arch\nSigLevel = PackageRequired|" $pacman_conf
fi

# Add the [archzfs] repository configuration if it doesn't exist
if ! grep -q "\[archzfs\]" "$pacman_conf"; then
    echo -e "\n[archzfs]\nServer = https://archzfs.com/\$repo/\$arch\nSigLevel = Optional TrustAll" >> $pacman_conf
fi

# Make the changes for [core], [extra], [multilib] and [community]
for repo in core extra multilib community; do
    sed -i "/^\[$repo\]/,/Include/ s|Include = .*|Server = https://archive.archlinux.org/repos/${formatted_date}/\$repo/os/\$arch\nSigLevel = PackageRequired|" $pacman_conf
done




sudo cp /etc/pacman.conf /etc/pacman.conf.backup

sudo cp $ISO_HOME/pacman.conf /etc/pacman.conf


sudo cp $ISO_HOME/airootfs/etc/pacman.conf $ISO_HOME/airootfs/etc/pacman.conf.backup
sudo cp $ISO_HOME/pacman.conf $ISO_HOME/airootfs/etc/pacman.conf

sudo echo -e "\n[zfsrepo]\nSigLevel = Optional TrustAll\nServer = file:///home/$USER/ISOBUILD/zfsiso/zfsrepo" >> $ISO_HOME/pacman.conf

cd $ISO_HOME



mkdir {WORK,ISOOUT}


(cd $ISO_HOME && sudo mkarchiso -v -w WORK -o ISOOUT .)

sudo cp /etc/pacman.conf /etc/pacman.conf.modified
sudo mv /etc/pacman.conf.backup /etc/pacman.conf

user_dir="/home/$USER"
pyUrl="https://raw.githubusercontent.com/Epineph/zfsArch/main/test.py"


list_devices() {
    echo "Available devices:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
}



locate_customISO_file() {
  local ISO_LOCATION="$ISO_HOME/ISOOUT/"
  local ISO_FILES="$ISO_LOCATION/archlinux-*.iso"

  for f in $ISO_FILES; do
    if [ -f "$f" ]; then
      list_devices
      read -p "Enter the device name \
      (e.g., /dev/sda, /dev/nvme0n1): " device

      if [ -b "$device" ]; then
        burnISO_to_USB "$f" "$device"  # Burn the ISO to USB
      else
        echo "Invalid device name."
      fi
    fi
  done
}


burnISO_to_USB() {
    # Install ddrescue if not installed
    if ! type ddrescue &>/dev/null; then
        echo "ddrescue not found. Installing it now."
        sudo pacman -S ddrescue
    fi

    # Burn the ISO to USB with ddrescue
    echo "Burning ISO to USB with ddrescue. Please wait..."
    sudo ddrescue -d -D --force "$1" "$2" /tmp/ddrescue.log
}


read -p "Do you want to burn the ISO to USB right \
now? (yes/no): " confirmation
if [ "$confirmation" == "yes" ]; then
  read -p "do you want to choose the sizes of the partitions? \
  (yes/no): " USER_PARTITION_CONFIRMATION
    if [ "$USER_PARTITION_CONFIRMATION" == "yes" ]; then
    list_devices
    echo "iso path is (remember to include filename):" \
    && ls -l $ISO_HOME/ISOOUT
      (cd $USER_DIR && curl -L $PY_URL > py_script.py
      sudo chmod +rwx py_script.py && sudo python3 ./py_script.py)
    else
      locate_customISO_file
    fi
else
  echo "Exiting."
  sleep 2
  exit
fi

)
