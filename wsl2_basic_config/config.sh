#!/usr/bin/env bash

# Exit on error.
set -e

# Setup logging
LOG_FILE="$HOME/wsl2_setup.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

# Colors for messages
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m" # No Color

# === UTILITY FUNCTIONS ===

# Function to check if package is available in repositories
check_package_availability() {
  local packages=("$@")
  local unavailable=()
  
  echo -e "${BLUE}Checking package availability...${NC}"
  
  for package in "${packages[@]}"; do
    if ! apt-cache show "$package" &> /dev/null; then
      unavailable+=("$package")
    fi
  done
  
  if [ ${#unavailable[@]} -gt 0 ]; then
    echo -e "${YELLOW}The following packages are not available in repositories:${NC}"
    printf '%s\n' "${unavailable[@]}"
    echo -e "${BLUE}The script will try alternatives where available.${NC}"
  else
    echo -e "${GREEN}All packages are available in repositories.${NC}"
  fi
}

# Function to download with retry
download_with_retry() {
  local url="$1"
  local output="$2"
  local max_attempts=3
  local attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    echo -e "${BLUE}Downloading $url (attempt $attempt/$max_attempts)...${NC}"
    if curl -fsSL "$url" -o "$output"; then
      echo -e "${GREEN}Download successful.${NC}"
      return 0
    else
      echo -e "${YELLOW}Download failed. Retrying in 5 seconds...${NC}"
      sleep 5
      ((attempt++))
    fi
  done
  
  echo -e "${RED}Failed to download $url after $max_attempts attempts.${NC}"
  return 1
}

# Function to safely install packages with fallbacks
install_package_safely() {
  local package="$1"
  local fallback="$2"
  local description="$3"
  
  echo -e "${BLUE}Installing $package ($description)...${NC}"
  
  # Check if package is available
  if apt-cache show "$package" &> /dev/null; then
    if sudo apt-get install -y "$package"; then
      echo -e "${GREEN}Successfully installed $package${NC}"
      return 0
    else
      echo -e "${YELLOW}Failed to install $package, trying alternative...${NC}"
    fi
  else
    echo -e "${YELLOW}Package $package not found in repositories${NC}"
  fi
  
  # Try fallback if provided
  if [ -n "$fallback" ]; then
    echo -e "${BLUE}Trying fallback: $fallback${NC}"
    if apt-cache show "$fallback" &> /dev/null; then
      if sudo apt-get install -y "$fallback"; then
        echo -e "${GREEN}Successfully installed fallback $fallback${NC}"
        return 0
      else
        echo -e "${RED}Failed to install both $package and $fallback${NC}"
        return 1
      fi
    else
      echo -e "${RED}Fallback package $fallback also not found${NC}"
      return 1
    fi
  else
    echo -e "${RED}No fallback available for $package${NC}"
    return 1
  fi
}

# === MAIN FUNCTIONS IN EXECUTION ORDER ===

# 1. Function to check internet connectivity
check_internet() {
  echo -e "${BLUE}Checking internet connectivity...${NC}"
  if ! ping -c 1 8.8.8.8 &> /dev/null; then
    echo -e "${RED}No internet connection. Please check your network and try again.${NC}"
    exit 1
  fi
  echo -e "${GREEN}Internet connection confirmed.${NC}"
}

# 2. Function to install basic system packages
install_basic_packages() {
  echo -e "${GREEN}Installing basic system packages...${NC}"
  # Update/Download package information from all configured sources.
  sudo apt-get update && sudo apt-get upgrade -y 2>&1 >/dev/null

  # Check availability of modern CLI tools before installation
  check_package_availability "bat" "exa" "eza" "fd-find" "fd" "ripgrep" "fzf" "tree" "htop" "neofetch"

  sudo apt-get install -y unzip python3-pip jq wslu keychain curl wget git
}

# 3. Function to install modern CLI tools
install_modern_cli_tools() {
  echo -e "${GREEN}Installing modern CLI tools...${NC}"
  # Install packages safely with fallbacks
  install_package_safely "bat" "batcat" "syntax highlighting cat replacement"
  install_package_safely "exa" "eza" "modern ls replacement" 
  install_package_safely "fd-find" "fd" "fast find replacement"
  install_package_safely "ripgrep" "rg" "fast grep replacement"
  install_package_safely "fzf" "" "fuzzy finder"
  install_package_safely "tree" "" "directory tree viewer"
  install_package_safely "htop" "" "interactive process viewer"
  install_package_safely "neofetch" "" "system information tool"
}

# 4. Function to setup Python environment
setup_python_environment() {
  echo -e "${GREEN}Setting up Python environment...${NC}"
  
  # Update pip to the latest version with --break-system-packages
  # Remove EXTERNALLY-MANAGED file if it exists to allow pip installations
  # Check multiple possible locations for different Python versions
  externally_managed_files=(
      "/usr/lib/python3.12/EXTERNALLY-MANAGED"
      "/usr/lib/python3.11/EXTERNALLY-MANAGED"
      "/usr/lib/python3.10/EXTERNALLY-MANAGED"
      "/usr/lib/python3/EXTERNALLY-MANAGED"
  )

  removed_any=false
  for file in "${externally_managed_files[@]}"; do
      if [ -f "$file" ]; then
          echo -e "${BLUE}Removing Python EXTERNALLY-MANAGED restriction: $file${NC}"
          sudo rm "$file" || echo -e "${YELLOW}Failed to remove $file${NC}"
          removed_any=true
      fi
  done

  if [ "$removed_any" = false ]; then
      echo -e "${YELLOW}No EXTERNALLY-MANAGED files found (already removed or using system packages)${NC}"
  fi

  echo -e "${GREEN}Updating pip to the latest version...${NC}"
  python3 -m pip install --upgrade pip --break-system-packages

  # Install Python packages
  echo -e "${GREEN}Installing Python packages...${NC}"
  python_packages="ansible ansible-lint argcomplete boto3 pywinrm requests"

  for package in $python_packages; do
      if ! python3 -c "import $package" &>/dev/null; then
          echo -e "${BLUE}Installing Python package: $package${NC}"
          python3 -m pip install --break-system-packages "$package" || echo -e "${YELLOW}Failed to install $package, continuing...${NC}"
      else
          echo -e "${YELLOW}Python package $package already installed${NC}"
      fi
  done
}

# 5. Function to copy and configure .bashrc_extra
copy_bashrc_extra() {
  local bashrc_extra=".bashrc_extra"
  local bashrc="$HOME/.bashrc"
  
  if [ -f "$bashrc_extra" ]; then
    echo -e "${GREEN}Copying the extended bashrc...${NC}"
    cp -f "$bashrc_extra" "$HOME/.bashrc_extra"
    
    # Check whether the operation was successful
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}The file was copied correctly to $HOME/.bashrc_extra.${NC}"
      
      # Add sourcing to .bashrc if not already present
      if ! grep -q ".bashrc_extra" "$bashrc"; then
        echo '' >> "$bashrc"
        echo 'if [ -f ~/.bashrc_extra ]; then
    . ~/.bashrc_extra
fi' >> "$bashrc"
        echo -e "${GREEN}Added .bashrc_extra sourcing to .bashrc${NC}"
      fi
    else
      echo -e "${RED}An error occurred while copying the file.${NC}"
      return 1
    fi
  else
    echo -e "${YELLOW}File $bashrc_extra not found in current directory.${NC}"
    return 1
  fi
}

# 6. Function to install AWS CLI
install_aws_cli() {
  if ! command -v aws &> /dev/null; then
    echo -e "${GREEN}Installing AWS CLI...${NC}"
    if download_with_retry "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" "/tmp/awscliv2.zip"; then
      unzip -q /tmp/awscliv2.zip -d /tmp
      sudo /tmp/aws/install
      rm -rf /tmp/aws /tmp/awscliv2.zip
    else
      echo -e "${RED}Failed to install AWS CLI${NC}"
      return 1
    fi
  fi
  echo -e "${BLUE}$(aws --version)${NC}"
}

# 7. Function to install Session Manager plugin
install_session_manager_plugin() {
  if ! command -v session-manager-plugin &> /dev/null; then
    echo -e "${GREEN}Installing Session Manager plugin...${NC}"
    if download_with_retry "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" "/tmp/session-manager-plugin.deb"; then
      sudo dpkg -i /tmp/session-manager-plugin.deb
      rm -f /tmp/session-manager-plugin.deb
    else
      echo -e "${RED}Failed to install Session Manager plugin${NC}"
      return 1
    fi
  fi
  echo -e "${BLUE}$(session-manager-plugin)${NC}"
}

# 8. Function to install Docker
install_docker() {
  if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key.
    echo -e "${GREEN}Installing Docker...${NC}"
    sudo install -m 0755 -d /etc/apt/keyrings
    
    # Download GPG key only if it doesn't exist
    if [ ! -f /etc/apt/keyrings/docker.asc ]; then
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
    else
        echo -e "${YELLOW}Docker GPG key already exists${NC}"
    fi
    
    # Add the repository to Apt sources only if not already added
    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        echo -e "${YELLOW}Docker repository already configured${NC}"
    fi
    
    sudo apt-get update
    # Install the Docker packages.
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
  fi
  echo -e "${BLUE}$(docker --version)${NC}"
}

# 9. Post-installation steps for Docker Engine
post_install_docker() {
  if [ ! -d "$HOME/.docker" ]; then
    mkdir -p $HOME/.docker
    sudo chown $USER:$USER /home/$USER/.docker -R
    sudo chmod g+rwx $HOME/.docker -R
  fi
  # Add your user to the docker group.
  if ! groups $USER | grep &>/dev/null '\bdocker\b'; then
    echo -e "${BLUE}Adding user to docker group...${NC}"
    sudo usermod -aG docker $USER
  else
    echo -e "${YELLOW}User already in docker group${NC}"
  fi
  # Configure Docker to start on boot with systemd
  if ! systemctl is-enabled docker.service &>/dev/null; then
    echo -e "${BLUE}Enabling Docker service...${NC}"
    sudo systemctl enable docker.service
  else
    echo -e "${YELLOW}Docker service already enabled${NC}"
  fi
  
  if ! systemctl is-enabled containerd.service &>/dev/null; then
    echo -e "${BLUE}Enabling containerd service...${NC}"
    sudo systemctl enable containerd.service
  else
    echo -e "${YELLOW}Containerd service already enabled${NC}"
  fi
}

# 10. Function to clone Terraform version manager repository
clone_tfenv_repository() {
  if [ -d ~/.tfenv ]; then
      echo -e "${YELLOW}Repository 'Terraform version manager' already exists.${NC}"
  else
      echo -e "${GREEN}Cloning the repository 'Terraform version manager'.${NC}"
      git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv
  fi
}

# 11. Function to configure git
git_configuration() {
  # Checking whether user data is already set up.
  if [ -z "$(git config --global user.name)" ] || [ -z "$(git config --global user.email)" ]; then
      echo -e "${RED}No user data configuration in GIT.${NC}"
      read -p "Enter your name: " name
      read -p "Enter your last name: " last_name
      read -p "Enter your e-mail address: " email

      # Configuring user data in GIT.
      git config --global user.name "$name $last_name"
      git config --global user.email "$email"

      echo -e "${GREEN}Configuration complete. The user data in GIT has been updated:${NC}"
      echo -e "${BLUE}$(git config --global --list | grep user)${NC}"
  else
      echo -e "${YELLOW}The user data in GIT is already configured:${NC}"
      echo -e "${BLUE}$(git config --global --list | grep user)${NC}"
  fi
  
  # Set useful Git defaults
  echo -e "${GREEN}Setting up Git defaults...${NC}"
  git config --global init.defaultBranch main || true
  git config --global pull.rebase false || true
  git config --global core.autocrlf input || true
  git config --global core.editor "nano" || true
  git config --global alias.st status || true
  git config --global alias.co checkout || true
  git config --global alias.br branch || true
  git config --global alias.unstage "reset HEAD --" || true
  git config --global alias.last "log -1 HEAD" || true
  git config --global alias.visual "!gitk" || true
}

# === SCRIPT EXECUTION ===

# Function call
echo -e "${BLUE}Starting WSL2 configuration...${NC}"
echo -e "${BLUE}Log file: $LOG_FILE${NC}"

check_internet
install_basic_packages
install_modern_cli_tools
setup_python_environment
copy_bashrc_extra
install_aws_cli
install_session_manager_plugin
install_docker
post_install_docker
clone_tfenv_repository
git_configuration

echo
echo -e "${RED}The basic configuration of WSL2 is now complete.${NC}"
echo -e "${RED}You should restart WSL2 using PowerShell as administrator and use the command 'wsl -t Ubuntu-24.04'.${NC}"