# 🐧 WSL2 Complete Development Environment Setup

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows%2010%2B-lightgrey.svg)
![WSL](https://img.shields.io/badge/WSL-2.0-green.svg)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-orange.svg)

A comprehensive automation suite for setting up Windows Subsystem for Linux (WSL2) with a complete development environment. This repository provides scripts to install WSL2 on Windows and configure a fully-featured Ubuntu development environment with modern CLI tools, Docker, AWS tools, and more.

## ✨ Features

### Windows Setup (`SetupWSL2.ps1`)
- ✅ Automatic WSL2 feature enablement
- ✅ Virtual Machine Platform configuration
- ✅ Latest WSL distribution installation
- ✅ Winget package manager setup

### WSL Development Environment (`config.sh`)
- 🔧 **System Packages**: Essential development tools and utilities
- 🛠️ **Modern CLI Tools**: bat, exa/eza, fd-find, ripgrep, fzf, tree, htop, neofetch
- 🐍 **Python Environment**: pip, ansible, boto3, and development packages
- ☁️ **Cloud Tools**: AWS CLI, Session Manager plugin
- 🐳 **Containerization**: Docker CE with proper user configuration
- 🌍 **Infrastructure**: Terraform environment manager (tfenv)
- 📝 **Version Control**: Git with useful aliases and configurations
- 🔐 **Security**: SSH key management with keychain
- 🎨 **Shell Enhancement**: Custom prompt with git integration and modern aliases

## 📋 Contents
- `SetupWSL2.ps1` - PowerShell script for Windows WSL2 installation
- `wsl2_basic_config/` - Complete WSL environment configuration suite
  - `config.sh` - Main configuration script with robust error handling
  - `.bashrc_extra` - Enhanced shell configuration with modern aliases
  - `README.md` - Detailed WSL configuration documentation

## 🚀 Quick Start

### Prerequisites
- Windows 10 version 2004+ or Windows 11
- PowerShell 5.1 or higher
- Administrative privileges
- Active internet connection

### Step 1: Windows Setup

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/solarekm/wsl2.git
   cd wsl2
   ```

2. **Run PowerShell as Administrator and execute:**
   ```powershell
   .\SetupWSL2.ps1
   ```

3. **Restart your computer** when prompted.

### Step 2: WSL Environment Configuration

1. **Open WSL terminal** (search "Ubuntu" in Start Menu)

2. **Navigate to configuration directory:**
   ```bash
   cd /path/to/wsl2/wsl2_basic_config
   ```

3. **Run the configuration script:**
   ```bash
   chmod +x config.sh
   ./config.sh
   ```

4. **Follow interactive prompts** for Git configuration

5. **Restart WSL** to apply all changes:
   ```powershell
   # In PowerShell as Administrator
   wsl -t Ubuntu-24.04
   wsl
   ```

## 🛠️ What Gets Installed

### Core System Tools
- **Package Managers**: apt, pip, winget integration
- **Network Tools**: curl, wget, wslu (WSL utilities)
- **Development**: git, unzip, keychain

### Modern CLI Replacements
- **`bat`/`batcat`** → Enhanced `cat` with syntax highlighting
- **`exa`/`eza`** → Modern `ls` with git integration
- **`fd-find`** → Fast and user-friendly `find` replacement
- **`ripgrep`** → Ultra-fast text search tool
- **`fzf`** → Command-line fuzzy finder
- **`tree`** → Directory structure visualization
- **`htop`** → Interactive process viewer
- **`neofetch`** → System information display

### Development Environment
- **Docker**: Container platform with user permissions
- **AWS CLI**: Command-line interface for Amazon Web Services
- **Session Manager**: Secure shell access to EC2 instances
- **Terraform**: Infrastructure as code via tfenv manager

### Python Ecosystem
- **ansible** → Infrastructure automation
- **boto3** → AWS SDK for Python
- **requests** → HTTP library
- **argcomplete** → Command completion
- **pywinrm** → Windows Remote Management

## 🔧 Advanced Features

- **🔄 Idempotent**: Run multiple times safely
- **🛡️ Error Resilient**: Robust error handling and recovery
- **📝 Comprehensive Logging**: All operations logged to `~/wsl2_setup.log`
- **🔍 Package Fallbacks**: Automatic alternatives for unavailable packages
- **🌐 Network Retry**: Automatic retry for network operations
- **⚡ Smart Detection**: Skips already installed components

## 📖 Documentation

For detailed configuration options and troubleshooting, see:
- [WSL Configuration Guide](./wsl2_basic_config/README.md)
- [Installation Log](~/wsl2_setup.log) (created during setup)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Microsoft WSL team for the amazing Windows Subsystem for Linux
- Ubuntu team for the excellent Ubuntu distribution
- All maintainers of the CLI tools and packages included in this setup

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/solarekm/wsl2/issues)
- **Project**: [GitHub Repository](https://github.com/solarekm/wsl2)