# Azure Functions Infrastructure Deployment Script
# This script deploys the Azure Functions app infrastructure using Bicep

param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$Environment,
    
    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "main.parameters.json",
    
    [Parameter(Mandatory = $false)]
    [string]$BicepFile = "main.bicep"
)

# Check if Azure CLI is installed
function Test-AzureCLI {
    try {
        $null = az --version
        return $true
    }
    catch {
        return $false
    }
}

# Check if user is logged in to Azure
function Test-AzureLogin {
    try {
        $account = az account show 2>$null
        return $account -ne $null
    }
    catch {
        return $false
    }
}

Write-Host "Starting Azure Functions Infrastructure Deployment" -ForegroundColor Green

if (-not (Test-AzureCLI)) {
    Write-Error "Azure CLI is not installed"
    exit 1
}

if (-not (Test-AzureLogin)) {
    Write-Error "Not logged in to Azure"
    exit 1
}

# Set subscription
Write-Host "Setting subscription to $SubscriptionId" -ForegroundColor Blue
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set subscription"
    Write-Error "az account set --subscription id"
    exit 1
}

# Show current subscription
$currentSubscription = az account show --query "name" -o tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($currentSubscription)) {
    Write-Error "Failed to retrieve current subscription name"
    Write-Error "az account show --query name -o tsv"
    exit 1
}

Write-Host "Current subscription: $currentSubscription" -ForegroundColor Blue

# Read from parameters file
Write-Host "Reading parameters from file: $ParametersFile" -ForegroundColor Blue
$parametersContent = Get-Content -Path $ParametersFile -Raw | ConvertFrom-Json
$Name = $parametersContent.parameters.name.value
$Location = $parametersContent.parameters.location.value

# Build resource group and function app names
$ResourceGroupName = "rg-$Name-$Environment"
$FunctionAppName = "$Name-$Environment"

Write-Host "Environment: $Environment" -ForegroundColor Blue
Write-Host "Function App Name: $FunctionAppName" -ForegroundColor Blue
Write-Host "Resource Group Name: $ResourceGroupName" -ForegroundColor Blue
Write-Host "Location: $Location" -ForegroundColor Blue

# Create resource group if it doesn't exist
Write-Host "Checking if resource group '$ResourceGroupName' exists..." -ForegroundColor Blue
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "false") {
    Write-Host "Creating resource group '$ResourceGroupName' in '$Location'..." -ForegroundColor Blue

    az group create --name $ResourceGroupName --location $Location
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create resource group"
        Write-Error "az group create --name $ResourceGroupName --location $Location"
        exit 1
    }

    Write-Host "Resource group created successfully" -ForegroundColor Green
} else {
    Write-Host "Resource group already exists" -ForegroundColor Green
}

# Validate Bicep template
Write-Host "Validating Bicep template..." -ForegroundColor Blue
az deployment group validate `
    --resource-group $ResourceGroupName `
    --template-file $BicepFile `
    --parameters $ParametersFile `
    --parameters environment=$Environment

if ($LASTEXITCODE -ne 0) {
    Write-Error "Bicep template validation failed"
    exit 1
}
Write-Host "Template validation successful" -ForegroundColor Green

# Deploy the infrastructure
Write-Host "Deploying Azure Functions infrastructure..." -ForegroundColor Blue
$deploymentName = "azurefuncapp-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

az deployment group create `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --template-file $BicepFile `
    --parameters $ParametersFile `
    --parameters environment=$Environment `
    --verbose

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed"
    exit 1
}
Write-Host "Deployment completed successfully" -ForegroundColor Green

# Get deployment outputs
Write-Host "Retrieving deployment outputs..." -ForegroundColor Blue
$outputs = az deployment group show `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

if ($outputs) {
    Write-Host "Deployment Outputs:" -ForegroundColor Yellow
    Write-Host "  Function App Name: $($outputs.functionAppName.value)" -ForegroundColor White
    Write-Host "  Function App URL: $($outputs.functionAppUrl.value)" -ForegroundColor White
    Write-Host "  Storage Account: $($outputs.storageAccountName.value)" -ForegroundColor White
    Write-Host "  Application Insights: $($outputs.applicationInsightsName.value)" -ForegroundColor White
    Write-Host "  App Insights Key: $($outputs.applicationInsightsInstrumentationKey.value)" -ForegroundColor White
}

Write-Host "Azure Functions infrastructure deployment completed" -ForegroundColor Green