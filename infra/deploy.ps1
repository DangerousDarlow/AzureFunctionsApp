# This script builds and deploys the Azure Functions app

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$Environment,
    
    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "main.parameters.json",
    
    [Parameter(Mandatory = $false)]
    [string]$ProjectPath = "..\src\AzureFunctionsApp\AzureFunctionsApp\AzureFunctionsApp.csproj",
    
    [Parameter(Mandatory = $false)]
    [string]$BuildConfiguration = "Release"
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

# Check if dotnet is installed
function Test-DotNet {
    try {
        $null = dotnet --version
        return $true
    }
    catch {
        return $false
    }
}

function Test-Tar {
    try {
        $null = Tar --version
        return $true
    }
    catch {
        return $false
    }
}

Write-Host "Starting Azure Functions App Deployment" -ForegroundColor Green

if (-not (Test-AzureCLI)) {
    Write-Error "Azure CLI is not installed"
    exit 1
}

if (-not (Test-AzureLogin)) {
    Write-Error "Not logged in to Azure"
    exit 1
}

if (-not (Test-DotNet)) {
    Write-Error ".NET SDK is not installed"
    exit 1
}

if (-not (Test-Tar)) {
    Write-Error "Tar is not installed"
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

# Read name from parameters file
Write-Host "Reading parameters from file: $ParametersFile" -ForegroundColor Blue
$parametersContent = Get-Content -Path $ParametersFile -Raw | ConvertFrom-Json
$Name = $parametersContent.parameters.name.value

# Build resource group and function app names
$ResourceGroupName = "rg-$Name-$Environment"
$FunctionAppName = "$Name-$Environment"

Write-Host "Environment: $Environment" -ForegroundColor Blue
Write-Host "Function App Name: $FunctionAppName" -ForegroundColor Blue
Write-Host "Resource Group Name: $ResourceGroupName" -ForegroundColor Blue
Write-Host "Project Path: $ProjectPath" -ForegroundColor Blue
Write-Host "Build Configuration: $BuildConfiguration" -ForegroundColor Blue

# Verify resource group exists
Write-Host "Checking if resource group exists..." -ForegroundColor Blue

$rgExists = az group exists --name $ResourceGroupName
if ($LASTEXITCODE -ne 0 -or $rgExists -eq "false") {
    Write-Error "Resource group does not exist"
    Write-Error "az group exists --name $ResourceGroupName"
    exit 1
}

Write-Host "Resource group exists" -ForegroundColor Green

# Verify function app exists
Write-Host "Checking if function app exists..." -ForegroundColor Blue

$functionAppDetails = az functionapp show --name $FunctionAppName --resource-group $ResourceGroupName 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Function app does not exist or could not be queried"
    Write-Error "az functionapp show --name $FunctionAppName --resource-group $ResourceGroupName"
    exit 1
}

Write-Host "Function app exists" -ForegroundColor Green

# Build the project
Write-Host "Building the Azure Functions app..." -ForegroundColor Blue
$projectDir = Split-Path -Parent $ProjectPath
$publishDir = Join-Path $projectDir "bin\$BuildConfiguration\net9.0\publish"
Write-Host "Publish directory: $publishDir" -ForegroundColor Blue

if (Test-Path $publishDir) {
    Remove-Item -Path $publishDir -Recurse -Force
}

dotnet publish $ProjectPath --configuration $BuildConfiguration --output $publishDir --verbosity minimal

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed"
    Write-Error "dotnet publish $ProjectPath --configuration $BuildConfiguration --output $publishDir --verbosity minimal"
    exit 1
}

Write-Host "Build completed successfully" -ForegroundColor Green

Write-Host "Creating deployment zip file using tar..." -ForegroundColor Blue

$originalDir = Get-Location

$zipPath = Join-Path $originalDir "deploy.zip"
if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}

try {
    Set-Location $publishDir

    tar -acf $zipPath *
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create zip file"
        Write-Error "cd $publishDir; tar -acf $zipPath *"
        exit 1
    }
}
catch {
    Write-Error "Failed to create zip file: $($_.Exception.Message)"
    Set-Location $originalDir
    exit 1
}
finally {
    Set-Location $originalDir
}

Write-Host "Deployment zip file created at: $zipPath" -ForegroundColor Green

$deployDetails = az functionapp deployment source config-zip --resource-group $ResourceGroupName --name $FunctionAppName --src $zipPath 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed"
    Write-Error "az functionapp deployment source config-zip --resource-group $ResourceGroupName --name $FunctionAppName --src $zipPath"
    exit 1
}

Write-Host "Deployment completed successfully" -ForegroundColor Green

Write-Host "Azure Functions app deployment completed successfully" -ForegroundColor Green