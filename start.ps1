#Set Container Image Hardening
Set-ItemProperty -Name restrictnullsessaccess -Path HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters -Value 1
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name restrictanonymous -Value 1

#Install AZ Modules
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module Az -force
Install-Module Az.ImageBuilder -Force

#Install Azure CLI
$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
[Environment]::SetEnvironmentVariable("PATH", $Env:PATH + ";C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin", [EnvironmentVariableTarget]::Machine)

#Install Bicep
# Create the install folder
$installPath = "$env:USERPROFILE\.bicep"
$installDir = New-Item -ItemType Directory -Path $installPath -Force
$installDir.Attributes += 'Hidden'
# Fetch the latest Bicep CLI binary
(New-Object Net.WebClient).DownloadFile("https://github.com/Azure/bicep/releases/latest/download/bicep-win-x64.exe", "$installPath\bicep.exe")
# Add bicep to your PATH
$currentPath = (Get-Item -path "HKCU:\Environment" ).GetValue('Path', '', 'DoNotExpandEnvironmentNames')
if (-not $currentPath.Contains("%USERPROFILE%\.bicep")) { setx PATH ($currentPath + ";%USERPROFILE%\.bicep") }
if (-not $env:path.Contains($installPath)) { $env:path += ";$installPath" }
# Verify you can now access the 'bicep' command.
bicep --help

#Install AZ Copy
$InstallPath = 'C:\AzCopy'
# Cleanup Destination
if (Test-Path $InstallPath) {
    Get-ChildItem $InstallPath | Remove-Item -Confirm:$false -Force
}
# Zip Destination
$zip = "$InstallPath\AzCopy.Zip"
# Create the installation folder (eg. C:\AzCopy)
$null = New-Item -Type Directory -Path $InstallPath -Force
# Download AzCopy zip for Windows
Start-BitsTransfer -Source "https://aka.ms/downloadazcopy-v10-windows" -Destination $zip
# Expand the Zip file
Expand-Archive $zip $InstallPath -Force
# Move to $InstallPath
Get-ChildItem "$($InstallPath)\*\*" | Move-Item -Destination "$($InstallPath)\" -Force
#Cleanup - delete ZIP and old folder
Remove-Item $zip -Force -Confirm:$false
Get-ChildItem "$($InstallPath)\*" -Directory | ForEach-Object { Remove-Item $_.FullName -Recurse -Force -Confirm:$false }
# Add InstallPath to the System Path if it does not exist
if ($env:PATH -notcontains $InstallPath) {
    $path = ($env:PATH -split ";")
    if (!($path -contains $InstallPath)) {
        $path += $InstallPath
        $env:PATH = ($path -join ";")
        $env:PATH = $env:PATH -replace ';;', ';'
    }
    [Environment]::SetEnvironmentVariable("Path", ($env:path), [System.EnvironmentVariableTarget]::Machine)
}

#Install PowerShell 7
$gcFolder = New-Item -Path 'c:\Temp\' -Name 'Software' -ItemType 'Directory' -Force
$pwshLatestAssets = Invoke-RestMethod (Invoke-RestMethod https://api.github.com/repos/PowerShell/PowerShell/releases/latest).assets_url
$pwshDownloadUrl = ($pwshLatestAssets | Where-Object { $_.browser_download_url -like "*win-x64.zip" }).browser_download_url
$pwshZipFileName = $pwshDownloadUrl.split('/')[-1]
Write-Host "Downloading PowerShell stand-alone binaries"
$pwshZipDownloadPath = Join-Path -Path $gcFolder -ChildPath $pwshZipFileName
$invokeWebParams = @{
    Uri     = $pwshDownloadUrl
    OutFile = $pwshZipDownloadPath
}
Invoke-WebRequest @invokeWebParams
Write-Host "5. Adding PowerShell Core"
Expand-Archive -Path $pwshZipDownloadPath -DestinationPath 'C:\Program Files\PowerShell 7'
[Environment]::SetEnvironmentVariable("PATH", $Env:PATH + ";C:\Program Files\PowerShell 7\", [EnvironmentVariableTarget]::Machine)