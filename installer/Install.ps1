# This file is part of MagiskOnWSALocal.
#
# MagiskOnWSALocal is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# MagiskOnWSALocal is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with MagiskOnWSALocal.  If not, see <https://www.gnu.org/licenses/>.
#
# Copyright (C) 2023 LSPosed Contributors
#

$Host.UI.RawUI.WindowTitle = "Installing MagiskOnWSA...."
function Test-Administrator {
    [OutputType([bool])]
    param()
    process {
        [Security.Principal.WindowsPrincipal]$user = [Security.Principal.WindowsIdentity]::GetCurrent();
        return $user.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator);
    }
}

function Get-InstalledDependencyVersion {
    param (
        [string]$Name,
        [string]$ProcessorArchitecture
    )
    process {
        return Get-AppxPackage -Name $Name | ForEach-Object { if ($_.Architecture -eq $ProcessorArchitecture) { $_ } } | Sort-Object -Property Version | Select-Object -ExpandProperty Version -Last 1;
    }
}

Function Test-CommandExists {
    Param ($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try { if (Get-Command $command) { RETURN $true } }
    Catch { RETURN $false }
    Finally { $ErrorActionPreference = $oldPreference }
} #end function test-CommandExists

function Finish {
    Write-Host "Optimizing VHDX size...."
    If (Test-CommandExists Optimize-VHD) { Optimize-VHD ".\*.vhdx" -Mode Full }
    Clear-Host
    Start-Process "wsa://com.topjohnwu.magisk"
    Start-Process "wsa://com.android.vending"
}

If (-Not (Test-Administrator)) {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
    $proc = Start-Process -PassThru -WindowStyle Hidden -Verb RunAs ConHost.exe -Args "powershell -ExecutionPolicy Bypass -Command Set-Location '$PSScriptRoot'; &'$PSCommandPath' EVAL"
    $proc.WaitForExit()
    If ($proc.ExitCode -Ne 0) {
        Clear-Host
        Write-Warning "Failed to launch start as Administrator`r`nPress any key to exit"
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
    }
    exit
}
ElseIf (($args.Count -Eq 1) -And ($args[0] -Eq "EVAL")) {
    Start-Process ConHost.exe -Args "powershell -ExecutionPolicy Bypass -Command Set-Location '$PSScriptRoot'; &'$PSCommandPath'"
    exit
}

$FileList = Get-Content -Path .\filelist.txt
If (((Test-Path -Path $FileList) -Eq $false).Count) {
    Write-Error "Some files are missing in the folder. Please try to build again. Press any key to exist"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

If ((Test-Path -Path "MakePri.ps1") -Eq $true) {
    $ProcMakePri = Start-Process powershell.exe -PassThru -Args "-ExecutionPolicy Bypass -File MakePri.ps1" -WorkingDirectory $PSScriptRoot
    $ProcMakePri.WaitForExit()
    If ($ProcMakePri.ExitCode -Ne 0) {
        Write-Warning "Failed to merge resources, WSA Seetings will always be in English`r`n"
    }
}

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"

If ($(Get-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform').State -Ne "Enabled") {
    Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName 'VirtualMachinePlatform'
    Clear-Host
    Write-Warning "Need restart to enable virtual machine platform`r`nPress y to restart or press any key to exit"
    $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    If ("y" -Eq $key.Character) {
        Restart-Computer -Confirm
    }
    Else {
        exit 1
    }
}

[xml]$Xml = Get-Content ".\AppxManifest.xml";
$Name = $Xml.Package.Identity.Name;
Write-Host "Installing $Name version: $($Xml.Package.Identity.Version)"
$ProcessorArchitecture = $Xml.Package.Identity.ProcessorArchitecture;
$Dependencies = $Xml.Package.Dependencies.PackageDependency;
$Dependencies | ForEach-Object {
    $InstalledVersion = Get-InstalledDependencyVersion -Name $_.Name -ProcessorArchitecture $ProcessorArchitecture;
    If ( $InstalledVersion -Lt $_.MinVersion ) {
        Write-Host "Dependency package $($_.Name) $ProcessorArchitecture required minimum version: $($_.MinVersion). Installing...."
        Add-AppxPackage -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Path "$($_.Name)_$ProcessorArchitecture.appx"
    }
    Else {
        Write-Host "Dependency package $($_.Name) $ProcessorArchitecture current version: $InstalledVersion. Nothing to do."
    }
}

$Installed = $null
$Installed = Get-AppxPackage -Name $Name

If (($null -Ne $Installed) -And (-Not ($Installed.IsDevelopmentMode))) {
    Clear-Host
    Write-Warning "There is already one installed WSA. Please uninstall it first.`r`nPress y to uninstall existing WSA or press any key to exit"
    $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    If ("y" -Eq $key.Character) {
        Clear-Host
        Remove-AppxPackage -Package $Installed.PackageFullName
    }
    Else {
        exit 1
    }
}
Clear-Host
Write-Host "Installing MagiskOnWSA...."
If (Test-CommandExists WsaClient) { Start-Process WsaClient -Wait -Args "/shutdown" }
Stop-Process -Name "WsaClient" -ErrorAction SilentlyContinue
Add-AppxPackage -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Register .\AppxManifest.xml
If ($?) {
    Finish
}
ElseIf ($null -Ne $Installed) {
    Clear-Host
    Write-Error "Failed to update.`r`nPress any key to uninstall existing installation while preserving user data.`r`nTake in mind that this will remove the Android apps' icon from the start menu.`r`nIf you want to cancel, close this window now."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Clear-Host
    Remove-AppxPackage -PreserveApplicationData -Package $Installed.PackageFullName
    Add-AppxPackage -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Register .\AppxManifest.xml
    If ($?) {
        Finish
    }
}
Write-Host "All Done!`r`nPress any key to exit"
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
