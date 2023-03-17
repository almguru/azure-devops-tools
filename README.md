# Azure DevOps Tools

Useful tools for managing Azure DevOps

## AKS Service Connection

This tool helps you to create a service connection to an Azure Kubernetes Service (AKS) cluster.

```bash
./admin/create-aks-service-account.sh -g <resource-group> -c <aks-cluster-name> -n <namespace> [-s <subscription>]
```

this script creates service account and secret and returns cluster name, URL and secret content to be used to create AKS Service Connection either for environment resource or on project level. Script requires [Azure CLI][azurecli] to be installed and logged in.

[azurecli]: https://learn.microsoft.com/en-us/cli/azure/


## Using Azure commandlets from Azure Pipelines

There is a [AzureCLI@2][azureclitask] task in Azure Pipelines that can be used to run Azure CLI commands. However, it does not initialize Azure context if you want use PowerShell Az.* modules. This is a workaround to initialize Azure context in Azure Pipelines.

```powershell
./pipelines/Initialize-AzurePsSession.ps1 [-AdditionalModules "Az.Storage"]
```

See [Initialize-AzurePsSession.ps1](pipelines/Initialize-AzurePsSession.ps1) for implementation details. You may also see help information by running:
```powershell
Get-Help ./pipelines/Initialize-AzurePsSession.ps1
```

[azureclitask]: https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/azure-cli-v2?view=azure-pipelines