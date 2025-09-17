# WSL2 Basic Configuration

This directory contains scripts and configuration files to set up a basic working environment within the Windows Subsystem for Linux (WSL), tested with the Ubuntu-24.04 distribution.

## Contents

- `.bashrc_extra` - Contains additional bash shell configuration commands.
- `config.sh` - A shell script to automate the setup of your WSL environment with Ubuntu-24.04.

## Configuration Steps

To properly set up your WSL environment using the provided scripts and configuration files, specifically tailored for Ubuntu-24.04, follow these steps:

1. Open your WSL terminal and navigate to the directory where you have placed these files.

2. Ensure that `config.sh` is executable:

    ```bash
    chmod +x config.sh
    ```

3. Run `config.sh` to start the configuration process:

    ```bash
    ./config.sh
    ```

   This script will source the `.bashrc_extra` file to update your shell configuration and install necessary packages and tools.

4. Once the script completes, you may need to restart your terminal or source your `.bashrc` to apply the changes:

    ```bash
    source ~/.bashrc
    ```

## Customization

Feel free to modify the `config.sh` and `.bashrc_extra` files to suit your specific needs. Add or remove packages and configurations as needed. This setup is optimized for Ubuntu-24.04, but may be adapted for other distributions.

## Troubleshooting

If you encounter any issues while running the scripts, ensure that:

- You have the necessary permissions to execute the scripts.
- You are using the recommended Ubuntu-24.04 distribution or another compatible WSL distribution.
- Your WSL distribution is up-to-date.
- You are connected to the internet, as some scripts may require downloading packages from online repositories.

## Contributing

Contributions to improve the configuration or add more utilities are welcome, especially those tested with Ubuntu-22.04. If you have any suggestions or improvements, please fork the repository, make your changes, and submit a pull request.

## License

This project is licensed under the MIT License - see the LICENSE file in the root directory for details.

## Acknowledgments

- Thanks to all the contributors who have helped to enhance this WSL configuration.
- Special thanks to the creators and maintainers of the packages and tools included in this setup, with particular regard for those optimized for Ubuntu-22.04.
