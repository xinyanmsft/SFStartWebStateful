function CreateClusterDeploymentFiles([string]$subscriptionId, [string]$clusterName, [string]$resourceGroupName, [string]$resourceGroupLocation, [SecureString]$certPassword, [SecureString]$adminPassword, [string]$appInsightsKey, [string]$outputFolder) {
    $ErrorActionPreference = "Stop"

    if (-not (Test-Path $outputFolder -pathType container)){
        throw [System.ApplicationException] "Output folder $outputFolder does not exist." 
    }
    
    $validName = IsValidClusterName $clusterName
    if (!$validName) {
        throw [System.ApplicationException] "Invalid cluster name $clusterName is not valid"
    }   

    $validLocation = IsValidClusterLocation $resourceGroupLocation
    if (!$validLocation) {
        throw [System.ApplicationException] "Invalid cluster location"
    }

    $dnsName = "$clusterName.$resourceGroupLocation.cloudapp.azure.com"
    $certFile = Join-Path $outputFolder "$clusterName.pfx"
    $cert = & "$PSScriptRoot\helpers\CreateAndUpload-Certificate.ps1" -KeyVaultLocation $resourceGroupLocation -CertificateDnsName $dnsName -CertificateSecretName "Cert$clusterName" -SecureCertificatePassword $certPassword -KeyVaultName "Key$clusterName" -KeyVaultResourceGroupName $resourceGroupName -PfxFileOutputPath $certFile

    Write-Host "Certificate $certFile created and uploaded to Azure key vault."

    $serviceFabricCertificateThumbprint = $cert.Get_Item('ServiceFabricCertificateThumbprint')
    $serviceFabricKeyVaultId = $cert.Get_Item('ServiceFabricKeyVaultId')
    $serviceFabricCertificateSecretId = $cert.Get_Item('ServiceFabricCertificateSecretId')

    $azureDeployParametersTemplate = [IO.File]::ReadAllText("$PSScriptRoot\..\templates\azuredeploy.parameters.json.template")
    $azureDeployParameters = $azureDeployParametersTemplate.Replace("{clusterLocation}", $resourceGroupLocation).Replace("{clusterName}", $clusterName).Replace("{adminPassword}", $adminPassword).Replace("{certificateThumbprint}", $serviceFabricCertificateThumbprint).Replace("{subscriptionId}", $subscriptionId).Replace("{keyVaultResourceGroupName}", $resourceGroupName).Replace("{keyVaultName}", "Key$clusterName").Replace("{serviceFabricCertificateSecretId}", $serviceFabricCertificateSecretId).Replace("{appInsightsKey}", $appInsightsKey)
    $parameterFileName = Join-Path $outputFolder "$clusterName.azuredeploy.parameters.json"
    [IO.File]::WriteAllText($parameterFileName, $azureDeployParameters)
    
    Write-Host "Parameter file $parameterFileName is created." 

    $publishProfileTemplate = [IO.File]::ReadAllText("$PSScriptRoot\..\templates\Cloud.xml.template")
    $publishProfile = $publishProfileTemplate.Replace("{clusterName}", $clusterName).Replace("{clusterLocation}", $resourceGroupLocation).Replace("{thumbprint}", $serviceFabricCertificateThumbprint)
    $publishProfileFileName = Join-Path $outputFolder "$clusterName.CI.xml"
    [IO.File]::WriteAllText($publishProfileFileName, $publishProfile)

    Write-Host "Publish profile $publishProfileFileName created."
}