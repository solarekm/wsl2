# PowerShell Script to Prepare Windows for WSL2 Installation and Install Winget if necessary

# Function to check if the script is run as an administrator
function Is-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if the script is run with administrative privileges
if (-not (Is-Administrator)) {
    Write-Host "This script requires administrator privileges. Please run PowerShell as an administrator and try again." -ForegroundColor Red
    exit
}

# Function to check if Winget is installed
function Is-WingetInstalled {
    return Get-Command winget -ErrorAction SilentlyContinue
}

# Install Winget if it is not present
if (-not (Is-WingetInstalled)) {
    Write-Host "Winget is not installed. Attempting to install Winget..." -ForegroundColor Yellow
    # Since Winget is included in the App Installer, we can use the following PowerShell command to install it
    winget install Microsoft.Winget.Source --source winget
}

Write-Host "Enabling feature: Microsoft-Windows-Subsystem-Linux" -ForegroundColor Green
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

Write-Host "Enabling feature: VirtualMachinePlatform" -ForegroundColor Green
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Install Windows Subsystem for Linux using its Microsoft Store ID with Winget
Write-Host "Installing Windows Subsystem for Linux (WSL) from the Microsoft Store" -ForegroundColor Green
winget install --id=9P9TQF7MRM4R --source=msstore

Write-Host "Setting WSL 2 as the default version" -ForegroundColor Green
wsl --set-default-version 2

Write-Host "WSL2 configuration complete. Please restart your computer to complete the setup process." -ForegroundColor Green
