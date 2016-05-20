
function GetOrCreateServicePrincipal([string]$subscriptionId, [string]$applicationName, [string]$spnRole="Owner", [string]$alwaysCreate=$False, [string]$guidPassword=""){
    <#
    .SYNOPSIS
    Create a service principal
    #>
    $ErrorActionPreference = "Stop"

    $s = LoginToAzureRM $subscriptionId
    $azureSubscription = Get-AzureRmSubscription -SubscriptionID $subscriptionId

    $displayName = [String]::Format("Fabric.VSTS.{0}.{1}.{2}", $env:USERNAME, $azureSubscription.SubscriptionId, $applicationName)
    $identifierUri = "http://$displayName"
    $homePage = $identifierUri
    
    if ($alwaysCreate) {
        $identifierUri = $identifierUri + "/" + [GUID]::NewGuid()
    }
    
    $azureAdApplication = Get-AzureRmADApplication -IdentifierUri $identifierUri -ErrorAction SilentlyContinue
    if (!$azureAdApplication) {
        Write-Host "Creating new AAD application $displayName"
        $azureAdApplication = New-AzureRmADApplication -DisplayName $displayName -HomePage $homePage -IdentifierUris $identifierUri -Password $guidPassword -Verbose
    } else {
        Write-Host "Use existing AAD application $displayName"
    }
    $appId = $azureAdApplication.ApplicationId

    $spn = Get-AzureRmADServicePrincipal -ServicePrincipalName $identifierUri
    if (!$spn) {
        Write-Host "Creating service principal in application $appId"
        $spn = New-AzureRmADServicePrincipal -ApplicationId $appId
    }

    #Assign role to SPN
    $roleAssignmentCreated = $false
    $retry = 0
    while(-not $roleAssignmentCreated) {
      Start-Sleep -s 5
      $retry = $retry + 1
      try {
          $assignment = Get-AzureRmRoleAssignment -ServicePrincipalName $appId -RoleDefinitionName $spnRole -ErrorAction SilentlyContinue
          if (!$assignment) {
            $assignment = New-AzureRmRoleAssignment -RoleDefinitionName $spnRole -ServicePrincipalName $appId
          }
          $roleAssignmentCreated = $true
          break
      }
      catch {
        # New-AzureRmRoleAssignment fails immediately after New-AzureRmADServicePrincipal is run.
        if ($retry -ge 20) {
          Throw "Timeout retrying New-AzureRmRoleAssignment"
        }
      }
    }

    return @{
        "ServicePrincipalId" = $spn.ServicePrincipalName;
        "ServicePrincipalKey" = $guidPassword;
        "TenantId" = $azureSubscription.TenantId;
        "SubscriptionId" = $azureSubscription.SubscriptionId;
        "SubscriptionName" = $azureSubscription.SubscriptionName
    }
}
