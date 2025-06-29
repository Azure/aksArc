# Function to log messages
function Log-Message {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "$timestamp [$level] $message"
}


# Function to download the certificate
function Download-Certificate {
    param (
        [string]$url,
        [string]$destinationPath
    )

    try {
        if (-Not (Test-Path -Path $destinationPath)) {
            Log-Message -message "Downloading certificate from $url"
            Invoke-WebRequest -Uri $url -OutFile $destinationPath
            if (-Not (Test-Path -Path $destinationPath)) {
                Log-Message -message "Failed to download certificate from $url" -level "ERROR"
                throw "Failed to download certificate from $url"
            }
            Log-Message -message "Certificate downloaded to $destinationPath"
        } else {
            Log-Message -message "Certificate already exists at $destinationPath. Skipping download."
        }
    }
    catch {
        Log-Message -message "An error occurred: $_" -level "ERROR"
        throw $_
    }
}


# Function to download, and extract, if executable doesn't exist
function Download-Extract {
    param (
        [string]$url,
        [string]$destinationPath,
        [string]$exePath
    )

    try {
        # Check if the executable already exists
        if (-Not (Test-Path -Path $exePath)) {
            Log-Message -message "Executable not found at $exePath. Proceeding with download and extraction."

            # Download the file using curl
            Log-Message -message "Downloading file from $url"
            & curl -o $destinationPath $url

            # Extract the file using tar
            Log-Message -message "Extracting file to $(Split-Path -Parent $destinationPath)"
            tar -xf $destinationPath -C $(Split-Path -Parent $destinationPath)
            # Check if file exists
            if (-Not (Test-Path -Path $exePath)) {
                Log-Message -message "Failed to extract file to $exePath" -level "ERROR"
                throw "Failed to extract file to $exePath"
            }

        } else {
            Log-Message -message "Executable already exists at $exePath. Skipping download and extraction."
        }
    }
    catch {
        Log-Message -message "An error occurred: $_" -level "ERROR"
        throw $_
    }
}



$caCertificatePath = "https://www.microsoft.com/pkiops/certs/Microsoft%20Supply%20Chain%20RSA%20Root%20CA%202022.crt"
$tsaCertificatePath = "http://www.microsoft.com/pki/certs/MicRooCerAut_2010-06-23.crt"
$notationWinDownLoadPath = "https://github.com/notaryproject/notation/releases/download/v1.3.1/notation_1.3.1_windows_amd64.zip"
$notationLinuxDownLoadPath = "https://github.com/notaryproject/notation/releases/download/v1.3.1/notation_1.3.1_linux_amd64.tar.gz"
$currentFolder = Get-Location
Log-Message -message "The current folder is $currentFolder"

# Linux folder Path
$linuxFolder = Join-Path -Path $currentFolder -ChildPath "linux"
$linuxDestinationPath = Join-Path -Path $linuxFolder  -ChildPath "notation.tar.gz"
$linuxExePath = Join-Path -Path $linuxFolder -ChildPath "notation"
Log-Message -message "Linux folder location is $linuxFolder"
If (!(Test-Path "$linuxFolder"))
{
    New-Item -Force -ItemType Directory -Path "$linuxFolder" | Out-Null
}

Download-Extract -url $notationLinuxDownLoadPath -destinationPath "$linuxDestinationPath" -exePath "$linuxExePath"
If (Test-Path "$linuxDestinationPath")
{
    Remove-Item -Path "$linuxDestinationPath" -Force | Out-Null
}

$caCertificateLocalPath = Join-Path -Path $linuxFolder  -ChildPath "ca.crt"
$tsaCertificateLocalPath = Join-Path -Path $linuxFolder  -ChildPath "tsa.crt"

Download-Certificate -url $caCertificatePath -destinationPath $caCertificateLocalPath
Download-Certificate -url $tsaCertificatePath -destinationPath $tsaCertificateLocalPath

# Windows Section
$winFolder = Join-Path -Path $currentFolder -ChildPath "win"
$winDestinationPath = Join-Path -Path $winFolder -ChildPath "notation.zip"
$winExePath = Join-Path -Path $winFolder -ChildPath "notation.exe"

Log-Message -message "Windows folder location is $winFolder"
If (!(Test-Path $winFolder))
{
    New-Item -Force -ItemType Directory -Path "$winFolder" | Out-Null
}

Download-Extract -url $notationWinDownLoadPath -destinationPath "$winDestinationPath" -exePath "$winExePath"
If (Test-Path "$winDestinationPath")
{
    Remove-Item -Path "$winDestinationPath" -Force | Out-Null
}
$caCertificateLocalPath = Join-Path -Path $winFolder  -ChildPath "ca.crt"
$tsaCertificateLocalPath = Join-Path -Path $winFolder  -ChildPath "tsa.crt"

Download-Certificate -url $caCertificatePath -destinationPath $caCertificateLocalPath
Download-Certificate -url $tsaCertificatePath -destinationPath $tsaCertificateLocalPath