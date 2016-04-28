
param(
 [Parameter(Mandatory=$True)]
 [string]
 $subscriptionId,

 [Parameter(Mandatory=$True)]
 [string]
 $resourceGroupName,

 [string]
 $resourceGroupLocation,

 [Parameter(Mandatory=$True)]
 [string]
 $storageName,

 [string]
 $templateFilePath = "$PSScriptRoot\..\templates\storage\template.json",

 [string]
 $parametersFilePath = "$PSScriptRoot\..\templates\storage\parameters.json"
)

Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    $provider = Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace -Force;
}

$ErrorActionPreference = "Stop"

# Register RPs
$resourceProviders = @("microsoft.storage");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. Creating...";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    $rmgroup = New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

# Start the deployment
Write-Host "Starting deployment...";
if(Test-Path $parametersFilePath) {
    $deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -storageAccounts_name $storageName -storageAccounts_location $resourceGroupLocation;
} else {
    $deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -storageAccounts_name $storageName -storageAccounts_location $resourceGroupLocation;
}

$storageAccount = Get-AzureRmResource -ResourceGroupName $resourceGroupName -ResourceType Microsoft.Storage/storageAccounts -ResourceName $storageName
$keys = Invoke-AzureRmResourceAction -ResourceGroupName $resourceGroupName -ResourceType Microsoft.Storage/storageAccounts -ResourceName $storageName -Action listKeys -ApiVersion 2015-05-01-preview -Force
$primaryKey = $keys.Key1

return $primaryKey
