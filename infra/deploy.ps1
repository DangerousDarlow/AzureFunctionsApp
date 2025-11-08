# Azure Functions App Deployment Script
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

# Function to check if Azure CLI is installed
function Test-AzureCLI {
    try {
        $null = az --version
        return $true
    }
    catch {
        return $false
    }
}

# Function to check if user is logged in to Azure
function Test-AzureLogin {
    try {
        $account = az account show 2>$null
        return $account -ne $null
    }
    catch {
        return $false
    }
}

# Function to check if dotnet is installed
function Test-DotNet {
    try {
        $null = dotnet --version
        return $true
    }
    catch {
        return $false
    }
}

# Function to check if Azure Functions Core Tools is installed
function Test-FuncTools {
    try {
        $null = func --version
        return $true
    }
    catch {
        return $false
    }
}

Write-Host "Starting Azure Functions App Deployment" -ForegroundColor Green

# Check if .NET is installed
if (-not (Test-DotNet)) {
    Write-Error ".NET SDK is not installed. Please install it from https://dotnet.microsoft.com/download"
    exit 1
}

# Check if Azure CLI is installed
if (-not (Test-AzureCLI)) {
    Write-Error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check if Azure Functions Core Tools is installed
if (-not (Test-FuncTools)) {
    Write-Error "Azure Functions Core Tools is not installed. Please install it from https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local"
    exit 1
}

# Check if user is logged in
if (-not (Test-AzureLogin)) {
    Write-Host "You are not logged in to Azure. Please log in..." -ForegroundColor Yellow
    az login
    if (-not (Test-AzureLogin)) {
        Write-Error "Failed to log in to Azure"
        exit 1
    }
}

# Set subscription
Write-Host "Setting subscription to $SubscriptionId" -ForegroundColor Blue
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set subscription"
    exit 1
}

# Show current subscription
$currentSubscription = az account show --query "name" -o tsv
Write-Host "Current subscription: $currentSubscription" -ForegroundColor Blue

# Read parameters from parameters file
Write-Host "Reading parameters from file..." -ForegroundColor Blue
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
Write-Host "Checking if resource group '$ResourceGroupName' exists..." -ForegroundColor Blue
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "false") {
    Write-Error "Resource group '$ResourceGroupName' does not exist. Please run provision.ps1 first."
    exit 1
}
Write-Host "Resource group exists" -ForegroundColor Green

# Verify function app exists
Write-Host "Checking if function app '$FunctionAppName' exists..." -ForegroundColor Blue
$functionAppExists = az functionapp show --name $FunctionAppName --resource-group $ResourceGroupName 2>$null
if (-not $functionAppExists) {
    Write-Error "Function app '$FunctionAppName' does not exist. Please run provision.ps1 first."
    exit 1
}
Write-Host "Function app exists" -ForegroundColor Green

# Build the project
Write-Host "Building the Azure Functions app..." -ForegroundColor Blue
$projectDir = Split-Path -Parent $ProjectPath
$publishDir = Join-Path $projectDir "bin\$BuildConfiguration\net9.0\publish"

# Clean previous builds
if (Test-Path $publishDir) {
    Write-Host "Cleaning previous build output..." -ForegroundColor Blue
    Remove-Item -Path $publishDir -Recurse -Force
}

# Build and publish
dotnet publish $ProjectPath `
    --configuration $BuildConfiguration `
    --output $publishDir `
    --verbosity minimal

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed"
    exit 1
}
Write-Host "Build completed successfully" -ForegroundColor Green

# Deploy to Azure Functions using Core Tools
Write-Host "Deploying to Azure Functions app '$FunctionAppName'..." -ForegroundColor Blue

# Change to the publish directory for deployment
Set-Location $publishDir

# Explicitly specify runtime to avoid detection issues when publishing from the compiled output
func azure functionapp publish $FunctionAppName --no-build --dotnet-isolated

if ($LASTEXITCODE -ne 0) {
    Set-Location $PSScriptRoot
    Write-Error "Deployment failed"
    exit 1
}

# Return to the script directory
Set-Location $PSScriptRoot

Write-Host "Deployment completed successfully!" -ForegroundColor Green

# Get function app URL
$functionAppUrl = az functionapp show `
    --resource-group $ResourceGroupName `
    --name $FunctionAppName `
    --query "defaultHostName" `
    --output tsv

Write-Host "Function App URL: https://$functionAppUrl" -ForegroundColor Yellow

Write-Host "Azure Functions app deployment completed!" -ForegroundColor Green
