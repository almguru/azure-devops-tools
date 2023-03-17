# Azure DevOps Tools

Useful tools for managing Azure DevOps

## AKS Service Connection

This tool helps you to create a service connection to an Azure Kubernetes Service (AKS) cluster.

```bash
./administration/create-aks-service-account.sh -g <resource-group> -c <aks-cluster-name> -n <namespace> [-s <subscription>]
```

this script creates service account and secret and returns cluster name, URL and secret content to be used to create AKS Service Connection either for environment resource or on project level. Script requires [Azure CLI][azurecli] to be installed and logged in.

[azurecli]: https://learn.microsoft.com/en-us/cli/azure/
