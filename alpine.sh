#!/bin/sh

# Prompt for user input
read -p "Enter username for the new user: " USERNAME
read -p "Enter full name for the new user: " FULLNAME

# Create a new user
adduser -D "$USERNAME"
echo "Setting password for $USERNAME"
passwd "$USERNAME"

# Add user to sudo group (Alpine's equivalent to wheel group)
adduser "$USERNAME" wheel

# Configure locales
echo "Setting up locales..."
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
export LANG=en_US.UTF-8

# Install essential packages
echo "Updating package repositories..."
apk update
echo "Installing essential packages..."
apk add sudo bash vim curl wget git

echo "Basic setup complete."
