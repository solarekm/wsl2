#!/usr/bin/env bash

# Exit on error
set -e

# Append custom bashrc content if not already present
bashrc_extra=".bashrc_extra"
bashrc="$HOME/.bashrc"

if [ -f "$bashrc_extra" ]; then
  cp -f "$bashrc_extra" "$HOME"
  if ! grep -q ".bashrc_extra" "$bashrc"; then
    echo '' >> "$bashrc"
    echo 'if [ -f ~/.bashrc_extra ]; then
    . ~/.bashrc_extra
    fi' >> "$bashrc"
  fi
fi

# File with package names
req_packages="req_packages"
py_libraries="py_libraries"

# Update/Download package information from all configured sources
sudo apt-get update 2>&1 >/dev/null

# Checking if the required packages are installed
missing_packages=()
while IFS= read -r req_package || [[ -n "$req_package" ]]; do
  if [ -n "$req_package" ] && ! dpkg -l | grep -qw "$req_package"; then
    missing_packages+=("$req_package")
  fi
done < "$req_packages"

if [ ${#missing_packages[@]} -gt 0 ]; then
  echo "The following packages are missing and will be installed: ${missing_packages[*]}"
  sudo apt-get install -y "${missing_packages[@]}"
fi

# Checking if the required python libraries are installed
while IFS= read -r py_library || [[ -n "$py_library" ]]; do
  if [ -n "$py_library" ] && ! pip3 show "$py_library" > /dev/null 2>&1; then
    echo "Library $py_library is not installed. Attempting to install it..."
    pip3 install "$py_library"
  fi
done < "$py_libraries"

# Function to install AWS CLI
install_aws_cli() {
  if ! command -v aws &> /dev/null; then
    echo "\e[32mInstalling AWS CLI...\e[0m"
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    sudo /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
  fi
  echo "$(tput setaf 4)$(aws --version)$(tput sgr0)"
}

# Function to install Session Manager plugin
install_session_manager_plugin() {
  if ! command -v session-manager-plugin &> /dev/null; then
    echo "\e[32mInstalling Session Manager plugin...\e[0m"
    curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "/tmp/session-manager-plugin.deb"
    sudo dpkg -i /tmp/session-manager-plugin.deb
    rm -f /tmp/session-manager-plugin.deb
  fi
  echo "$(tput setaf 4)$(session-manager-plugin)$(tput sgr0)"
}

# Function to install Docker
install_docker() {
  if ! command -v docker &> /dev/null; then
    echo "\e[32mInstalling Docker...\e[0m"
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo groupadd docker
    sudo usermod -aG docker $USER
    newgrp docker
    sudo chown $USER:$USER /home/$USER/.docker -R
    sudo chmod g+rwx $HOME/.docker -R
    sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
    sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
  fi
  echo "$(tput setaf 4)$(docker --version)$(tput sgr0)"
}

# Function to install Terraform
install_terraform() {
  if ! command -v terraform &> /dev/null; then
    echo "Installing Terraform..."
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update
    sudo apt-get install -y terraform
  fi
  echo "$(tput setaf 4)$(terraform --version)$(tput sgr0)"
}

# Function to configure git
git_configuration() {
  # Checking whether user data is already set up
  if [ -z "$(git config --global user.name)" ] || [ -z "$(git config --global user.email)" ]; then
      echo "No user data configuration in GIT."
      read -p "Enter your name: " name
      read -p "Enter your last name: " last_name
      read -p "Enter your e-mail address: " email

      # Configuring user data in GIT
      git config --global user.name "$name $last_name"
      git config --global user.email "$email"

      echo -e "\e[34mConfiguration complete. The user data in GIT has been updated:\e[0m"
      echo "$(tput setaf 4)$(git config --global --list | grep user)$(tput sgr0)"
  else
      echo -e "\e[34mThe user data in GIT is already configured:\e[0m"
      echo "$(tput setaf 4)$(git config --global --list | grep user)$(tput sgr0)"
  fi
}

install_aws_cli
install_session_manager_plugin
install_docker
# install_terraform
git_configuration

# Cloning the repository "Terraform version manager"
if [ -d ~/.tfenv ]; then
  echo -e "\e[34mRepository Terraform version manager already exists.\e[0m"
else
  git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv
fi

echo
echo -e "\e[31mThe basic configuration of WSL2 is now complete.\e[0m"
echo -e "\e[31mYou should restart WSL2 using PowerShell as administrator and use the command 'wsl --shutdown'.\e[0m"
