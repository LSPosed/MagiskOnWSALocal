# Automated Install script by Midonei
$Host.UI.RawUI.WindowTitle = "Installing MagiskOnWSA..."
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

function Finish {
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

If (((Test-Path -Path "Styles","vendor.img","WsaProxy","system.img","CustomInstall","AppxManifest.xml","lxutil.dll","Microsoft.Web.WebView2.Core.dll","wslcoredeps.dll","Licenses","WsaClient","WSACodecs.dll","classicAppInstaller_WSA.sccd","userdata.vhdx","system_ext.img","networking.json","networking_schema.json","Images","libEGL.dll","WsaSettings.winmd","appcompatdb_schema.json","product.img","WsaService","Fonts","appcompatdb.json","Microsoft.Web.WebView2.Core.winmd","Microsoft.UI.Xaml_x64.appx","metadata.vhdx","WsaSettingsBroker","libGLESv2.dll","WSACrashUploader","wsldevicehost.dll","Tools","Microsoft.UI.Xaml.winmd","Registry.dat","GSKServer","WsaSettings.exe","Assets","wslcore.dll","Microsoft.VCLibs.x64.14.00.Desktop.appx","gfxstream_backend.dll","wslhost.exe","resources.pri") -Eq $false).Count) {
    Write-Error "Some files are missing in the folder. Please try to build again. Press any key to exist"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
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
$ProcessorArchitecture = $Xml.Package.Identity.ProcessorArchitecture;
$Dependencies = $Xml.Package.Dependencies.PackageDependency;
$Dependencies | ForEach-Object {
    If ($_.Name -Eq "Microsoft.VCLibs.140.00.UWPDesktop") {
        $HighestInstalledVCLibsVersion = Get-InstalledDependencyVersion -Name $_.Name -ProcessorArchitecture $ProcessorArchitecture;
        If ( $HighestInstalledVCLibsVersion -Lt $_.MinVersion ) {
            Add-AppxPackage -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Path "Microsoft.VCLibs.$ProcessorArchitecture.14.00.Desktop.appx"
        }
    }
    ElseIf ($_.Name -Match "Microsoft.UI.Xaml") {
        $HighestInstalledXamlVersion = Get-InstalledDependencyVersion -Name $_.Name -ProcessorArchitecture $ProcessorArchitecture;
        If ( $HighestInstalledXamlVersion -Lt $_.MinVersion ) {
            Add-AppxPackage -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Path "Microsoft.UI.Xaml_$ProcessorArchitecture.appx"
        }
    }
}

$Installed = $null
$Installed = Get-AppxPackage -Name 'MicrosoftCorporationII.WindowsSubsystemForAndroid'

If (($null -Ne $Installed) -And (-Not ($Installed.IsDevelopmentMode))) {
    Clear-Host
    Write-Warning "There is already one installed WSA. Please uninstall it first.`r`nPress y to uninstall existing WSA or press any key to exit"
    $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    If ("y" -Eq $key.Character) {
        Remove-AppxPackage -Package $Installed.PackageFullName
    }
    Else {
        exit 1
    }
}
Clear-Host
Write-Host "Installing MagiskOnWSA..."
Stop-Process -Name "WsaClient" -ErrorAction SilentlyContinue
Add-AppxPackage -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Register .\AppxManifest.xml
If ($?) {
    Finish
}
ElseIf ($null -Ne $Installed) {
    Clear-Host
    Write-Host "Failed to update, try to uninstall existing installation while preserving userdata..."
    Remove-AppxPackage -PreserveApplicationData -Package $Installed.PackageFullName
    Add-AppxPackage -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Register .\AppxManifest.xml
    If ($?) {
        Finish
    }
}
Write-Host "All Done!`r`nPress any key to exit"
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
