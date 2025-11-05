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
- `main.parameters.json` - Parameters file with default values
- `deploy.ps1` - PowerShell deployment script

## Quick Deployment

1. **Update parameters** (optional):
   Edit `main.parameters.json` to customize:
   - Function app name
   - Environment name
   - Tags

2. **Run deployment script**:
   ```powershell
   .\deploy.ps1 -ResourceGroupName "rg-azurefuncapp-dev"
   ```

## Manual Deployment

If you prefer to deploy manually using Azure CLI:

```bash
# Create resource group
az group create --name "rg-azurefuncapp-dev" --location "ukwest"

# Deploy infrastructure
az deployment group create \
  --resource-group "rg-azurefuncapp-dev" \
  --template-file main.bicep \
  --parameters main.parameters.json
```

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

## Next Steps

1. Deploy your .NET 9 Function App code
2. Configure any additional environment variables
3. Set up CI/CD pipeline for automated deployments
4. Configure monitoring alerts and dashboards

## Customization

To modify the infrastructure:

1. Update `main.bicep` with your changes
2. Validate changes: `az deployment group validate --resource-group <rg-name> --template-file main.bicep --parameters main.parameters.json`
3. Deploy updates using the deployment script or Azure CLI

## Security Considerations

- All resources use HTTPS only with TLS 1.2 minimum
- Storage account has public blob access disabled
- Function app uses managed identity where possible
- Application settings are securely managed through Azure