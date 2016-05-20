function CreateAIDiagnostics([string]$subscriptionId, [string]$appInsightsAppName, [string]$resourceGroupName) {
    $ErrorActionPreference = "Stop"

    LoginToAzureRM $subscriptionId

    $templateFilePath = "$PSScriptRoot\..\Templates\AI.template.json"
    $parametersFilePath = "$PSScriptRoot\..\Templates\AI.parameters.json"

    # register resource providers    
    $resourceProviders = @("microsoft.insights");
    if($resourceProviders.length) {
        foreach($resourceProvider in $resourceProviders) {
            RegisterRP($resourceProvider);
        }
    }

    try {
        $appInsightsApp = Get-AzureRmResource -ResourceGroupName $resourceGroupName -ResourceType Microsoft.Insights/components -ResourceName $appInsightsAppName -ErrorAction SilentlyContinue
    }
    catch {
    }
    
    if (!$appInsightsApp) {
        # create AppInsights 
        Write-Host "Create Application Insights resource ...";
        if(Test-Path $parametersFilePath) {
            $deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -appInsightsAppName $appInsightsAppName
        } else {
            $deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -appInsightsAppName $appInsightsAppName
        }

        $appInsightsApp = Get-AzureRmResource -ResourceGroupName $resourceGroupName -ResourceType Microsoft.Insights/components -ResourceName $appInsightsAppName    
        Write-Host "Application Insights application '$appInsightsAppName' created"
    } else {
        Write-Host "Application Insights application '$appInsightsAppName' already exists"
    }
    
    return $appInsightsApp.Properties.InstrumentationKey
}