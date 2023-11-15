#!/bin/bash
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
# Get the current language setting
current_lang=$(locale | grep "^LANG=" | cut -d= -f2)

# If the LANG variable is not set, default to 'C'
if [ -z "$current_lang" ]; then
    current_lang="C"
fi

# Export the LC_ALL and LANGUAGE
export LC_ALL="C"
export LANGUAGE="$current_lang"

# Verify settings
echo "Locale settings: LC_ALL=$LC_ALL, LANGUAGE=$LANGUAGE"

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

clone() {
    # Define the build directory
    build_dir=~/builtPackages

    # Ensure the build directory exists
    mkdir -p "$build_dir"

    # Check if the first argument is an HTTP URL
    if [[ $1 == http* ]]; then
        # Handle AUR links
        if [[ $1 == *aur.archlinux.org* ]]; then
            # Clone the repository
            git -C "$build_dir" clone "$1"
            # Change to the repository's directory
            repo_name=$(basename "$1" .git)
            cd "$build_dir/$repo_name"

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

(clone https://aur.archlinux.org/zfs-dkms-raidz-expansion-git.git build && clone https://aur.archlinux.org/zfs-utils-raidz-expansion-git.git build)

mkdir -p ~/ISOBUILD

cp -r /usr/share/archiso/configs/releng ~/ISOBUILD/

sleep 1

cd ~/ISOBUILD

mv releng/ zfsiso



cd zfsiso

mkdir zfsrepo

cd zfsrepo

cp ~/builtPackages/zfs-dkms/*.zst .
sleep 2
cp ~/builtPackages/zfs-utils/*.zst .

sleep 2

repo-add zfsrepo.db.tar.gz *.zst

sleep 1

echo -e "\n[zfsrepo]" | sudo tee -a ~/ISOBUILD/zfsiso/pacman.conf
echo "SigLevel = Optional TrustAll" | sudo tee -a ~/ISOBUILD/zfsiso/pacman.conf
echo "Server = file:///home/$USER/ISOBUILD/zfsiso/zfsrepo" | sudo tee -a ~/ISOBUILD/zfsiso/pacman.conf

sed -i "/\ParallelDownloads = 5/"'s/^#//' ~/ISOBUILD/zfsiso/pacman.conf

sed -i "/\[multilib\]/,/Include/"'s/^#//' ~/ISOBUILD/zfsiso/pacman.conf

echo "linux-headers" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "zfs-dkms-raidz-expansion-git" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "zfs-utils-raidz-expansion-git" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "pacman-contrib" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "wget" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "rsync" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "curl" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "git" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "mkinitcpio-archiso" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "mkinitcpio-utils" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "mkinitcpio-systemd-tool" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "mkinitcpio-nfs-utils" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "neovim" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "github-cli" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "hwdetect" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "libnfs" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64
echo "findutils" | sudo tee -a ~/ISOBUILD/zfsiso/packages.x86_64




# Define the URL
echo -e "\n[community]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a ~/ISOBUILD/zfsiso/pacman.conf
echo -e "\n[community]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a ~/etc/pacman.conf
sudo chmod u+rwx ~/ISOBUILD/zfsiso/pacman.conf

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

# Define the path to your pacman.conf file
pacman_conf="~/ISOBUILD/zfsiso/pacman.conf"

# Define the new XferCommand
new_xfer_command="XferCommand = /usr/bin/curl -L -C - --max-time 300 --retry 3 --retry-delay 3 '%u' > '%o'"

# Check if XferCommand (commented or uncommented) exists in the file
if grep -q "^#XferCommand\|^XferCommand" "$pacman_conf"; then
    # Modify the existing XferCommand line, whether it's commented or not
    sed -i "/^#XferCommand\|^XferCommand/c\\$new_xfer_command" "$pacman_conf"
else
    # If XferCommand does not exist at all, add it
    echo "$new_xfer_command" >> "$pacman_conf"
fi


cd ~/ISOBUILD/zfsiso
mkdir {WORK,ISOOUT}


(cd ~/ISOBUILD/zfsiso && sudo mkarchiso -v -w WORK -o ISOOUT .)


)
