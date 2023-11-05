# System Setup Script

This repository contains a Bash script for automating the setup of a Linux environment. The script is designed to run on Debian-based distributions and automates the installation of essential packages, Python libraries, and development tools such as AWS CLI, Docker, and Terraform.

## Prerequisites

Before running the script, ensure that you have a Debian-based Linux distribution. This script has been tested on Ubuntu.

## Features

- Automatic update of package listings.
- Installation of required packages listed in a file.
- Installation of required Python libraries listed in a file.
- Installation of AWS CLI v2.
- Installation of Docker and adding the user to the Docker group.
- Installation of Terraform.
- Update of the user's `.bashrc` with custom configuration from `.bashrc_extra`.

## Usage

To use the script, follow these steps:

1. Clone the repository or download the `setup.sh` script to your local machine.
2. Make sure you have the `req_packages`, `py_libraries` and `.bashrc_extra` files in the same directory as the script. These files should contain the list of packages and Python libraries you wish to install, respectively.
3. Give the script execution permissions:

    ```sh
    chmod +x setup.sh
    ```

4. Run the script:

    ```sh
    ./setup.sh
    ```

5. The script will ask for your user password for executing commands with `sudo`.
