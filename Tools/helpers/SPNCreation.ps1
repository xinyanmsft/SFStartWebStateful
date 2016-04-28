param
(
    [Parameter(Mandatory=$true, HelpMessage="Enter Azure Subscription Id. You need to be Subscription Admin to execute the script")]
    [string] $subscriptionId,

    [Parameter(Mandatory=$true, HelpMessage="Provide a password for SPN application that you would create")]
    [string] $password,

    [Parameter(Mandatory=$false, HelpMessage="Provide a SPN role assignment")]
    [string] $spnRole = "owner"
)

#Initialize
$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"
$userName = $env:USERNAME
$newguid = [guid]::NewGuid()
$displayName = [String]::Format("VSO.{0}.{1}", $userName, $newguid)
$homePage = "http://" + $displayName
$identifierUri = $homePage


#Initialize subscription
$isAzureModulePresent = Get-Module -Name AzureRM* -ListAvailable
if ([String]::IsNullOrEmpty($isAzureModulePresent) -eq $true)
{
    Write-Output "Script requires AzureRM modules to be present. Obtain AzureRM from https://github.com/Azure/azure-powershell/releases. Please refer https://github.com/Microsoft/vso-agent-tasks/blob/master/Tasks/DeployAzureResourceGroup/README.md for recommended AzureRM versions." -Verbose
    return
}

Import-Module -Name AzureRM.Profile
$login = Login-AzureRmAccount -SubscriptionID $subscriptionId
$azureSubscription = Get-AzureRmSubscription -SubscriptionID $subscriptionId
$connectionName = $azureSubscription.SubscriptionName
$tenantId = $azureSubscription.TenantId
$id = $azureSubscription.SubscriptionId

#Create a new AD Application
$azureAdApplication = New-AzureRmADApplication -DisplayName $displayName -HomePage $homePage -IdentifierUris $identifierUri -Password $password -Verbose
$appId = $azureAdApplication.ApplicationId

#Create new SPN
$spn = New-AzureRmADServicePrincipal -ApplicationId $appId
$spnName = $spn.ServicePrincipalName

#Assign role to SPN
$roleAssignmentCreated = $false
$retry = 0
while(-not $roleAssignmentCreated) {
  Start-Sleep -s 10
  $retry = $retry + 1
  try {
      $assignment = New-AzureRmRoleAssignment -RoleDefinitionName $spnRole -ServicePrincipalName $appId
      $roleAssignmentCreated = $true
      break
  }
  catch {
    # New-AzureRmRoleAssignment fails immediately after New-AzureRmADServicePrincipal is run.
    if ($retry -ge 10) {
      Throw "Timeout retrying New-AzureRmRoleAssignment"
    }
  }
}

$result = @{
    'ConnectionName' = $($connectionName);
	'SubscriptionId' = $($id);
	'SubscriptionName' = $($connectionName);
	'ServicePrincipalId' = $($appId);
	'ServicePrincipalKey' = $($password);
	'TenantId' = $($tenantId)
}
return $result
