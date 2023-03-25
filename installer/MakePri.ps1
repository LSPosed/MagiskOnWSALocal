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

$Host.UI.RawUI.WindowTitle = "Merging resources...."
If ((Test-Path -Path "pri") -Eq $true -And (Test-Path -Path "xml") -Eq $true) {
    $AppxManifestFile = ".\AppxManifest.xml"
    Copy-Item .\resources.pri -Destination ".\pri\resources.pri" | Out-Null
    $ProcNew = Start-Process -PassThru makepri.exe -WindowStyle Hidden -Args "new /pr .\pri /cf .\xml\priconfig.xml /of .\resources.pri /mn $AppxManifestFile /o"
    $ProcNew.WaitForExit()
    If ($ProcNew.ExitCode -Ne 0) {
        Write-Warning "Failed to merge resources from pris`r`nTrying to dump pris to priinfo...."
        New-Item -Path "." -Name "priinfo" -ItemType "directory"
        $Processes = ForEach ($Item in Get-Item ".\pri\*" -Include "*.pri") {
            $Name = $Item.Name
            $RelativePath = $Item | Resolve-Path -Relative
            Write-Host "Dumping $Name....`r`n"
            Start-Process -PassThru -WindowStyle Hidden makepri.exe -Args "dump /if $RelativePath /o /es .\pri\resources.pri /of .\priinfo\$Name.xml /dt detailed"
        }
        Write-Host "Dumping resources....`r`n"
        $Processes | Wait-Process
        Write-Host "Creating pri from dumps....`r`n"
        $ProcNewFromDump = Start-Process -PassThru -WindowStyle Hidden makepri.exe -Args "new /pr .\priinfo /cf .\xml\priconfig.xml /of .\resources.pri /mn $AppxManifestFile /o"    
        $ProcNewFromDump.WaitForExit()
        Remove-Item 'priinfo' -Recurse
        If ($ProcNewFromDump.ExitCode -Ne 0) {
            Write-Warning "Failed to create resources from priinfos`r`n"
            exit 1
        }
    }

    $ProjectXml = [xml](Get-Content $AppxManifestFile)
    $ProjectResources = $ProjectXml.Package.Resources;
    $Item = Get-Item .\xml\* -Exclude "priconfig.xml" -Include "*.xml"
    $Item | ForEach-Object {
        $Xml = [xml](Get-Content $_)
        $Resource = $Xml.Package.Resources.Resource
        $newNode = $ProjectXml.ImportNode($Resource, $true)
        $ProjectResources.AppendChild($newNode)
    }
    $ProjectXml.Save($AppxManifestFile)
    Remove-Item 'pri' -Recurse
    Set-Content -Path "filelist.txt" -Value (Get-Content -Path "filelist.txt" | Select-String -Pattern '^pri$' -NotMatch)
    Remove-Item 'xml' -Recurse
    Set-Content -Path "filelist.txt" -Value (Get-Content -Path "filelist.txt" | Select-String -Pattern '^xml$' -NotMatch)
    Remove-Item 'makepri.exe'
    Set-Content -Path "filelist.txt" -Value (Get-Content -Path "filelist.txt" | Select-String -Pattern 'makepri.exe' -NotMatch)
    Remove-Item $PSCommandPath -Force
    Set-Content -Path "filelist.txt" -Value (Get-Content -Path "filelist.txt" | Select-String -Pattern 'MakePri.ps1' -NotMatch)
    exit 0
}
