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

If ((Test-Path -Path "pri") -Eq $true -And (Test-Path -Path "xml") -Eq $true) {
    $AppxManifestFile = ".\AppxManifest.xml"
    Copy-Item .\resources.pri -Destination ".\pri\resources.pri"
    $proc = Start-Process -PassThru makepri.exe -Args "new /pr .\pri /cf .\xml\priconfig.xml /of .\resources.pri /mn $AppxManifestFile /o"
    $proc.WaitForExit()
    If ($proc.ExitCode -Ne 0) {
        Write-Warning "Failed to merge resources`r`n"
        exit 1
    }
    else {
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
}
