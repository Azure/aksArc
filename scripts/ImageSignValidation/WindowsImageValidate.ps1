# Function to log messages
function Log-Message {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "$timestamp [$level] $message"
}

function Run-Command {
    param (
        [string]$executable,
        [string[]]$params
    )
    try {
        & $executable @params | Out-Null
        if ($?) {
            return $true
        } else {
            return $false
        }
    } catch {
        Log-Message -message "Command '$executable $($params -join ' ')' failed with error: $_" -level "ERROR"
        return $false
    }
}

function Install-Certs {
    param (
        [string]$notationPath,
        [string]$caCertificateLocalPath,
        [string]$tsaCertificateLocalPath
    )

    $result = & $notationPath cert ls --type ca --store supplychain ca.crt
    if (-not $result) {
        Run-Command -executable $notationPath -params @("cert", "add", "--type", "ca", "--store", "supplychain", $caCertificateLocalPath) | Out-Null
        Run-Command -executable $notationPath -params @("cert", "ls", "--type", "ca")  | Out-Null
    }

    $result = & $notationPath cert ls --type tsa --store esrp tsa.crt
    if (-not $result) {
        Run-Command -executable $notationPath -params @("cert", "add", "--type", "tsa", "--store", "esrp", $tsaCertificateLocalPath)  | Out-Null
        Run-Command -executable $notationPath -params @("cert", "ls", "--type", "esrp")  | Out-Null
    }
}


function Remove-Certs {
    param (
        [string]$notationPath,
        [string]$caCertificateLocalPath,
        [string]$tsaCertificateLocalPath
    )

    $result = & $notationPath cert delete --type ca --store supplychain ca.crt -y
    $result = & $notationPath cert delete --type tsa --store esrp tsa.crt -y
}

function Get-CrictlImagesWithNoneTag {
    # Run the crictl command and capture the output
    $output = & crictl images --output=json | ConvertFrom-Json
    # Initialize an array to hold the objects
    $imageArray = @()

    foreach ($image in $output.images) {
        $repoTag = $image.repoTags[0]
        $repoDigest = $image.repoDigests[0]
        $imageArray += "$repoTag=$repoDigest"
    }

    # Output the array of objects
    return $imageArray
}

function Remove-TrustImageFile {
    param (
        [string]$fileLocation
    )
    Remove-Item -Path $fileLocation -Force | Out-Null
}

function New-TrustImageFile {
    param (
        [string]$image,
        [string]$notationPath,
        [string]$tempFolder = "C:\temp"
    )
    $trustData = @{
        version = "1.0"
        trustPolicies = @(
            @{
                name = "supplychain"
                registryScopes = @("*")
                signatureVerification = @{ level = "strict" }
                trustStores = @("ca:supplychain", "tsa:esrp")
                trustedIdentities = @("x509.subject: CN=Microsoft SCD Products RSA Signing,O=Microsoft Corporation,L=Redmond,ST=Washington,C=US")
            }
        )
    }
    $fileLocation = Join-Path -Path $tempFolder -ChildPath "trust.json"
    $trustJson = $trustData | ConvertTo-Json -Depth 4
    Set-Content -Path $fileLocation -Value $trustJson | Out-Null
    Run-Command -executable $notationPath -params @("policy", "import", $fileLocation, "--force") | Out-Null
    Run-Command -executable $notationPath -params @("policy", "show") | Out-Null
    return $fileLocation
}

# Usage
$currentFolder = $PSScriptRoot
Log-Message -message "The current folder is $currentFolder"
$caCertificateLocalPath = Join-Path -Path $currentFolder -ChildPath "ca.crt"
$tsaCertificateLocalPath = Join-Path -Path $currentFolder -ChildPath "tsa.crt"
$winExePath = Join-Path -Path $currentFolder -ChildPath "notation.exe"

If (!(Test-Path "$caCertificateLocalPath"))
{
    Log-Message -message "ca.crt not found in $currentFolder"
}

If (!(Test-Path "$tsaCertificateLocalPath"))
{
    Log-Message -message "tsa.crt not found in $currentFolder"
}

If (!(Test-Path "$winExePath"))
{
    Log-Message -message "notation file not found in $currentFolder"
}

Install-Certs -notationPath $winExePath -caCertificateLocalPath $caCertificateLocalPath -tsaCertificateLocalPath $tsaCertificateLocalPath

$returnDetails = Get-CrictlImagesWithNoneTag
$validateCount = $returnDetails.Count
$validImageArray = @()
$inValidImageArray = @()
foreach ($image in $returnDetails) {
    $imagetoCheck = ""
    $key, $value = $image -split '='
    if ($value -ieq 'null') {
        $imagetoCheck = $key
    } else {
        $imagetoCheck = $value
    }
    $fileLocation = New-TrustImageFile -image $imagetoCheck -notationPath $exePath -tempFolder $currentFolder
    $result = Run-Command -executable $exePath -params @("verify", $imagetoCheck, "--verbose")
    if ($result) {
        $validImageArray += $imagetoCheck
    } else {
        $inValidImageArray += $imagetoCheck
    }
    Remove-TrustImageFile -fileLocation $fileLocation | Out-Null
}

$imageLists = @{
failed_signed_images = $inValidImageArray
passed_signed_images = $validImageArray
}
# Convert the hashtable to JSON format
$jsonContent = $imageLists | ConvertTo-Json -Depth 4
# Write the JSON content to a file
$jsonFilePath = Join-Path $currentFolder -ChildPath "imagevalidation_results_windows.json"
$jsonContent | Out-File -FilePath $jsonFilePath -Encoding utf8

Log-Message -message "Sign image result present in file : $jsonFilePath"
Remove-Certs -notationPath $winExePath -caCertificateLocalPath $caCertificateLocalPath -tsaCertificateLocalPath $tsaCertificateLocalPath