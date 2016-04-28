param(
 [Parameter(Mandatory=$True)]
 [string]
 $subscriptionId,

 [Parameter(Mandatory=$True)]
 [string]
 $resourceGroupName,

 [Parameter(Mandatory=$True)]
 [string]
 $resourceGroupLocation,

 [Parameter(Mandatory=$True)]
 [string]
 $appInsightsAppName,

 [string]
 $templateFilePath = "$PSScriptRoot\..\templates\ai\template.json",

 [string]
 $parametersFilePath = "$PSScriptRoot\..\templates\ai\parameters.json"
)

Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    $provider = Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace -Force;
}

# Register RPs
$resourceProviders = @("microsoft.insights");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist, creating ...";
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
Write-Host "Starting AppInsights deployment...";
if(Test-Path $parametersFilePath) {
    $deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -appInsightsAppName $appInsightsAppName;
} else {
    $deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -appInsightsAppName $appInsightsAppName;
}

$appInsightsApp = Get-AzureRmResource -ResourceGroupName $resourceGroupName -ResourceType Microsoft.Insights/components -ResourceName $appInsightsAppName

Write-Host "AppInsights application '$appInsightsAppName' created"
return $appInsightsApp.Properties.InstrumentationKey
