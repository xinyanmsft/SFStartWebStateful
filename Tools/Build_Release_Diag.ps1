
param(
 [Parameter(Mandatory=$True, HelpMessage="Azure subscription Id")]
 [string]
 $subscriptionId,

 [Parameter(Mandatory=$False, HelpMessage="The application name")]
 [string]
 $applicationName,

 [Parameter(Mandatory=$False)]
 [string]
 $resourceGroupName,

 [Parameter(Mandatory=$True, HelpMessage="Your service fabric cluster name.")]
 [string]
 $clusterName,
 
 [Parameter(Mandatory=$True, HelpMessage="Desired location, such as westus, eastus, etc.")]
 [string]
 $resourceGroupLocation 
)

#Requires -RunAsAdministrator
Import-Module "$PSScriptRoot\Scripts\Master.psm1"

$ErrorActionPreference = "Stop"

$c = Get-PrerequisitesStatus
if (!$c)
{
    Write-Host "Prerequisites not installed. Exit"
    EXIT
}

if ([string]::IsNullOrEmpty($applicationName)) {
    $applicationName = "Application1"
}

$validClusterName = IsValidClusterName $clusterName
if (!$validClusterName) {
    Write-Host "Invalid cluster name"
    EXIT
}

$validClusterLocation = IsValidClusterLocation $resourceGroupLocation
if (!$validClusterLocation) {
    Write-Host "Invalid resource group location"
    EXIT
}

$appInsightsAppName = $clusterName
$resourceGroupName = "RG-$applicationName"
$clusterRGName = "CluseterRG-$applicationName"

$outputFolderName = "files-$clusterName"
$outputFolder = Join-Path $PSScriptRoot $outputFolderName
New-Item $outputFolder -type directory -ErrorAction SilentlyContinue | Out-Null
if (-not (Test-Path $outputFolder -pathType container)){
    Write-Error "Cannot create output folder $outputFolder. Please ensure you have proper the permission."
    EXIT 
}

$certPassword = GetPassword 'A self-signed certificate will be created to secure the service fabric cluster. Please enter the password to secure your certificate'
$adminPassword = GetPassword "Please enter the password to secure your service fabric cluster virtual machines (the user name is 'testadm')"

$vstsAccount = Read-Host "Please enter your Visual Sutdio Team Services URL, such as 'https://contoso.visualstudio.com'"
$vstsUser = Read-Host "Please enter Visual Studio Team Services username, such as john@contoso.com"
do {
    $vstsPassword = Read-Host "Please enter Visual Studio Team Services personal access token or alternate credential, the one you use to access your GIT repo" -AsSecureString

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($vstsPassword)
    $vstsPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

    if ($vstsAccount.EndsWith("/") -ne $True) {
      $vstsAccount = $vstsAccount + "/";
    }

    $isConnectionValid = VerifyVSTSConnection $vstsAccount $vstsUser $vstsPassword
    if (!$isConnectionValid) {
        Write-Host "Can not connect to VSTS account $vstsAccountUrl using the credentials you supplied. Please make sure your specified the correct account URL (e.g. https://contoso.visualstudio.com) and credential."
    }
}while(!$isConnectionValid)

do {
    $vstsProjectName = Read-Host "Please enter the project name to host your source code"
}while([string]::IsNullOrEmpty($vstsProjectName))

$vstsRepoName = Read-Host "Please enter the repositary name to host your source code. Skip to use the default repo of the project"
if ([string]::IsNullOrEmpty($vstsRepoName)){
    $vstsRepoName = $vstsProjectName    
}

$buildDefinitionName = "Build_" + $applicationName
$releaseDefinitionName = "Release_" + $clusterName
$i = 1
do {
    $buildDefinitionExist = IsVSTSBuildDefinitionExist $vstsAccount $vstsUser $vstsPassword $vstsProjectName $buildDefinitionName
    $releaseDefinitionExist = IsVSTSReleaseDefinitionExist $vstsAccount $vstsUser $vstsPassword $vstsProjectName $releaseDefinitionName
    
    if ($buildDefinitionExist -or $releaseDefinitionExist) {
        $buildDefinitionName = "Build_" + $applicationName + "_" + $i
        $releaseDefinitionName = "Release_" + $clusterName + "_" + $i
        $i++
    }
}while($buildDefinitionExist -or $releaseDefinitionExist)

LoginToAzureRM $subscriptionId

Write-Host "Ensuring Azure resource group ..."
$resourceGroup = GetOrCreateResourceGroup $resourceGroupName $resourceGroupLocation

$appInsightsKey = CreateAIDiagnostics $subscriptionId $appInsightsAppName $resourceGroupName

Write-Host "Creating deployment files ..."
CreateClusterDeploymentFiles $subscriptionId $clusterName $resourceGroupName $resourceGroupLocation $certPassword $adminPassword $appInsightsKey $outputFolder

Write-Host "Create CI build and release definitions ..."
CreateVSTSCIFlow $vstsAccount $vstsUser $vstsPassword $vstsProjectName $vstsRepoName $buildDefinitionName $releaseDefinitionName $subscriptionId $applicationName $clusterName $clusterRGName $resourceGroupLocation $outputFolderName

Write-Host "********************************************************************************"
Write-Host "If you haven't, please add your project to the following GIT repo. "
Write-Host "	git remote add origin $vstsAccount/DefaultCollection/$vstsProjectName/_git/$vstsRepoName"
Write-Host " "
Write-Host "Build definition '$buildDefinitionName' and release definition '$releaseDefinitionName' created in $vstsAccount/DefaultCollection/$vstsProjectName/_build for continuous build and deploy."
Write-Host " "
Write-Host "$PSScriptRoot\templates\azuredeploy.parameters.json and templates\CI.xml created. These files need to be added to your repositary to enable the above continuous build and deploy."
Write-Host "After adding this files to your repo, push it to the GIT repo. This will automatically queue a build. Go to $vstsAccount/DefaultCollection/$vstsProjectName/_build to see its status."
Write-Host "	git push -u origin --all"
Write-Host " "
Write-Host "After the build and deploy succeeds, you should be able to access the Service Fabric cluster via:"
Write-Host "    https://$clusterName.$resourceGroupLocation.cloudapp.azure.com:19080"
Write-Host "Please use a browser that supports HTML5 local storage, such as Microsoft Edge or Chrome. Client certificate named '$clusterName.$resourceGroupLocation.cloudapp.azure.com' is required. If you need to access via browser in a different computer, please import $certFile to personal certificate store." 
Write-Host " "
Write-Host "Please follow the 'Set up your build machine' section in https://azure.microsoft.com/en-us/documentation/articles/service-fabric-set-up-continuous-integration/#set-up-your-build-machine to set up your build agent, using certificate $certFile"
Write-Host "For testing purposes, this machine already has the certificate installed. You can use this machine as your build agent (set your build agent to run as local system in this case)."
Write-Host " "
Write-Host "Diagnostics information such as logs and performance counter can be viewed from Application Insights, https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/microsoft.insights/components/$appInsightsAppName"
Write-Host "********************************************************************************"

