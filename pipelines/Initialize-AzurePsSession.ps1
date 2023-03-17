<#
.SYNOPSIS
    Initializes PowerShell session to work with Azure Subscription.
.DESCRIPTION
    Installs required modules and initializes the session to work with Azure Subscription.
    This script intended to be run from Azure Pipelines only within AzureCLI@2 tasks
    
.PARAMETER AdditionalModules
    List of additional PowerShell modules to be installed.

.EXAMPLE    
    Initialize-AzurePsSession [-AdditionalModules "Az.Storage"]
#>

#requires -version 7

Param
(    
    [parameter(Mandatory = $false, Position = 1)]
    [string[]]
    $AdditionalModules = $null
)

if (-not $env:servicePrincipalKey -or -not $env:tenantId -or -not $env:servicePrincipalId)
{
    throw "Please set the following environment variables: servicePrincipalKey, tenantId, servicePrincipalId or run the script from AzureCLI@2 Azure Pipeline Task"
}

Write-Host "Checking for required Powershell modules"

$modulesToInstall = @("Az.Accounts")

if ($null -ne $AdditionalModules)
{
   $modulesToInstall = $modulesToInstall + $AdditionalModules
}
              
Write-Host "##[command]Set-PSRepository -Name PSGallery -InstallationPolicy Trusted"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

Write-Host "##[command]Install-Module -Name $($modulesToInstall)"
Install-Module -Name $modulesToInstall

$password = ConvertTo-SecureString -String $env:servicePrincipalKey -AsPlainText -Force
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList  $env:servicePrincipalId, $password

Write-Host "##[command]Connect-AzAccount -Credential $credential -Tenant $env:tenantId -ServicePrincipal"
Connect-AzAccount -Credential $credential -Tenant $env:tenantId -ServicePrincipal

$subscription = az account show --query "id" -o tsv

if (-not $subscription)
{
    throw "Failed to get Azure Subscription ID"
}

Write-Host "##[command]Set-AzContext -Subscription $($subscription)"
Set-AzContext -Subscription $subscription