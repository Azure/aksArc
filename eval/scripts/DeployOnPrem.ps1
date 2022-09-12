# First, you should disable any NICs that aren't required - the AKS-HCI Eval only needs a single physical NIC

$Nic = Get-NetAdapter -Physical | Select-Object Name, Status, InterfaceDescription, ifIndex, MacAddress, LinkSpeed, MTUSize | `
    Sort-Object ifindex | Out-GridView -title "Choose a single network adapter for use with AKS-HCI" -OutputMode Single
Get-NetAdapter | Where-Object ifIndex -NotLike $nic.ifIndex | Disable-NetAdapter -Confirm:$false
Get-NetAdapter -Physical | Sort-Object Status -Descending

# Download Windows Admin Center
$ProgressPreference = "SilentlyContinue"
mkdir -Path "C:\WAC"
Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/WACDownload' -OutFile "C:\WAC\WindowsAdminCenter.msi"

# Install Windows Admin Center
$msiArgs = @("/i", "C:\WAC\WindowsAdminCenter.msi", "/qn", "/L*v", "log.txt", "SME_PORT=443", "SSL_CERTIFICATE_OPTION=generate")
Start-Process msiexec.exe -Wait -ArgumentList $msiArgs

# Download the AKSHCI DSC files, and unzip them to C:\AKSHCIHOST, then copy the PS modules to the main PS modules folder
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Azure/aks-hci/main/eval/dsc/akshcihost.zip' -OutFile 'C:\akshcihost.zip' -UseBasicParsing
Expand-Archive -Path C:\akshcihost.zip -DestinationPath C:\AksHciHost
Get-ChildItem -Path C:\AksHciHost -Directory | Copy-Item -Destination "$env:ProgramFiles\WindowsPowerShell\Modules" -Recurse

# Change your location
Set-Location 'C:\AksHciHost'
. .\akshcihost.ps1

# Set Parameters for the DSC to run
$Admincreds = Get-Credential -Message "Enter your administrator credentials"
$domainName = 'akshci.local'
$environment = 'Workgroup'
$enableDHCP = 'Enabled'
$customRdpPort = '3389'

# Lock in the DSC and generate the MOF files
AKSHCIHost -Admincreds $Admincreds -DomainName $domainName -environment $environment -enableDHCP $enableDHCP -customRdpPort $customRdpPort

# Change location to where the MOFs are located, then execute the DSC configuration
Set-Location .\AKSHCIHost\

Set-DscLocalConfigurationManager  -Path . -Force
Start-DscConfiguration -Path . -Wait -Force -Verbose

# You may need to manually reboot and then wait to allow the DSC to complete.  Once complete, check by running:
Get-DscConfigurationStatus