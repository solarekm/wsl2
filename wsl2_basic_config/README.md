# WSL2 Basic Configuration

This directory contains scripts and configuration files to set up a basic working environment within the Windows Subsystem for Linux (WSL).

## Contents

- `.bashrc_extra` - Contains additional bash shell configuration commands.
- `config.sh` - A shell script to automate the setup of your WSL environment.
- `py_libraries` - A list of Python libraries to be installed.
- `req_packages` - A file listing required system packages.

## Configuration Steps

To properly set up your WSL environment using the provided scripts and configuration files, follow these steps:

1. Open your WSL terminal and navigate to the directory where you have placed these files.

2. Ensure that `config.sh` is executable:

    ```bash
    chmod +x config.sh
    ```

3. Run `config.sh` to start the configuration process:

    ```bash
    ./config.sh
    ```

   This script will source the `.bashrc_extra` file to update your shell configuration and install the packages listed in `req_packages` and `py_libraries`.

4. Once the script completes, you may need to restart your terminal or source your `.bashrc` to apply the changes:

    ```bash
    source ~/.bashrc
    ```

## Customization

Feel free to modify the `config.sh`, `.bashrc_extra`, `py_libraries`, and `req_packages` files to suit your specific needs. Add or remove packages and configurations as needed.

## Troubleshooting

If you encounter any issues while running the scripts, ensure that:

- You have the necessary permissions to execute the scripts.
- Your WSL distribution is up-to-date.
- You are connected to the internet, as some scripts may require downloading packages from online repositories.

## Contributing

Contributions to improve the configuration or add more utilities are welcome. If you have any suggestions or improvements, please fork the repository, make your changes, and submit a pull request.

## License

This project is licensed under the MIT License - see the LICENSE file in the root directory for details.

## Acknowledgments

- Thanks to all the contributors who have helped to enhance this WSL configuration.
- Special thanks to the creators and maintainers of the packages and tools included in this setup.
