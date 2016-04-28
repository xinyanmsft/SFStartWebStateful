param(
 [Parameter(Mandatory=$True)]
 [string]
 $accountUrl,

 [Parameter(Mandatory=$True)]
 [string]
 $userName,

 [Parameter(Mandatory=$True)]
 [string]
 $password,

 [Parameter(Mandatory=$True)]
 [string]
 $projectName,

 [Parameter(Mandatory=$False)]
 [string]
 $repoName,

 [Parameter(Mandatory=$True)]
 [string]
 $buildDefinitionName
)

$ErrorActionPreference = "Stop"

$vsoApiVersion = "?api-version=2.0"
$vsoPreviewApiVersion = "?api-version=2.0-preview"

if ($accountUrl.EndsWith("/") -ne $True) {
  $accountUrl = $accountUrl + "/";
}

$vsoCommonHeader = @{
  'Authorization' = 'Basic ' + [System.Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes($userName + ":" + $password));
  'content-type' = 'application/json'
};

if ([string]::IsNullOrEmpty($repoName)) {
  $repoName = $projectName
}

# Create the project
Function CreateProject {
  $projectUrl = $accountUrl + "defaultcollection/_apis/projects/";

  try {
    $getResult = Invoke-RestMethod -Method Get -Uri ($projectUrl + $projectName + $vsoApiVersion) -Header $vsoCommonHeader
    Write-Host "Project $projectName already exist."
    return $getResult;
  }
  catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        $newProject = @{
          'name' = $projectName;
          'description' = 'project description ...';
          'capabilities' = @{
              'versioncontrol' = @{ 'sourceControlType' = 'Git' };
              'processTemplate' = @{ 'templateTypeId' = 'adcc42ab-9882-485e-a3ed-7678f01f66bc' }
            }
        };

        $createResult = Invoke-RestMethod -Method Post -Body (ConvertTo-Json $newProject -Depth 100) -Uri ($projectUrl + $vsoApiVersion) -Header $vsoCommonHeader;
        Write-Host "Create project $projectName ..."

        while($True) {
          $progress = Invoke-RestMethod -Method Get -Uri $createResult.url -Header $vsoCommonHeader
          if ($progress.status -eq 'succeeded') {
            $getResult = Invoke-RestMethod -Method Get -Uri ($projectUrl + $projectName + $vsoApiVersion) -Header $vsoCommonHeader
            Write-Host "Project $projectName created."
            return $getResult;
         }

          Start-Sleep -s 5
        }
    } else {
      throw;
    }
  }
};

Function CreateRepo {
  Param(
    [string]$projectId
  )

  try {
    $getRepoUrl = $accountUrl + "defaultcollection/" + $projectId + "/_apis/git/repositories/" + $repoName;
    $getResult = Invoke-RestMethod -Method Get -Uri ($getRepoUrl + $vsoApiVersion) -Header $vsoCommonHeader

    Write-Host "Repository $repoName already exist."
    return $getResult;
  }
  catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
      $newRepo = @{
          'name' = $repoName;
          'project' = @{ 'id' = $projectId }
      };
      $createRepoUrl = $accountUrl + "defaultcollection/_apis/git/repositories"
      $createResult = Invoke-RestMethod -Method Post -Body (ConvertTo-Json $newRepo -Depth 100) -Uri ($createRepoUrl + $vsoApiVersion) -Header $vsoCommonHeader;
      Write-Host "Repo $repoName created. To push existing repo, run: "
      Write-Host "git remote add origin " $createResult.Get-Item('remoteUrl')
      Write-Host "git push -u origin --all"

      return $createResult;
    } else {
      throw;
    }
  }
};

Function GetParameterValue{
  Param(
    [string] $name
  )
  $r = [environment]::GetEnvironmentVariable($name)
  if ([string]::IsNullOrEmpty($r)) {
    Throw New-Object System.ArgumentException "Environment variable $name is not defined."
  }
  return $r
}

Function CreateBuildVariables {
  $buildConfig = @{value='Release';allowOverride='true' }
  $buildPlatform = @{value='x64';allowOverride='false' }
  
  return @{
    BuildConfiguration = $buildConfig;
    BuildPlatform = $buildPlatform
  };
}

Function CreateBuildTriggers {
  return @{
        'batchChanges' = 'true';
        'maxConcurrentBuildsPerBranch' = 1;
        'triggerType' = 'continuousIntegration';
        'branchFilters' = @('+refs/heads/master')
    };
}

Function CreateNuGetRestoreBuildStep {
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

Function CreateMSBuildStep{
    Param(
      [string]$targetname,
      [string]$projName,
      [string]$arguments
    )

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

Function CreateScriptBuildStep{
  Param(
    [string]$name,
    [string]$scriptName,
    [string]$arguments
  )

  return @{
    'enabled' = 'true';
    'continueOnError' = 'false';
    'alwaysRun' = 'false';
    'displayName' = "Script $name";
    'task' = @{'id' = 'e213ff0f-5d5c-4791-802d-52ea3e7be1f1'; 'versionSpec' = '*'};
    'inputs' = @{
      'scriptName' = $scriptName;
      'arguments' = $arguments;
      'workingFolder' = ''
    };
  };
}

Function CreateServiceEndpoint{
 Param(
 [string]$projectId
 )
 $randomNum = Get-Random
 $serviceEndpoint = @{
	'authorization' = @{
		'scheme' = 'ServicePrincipal';
		'parameters' = @{
			'serviceprincipalid' = $env:ServicePrincipalId;
			'serviceprincipalkey' = $env:ServicePrincipalKey;
			'tenantid' = $env:ServicePrincipalTenantId
		}
	}
	'data' = @{
		'SubscriptionId' = $env:ServicePrincipalSubscriptionId;
		'SubscriptionName' = $env:ServicePrincipalSubscriptionName
	};
	'name' = "CI_ConnectionEndpoint_$randomNum";
	'type' = 'azurerm';
	'url' = 'https://management.core.windows.net/'
 }

 $createServiceEndpointUrl = $accountUrl + "defaultcollection/" + $projectId + "/_apis/distributedtask/serviceendpoints"

 $createResult = Invoke-RestMethod -Method Post -Body (ConvertTo-Json $serviceEndpoint -Depth 100) -Uri ($createServiceEndpointUrl + $vsoPreviewApiVersion) -Header $vsoCommonHeader
 return $createResult
}

Function CreateRemoveCluster{
  Param([string]$serviceEndPointId)

  return @{
	enabled = 'true';
	continueOnError = 'true';
	alwaysRun = 'false';
	displayName = 'Remove existing cluster';
	task = @{'id' = '94a74903-f93f-4075-884f-dc11f34058b4'; 'versionSpec' = '*'};
	inputs = @{
		ConnectedServiceNameSelector = "ConnectedServiceName";
        ConnectedServiceName = $serviceEndPointId;
        action = "DeleteRG";
        actionClassic = "Select Resource Group";
        resourceGroupName = $env:ServiceFabricClusterResourceGroupName;
        location = $env:ServiceFabricClusterLocation        
	}
  }
}

Function CreateDeployCluster{
  Param([string]$serviceEndPointId)

  return @{
	enabled = 'true';
	continueOnError = 'false';
	alwaysRun = 'false';
	displayName = 'Provision Secure Cluster';
	task = @{'id' = '94a74903-f93f-4075-884f-dc11f34058b4'; 'versionSpec' = '*'};
	inputs = @{
		ConnectedServiceNameSelector = "ConnectedServiceName";
        ConnectedServiceName = $serviceEndPointId;
        action = "Create Or Update Resource Group";
        actionClassic = "Select Resource Group";
        resourceGroupName = $env:ServiceFabricClusterResourceGroupName;
        location = $env:ServiceFabricClusterLocation;
		csmFile = "Tools/helpers/Automation/azuredeploy.json";
        csmParametersFile = "Tools/helpers/Automation/azuredeploy.parameters.json"
	}
  }
}

Function CreateBuildDefinition{
  Param(
    [string]$buildName,
    [string]$repoId,
    [string]$repoName,
    [string]$repoUrl,
    [string]$projectName,
    [string]$projectId,
	[string]$serviceEndPointId
  )

  $step1 = CreateNuGetRestoreBuildStep;
  $step2 = CreateMSBuildStep 'Build' 'Application1.sln' ''
  $step3 = CreateMSBuildStep 'Package' 'Application1\Application1.FabricApplication.sfproj' '/t:Package'
  $step4 = CreateRemoveCluster $serviceEndPointId
  $step5 = CreateDeployCluster $serviceEndPointId
  $step6 = CreateScriptBuildStep 'Deploy' 'Application1\Scripts\Deploy-FabricApplication.ps1' '-PublishProfileFile Application1\PublishProfiles\CI.xml -ApplicationPackagePath Application1\pkg\$(BuildConfiguration) -OverwriteBehavior Always'

  $triggers = CreateBuildTriggers
  $variables = CreateBuildVariables

  $newBuild = @{
    name = $buildName;
    type = 'build';
    quality = 'definition';
    queue = @{'id' = 1};
	build = @($step1, $step2, $step3, $step4, $step5, $step6);
    project = @{'id' = $projectId};
    repository = @{
      id = $repoId;
      type = 'tfsgit';
      name = $repoName;
      defaultBranch = 'refs/heads/master';
      url = $repoUrl;
      clean = 'false'
    };
	triggers = @($triggers);
    variables = $variables      
  };
  
  $buildUrl = $accountUrl + 'defaultcollection/' + $projectName + '/_apis/build/definitions'

  $createBuildResult = Invoke-RestMethod -Method Post -Body (ConvertTo-Json $newBuild -Depth 100) -Uri ($buildUrl + $vsoApiVersion) -Header $vsoCommonHeader
}

$project = CreateProject
$repo = CreateRepo $project.id

$serviceEndpoint = CreateServiceEndpoint $project.id

CreateBuildDefinition $buildDefinitionName $repo.id $repo.name $repo.url $repo.project.name $project.id $serviceEndpoint.id
