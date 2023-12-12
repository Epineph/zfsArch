#!/bin/bash

USER_DIR="/home/$USER"
BUILD_DIR="$USER_DIR/builtPackages"
PY_GH_SCRIPT="$GIT_NAME/$REPO_NAME"
GIT_NAME="Epinephrine"
GIT_REPO="zfsArch"
ISOBUILD_DIR="$USER_DIR/ISOBUILD"
ISO_HOME="$ISOBUILD_DIR/zfsiso"
ISO_LOCATION="$ISO_HOME/ISOOUT/"
ISO_REPO_DIR="$ISO_HOME/zfsrepo"
ISO_FILES="$ISO_LOCATION/archlinux-*.iso"
AUR_URL="https://aur.archlinux.org"                          #
YAY_PATH="$USER_DIR/AUR-helpers/yay"
RELENG_DIR="/usr/share/archiso/configs/releng"
USB_HOME="$ISO_HOME/airootfs"
PY_URL="https://raw.githubusercontent.com/Epineph/zfsArch/main/test.py"

                                                                    
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
                                                                    
  # If there are missing packages, ask the user if they want to     ' 
  # install them                                                    
  if [ ${#missing_packages[@]} -ne 0 ]; then                        
    echo "The following packages are not installed:                 
    ${missing_packages[*]}"                                         
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
      echo "The following packages are required to continue:        
      ${missing_packages[*]}. Aborting."                            
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
      echo "Installing yay into $YAY_PATH..."
      mkdir -p $YAY_PATH && git -C $YAY_PATH clone $AUR_URL/yay.git && \
      (cd $YAY_PATH && makepkg -si)
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

check_and_install_packages archiso git python-setuptools curl 
python-requests python-beautifulsoup4 base-devel pacman-contrib

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



(clone $AUR_URL/ms-sys.git build && \
clone $AUR_URL/zfs-dkms.git build && \
clone $AUR_URL/zfs-utils.git build)

mkdir -p $ISOBUILD_DIR

cp -r /usr/share/archiso/configs/releng $ISOBUILD_DIR/

sleep 1

cd $ISO_BUILD_DIR

mv releng/ zfsiso

cd zfsiso

sleep 1

mkdir -p $ISO_REPO_DIR

cd zfsrepo

cp $BUILD_DIR/zfs-dkms/*.zst .
sleep 2
cp $BUILD_DIR/zfs-utils/*.zst .
sleep 2
cp $BUILD_DIR/ms-sys/*.zst .

sleep 2

repo-add zfsrepo.db.tar.gz *.zst

sleep 1


sed -i "/#ParallelDownloads = 5/"'s/^#//' $ISO_HOME/pacman.conf

sed -i "/#[multilib#]/,/Include/"'s/^#//' $ISO_HOME/pacman.conf

echo -e "#n#n#Custom Packages#nlinux-headers#nzfs-dkms#nzfs-utils"\
 | sudo tee -a $ISO_HOME/packages.x86_64


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
file_pattern = re.compile(r'zfs-linux-#d+.*#.zst')
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


if ! grep -q "#[community#]" "$pacman_conf"; then
        sed -i "/^#[$repo#]/,/Include/ s|Include = .*|Server = \
        https://archive.archlinux.org/repos/${formatted_date}/#$repo/os/\
        #$arch#nSigLevel = PackageRequired|" $pacman_conf
fi

# Add the [archzfs] repository configuration if it doesn't exist
if ! grep -q "#[archzfs#]" "$pacman_conf"; then
    echo -e "#n[archzfs]#nServer = https://archzfs.com/#$repo/#$arch#n\
    SigLevel = Optional TrustAll" >> $pacman_conf
fi

# Make the changes for [core], [extra], [multilib] and [community]
for repo in core extra multilib community; do
    sed -i "/^#[$repo#]/,/Include/ s|Include = .*|Server = \
    https://archive.archlinux.org/repos/${formatted_date}/#$repo/os/#\
    $arch#nSigLevel = PackageRequired|" $pacman_conf
done




sudo cp /etc/pacman.conf /etc/pacman.conf.backup

sudo cp $ISO_HOME/pacman.conf /etc/pacman.conf


sudo cp $USB_HOME/etc/pacman.conf $USB_HOME/etc/pacman.conf.backup
sudo cp $ISO_HOME/pacman.conf $USB_HOME/etc/pacman.conf

echo -e "#n[zfsrepo]#nSigLevel = Optional TrustAll#nServer = \
file:///home/$USER/ISOBUILD/zfsiso/zfsrepo" >> $iso_home/pacman.conf

cd $iso_home



mkdir {WORK,ISOOUT}


(cd $iso_home && sudo mkarchiso -v -w WORK -o ISOOUT .)

sudo cp /etc/pacman.conf /etc/pacman.conf.modified
sudo mv /etc/pacman.conf.backup /etc/pacman.conf



list_devices() {
    echo "Available devices:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
}

locate_customISO_file() {
    local latest_iso=$(find $ISO_HOME/ISOOUT -type f -name "archlinux-*.iso" -printf "%T@ %p\n" | sort -n | tail -1 | cut -d' ' -f2-)
    if [[ -f "$latest_iso" ]]; then
        list_devices
        read -p "Enter the device name (e.g., /dev/sda, /dev/nvme0n1): " device

        if [ -b "$device" ]; then
            read -p "Do you want manual partitioning? (yes/no): " manual_partitioning
            if [[ "$manual_partitioning" == "yes" ]]; then
                # Manual partitioning with Python script
                (cd $USER_DIR && curl -L $PY_URL > py_script.py
                sudo chmod +rwx py_script.py && sudo python3 ./py_script.py "$latest_iso" "$device")
		sudo umount /mnt && sudo rm py_script.py
            else
                # Automatic partitioning with ddrescue
                burnISO_to_USB "$latest_iso" "$device"
            fi
        else
            echo "Invalid device name."
        fi
    else
        echo "No ISO file found."
    fi
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

locate_customISO_file
