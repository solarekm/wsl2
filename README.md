# Windows Subsystem for Linux (WSL) Basic Configuration

This repository holds a set of scripts designed to prepare a Windows system for WSL and to configure a basic working environment in WSL.

## Contents
- `SetupWSL2.ps1` - A PowerShell script to automate the setup of Windows Subsystem for Linux (WSL) on a Windows machine.
- `wsl2_basic_config/` - A collection of configurations and scripts to set up a basic working environment within WSL.

## Getting Started

### Prerequisites
- Windows 10 or higher.
- PowerShell 5.1 or higher.
- Administrative privileges on the system.

### Installation

1. Clone the repository or download the ZIP file and extract it on your local machine.

    ```shell
    git clone https://github.com/solarekm/wsl2.git
    ```

2. Navigate to the directory containing `SetupWSL2.ps1`.

3. Right-click on PowerShell and run as Administrator.

4. Execute the `SetupWSL2.ps1` script:

    ```powershell
    .\SetupWSL2.ps1
    ```

5. After the script finishes, restart your computer to complete the WSL2 feature installation.

### Configuring WSL Environment

1. After your system restarts, open WSL terminal.

2. Navigate to the `wsl2_basic_config` directory:

    ```shell
    cd path/to/wsl2_basic_config
    ```

3. Run the configuration script:

    ```shell
    ./config.sh
    ```

4. Follow any on-screen prompts to complete the configuration.

## What's Inside `wsl2_basic_config`

- `.bashrc_extra` - Additional bash configurations.
- `config.sh` - Script to set up environment variables and install necessary packages.
- `py_libraries` - List of Python libraries to install.
- `req_packages` - System packages required for your WSL environment.

## Contributions

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

Project Link: https://github.com/solarekm/wsl2