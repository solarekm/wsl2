#!/usr/bin/env bash

# Exit on error.
set -e

# Check for command line arguments
CHECK_ONLY=false
FIX_ONLY=false
FIX_WARNINGS=false
SHOW_HELP=false

for arg in "$@"; do
  case $arg in
    --check|-c)
      CHECK_ONLY=true
      shift
      ;;
    --fix|-f)
      FIX_ONLY=true
      shift
      ;;
    --fix-warnings|-w)
      FIX_WARNINGS=true
      shift
      ;;
    --help|-h)
      SHOW_HELP=true
      shift
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--check|-c] [--fix|-f] [--fix-warnings|-w] [--help|-h]"
      exit 1
      ;;
  esac
done

# Show help if requested
if [ "$SHOW_HELP" = true ]; then
  echo "WSL2 Configuration Script"
  echo
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "OPTIONS:"
  echo "  --check, -c         Only run verification checks, skip installation"
  echo "  --fix, -f           Only fix missing components, skip full installation"
  echo "  --fix-warnings, -w  Fix optional components (yellow warnings)"
  echo "  --help, -h          Show this help message"
  echo
  echo "Examples:"
  echo "  $0                   # Run full installation and verification"
  echo "  $0 --check           # Only check current installation status"
  echo "  $0 --fix             # Only install missing components"
  echo "  $0 --fix-warnings    # Fix optional warnings (SSH, tfenv, tool alternatives)"
  exit 0
fi

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
  check_package_availability "bat" "exa" "eza" "fd-find" "fd" "ripgrep" "fzf" "tree" "htop" "neofetch" "gh"

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
  install_package_safely "gh" "" "GitHub CLI for repository management"
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

# 5a. Function to setup CLI tool aliases (bat, fd) for consistent naming
setup_cli_tool_aliases() {
  echo -e "${GREEN}Setting up CLI tool aliases for consistent naming...${NC}"
  
  local need_local_bin_path=false
  
  # Create ~/.local/bin if it doesn't exist
  mkdir -p "$HOME/.local/bin"
  
  # Setup bat alias if only batcat is available
  if command -v batcat &> /dev/null && ! test -f "$(command -v bat 2>/dev/null)"; then
    echo -e "${BLUE}Creating 'bat' command (symlink to batcat)...${NC}"
    if ln -sf "$(which batcat)" "$HOME/.local/bin/bat" 2>/dev/null; then
      echo -e "${GREEN}✅ Successfully created 'bat' command${NC}"
      need_local_bin_path=true
    else
      echo -e "${YELLOW}⚠️  Could not create 'bat' symlink, 'batcat' works identically${NC}"
    fi
  elif test -f "$(command -v bat 2>/dev/null)"; then
    echo -e "${GREEN}✅ 'bat' already available${NC}"
  fi
  
  # Setup fd alias if only fdfind is available
  if command -v fdfind &> /dev/null && ! test -f "$(command -v fd 2>/dev/null)"; then
    echo -e "${BLUE}Creating 'fd' command (symlink to fdfind)...${NC}"
    if ln -sf "$(which fdfind)" "$HOME/.local/bin/fd" 2>/dev/null; then
      echo -e "${GREEN}✅ Successfully created 'fd' command${NC}"
      need_local_bin_path=true
    else
      echo -e "${YELLOW}⚠️  Could not create 'fd' symlink, 'fdfind' works identically${NC}"
    fi
  elif test -f "$(command -v fd 2>/dev/null)"; then
    echo -e "${GREEN}✅ 'fd' already available${NC}"
  fi
  
  # Add ~/.local/bin to PATH if we created any symlinks
  if [ "$need_local_bin_path" = true ]; then
    if ! grep -q 'PATH.*\.local/bin' "$HOME/.bashrc_extra" 2>/dev/null; then
      echo >> "$HOME/.bashrc_extra"
      echo '# Add ~/.local/bin to PATH for user binaries' >> "$HOME/.bashrc_extra"
      echo 'if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then' >> "$HOME/.bashrc_extra"
      echo '    export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc_extra"
      echo 'fi' >> "$HOME/.bashrc_extra"
      echo -e "${GREEN}✅ Added ~/.local/bin to PATH in .bashrc_extra${NC}"
    fi
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

# === VERIFICATION FUNCTION ===

# Function to verify installation status
verify_installation() {
  echo
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}    INSTALLATION VERIFICATION REPORT   ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo

  local total_checks=0
  local passed_checks=0
  local failed_checks=0

  # Helper function to check command availability
  check_command() {
    local cmd="$1"
    local description="$2"
    local optional="${3:-false}"
    
    total_checks=$((total_checks + 1))
    
    if command -v "$cmd" &> /dev/null; then
      echo -e "✅ ${GREEN}$description${NC} - $(command -v "$cmd")"
      passed_checks=$((passed_checks + 1))
    else
      if [ "$optional" = "true" ]; then
        echo -e "⚠️  ${YELLOW}$description${NC} - Not installed (optional)"
      else
        echo -e "❌ ${RED}$description${NC} - Not found"
        failed_checks=$((failed_checks + 1))
      fi
    fi
  }

  # Helper function to check file existence
  check_file() {
    local file="$1"
    local description="$2"
    local optional="${3:-false}"
    
    total_checks=$((total_checks + 1))
    
    if [ -f "$file" ]; then
      echo -e "✅ ${GREEN}$description${NC} - $file"
      passed_checks=$((passed_checks + 1))
    else
      if [ "$optional" = "true" ]; then
        echo -e "⚠️  ${YELLOW}$description${NC} - File not found (optional)"
      else
        echo -e "❌ ${RED}$description${NC} - File not found"
        failed_checks=$((failed_checks + 1))
      fi
    fi
  }

  # Helper function to check directory existence
  check_directory() {
    local dir="$1"
    local description="$2"
    local optional="${3:-false}"
    
    total_checks=$((total_checks + 1))
    
    if [ -d "$dir" ]; then
      echo -e "✅ ${GREEN}$description${NC} - $dir"
      passed_checks=$((passed_checks + 1))
    else
      if [ "$optional" = "true" ]; then
        echo -e "⚠️  ${YELLOW}$description${NC} - Directory not found (optional)"
      else
        echo -e "❌ ${RED}$description${NC} - Directory not found"
        failed_checks=$((failed_checks + 1))
      fi
    fi
  }

  # Helper function to check service status
  check_service() {
    local service="$1"
    local description="$2"
    
    total_checks=$((total_checks + 1))
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
      echo -e "✅ ${GREEN}$description${NC} - Service active"
      passed_checks=$((passed_checks + 1))
    elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
      echo -e "⚠️  ${YELLOW}$description${NC} - Service enabled but not running"
      passed_checks=$((passed_checks + 1))
    else
      echo -e "❌ ${RED}$description${NC} - Service not available"
      failed_checks=$((failed_checks + 1))
    fi
  }

  echo -e "${BLUE}🔧 System Tools:${NC}"
  check_command "curl" "curl"
  check_command "wget" "wget" 
  check_command "git" "Git"
  check_command "jq" "jq JSON processor"
  check_command "unzip" "unzip"
  check_command "keychain" "SSH keychain"
  echo

  echo -e "${BLUE}🛠️ Modern CLI Tools:${NC}"
  check_command "bat" "bat (syntax highlighting cat)" "true"
  check_command "batcat" "batcat (alternative)" "true"
  check_command "exa" "exa (modern ls)" "true"
  check_command "eza" "eza (modern ls alternative)" "true"
  check_command "fd" "fd (fast find)" "true"
  check_command "fdfind" "fd-find (alternative)" "true"
  check_command "rg" "ripgrep (fast grep)" "true"
  check_command "fzf" "fzf (fuzzy finder)" "true"
  check_command "tree" "tree" "true"
  check_command "htop" "htop" "true"
  check_command "neofetch" "neofetch" "true"
  check_command "gh" "GitHub CLI" "true"
  echo

  echo -e "${BLUE}🐍 Python Environment:${NC}"
  check_command "python3" "Python 3"
  check_command "pip" "pip package manager"
  
  # Check Python packages
  # Note: Some packages have different import names than pip names
  declare -A python_packages=(
    ["ansible"]="ansible"
    ["boto3"]="boto3" 
    ["requests"]="requests"
    ["argcomplete"]="argcomplete"
    ["pywinrm"]="winrm"  # pip package 'pywinrm' imports as 'winrm'
  )
  
  for pip_name in "${!python_packages[@]}"; do
    import_name="${python_packages[$pip_name]}"
    total_checks=$((total_checks + 1))
    if python3 -c "import $import_name" &>/dev/null; then
      echo -e "✅ ${GREEN}Python package: $pip_name${NC}"
      passed_checks=$((passed_checks + 1))
    else
      echo -e "❌ ${RED}Python package: $pip_name${NC} - Not installed"
      failed_checks=$((failed_checks + 1))
    fi
  done
  echo

  echo -e "${BLUE}☁️ Cloud & Infrastructure:${NC}"
  check_command "aws" "AWS CLI"
  check_command "session-manager-plugin" "Session Manager Plugin"
  check_command "docker" "Docker"
  check_command "tfenv" "Terraform Environment Manager" "true"
  
  # Check Docker service
  if command -v docker &> /dev/null; then
    check_service "docker" "Docker service"
    
    # Check Docker group membership
    total_checks=$((total_checks + 1))
    if groups | grep -q docker; then
      echo -e "✅ ${GREEN}Docker group membership${NC} - User in docker group"
      passed_checks=$((passed_checks + 1))
    else
      echo -e "⚠️  ${YELLOW}Docker group membership${NC} - User not in docker group (may need logout/login)"
    fi
  fi
  echo

  echo -e "${BLUE}📁 Configuration Files:${NC}"
  check_file "$HOME/.bashrc_extra" "Enhanced bashrc configuration"
  check_directory "$HOME/.tfenv" "Terraform environment directory" "true"
  check_file "$LOG_FILE" "Setup log file"
  echo

  echo -e "${BLUE}🔑 SSH Configuration:${NC}"
  check_directory "$HOME/.ssh" "SSH directory" "true"
  if [ -d "$HOME/.ssh" ]; then
    ssh_keys=$(find "$HOME/.ssh" -name "*.pub" 2>/dev/null | wc -l)
    if [ "$ssh_keys" -gt 0 ]; then
      echo -e "✅ ${GREEN}SSH keys found${NC} - $ssh_keys public key(s)"
    else
      echo -e "⚠️  ${YELLOW}SSH keys${NC} - No public keys found"
    fi
  fi
  echo

  # Summary
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}           SUMMARY REPORT               ${NC}"
  echo -e "${BLUE}========================================${NC}"
  
  local success_rate=0
  if [ $total_checks -gt 0 ]; then
    success_rate=$((passed_checks * 100 / total_checks))
  fi

  echo -e "📊 ${BLUE}Total checks:${NC} $total_checks"
  echo -e "✅ ${GREEN}Passed:${NC} $passed_checks"
  echo -e "❌ ${RED}Failed:${NC} $failed_checks"
  echo -e "📈 ${BLUE}Success rate:${NC} ${success_rate}%"
  echo

  if [ $failed_checks -eq 0 ]; then
    echo -e "🎉 ${GREEN}All critical components installed successfully!${NC}"
  elif [ $failed_checks -le 3 ]; then
    echo -e "⚠️  ${YELLOW}Most components installed. Check failed items above.${NC}"
  else
    echo -e "🔧 ${RED}Several components failed to install. Check the log file: $LOG_FILE${NC}"
  fi
  
  echo -e "${BLUE}========================================${NC}"
  echo
}

# === FIX MISSING COMPONENTS FUNCTION ===

# Function to fix only missing components
fix_missing_components() {
  echo
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}    FIXING MISSING COMPONENTS          ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo

  local fixed_count=0
  local failed_count=0

  # Check and fix Python packages
  echo -e "${BLUE}🐍 Checking Python packages...${NC}"
  # Note: Some packages have different import names than pip names
  declare -A python_packages=(
    ["ansible"]="ansible"
    ["boto3"]="boto3" 
    ["requests"]="requests"
    ["argcomplete"]="argcomplete"
    ["pywinrm"]="winrm"  # pip package 'pywinrm' imports as 'winrm'
  )
  
  for pip_name in "${!python_packages[@]}"; do
    import_name="${python_packages[$pip_name]}"
    if ! python3 -c "import $import_name" &>/dev/null; then
      echo -e "${YELLOW}Installing missing Python package: $pip_name${NC}"
      if python3 -m pip install "$pip_name" --break-system-packages --user; then
        echo -e "✅ ${GREEN}Successfully installed $pip_name${NC}"
        fixed_count=$((fixed_count + 1))
      else
        echo -e "❌ ${RED}Failed to install $pip_name${NC}"
        failed_count=$((failed_count + 1))
      fi
    else
      echo -e "✅ ${GREEN}$pip_name already installed${NC}"
    fi
  done
  echo

  # Check and fix modern CLI tools
  echo -e "${BLUE}🛠️ Checking modern CLI tools...${NC}"
  
  # Check for bat/batcat
  if ! command -v bat &> /dev/null && ! command -v batcat &> /dev/null; then
    echo -e "${YELLOW}Installing bat...${NC}"
    if install_package_safely "bat" "batcat" "syntax highlighting cat replacement"; then
      fixed_count=$((fixed_count + 1))
    else
      failed_count=$((failed_count + 1))
    fi
  else
    echo -e "✅ ${GREEN}bat/batcat already available${NC}"
  fi

  # Check for fd/fdfind
  if ! command -v fd &> /dev/null && ! command -v fdfind &> /dev/null; then
    echo -e "${YELLOW}Installing fd-find...${NC}"
    if install_package_safely "fd-find" "fd" "fast find replacement"; then
      fixed_count=$((fixed_count + 1))
    else
      failed_count=$((failed_count + 1))
    fi
  else
    echo -e "✅ ${GREEN}fd/fdfind already available${NC}"
  fi

  # Check for missing CLI tools
  cli_tools=("exa:eza" "rg:ripgrep" "fzf:" "tree:" "htop:" "neofetch:" "gh:")
  for tool_pair in "${cli_tools[@]}"; do
    IFS=':' read -r primary fallback <<< "$tool_pair"
    
    if ! command -v "$primary" &> /dev/null; then
      if [ -n "$fallback" ] && ! command -v "$fallback" &> /dev/null; then
        echo -e "${YELLOW}Installing $primary...${NC}"
        if install_package_safely "$primary" "$fallback" "modern CLI tool"; then
          fixed_count=$((fixed_count + 1))
        else
          failed_count=$((failed_count + 1))
        fi
      elif [ -z "$fallback" ]; then
        echo -e "${YELLOW}Installing $primary...${NC}"
        if install_package_safely "$primary" "" "modern CLI tool"; then
          fixed_count=$((fixed_count + 1))
        else
          failed_count=$((failed_count + 1))
        fi
      else
        echo -e "✅ ${GREEN}$primary/$fallback already available${NC}"
      fi
    else
      echo -e "✅ ${GREEN}$primary already available${NC}"
    fi
  done
  echo

  # Check and fix AWS CLI
  if ! command -v aws &> /dev/null; then
    echo -e "${BLUE}☁️ Installing AWS CLI...${NC}"
    install_aws_cli
    if command -v aws &> /dev/null; then
      fixed_count=$((fixed_count + 1))
    else
      failed_count=$((failed_count + 1))
    fi
  else
    echo -e "✅ ${GREEN}AWS CLI already installed${NC}"
  fi

  # Check and fix Session Manager Plugin
  if ! command -v session-manager-plugin &> /dev/null; then
    echo -e "${BLUE}☁️ Installing Session Manager Plugin...${NC}"
    install_session_manager_plugin
    if command -v session-manager-plugin &> /dev/null; then
      fixed_count=$((fixed_count + 1))
    else
      failed_count=$((failed_count + 1))
    fi
  else
    echo -e "✅ ${GREEN}Session Manager Plugin already installed${NC}"
  fi

  # Check and fix Docker
  if ! command -v docker &> /dev/null; then
    echo -e "${BLUE}🐳 Installing Docker...${NC}"
    install_docker
    post_install_docker
    if command -v docker &> /dev/null; then
      fixed_count=$((fixed_count + 1))
    else
      failed_count=$((failed_count + 1))
    fi
  else
    echo -e "✅ ${GREEN}Docker already installed${NC}"
    
    # Check Docker group membership
    if ! groups | grep -q docker; then
      echo -e "${YELLOW}Adding user to docker group...${NC}"
      sudo usermod -aG docker "$USER"
      echo -e "⚠️  ${YELLOW}Please logout and login again to activate docker group membership${NC}"
    fi
  fi

  # Check and fix Terraform Environment Manager
  if ! command -v tfenv &> /dev/null; then
    echo -e "${BLUE}🌍 Installing Terraform Environment Manager...${NC}"
    clone_tfenv_repository
    if command -v tfenv &> /dev/null; then
      fixed_count=$((fixed_count + 1))
    else
      failed_count=$((failed_count + 1))
    fi
  else
    echo -e "✅ ${GREEN}Terraform Environment Manager already installed${NC}"
  fi

  # Check and fix bashrc_extra
  if [ ! -f "$HOME/.bashrc_extra" ]; then
    echo -e "${BLUE}📁 Copying bashrc_extra...${NC}"
    copy_bashrc_extra
    if [ -f "$HOME/.bashrc_extra" ]; then
      fixed_count=$((fixed_count + 1))
    else
      failed_count=$((failed_count + 1))
    fi
  else
    echo -e "✅ ${GREEN}.bashrc_extra already configured${NC}"
  fi

  # Setup CLI tool aliases after installing packages
  echo -e "${BLUE}🔗 Setting up CLI tool aliases...${NC}"
  setup_cli_tool_aliases

  echo
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}           FIX SUMMARY                  ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo -e "🔧 ${BLUE}Components fixed:${NC} $fixed_count"
  echo -e "❌ ${RED}Failed to fix:${NC} $failed_count"
  
  if [ $failed_count -eq 0 ]; then
    echo -e "🎉 ${GREEN}All missing components have been fixed!${NC}"
  else
    echo -e "⚠️  ${YELLOW}Some components could not be fixed. Check the log for details.${NC}"
  fi
  echo -e "${BLUE}========================================${NC}"
  echo
}

# === FIX WARNINGS FUNCTION ===

# Function to fix optional components (yellow warnings)
fix_warnings() {
  echo
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}    FIXING OPTIONAL COMPONENTS         ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo

  local fixed_count=0
  local failed_count=0

  # Fix Terraform environment directory
  echo -e "${BLUE}🌍 Checking Terraform environment...${NC}"
  if [ ! -d "$HOME/.tfenv" ]; then
    echo -e "${YELLOW}Creating Terraform environment directory...${NC}"
    if mkdir -p "$HOME/.tfenv/bin"; then
      echo -e "✅ ${GREEN}Created ~/.tfenv directory structure${NC}"
      fixed_count=$((fixed_count + 1))
      
      # If tfenv is already cloned elsewhere, create symlink
      if [ -d "$HOME/.tfenv-repo" ]; then
        echo -e "${BLUE}Linking existing tfenv installation...${NC}"
        ln -sf "$HOME/.tfenv-repo/bin/tfenv" "$HOME/.tfenv/bin/tfenv" 2>/dev/null || true
      fi
    else
      echo -e "❌ ${RED}Failed to create ~/.tfenv directory${NC}"
      failed_count=$((failed_count + 1))
    fi
  else
    echo -e "✅ ${GREEN}Terraform environment directory already exists${NC}"
  fi
  echo

  # Fix SSH directory and setup
  echo -e "${BLUE}🔑 Checking SSH configuration...${NC}"
  if [ ! -d "$HOME/.ssh" ]; then
    echo -e "${YELLOW}Creating SSH directory...${NC}"
    if mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"; then
      echo -e "✅ ${GREEN}Created ~/.ssh directory with proper permissions${NC}"
      fixed_count=$((fixed_count + 1))
      
      # Create basic SSH config if it doesn't exist
      if [ ! -f "$HOME/.ssh/config" ]; then
        cat > "$HOME/.ssh/config" << 'EOF'
# SSH Configuration
# Uncomment and modify as needed

# Host github.com
#   HostName github.com
#   User git
#   IdentityFile ~/.ssh/id_rsa

# Host myserver
#   HostName your-server.com
#   User your-username
#   Port 22
#   IdentityFile ~/.ssh/id_rsa
EOF
        chmod 600 "$HOME/.ssh/config"
        echo -e "📝 ${GREEN}Created basic SSH config template${NC}"
      fi
    else
      echo -e "❌ ${RED}Failed to create ~/.ssh directory${NC}"
      failed_count=$((failed_count + 1))
    fi
  else
    echo -e "✅ ${GREEN}SSH directory already exists${NC}"
  fi
  echo

  # Fix modern CLI tools (install exact names instead of alternatives)
  echo -e "${BLUE}🛠️ Installing preferred CLI tool names...${NC}"
  
  # Install bat if only batcat is available
  local need_local_bin_path=false
  
  if command -v batcat &> /dev/null && ! command -v bat &> /dev/null; then
    echo -e "${YELLOW}Creating 'bat' command alias (you currently have 'batcat')...${NC}"
    
    # Create a local bin directory if it doesn't exist
    mkdir -p "$HOME/.local/bin"
    
    # Create symlink for bat -> batcat
    if ln -sf "$(which batcat)" "$HOME/.local/bin/bat" 2>/dev/null; then
      echo -e "✅ ${GREEN}Successfully created 'bat' command (symlink to batcat)${NC}"
      fixed_count=$((fixed_count + 1))
      need_local_bin_path=true
    else
      echo -e "⚠️  ${YELLOW}Could not create 'bat' symlink, 'batcat' works identically${NC}"
    fi
  elif command -v bat &> /dev/null; then
    echo -e "✅ ${GREEN}'bat' already available${NC}"
  else
    echo -e "⚠️  ${YELLOW}Neither 'bat' nor 'batcat' found${NC}"
  fi

  # Create fd symlink if only fdfind is available  
  if command -v fdfind &> /dev/null && ! command -v fd &> /dev/null; then
    echo -e "${YELLOW}Creating 'fd' command alias (you currently have 'fdfind')...${NC}"
    
    # Create a local bin directory if it doesn't exist
    mkdir -p "$HOME/.local/bin"
    
    # Create symlink for fd -> fdfind
    if ln -sf "$(which fdfind)" "$HOME/.local/bin/fd" 2>/dev/null; then
      echo -e "✅ ${GREEN}Successfully created 'fd' command (symlink to fdfind)${NC}"
      fixed_count=$((fixed_count + 1))
      need_local_bin_path=true
    else
      echo -e "⚠️  ${YELLOW}Could not create 'fd' symlink, 'fdfind' works identically${NC}"
    fi
  elif command -v fd &> /dev/null; then
    echo -e "✅ ${GREEN}'fd' already available${NC}"
  else
    echo -e "⚠️  ${YELLOW}Neither 'fd' nor 'fdfind' found${NC}"
  fi
  
  # Add ~/.local/bin to PATH if we created any symlinks
  if [ "$need_local_bin_path" = true ]; then
    if ! grep -q 'PATH.*\.local/bin' "$HOME/.bashrc_extra" 2>/dev/null; then
      echo >> "$HOME/.bashrc_extra"
      echo '# Add ~/.local/bin to PATH for user binaries' >> "$HOME/.bashrc_extra"
      echo 'if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then' >> "$HOME/.bashrc_extra"
      echo '    export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc_extra"
      echo 'fi' >> "$HOME/.bashrc_extra"
      echo -e "✅ ${GREEN}Added ~/.local/bin to PATH in .bashrc_extra${NC}"
    fi
  fi
  echo

  # Generate SSH keys if directory exists but no keys found
  if [ -d "$HOME/.ssh" ] && [ $(find "$HOME/.ssh" -name "*.pub" 2>/dev/null | wc -l) -eq 0 ]; then
    echo -e "${BLUE}🔐 SSH key generation...${NC}"
    echo -e "${YELLOW}No SSH keys found. Would you like to generate SSH keys for Git/servers?${NC}"
    echo -e "${BLUE}This is optional - you can skip if you use HTTPS for Git.${NC}"
    read -p "Generate SSH key pair? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      read -p "Enter your email for SSH key: " ssh_email
      if [ -n "$ssh_email" ]; then
        if ssh-keygen -t rsa -b 4096 -C "$ssh_email" -f "$HOME/.ssh/id_rsa" -N ""; then
          echo -e "✅ ${GREEN}SSH key pair generated successfully${NC}"
          echo -e "${BLUE}Your public key:${NC}"
          cat "$HOME/.ssh/id_rsa.pub"
          echo
          echo -e "${YELLOW}Add this public key to your Git provider (GitHub/GitLab/etc.)${NC}"
          fixed_count=$((fixed_count + 1))
        else
          echo -e "❌ ${RED}Failed to generate SSH key${NC}"
          failed_count=$((failed_count + 1))
        fi
      else
        echo -e "⚠️  ${YELLOW}Skipped SSH key generation - no email provided${NC}"
      fi
    else
      echo -e "⚠️  ${YELLOW}Skipped SSH key generation${NC}"
    fi
  fi

  echo
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}           WARNINGS FIX SUMMARY        ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo -e "🔧 ${BLUE}Warnings fixed:${NC} $fixed_count"
  echo -e "❌ ${RED}Failed to fix:${NC} $failed_count"
  
  if [ $failed_count -eq 0 ]; then
    echo -e "🎉 ${GREEN}All optional components have been configured!${NC}"
  else
    echo -e "⚠️  ${YELLOW}Some optional components could not be configured.${NC}"
  fi
  echo -e "${BLUE}========================================${NC}"
  echo
}

# Function to get WSL distribution name dynamically
get_wsl_distro_name() {
  # Method 1: Use WSL_DISTRO_NAME environment variable (most reliable)
  if [ -n "$WSL_DISTRO_NAME" ]; then
    echo "$WSL_DISTRO_NAME"
    return 0
  fi
  
  # Method 2: Fallback to Ubuntu-{version} format
  if [ -f "/etc/os-release" ]; then
    local ubuntu_version=$(/bin/grep "VERSION_ID" /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
    if [ -n "$ubuntu_version" ]; then
      echo "Ubuntu-$ubuntu_version"
      return 0
    fi
  fi
  
  # Method 3: Final fallback
  echo "Ubuntu-24.04"
}

# === SCRIPT EXECUTION ===${NC}

if [ "$CHECK_ONLY" = true ]; then
  echo -e "${BLUE}Running verification checks only...${NC}"
  echo -e "${BLUE}Log file: $LOG_FILE${NC}"
  verify_installation
  exit 0
fi

if [ "$FIX_ONLY" = true ]; then
  echo -e "${BLUE}Running fix missing components only...${NC}"
  echo -e "${BLUE}Log file: $LOG_FILE${NC}"
  check_internet
  fix_missing_components
  echo
  echo -e "${BLUE}Running verification after fixes...${NC}"
  verify_installation
  exit 0
fi

if [ "$FIX_WARNINGS" = true ]; then
  echo -e "${BLUE}Fixing optional components (warnings)...${NC}"
  echo -e "${BLUE}Log file: $LOG_FILE${NC}"
  check_internet
  fix_warnings
  echo
  echo -e "${BLUE}Running verification after fixes...${NC}"
  verify_installation
  exit 0
fi

# Function call
echo -e "${BLUE}Starting WSL2 configuration...${NC}"
echo -e "${BLUE}Log file: $LOG_FILE${NC}"

check_internet
install_basic_packages
install_modern_cli_tools
setup_python_environment
copy_bashrc_extra
setup_cli_tool_aliases
install_aws_cli
install_session_manager_plugin
install_docker
post_install_docker
clone_tfenv_repository
git_configuration

# Run verification after installation
verify_installation

echo
echo -e "${RED}The basic configuration of WSL2 is now complete.${NC}"
wsl_distro=$(get_wsl_distro_name)
echo -e "${RED}You should restart WSL2 using PowerShell as administrator and use the command 'wsl -t $wsl_distro'.${NC}"