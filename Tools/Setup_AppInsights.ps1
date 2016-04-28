#################################################################################
#
# This script configures an Application Insights account, and generates the JSON file
# for integrating Azure Diagnostics (WAD) with AppInsight. After running this script, you 
# can use Visual Studio cloud explorer to update Azure diagnostics. 
#
# Before running this script, please ensure you have a valid Azure subscription.
#################################################################################

param(
 [Parameter(Mandatory=$True, HelpMessage="Azure subscription Id")]
 [string]
 $subscriptionId,

 [Parameter(Mandatory=$True, HelpMessage="Application Insights application name")]
 [string]
 $appInsightsAppName,

 [Parameter(Mandatory=$False)]
 [string]
 $resourceGroupName,

 [Parameter(Mandatory=$False)]
 [string]
 $resourceGroupLocation
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrEmpty($resourceGroupName)) {
  $resourceGroupName = $appInsightsAppName + "-DiagRG"
}

if ([string]::IsNullOrEmpty($resourceGroupLocation)) {
  $resourceGroupLocation = 'westus'
}

Write-Host "This script requires the latest AzureRM PowerShell module. To install, run this command: Install-Module AzureRM"
$anyKey = Read-Host "Press any key to continue ..."

# sign in
Write-Host "Logging in to Azure Resource Manager ...";
Login-AzureRmAccount;

# select subscription
Select-AzureRmSubscription -SubscriptionID $subscriptionId;

Write-Host "Creating Application Insights '$appInsightsAppName' in resource group '$resourceGroupName'..."
$appInsightsKey = & "$PSScriptRoot\helpers\Create-AI.ps1" -subscriptionId $subscriptionId  -resourceGroupName $resourceGroupName -resourceGroupLocation $resourceGroupLocation -appInsightsAppName $appInsightsAppName

$randomNum = Get-Random
$storageName = "$appInsightsAppName$randomNum".ToLower()
if ($storageName.Length -ge 25) {
    $storageName = $storageName.Substring($storageName.Length - 24)
}

Write-Host "Creating Azure storage '$storageName' in resource group '$resourceGroupName'..."
$storageKey = & "$PSScriptRoot\helpers\Create-Storage.ps1" -subscriptionId $subscriptionId -resourceGroupName $resourceGroupName -resourceGroupLocation $resourceGroupLocation -storageName $storageName

Write-Host "Generating WAD config files ...";
$wadConfigTemplate = [IO.File]::ReadAllText("$PSScriptRoot\templates\wad.json")
$wadConfig = $wadConfigTemplate.Replace("{storageAccountName}", $storageName).Replace("{appInsightKey}", $appInsightsKey)

$wadPrivateConfigTemplate = [IO.File]::ReadAllText("$PSScriptRoot\templates\wad_private.json")
$wadPrivateConfig = $wadPrivateConfigTemplate.Replace("{storageAccountKey}", $storageKey)

[IO.File]::WriteAllText("$PSScriptRoot\$appInsightsAppName-wad.json", $wadConfig)
[IO.File]::WriteAllText("$PSScriptRoot\$appInsightsAppName-wad-private.json", $wadPrivateConfig)

Write-Host "********************************************************************************"
Write-Host "Application Insight resource $appInsightsAppName created in https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/microsoft.insights/components/$appInsightsAppName"
Write-Host "WAD configuration files $appInsightsAppName-wad.json and $appInsightsAppName-wad-private.json are generated in $PSScriptRoot\. Please open Visual Studio's Cloud Explorer, right-click the VM scaleset and select Enable/Update diagnostics to upload the configuration files. This will enable sending application traces to Application Insights."
Write-Host "********************************************************************************"
