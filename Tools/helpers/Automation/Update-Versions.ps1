# Appends all versions with a timestamp
$versionSuffix = " (" + ([System.DateTimeOffset]::UtcNow.ToString('u').Replace(':', '.')) + ")"
$packageLocation = "${env:ServiceFabricApplicationProjectPath}\pkg\${env:BuildConfiguration}"

$appManifestPath = "$packageLocation\ApplicationManifest.xml"
$appManifestXml = [XML](Get-Content $appManifestPath)
$appManifestXml.ApplicationManifest.ApplicationTypeVersion += $versionSuffix
$appManifestXml.ApplicationManifest.ServiceManifestImport | ForEach { $_.ServiceManifestRef.ServiceManifestVersion += $versionSuffix }
$appManifestXml.Save($appManifestPath)

Write-Host "Updated application type '$($appManifestXml.ApplicationManifest.ApplicationTypeName)' to version '$($appManifestXml.ApplicationManifest.ApplicationTypeVersion)'"

$serviceManifestPaths = [System.IO.Directory]::EnumerateFiles($packageLocation, "ServiceManifest.xml", [System.IO.SearchOption]::AllDirectories)
$serviceManifestPaths | ForEach {
    $serviceManifestXml = [XML](Get-Content $_)
    $serviceManifestXml.ServiceManifest.Version += $versionSuffix
    $subPackages = @(
        $serviceManifestXml.ServiceManifest.CodePackage,
        $serviceManifestXml.ServiceManifest.ConfigPackage,
        $serviceManifestXml.ServiceManifest.DataPackage)
    $subPackages | Where { $_.Version } | ForEach { $_.Version += $versionSuffix }
    $serviceManifestXml.Save($_)
  
    Write-Host "Updated service '$($serviceManifestXml.ServiceManifest.Name)' to version '$($serviceManifestXml.ServiceManifest.Version)'"
}