#!/bin/bash

# This script sets up a jump host on an Ubuntu server using public key authentication.

# Update the system
sudo apt update
sudo apt upgrade -y

# Install OpenSSH Server
sudo apt install openssh-server -y

# Configure SSHd to allow key-based authentication and disable password authentication
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service to apply changes
sudo systemctl restart ssh

# Create a dedicated user for SSH access
read -p "Enter the username for the jump host: " username
sudo adduser $username

# Add the user to the sudo group
sudo usermod -aG sudo $username

# Create an SSH directory for the user
sudo mkdir -p /home/$username/.ssh
sudo chown $username:$username /home/$username/.ssh
sudo chmod 700 /home/$username/.ssh

# Prompt for the public key
read -p "Paste the public key for $username: " public_key

# Add the public key to the authorized_keys file
echo "$public_key" | sudo tee -a /home/$username/.ssh/authorized_keys
sudo chown $username:$username /home/$username/.ssh/authorized_keys
sudo chmod 600 /home/$username/.ssh/authorized_keys

echo "Jump host setup complete. You can now connect to the jump host using SSH:"
echo "ssh $username@your_jump_host_ip"