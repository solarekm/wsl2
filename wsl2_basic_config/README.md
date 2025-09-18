# 🔧 WSL2 Development Environment Configuration

This directory contains the automated configuration system for setting up a complete development environment in Windows Subsystem for Linux (WSL2). Optimized and tested for Ubuntu 24.04 LTS.

## 📁 Contents

### Core Files
- **`config.sh`** - Main configuration script with comprehensive error handling
- **`.bashrc_extra`** - Enhanced shell configuration with modern CLI aliases
- **`config_old.sh`** - Backup of previous configuration (auto-generated)

### Generated Files
- **`~/wsl2_setup.log`** - Comprehensive installation log (created during setup)

## 🚀 Quick Setup

### Prerequisites
- Ubuntu 24.04 LTS running in WSL2
- Active internet connection
- Basic user permissions (script handles sudo automatically)

### Installation

1. **Make the script executable:**
   ```bash
   chmod +x config.sh
   ```

2. **Run the configuration script:**
   ```bash
   ./config.sh
   ```

3. **Follow interactive prompts** for Git user configuration

4. **Restart your WSL session** to activate all changes:
   ```bash
   # In PowerShell as Administrator
   wsl -t Ubuntu-24.04
   wsl
   ```

## 🛠️ What Gets Configured

### System Foundation
- **Package Management**: Updates system packages and repositories
- **Internet Connectivity**: Validates network access before installation
- **Python Environment**: Secure pip configuration and essential packages
- **SSH Key Management**: Automated keychain setup for secure development

### Development Tools

#### Modern CLI Tools (with fallbacks)
| Tool | Purpose | Fallback | Command Alias |
|------|---------|----------|---------------|
| `bat`/`batcat` | Syntax-highlighted file viewer | System cat | `cat` |
| `exa`/`eza` | Modern directory listing | System ls | `ls`, `ll` |
| `fd-find`/`fd` | Fast file finder | System find | `find` |
| `ripgrep` | Ultra-fast text search | System grep | `grep` |
| `fzf` | Fuzzy finder | None | Direct command |
| `tree` | Directory tree viewer | None | Direct command |
| `htop` | Interactive process monitor | None | Direct command |
| `neofetch` | System information display | None | Direct command |

#### Cloud & Infrastructure
- **AWS CLI v2**: Latest Amazon Web Services command-line interface
- **Session Manager Plugin**: Secure EC2 access without SSH keys
- **Docker CE**: Complete container platform with user permissions
- **Terraform Environment Manager**: Version management for Infrastructure as Code

#### Development Environment
- **Git Configuration**: Enhanced with useful aliases and modern defaults
  ```bash
  git st    # status
  git co    # checkout  
  git br    # branch
  git unstage # reset HEAD --
  git last  # log -1 HEAD
  ```
- **Python Packages**: Essential development libraries
  - `ansible` - Infrastructure automation
  - `boto3` - AWS SDK for Python
  - `requests` - HTTP library
  - `argcomplete` - Command completion

### Shell Enhancements

#### Custom Prompt Features
- **Timestamp**: Shows current date and time
- **Git Integration**: Displays current branch and status
- **Color Coding**: User, host, and path highlighting
- **Directory Trimming**: Shortened paths for clean display

#### Smart Aliases (Dynamic)
The configuration intelligently sets aliases based on available tools:
```bash
# Only set if tools are installed
alias ll='exa -la --git'    # or 'eza -la --git'
alias cat='bat'             # or 'batcat' 
alias find='fdfind'         # or 'fd'
alias grep='rg'             # if ripgrep available
```

#### Browser Integration
- **`wslview`**: Opens URLs in Windows default browser
- **Environment Variable**: `BROWSER=wslview` for automatic integration

## 🔧 Advanced Features

### Reliability & Safety
- **🔄 Idempotent Design**: Safe to run multiple times
- **🛡️ Robust Error Handling**: Continues on non-critical failures  
- **📝 Comprehensive Logging**: All operations logged with timestamps
- **🔍 Package Validation**: Checks availability before installation
- **⚡ Smart Fallbacks**: Automatic alternatives for missing packages
- **🌐 Network Resilience**: Retry mechanism for downloads

### Security Considerations
- **SSH Key Management**: Automated permission fixing and keychain integration
- **Docker Security**: Proper user group configuration
- **Python Safety**: Careful handling of system package restrictions

## 📋 Configuration Process

The script follows this logical sequence:

1. **🌐 Connectivity Check** - Validates internet access
2. **📦 System Packages** - Updates and installs base tools
3. **🛠️ CLI Tools** - Modern alternatives with fallback handling
4. **🐍 Python Setup** - Environment and package installation
5. **🎨 Shell Config** - Copies and activates `.bashrc_extra`
6. **☁️ AWS Tools** - CLI and Session Manager setup
7. **🐳 Docker** - Complete installation and user configuration
8. **🌍 Infrastructure** - Terraform environment manager
9. **📝 Git** - User configuration and useful defaults

## 🎯 Customization

### Modifying Package Lists
Edit the script functions to add/remove packages:
```bash
# In install_modern_cli_tools()
install_package_safely "your-package" "fallback-package" "description"

# In setup_python_environment()  
python_packages="ansible boto3 your-package"
```

### Shell Customization
Modify `.bashrc_extra` for:
- Additional aliases
- Custom functions
- Environment variables
- Prompt modifications

### Git Configuration
The script sets these Git defaults (customizable):
```bash
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.autocrlf input
git config --global core.editor "nano"
```

## 🐛 Troubleshooting

### Common Issues

#### Permission Errors
```bash
# If Docker group membership doesn't take effect
newgrp docker
# Or restart WSL session
```

#### Package Installation Failures
- Check `~/wsl2_setup.log` for detailed error information
- Verify internet connectivity: `ping 8.8.8.8`
- Update package lists: `sudo apt update`

#### Python Package Issues
- The script safely handles `EXTERNALLY-MANAGED` restrictions
- For manual installation: Use `--break-system-packages` flag
- Virtual environments recommended for project-specific packages

#### WSL Integration Issues
- Ensure WSL utilities are installed: `sudo apt install wslu`
- For browser integration: Verify `wslview` command works
- Windows integration requires up-to-date WSL2

### Log Analysis
```bash
# View setup log
less ~/wsl2_setup.log

# Check recent errors
tail -n 50 ~/wsl2_setup.log | grep -i error

# Monitor installation in real-time
tail -f ~/wsl2_setup.log
```

## 🔄 Updates and Maintenance

### Re-running the Script
The configuration is designed to be re-run safely:
- Skips already installed packages
- Updates existing configurations
- Handles version changes gracefully

### Keeping Tools Updated
```bash
# System packages
sudo apt update && sudo apt upgrade

# Python packages  
pip install --upgrade package-name

# AWS CLI (automatic updates)
# Docker (via apt)
# Terraform versions (via tfenv)
```

## 🤝 Contributing

Improvements and suggestions are welcome! Areas for contribution:
- Additional CLI tools and their fallbacks
- Enhanced error handling
- New development environment presets
- Documentation improvements
- Testing on other Ubuntu versions

## 📄 License

This configuration is part of the WSL2 setup project, licensed under the MIT License. See the main repository LICENSE file for details.

## 🙏 Acknowledgments

- **Ubuntu Team**: For the excellent Ubuntu 24.04 LTS distribution
- **WSL Team**: For the amazing Windows Subsystem for Linux
- **CLI Tool Maintainers**: For creating the modern alternatives that make development enjoyable
- **Community**: For feedback and contributions to improve this configuration
