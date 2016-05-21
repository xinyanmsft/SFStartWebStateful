function VerifyVSTSConnection([string]$accountUrl, [string]$userName, [string]$password) {
    <#
    .SYNOPSIS
    Validate VSTS connection and credential
    #>

    $ErrorActionPreference = "Stop"

    $authHeader = GetVSTSAuthHeader $userName $password
    $apiVersion = GetVSTSAPIVersion

    $projectsUrl = $accountUrl + "defaultcollection/_apis/projects/"
    try {
        $getResult = Invoke-RestMethod -Method Get -Uri ($projectsUrl + $apiVersion) -Header $authHeader
        return $True
    }
    catch {
        return $False
    }
}

function IsVSTSBuildDefinitionExist([string]$accountUrl, [string]$userName, [string]$password, [string]$projectName, [string]$buildDefinitionName) {
    $authHeader = GetVSTSAuthHeader $userName $password
    $apiVersion = GetVSTSAPIVersion

    $buildUrl = $accountUrl + 'defaultcollection/' + $projectName + '/_apis/build/definitions'
    try {
        $getResult = Invoke-RestMethod -Method Get -Uri ($buildUrl + $apiVersion) -Header $authHeader -ErrorAction SilentlyContinue
        if ($getResult -and $getResult.value) {
            foreach($d in $getResult.value) {
                if ([string]::Compare($d.name, $buildDefinitionName, $true) -eq 0) {
                    return $true
                }
            }
        }
    }
    catch {
    }

    return $false
}

function IsVSTSReleaseDefinitionExist([string]$accountUrl, [string]$userName, [string]$password, [string]$projectName, [string]$releaseDefinitionName) {
    $authHeader = GetVSTSAuthHeader $userName $password

    $releaseUrl = $accountUrl.ToLower().Replace(".visualstudio.com/", ".vsrm.visualstudio.com/")
    $getReleaseUrl = $releaseUrl + 'defaultcollection/' + $projectName + '/_apis/release/definitions?api-version=3.0-preview.1'
    try {
        $getResult = Invoke-RestMethod -Method Get -Uri ($getReleaseUrl) -Header $authHeader -ErrorAction SilentlyContinue
        if ($getResult -and $getResult.value) {
            foreach($d in $getResult.value) {
                if ([string]::Compare($d.name, $releaseDefinitionName, $true) -eq 0) {
                    return $true
                }
            }
        }
    }
    catch {
    }
    return $false
}

function CreateVSTSCIFlow([string]$accountUrl, [string]$userName, [string]$password, [string]$projectName, [string]$repoName, [string]$buildDefinitionName, [string]$releaseDefinitionName, [string]$subscriptionId, [string]$applicationName, [string]$clusterName, [string]$clusterRGName, [string]$clusterLocation, $outputFolderName) {
    $ErrorActionPreference = "Stop"

    if ($accountUrl.EndsWith("/") -ne $True) {
        $accountUrl = $accountUrl + "/";
    }

    if ([string]::IsNullOrEmpty($repoName)) {
        $repoName = $projectName
    }

    $context = New-Object PSObject | Select-Object accountUrl, authHeader, projectName, repoName, buildDefinitionId, buildDefinitionName, releaseDefinitionName, subscriptionId, applicationName, apiVersion, previewApiVersion, projectId, repoId, serviceEndpointId, clusterName, clusterRGName, clusterLocation, outputFolderName
    $context.accountUrl = $accountUrl
    $context.authHeader = GetVSTSAuthHeader $userName $password
    $context.projectName = $projectName
    $context.repoName = $repoName
    $context.buildDefinitionName = $buildDefinitionName
    $context.releaseDefinitionName = $releaseDefinitionName
    $context.subscriptionId = $subscriptionId
    $context.applicationName = $applicationName
    $context.apiVersion = GetVSTSAPIVersion
    $context.previewApiVersion = GetVSTSPreviewAPIVersion
    $context.clusterName = $clusterName
    $context.clusterRGName = $clusterRGName
    $context.clusterLocation = $clusterLocation
    $context.outputFolderName = $outputFolderName

    $project = CreateVSTSProject $context
    $repo = CreateVSTSRepo $context
    $serviceEndpoint = SelectServiceEndpoints $context

    CreateVSTSBuildDefinition $context
}

function CreateVSTSProject($context) {
    $projectUrl = $context.accountUrl + "defaultcollection/_apis/projects/";

    try {
        $getResult = Invoke-RestMethod -Method Get -Uri ($projectUrl + $context.projectName + $context.apiVersion) -Header $context.authHeader
        Write-Host "Project" $context.projectName "already exist."
        $context.projectId = $getResult.id
        return $getResult;
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            $newProject = @{
              'name' = $context.projectName;
              'description' = 'description here';
              'capabilities' = @{
                  'versioncontrol' = @{ 'sourceControlType' = 'Git' };
                  'processTemplate' = @{ 'templateTypeId' = 'adcc42ab-9882-485e-a3ed-7678f01f66bc' }
                }
            };

            $createResult = Invoke-RestMethod -Method Post -Body (ConvertTo-Json $newProject -Depth 100) -Uri ($projectUrl + $context.apiVersion) -Header $context.authHeader
            Write-Host "Create project " $context.projectName

            while($True) {
                $progress = Invoke-RestMethod -Method Get -Uri $createResult.url -Header $context.authHeader
                if ($progress.status -eq 'succeeded') {
                    $getResult = Invoke-RestMethod -Method Get -Uri ($projectUrl + $context.projectName + $context.apiVersion) -Header $context.authHeader
                    Write-Host "Project" $context.projectName "created."
                    $context.projectId = $getResult.id
                    return $getResult;
                }
                Start-Sleep -s 5
            }
        } else {
            throw;
        }
    }
}

function CreateVSTSRepo($context) {
    try {
        $getRepoUrl = $context.accountUrl + "defaultcollection/" + $context.projectId + "/_apis/git/repositories/" + $context.repoName;
        $getResult = Invoke-RestMethod -Method Get -Uri ($getRepoUrl + $context.apiVersion) -Header $context.authHeader

        Write-Host "Repository" $context.repoName "already exist."
        $context.repoId = $getResult.id
        return $getResult;
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            $newRepo = @{
                'name' = $context.repoName;
                'project' = @{ 'id' = $context.projectId }
            };
            $createRepoUrl = $context.accountUrl + "defaultcollection/_apis/git/repositories"
            $createResult = Invoke-RestMethod -Method Post -Body (ConvertTo-Json $newRepo -Depth 100) -Uri ($createRepoUrl + $context.apiVersion) -Header $context.authHeader
            $context.repoId = $getResult.id

            Write-Host "Repo" $context.repoName "created. To push existing repo, run: "
            Write-Host "git remote add origin " $createResult.Get-Item('remoteUrl')
            Write-Host "git push -u origin --all"

            return $createResult;
        } else {
            throw;
        }
    }
}

function CreateVSTSBuildTriggers {
  return @{
        'batchChanges' = 'true';
        'maxConcurrentBuildsPerBranch' = 1;
        'triggerType' = 'continuousIntegration';
        'branchFilters' = @('+refs/heads/master')
    };
}

function CreateVSTSBuildVariables {
  $buildConfig = @{value='Release';allowOverride='true' }
  $buildPlatform = @{value='x64';allowOverride='false' }

  return @{
    BuildConfiguration = $buildConfig;
    BuildPlatform = $buildPlatform
  };
}

function CreateNuGetRestoreBuildStep {
  return @{
    'enabled' = 'true';
    'continueOnError' = 'false';
    'alwaysRun' = 'false';
    'displayName' = 'Restore NuGet packages';
    'task' = @{'id' = '333b11bd-d341-40d9-afcf-b32d5ce6f23b'; 'versionSpec' = '*'};
    'inputs' = @{
      'solution' = '**\*.sln';
      'nugetConfigPackage' = '';
      'noCache' = 'false';
      'nuGetRestoreArgs' = '';
      'nuGetPath' = ''
    };
  };
}

function CreateMSBuildStep([string]$targetname, [string]$projName, [string]$arguments) {
    return @{
      'enabled' = 'true';
      'continueOnError' = 'false';
      'alwaysRun' = 'false';
      'displayName' = "Build $targetname";
      'task' = @{'id' = 'c6c4c611-aa2e-4a33-b606-5eaba2196824'; 'versionSpec' = '*'};
      'inputs' = @{
        'solution' = $projName;
        'platform' = '$(BuildPlatform)';
        'configuration' = '$(BuildConfiguration)';
        'msbuildArguments' = $arguments;
        'clean' = 'false';
        'restoreNuGetPackages' = 'false';
        'logProjectEvents' = 'false';
        'msbuildLocationMethod' = 'version';
        'msbuildVersion' = '14.0';
        'msbuildArchitecture'= 'x86';
        'msbuildLocation' = ''
      };
    };
}

function SelectServiceEndpoints($context) {
    $getServiceEndpointUrl = $context.accountUrl + "defaultcollection/" + $context.projectId + "/_apis/distributedtask/serviceendpoints"
    $getResult = Invoke-RestMethod -Method Get -Uri ($getServiceEndpointUrl + $context.previewApiVersion) -Header $context.authHeader -ErrorAction SilentlyContinue
    if ($getResult -and ($getResult.count -gt 0)) {
        $i = 0
        $endpoints = @{}
        foreach($endpoint in $getResult.value) {
            if ($endpoint.type.CompareTo("azurerm") -eq 0) {
                if ($i -eq 0) {
                    Write-Host "Existing service endpoint found. You can select from an existing service endpoint, or create a new service endpoint:"
                    Write-Host "(0) Create a new endpoint"
                }

                $i++
                Write-Host "($i)" $endpoint.name "created by" $endpoint.createdBy.displayName
                $endpoints.Add($i, $endpoint)
            }
        }
        if ($i -gt 0) {
            do {
                $validInput = $false
                $selectionStr = Read-Host "Please select (0 - $i)"
                $selection = $selectionStr -as [int]
                if (($selection -ne $null) -and ($selection -le $i) -and ($selection -ge 0)) {
                    $validInput = $true
                    if ($selection -eq 0) {
                        return CreateServiceEndpoint($context);
                    }

                    $endpoint = $endpoints.Get_Item($selection)
                    $context.serviceEndpointId = $endpoint.id
                    return $endpoint
                }
            }while(!$validInput)
        }
    }

    return CreateServiceEndpoint($context)
}

Function CreateServiceEndpoint($context){
    $guidPassword = [GUID]::NewGuid()
    $servicePrincipal = GetOrCreateServicePrincipal $context.subscriptionId $context.applicationName "Owner" $True $guidPassword

    $serviceEndpoint = @{
        'authorization' = @{
            'scheme' = 'ServicePrincipal';
            'parameters' = @{
                'serviceprincipalid' = $servicePrincipal.Get_Item("ServicePrincipalId");
                'serviceprincipalkey' = $servicePrincipal.Get_Item("ServicePrincipalKey");
                'tenantid' = $servicePrincipal.Get_Item("TenantId");
            }
        }
        'data' = @{
            'SubscriptionId' = $servicePrincipal.Get_Item("SubscriptionId");
            'SubscriptionName' = $servicePrincipal.Get_Item("SubscriptionName");
        };
        'name' = "CI_ConnectionEndpoint_$randomNum";
        'type' = 'azurerm';
        'url' = 'https://management.core.windows.net/'
    }

    $createServiceEndpointUrl = $context.accountUrl + "defaultcollection/" + $context.projectId + "/_apis/distributedtask/serviceendpoints"
    $createResult = Invoke-RestMethod -Method Post -Body (ConvertTo-Json $serviceEndpoint -Depth 100) -Uri ($createServiceEndpointUrl + $context.previewApiVersion) -Header $context.authHeader
    $context.serviceEndpointId = $createResult.id

    return $createResult
}

function CreatePublishArtifact($context, [string]$displayName, [string]$artifactName, [string]$path) {
  return @{
    'enabled' = 'true';
    'continueOnError' = 'false';
    'alwaysRun' = 'false';
    'displayName' = $displayName;
    'task' = @{'id' = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'; 'versionSpec' = '*'};
    'inputs' = @{
      'PathtoPublish' = $path;
      'ArtifactName' = $artifactName;
      'ArtifactType' = 'Container';
      'TargetPath' = '\\my\share\$(Build.DefinitionName)\$(Build.BuildNumber)'
    };
  }
}

function CreateDeployClusterTask($context){
    $clusterName = $context.clusterName
    $outputFolderName = $context.outputFolderName
    $buildDefinitionName = $context.buildDefinitionName
    return @{
      taskId = '94a74903-f93f-4075-884f-dc11f34058b4';
      version = '*';
      name = 'Create or Update Secure Cluster';
      enabled = $true;
        continueOnError = $false;
        alwaysRun = $false;
      definitionType = 'task';
      inputs = @{
          ConnectedServiceNameSelector = "ConnectedServiceName";
        ConnectedServiceName = $context.serviceEndPointId;
        ConnectedServiceNameClassic = '';
        action = "Create Or Update Resource Group";
        actionClassic = "Select Resource Group";
        resourceGroupName = $context.clusterRGName;
        cloudService = '';
        location = $context.clusterLocation;
        csmFile =  "`$(System.DefaultWorkingDirectory)/$buildDefinitionName/Tools/Templates/azuredeploy.json";
        csmParametersFile = "`$(System.DefaultWorkingDirectory)/$buildDefinitionName/Tools/$outputFolderName/$clusterName.azuredeploy.parameters.json";
        overrideParameters = '';
        enableDeploymentPrerequisitesForCreate = 'false';
        enableDeploymentPrerequisitesForSelect = 'false';
        outputVariable = '';
      }
  }
}

function CreateScriptTask([string]$name, [string]$scriptName, [string]$arguments) {
    return @{
        taskId = 'e213ff0f-5d5c-4791-802d-52ea3e7be1f1';
        version = '*';
        name = "Script $name";
        enabled = $true;
        continueOnError = $false;
        alwaysRun = $false;
        definitionType = 'task';
        inputs = @{
            scriptType = 'filepath';
            scriptName = $scriptName;
            arguments = $arguments;
            workingFolder = ''
        }
    }
}

function GetVSTSAuthHeader($userName, $password) {
    $authHeader = @{
        'Authorization' = 'Basic ' + [System.Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes($userName + ":" + $password));
        'content-type' = 'application/json'
    }
    return $authHeader
}

function GetVSTSAPIVersion {
    return "?api-version=2.0"
}

function GetVSTSPreviewAPIVersion {
    return "?api-version=2.0-preview"
}

function CreateVSTSReleaseDefinition($context, $tasks) {
    $buildDefinitionId = $context.buildDefinitionId
    $approval = @(@{rank = 1; isAutomated = $true; isNotificationOn = $false})
    $environment = @{
        name = "$clusterName-Environment";
        rank = 1;
        preDeployApprovals = @{'approvals' = $approval};
        postDeployApprovals = @{'approvals' = $approval};
        deployStep = @{ 'tasks' = $tasks };
        environmentOptions = @{emailNotificationType = 'Always'; skipArtifactsDownload = $false; timeoutInMinutes = 0};
        demands = @('Agent.Version -gtVersion 1.87');
        conditions = @(@{name = 'ReleaseStarted'; conditionType = 'event'; value = ''});
        executionPolicy = @{concurrencyCount = 0; queueDepthCount = 0};
        queueId = 1;
        runOptions = @{EnvironmentOwnerEmailNotificationType = 'Always'; skipArtifactsDownload = 'False'; TimeoutInMinutes = '0'};
        variables = @();
        schedules = @();
    }
    $artifact = @{
        type = 'Build';
        alias = $context.buildDefinitionName;
        definitionReference = @{
            definition = @{name = $context.buildDefinitionName; id = "$buildDefinitionId"};
            project = @{id = $context.projectId; name = $context.projectName}
        }
    }

    $newRelease = @{
        name = $context.releaseDefinitionName;
        environments = @($environment);
        artifacts = @($artifact);
        variables = @();
        releaseNameFormat = 'Release-$(rev:r)';
        triggers = @(@{artifactAlias = $context.buildDefinitionName; triggerType = "artifactSource"});
        retentionPolicy = @{daysToKeep = 60};
    };

    $releaseUrl = $context.accountUrl.ToLower().Replace(".visualstudio.com/", ".vsrm.visualstudio.com/")
    $createReleaseUrl = $releaseUrl + 'defaultcollection/' + $context.projectName + '/_apis/release/definitions?api-version=3.0-preview.1'

    $foo = ConvertTo-Json $newRelease -Depth 100

    $createReleaseResult = Invoke-RestMethod -Method Post -Body (ConvertTo-Json $newRelease -Depth 100) -Uri $createReleaseUrl -Header $context.authHeader
}

function CreateVSTSBuildDefinition($context) {
  $appName = $context.applicationName
  $buildDefinitionName = $context.buildDefinitionName

  $step1 = CreateNuGetRestoreBuildStep
  $step2 = CreateMSBuildStep 'Build' "$appName.sln" ''
  $step3 = CreateMSBuildStep 'Package' "$appName\$appName.FabricApplication.sfproj" '/t:Package'
  $step4 = CreatePublishArtifact $context 'Publish Artifact: Application Package' 'Application' $appName
  $step5 = CreatePublishArtifact $context 'Publish Artifact: Tools' 'Tools' 'Tools'

  $step7 = CreateDeployClusterTask $context
  $step8 = CreateScriptTask 'Deploy' "`$(System.DefaultWorkingDirectory)\$buildDefinitionName\Application\Scripts\Deploy-FabricApplication.ps1" "-PublishProfileFile `$(System.DefaultWorkingDirectory)\$buildDefinitionName\Tools\$outputFolderName\$clusterName.CI.xml -ApplicationPackagePath `$(System.DefaultWorkingDirectory)\$buildDefinitionName\Application\pkg\`$(BuildConfiguration) -OverwriteBehavior Always"

  $triggers = CreateVSTSBuildTriggers
  $variables = CreateVSTSBuildVariables

  $newBuild = @{
    name = $context.buildDefinitionName;
    type = 'build';
    quality = 'definition';
    queue = @{'id' = 1};
    build = @($step1, $step2, $step3, $step4, $step5);
    project = @{'id' = $context.projectId};
    repository = @{
      id = $context.repoId;
      type = 'tfsgit';
      name = $context.repoName;
      defaultBranch = 'refs/heads/master';
      url = $context.repoUrl;
      clean = 'false'
    };
    triggers = @($triggers);
    variables = $variables
  };

  $buildUrl = $context.accountUrl + 'defaultcollection/' + $context.projectName + '/_apis/build/definitions'

  $createBuildResult = Invoke-RestMethod -Method Post -Body (ConvertTo-Json $newBuild -Depth 100) -Uri ($buildUrl + $context.apiVersion) -Header $context.authHeader
  $context.buildDefinitionId = $createBuildResult.id

  CreateVSTSReleaseDefinition $context @($step7, $step8)
}
