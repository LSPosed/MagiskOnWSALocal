If ((Test-Path -Path "pri") -Eq $true -And (Test-Path -Path "xml") -Eq $true) {
    $proc = Start-Process -PassThru makepri.exe -Args "resourcepack /pr .\pri /cf .\xml\priconfig.xml /of .\resources.pri /if .\resources.pri /o"
    $proc.WaitForExit()
    If ($proc.ExitCode -Ne 0) {
        Write-Warning "Failed to merge resources`r`n"
        exit 1
    }
    else {
        $AppxManifestFile = ".\AppxManifest.xml"
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
        Remove-Item 'xml' -Recurse
        Remove-Item 'makepri.exe'
        Remove-Item $PSCommandPath -Force
        exit 0
    }
}
