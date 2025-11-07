# Azure Functions Infrastructure

This directory contains Bicep templates and deployment scripts for provisioning an Azure Functions API application with the following specifications:

## Architecture Overview

- **Runtime**: .NET 9 Isolated Worker
- **Location**: UK West
- **Hosting Plan**: Consumption (Dynamic) on Linux
- **Storage**: Standard Locally Redundant Storage (LRS)
- **Monitoring**: Application Insights with Log Analytics workspace

## Resources Provisioned

1. **Storage Account** - Standard LRS for Azure Functions runtime
2. **Log Analytics Workspace** - For structured logging and monitoring
3. **Application Insights** - Connected to Log Analytics for telemetry
4. **App Service Plan** - Consumption plan on Linux
5. **Azure Functions App** - .NET 9 isolated worker runtime

## Prerequisites

- Azure CLI installed and configured
- Azure subscription with appropriate permissions
- PowerShell (for deployment script)

## Files

- `main.bicep` - Main Bicep template defining all Azure resources
- `main.parameters.json` - JSON parameters file with base configuration values
- `deploy.ps1` - PowerShell deployment script that handles environment-specific deployments

## Quick Deployment

> [!IMPORTANT]
> Azure function app names must be globally unique. The function app name will be `{name}-{environment}` where `name` is the base name defined in `main.parameters.json` and `environment` is passed at deployment time. For example, if `name` is "azurefuncapp" and `environment` is "dev", the function app will be named "azurefuncapp-dev".

1. **Update parameters** (optional):
   Edit `main.parameters.json` to customize:
   - `name` - Base name for the function app (without environment suffix)
   - `location` - Azure region for all resources

2. Run deployment script
   ```powershell
   .\deploy.ps1 -SubscriptionId {subscription_id} -Environment {environment}
   ```

   The script will automatically:
   - Create a resource group named `rg-{name}-{environment}` (e.g., `rg-azurefuncapp-dev`)
   - Read base configuration from `main.parameters.json`
   - Pass the environment parameter to the Bicep deployment
   - Deploy all infrastructure resources

## Manual Deployment

If you prefer to deploy manually using Azure CLI:

```bash
# Create resource group
az group create --name "rg-azurefuncapp-dev" --location "ukwest"

# Deploy infrastructure
az deployment group create \
  --resource-group "rg-azurefuncapp-dev" \
  --template-file main.bicep \
  --parameters main.parameters.json \
  --parameters environment=dev
```

## Environment-Based Deployments

The deployment model supports multiple environments without needing separate parameter files:

- **Parameters File** (`main.parameters.json`): Contains base configuration (`name` and `location`)
- **Environment Parameter**: Passed at deployment time (e.g., `dev`, `test`, `prod`) to create environment-specific resources
- **Resource Naming**: All resources automatically include the environment suffix (e.g., `azurefuncapp-dev`, `azurefuncapp-prod`)
- **Resource Group Naming**: Automatically follows pattern `rg-{name}-{environment}`
- **Tags**: Dynamically generated in Bicep using the environment parameter

This approach is ideal for CI/CD pipelines (e.g., GitHub Actions) where environment values can be injected from workflow variables or secrets without duplicating parameter files.

### Example Resource Groups
- Dev: `rg-azurefuncapp-dev`
- Test: `rg-azurefuncapp-test`
- Prod: `rg-azurefuncapp-prod`

## Configuration Details

### Storage Account
- **Type**: StorageV2 with Standard LRS replication
- **Security**: HTTPS only, TLS 1.2 minimum, no public blob access
- **Authentication**: Default to OAuth when possible

### App Service Plan
- **SKU**: Y1 (Consumption/Dynamic tier)
- **OS**: Linux
- **Scaling**: Automatic based on demand

### Function App
- **Runtime**: .NET Isolated 9.0 on Linux
- **Version**: Functions v4
- **Security**: HTTPS only, TLS 1.2 minimum
- **Deployment**: Run from package enabled

### Monitoring
- **Application Insights**: Connected to Log Analytics workspace
- **Log Analytics**: 30-day retention, Per-GB pricing tier
- **Structured Logging**: Enabled through Application Insights integration

## Environment Variables

The following application settings are automatically configured:

- `AzureWebJobsStorage` - Storage account connection string
- `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING` - Content storage connection
- `FUNCTIONS_EXTENSION_VERSION` - Set to ~4
- `FUNCTIONS_WORKER_RUNTIME` - Set to dotnet-isolated
- `APPINSIGHTS_INSTRUMENTATIONKEY` - Application Insights key
- `APPLICATIONINSIGHTS_CONNECTION_STRING` - Application Insights connection string

## Outputs

After deployment, the following outputs are available:

- Function App Name
- Function App URL
- Storage Account Name
- Application Insights Name and Keys
- Log Analytics Workspace ID

## Security Considerations

- All resources use HTTPS only with TLS 1.2 minimum
- Storage account has public blob access disabled
- Function app uses managed identity where possible
- Application settings are securely managed through Azure