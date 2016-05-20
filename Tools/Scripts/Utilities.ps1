function Get-PrerequisitesStatus {
    <#
    .SYNOPSIS
    Checks whether prerequisites are installed.
    #>

    # check for AzureRM 
    if (-not (Get-Command Login-AzureRmAccount -errorAction SilentlyContinue)) {
        Write-Output "Script requires AzureRM modules to be present. Obtain AzureRM from https://github.com/Azure/azure-powershell/releases. Please refer https://github.com/Microsoft/vso-agent-tasks/blob/master/Tasks/DeployAzureResourceGroup/README.md for recommended AzureRM versions." -Verbose
        return $false
    }

    $isAzureModulePresent = Get-Module -Name AzureRM* -ListAvailable
    if ([String]::IsNullOrEmpty($isAzureModulePresent) -eq $true)
    {
        Write-Output "Script requires AzureRM modules to be present. Obtain AzureRM from https://github.com/Azure/azure-powershell/releases. Please refer https://github.com/Microsoft/vso-agent-tasks/blob/master/Tasks/DeployAzureResourceGroup/README.md for recommended AzureRM versions." -Verbose
        return $false
    }
    
    return $true
}

function GetOrCreateResourceGroup([string]$resourceGroupName, [string]$resourceGroupLocation) {
    <#
    .SYNOPSIS
    Retrieve the specified resource group. Create a new resource group if the specified one 
    does not exist.
    #>

    $ErrorActionPreference = "Stop"

    $resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if ($resourceGroup) {
        return $resourceGroup
    }
    
    if(!$resourceGroupLocation) {
        Write-Host "Resource group '$resourceGroupName' does not exist, creating ..."
        $resourceGroupLocation = Read-Host "resourceGroupLocation"
    }

    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'"
    do {
        try {
            $resourceGroup = New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
            if ($resourceGroup) {
                return $resourceGroup
            }
        }
        catch {
            Write-Host "Creating resource group failed, $_"
        }
        $shouldRetry = AskForYesNo "Do you want to retry this operation", "Y" 
    } while($true -eq $shouldRetry)

    throw [System.ApplicationException] "Failed to create resource group"
}

function LoginToAzureRM([string]$subscriptionId){
    <#
    .SYNOPSIS
    Login to AzureRM.
    #>
    $ErrorActionPreference = "Stop"

    Import-Module -Name AzureRM.Profile
    try {
        $context = Get-AzureRmContext
        Select-AzureRmSubscription -SubscriptionID $subscriptionId
    }
    catch {
        Write-Host "Login to Azure Resource Manager ..."
        $login = Login-AzureRmAccount -SubscriptionID $subscriptionId  
    }
}

function AskForYesNo([string]$prompt, [string]$defaultValue)
{
    $caption = $prompt + ' (Y/N)?'
    $result = Read-Host $caption

    if ([string]::IsNullOrWhiteSpace($result)) {
        $result = $defaultVal
    }

    $result = $result.ToLower().SubString(0, 1).CompareTo("y")
    return $result -eq 0
}

function IsValidClusterName([string]$name) {
    if (($name.Length -lt 4) -or ($name.Length -gt 23) -or !($name -match '^[a-z0-9\-]*$')) {
        Write-Error "The name of the cluster must be between 4 and 23 characters, and only have lowercase letters, numbers and hyphens." 
        return $false
    }
    return $true
}

function IsValidClusterLocation([string]$location) {
    if ([string]::IsNullOrWhiteSpace($location)) {
        Write-Error "Cluster location $location is not specified. Examples include westus, eastus, westeurope, etc."
        return $false
    }
    
    if ($location.Contains(" ")) {
        Write-Error "Cluster location $location is not valid. Examples include westus, eastus, westeurope, etc."
        return $false
    }
    
    return $true
}

function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )
    $provider = Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace -Force;
}

function GetPassword([string]$prompt) {
    while($true){
        $p1 = Read-Host $prompt -AsSecureString
        $p2 = Read-Host 'Please enter the password again' -AsSecureString
        
        $p1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1))
        $p2_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2))
  
        if ($p1_text.compareTo($p2_text) -eq 0) {
            return $p1
        }
        Write-Host "Password does not match. Please re-enter"
    }
}