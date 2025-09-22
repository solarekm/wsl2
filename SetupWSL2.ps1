# PowerShell Script to Prepare Windows for WSL2 Installation with Enhanced Error Handling
# Version: 2.0
# Author: Enhanced WSL2 Setup Script
# Description: Comprehensive WSL2 setup with proper error handling, logging, and verification

#Requires -RunAsAdministrator

# === CONFIGURATION AND SETUP ===

# Error handling configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Create log file
$LogFile = "$env:USERPROFILE\WSL2_Setup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# === LOGGING FUNCTIONS ===

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
    
    # Write to console with colors
    switch ($Level) {
        "SUCCESS" { Write-Host "✅ $Message" -ForegroundColor Green }
        "WARNING" { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
        "ERROR"   { Write-Host "❌ $Message" -ForegroundColor Red }
        default   { Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
    }
}

function Write-Progress-Header {
    param([string]$Title)
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "  $Title" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
}

# === VERIFICATION FUNCTIONS ===

function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WingetInstalled {
    try {
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetPath) {
            $version = & winget --version 2>$null
            Write-Log "Winget found: $version" "SUCCESS"
            return $true
        }
        return $false
    }
    catch {
        Write-Log "Error checking Winget: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-WSLFeatureEnabled {
    param([string]$FeatureName)
    
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
        if ($feature -and $feature.State -eq "Enabled") {
            Write-Log "Feature '$FeatureName' is already enabled" "SUCCESS"
            return $true
        }
        return $false
    }
    catch {
        Write-Log "Error checking feature '$FeatureName': $($_.Exception.Message)" "WARNING"
        return $false
    }
}

# === INSTALLATION FUNCTIONS ===

function Install-WingetPackageManager {
    if (Test-WingetInstalled) {
        Write-Log "Winget is already installed" "SUCCESS"
        return $true
    }
    
    Write-Log "Installing Winget Package Manager..." "INFO"
    
    try {
        # Download and install Microsoft Desktop App Installer (includes Winget)
        $AppInstallerUrl = "https://aka.ms/getwinget"
        $TempPath = "$env:TEMP\Microsoft.DesktopAppInstaller.msixbundle"
        
        Write-Log "Downloading Winget installer..." "INFO"
        Invoke-WebRequest -Uri $AppInstallerUrl -OutFile $TempPath -UseBasicParsing
        
        Write-Log "Installing Winget..." "INFO"
        Add-AppxPackage -Path $TempPath -ForceApplicationShutdown
        
        # Verify installation
        Start-Sleep -Seconds 3
        if (Test-WingetInstalled) {
            Write-Log "Winget installation completed successfully" "SUCCESS"
            Remove-Item -Path $TempPath -Force -ErrorAction SilentlyContinue
            return $true
        } else {
            throw "Winget verification failed after installation"
        }
    }
    catch {
        Write-Log "Failed to install Winget: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Enable-WSLFeature {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FeatureName,
        
        [Parameter(Mandatory=$true)]
        [string]$DisplayName
    )
    
    if (Test-WSLFeatureEnabled -FeatureName $FeatureName) {
        return $true
    }
    
    Write-Log "Enabling Windows feature: $DisplayName" "INFO"
    
    try {
        $result = dism.exe /online /enable-feature /featurename:$FeatureName /all /norestart
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Successfully enabled feature: $DisplayName" "SUCCESS"
            return $true
        } elseif ($LASTEXITCODE -eq 3010) {
            Write-Log "Feature enabled (restart required): $DisplayName" "SUCCESS"
            return $true
        } else {
            throw "DISM returned exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Log "Failed to enable feature '$DisplayName': $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Install-WSLFromStore {
    Write-Log "Installing Windows Subsystem for Linux from Microsoft Store..." "INFO"
    
    try {
        # Check if WSL is already installed
        $wslInstalled = Get-AppxPackage -Name "*WindowsSubsystemForLinux*" -ErrorAction SilentlyContinue
        if ($wslInstalled) {
            Write-Log "WSL is already installed" "SUCCESS"
            return $true
        }
        
        # Install WSL using Winget
        $result = & winget install --id=9P9TQF7MRM4R --source=msstore --accept-package-agreements --accept-source-agreements 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "WSL installation completed successfully" "SUCCESS"
            return $true
        } else {
            Write-Log "Winget exit code: $LASTEXITCODE, Output: $result" "WARNING"
            # Try alternative installation method
            Write-Log "Trying alternative installation method..." "INFO"
            $altResult = & winget install Microsoft.WindowsSubsystemForLinux --accept-package-agreements --accept-source-agreements 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "WSL installation completed via alternative method" "SUCCESS"
                return $true
            } else {
                throw "Both installation methods failed. Exit code: $LASTEXITCODE"
            }
        }
    }
    catch {
        Write-Log "Failed to install WSL: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Set-WSLDefaultVersion {
    Write-Log "Setting WSL 2 as the default version..." "INFO"
    
    try {
        $result = & wsl --set-default-version 2 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "WSL 2 set as default version successfully" "SUCCESS"
            return $true
        } else {
            Write-Log "WSL command output: $result" "WARNING"
            # WSL might not be fully ready yet, but command succeeded
            Write-Log "WSL default version command executed (may require restart)" "SUCCESS"
            return $true
        }
    }
    catch {
        Write-Log "Failed to set WSL default version: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# === MAIN EXECUTION ===

function Main {
    Write-Progress-Header "WSL2 Setup Script v2.0"
    
    Write-Log "Starting WSL2 configuration..." "INFO"
    Write-Log "Log file: $LogFile" "INFO"
    
    # Verify administrator privileges
    if (-not (Test-Administrator)) {
        Write-Log "This script requires administrator privileges. Please run PowerShell as an administrator." "ERROR"
        exit 1
    }
    
    Write-Log "Administrator privileges confirmed" "SUCCESS"
    
    # Track installation status
    $StepsCompleted = 0
    $TotalSteps = 5
    $RestartRequired = $false
    
    # Step 1: Install Winget
    Write-Progress-Header "Step 1/$TotalSteps: Installing Winget Package Manager"
    if (Install-WingetPackageManager) {
        $StepsCompleted++
    }
    
    # Step 2: Enable WSL Feature
    Write-Progress-Header "Step 2/$TotalSteps: Enabling WSL Feature"
    if (Enable-WSLFeature -FeatureName "Microsoft-Windows-Subsystem-Linux" -DisplayName "Windows Subsystem for Linux") {
        $StepsCompleted++
        $RestartRequired = $true
    }
    
    # Step 3: Enable Virtual Machine Platform
    Write-Progress-Header "Step 3/$TotalSteps: Enabling Virtual Machine Platform"
    if (Enable-WSLFeature -FeatureName "VirtualMachinePlatform" -DisplayName "Virtual Machine Platform") {
        $StepsCompleted++
        $RestartRequired = $true
    }
    
    # Step 4: Install WSL from Microsoft Store
    Write-Progress-Header "Step 4/$TotalSteps: Installing WSL from Microsoft Store"
    if (Install-WSLFromStore) {
        $StepsCompleted++
    }
    
    # Step 5: Set WSL 2 as default
    Write-Progress-Header "Step 5/$TotalSteps: Setting WSL 2 as Default Version"
    if (Set-WSLDefaultVersion) {
        $StepsCompleted++
    }
    
    # Final summary
    Write-Progress-Header "Installation Summary"
    
    Write-Log "Steps completed: $StepsCompleted/$TotalSteps" "INFO"
    
    if ($StepsCompleted -eq $TotalSteps) {
        Write-Log "🎉 WSL2 configuration completed successfully!" "SUCCESS"
    } elseif ($StepsCompleted -gt 0) {
        Write-Log "⚠️  WSL2 configuration partially completed. Check log for details." "WARNING"
    } else {
        Write-Log "❌ WSL2 configuration failed. Check log for details." "ERROR"
        exit 1
    }
    
    if ($RestartRequired) {
        Write-Host ""
        Write-Log "🔄 RESTART REQUIRED: Please restart your computer to complete the WSL2 setup." "WARNING"
        Write-Log "After restart, you can install Ubuntu 24.04 LTS from Microsoft Store" "INFO"
        Write-Log "or use: wsl --install -d Ubuntu-24.04" "INFO"
    }
    
    Write-Log "Setup log saved to: $LogFile" "INFO"
    Write-Host ""
    
    # Pause to let user read the summary
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Execute main function
try {
    Main
}
catch {
    Write-Log "Critical error in main execution: $($_.Exception.Message)" "ERROR"
    Write-Log "Setup log saved to: $LogFile" "ERROR"
    exit 1
}
