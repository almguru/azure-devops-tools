<#
.SYNOPSIS
    Provsions new repository and pipleine

.DESCRIPTION
    This script will provision a new git repository and corresponding pipeline based on product and component name.
    
    Prerequisites:
    - Azure DevOps CLI: https://docs.microsoft.com/en-us/azure/devops/cli/?view=azure-devops.
    - Command line Git client: https://git-scm.com/downloads

.PARAMETER ProductName
    Product name.

.PARAMETER ComponentName
    Product' component name.

.PARAMETER CreateNewDefaultBranch
    Create new default branch. Default: false.

.PARAMETER RequiredReviewers
    Required reviewers. List of required reviwers. You may put either e-mail address or Azure DevOps team name.

.PARAMETER RequiredReviewersPathFilter
    Filter path(s) on which the required reviwers policy is applied. Supports absolute paths, wildcards and multiple paths separated by ';'.
    Example: /WebApp/Models/Data.cs, /WebApp/* or *.cs,/WebApp/Models/Data.cs;ClientApp/Models/Data.cs.

.PARAMETER NewDefaultBranchName
    New default branch name. Default: develop.

.PARAMETER MainBranchName
    Main branch name. Default: main.

.PARAMETER TemplateName
    Name of template repository. Default: quick-start-no-code.

.PARAMETER ProjectName
    Azure DevOps project name. Default: Engineering.

.PARAMETER TemplateProjectName  
    Azure DevOps project name that contains template repo. Default: $ProjectName.

.PARAMETER OrganizationUrl
    Azure DevOps Service organization or Azure DevOps Server project collection URL. Default: https://dev.azure.com/almpro.

.PARAMETER UseSsh
    Use SSH for cloning repos. Default: false.

.PARAMETER DoNotDenyRootBranchesCreation
    Do not deny root branches creation for new repository. Default: false.

.NOTES
    Author: Vladimir Gusarov
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory, Position = 0, HelpMessage = "Product name")]
    [string] $ProductName,
    
    [Parameter(Mandatory, Position = 1, HelpMessage = "Product' component name")]
    [string] $ComponentName,

    [Parameter(HelpMessage = "Create new default branch")]
    [switch] $CreateNewDefaultBranch = $false,

    [Parameter(HelpMessage = "New default branch name")]
    [string] $NewDefaultBranchName = "develop",
 
    [Parameter(HelpMessage = "Main branch name")]
    [string] $MainBranchName = "main",

    [Parameter(Mandatory, HelpMessage = "Required reviewers. List of required reviwers. You may put either e-mail address or Azure DevOps team name.")]
    [string[]] $RequiredReviewers,

    [Parameter(HelpMessage = "Filter path(s) on which the required reviwers policy is applied. Supports absolute paths, wildcards and multiple paths separated by ';'.")]
    [string] $RequiredReviewersPathFilter = "*; !/documentation/*; !/docs/*",

    [Parameter(Position = 2, HelpMessage = "Name of template repository")]
    [string] $TemplateName = 'quickstart-no-code',

    [Parameter(HelpMessage = "Azure DevOps project name")]
    [string] $ProjectName = "Engineering",

    [Parameter(HelpMessage = "Azure DevOps project name that contains template repo")]
    [string] $TemplateProjectName = $ProjectName,

    [Parameter(HelpMessage = "Azure DevOps Service organization or Azure DevOps Server project collection URL")]
    [string] $OrganizationUrl = "https://dev.azure.com/almpro",

    [Parameter(HelpMessage = "Use SSH for cloning repos")]
    [switch] $UseSsh = $false,
    
    [Parameter(HelpMessage = "Do not deny root branches creation for new repository")]
    [switch] $DoNotDenyRootBranchesCreation = $false
)

function Write-CommandLog {
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]
        $Command
    )
    
    $tfPrefix = if ($env:TF_BUILD) { "##[command]" } else { "" }

    Write-Host -ForegroundColor 'cyan' "$tfPrefix$Command"
}

function Invoke-Az {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string] $Command
    )

    return Invoke-ShellCommand "az $Command --output 'json'" | ConvertFrom-Json
}

function Invoke-ShellCommand {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string] $Command
    )

    $singleLineCommand = $Command -replace '\s{2,}', ' ' # Remove extra spaces and new lines

    Write-CommandLog $singleLineCommand
    $result = Invoke-Expression "& $singleLineCommand"
    if ($LastExitCode -ne 0) {
        Write-Error "Failed to invoke az command. Exit code: $($LastExitCode)."
    }

    return $result
}

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$productNameNoSpaces = $ProductName.Trim().Replace(" ", "")
$componentNameNoSpaces = $ComponentName.Trim().Replace(" ", "-")
$repoName = "$($productNameNoSpaces)-$($componentNameNoSpaces)".ToLower()

#
# Cloning template repo
#
$templateRepo = Invoke-Az "repos show --project $TemplateProjectName --organization $OrganizationUrl --repository $TemplateName"
$templateUrl = if ($UseSsh) { $templateRepo.sshUrl } else { $templateRepo.remoteUrl }
$templateLocalFolder = ".fake"

Invoke-ShellCommand "git clone --bare $templateUrl $templateLocalFolder"

if ($PSCmdlet.ShouldProcess($repoName, "create repository")) {
    #
    # Create repository
    #
    $repo = Invoke-Az "repos create --project $ProjectName --organization $OrganizationUrl --name $repoName"
}

#
# Push from template
#
$currentDir = Get-Location
Set-Location $templateLocalFolder

$repoUrl = if ($UseSsh) { $repo.sshUrl } else { $repo.remoteUrl }
$remoteName = 'AzureDevOps'

if ($PSCmdlet.ShouldProcess($remoteName, "add remote")) {
    Invoke-ShellCommand "git remote add $remoteName $repoUrl"
}

$defaultBranchName = $MainBranchName

if ($CreateNewDefaultBranch) {
    $defaultBranchName = $NewDefaultBranchName
    Invoke-ShellCommand "git branch $NewDefaultBranchName"
}

if ($PSCmdlet.ShouldProcess($repoName, "pushing to repository")) {
    Invoke-ShellCommand "git push $remoteName --prune -f --all"
}
if ($PSCmdlet.ShouldProcess($defaultBranchName, "update repository default branch")) {
    Invoke-Az "repos update --project $ProjectName --organization $OrganizationUrl --repository $($repo.id) --default-branch $defaultBranchName" | Out-Null
}

#
# Create pipeline
#
$pipelineDescription = "`"CI/CD pipeline for '$($repo.name)' repository.`""
$pipelineYamlPath = "/azure-pipelines.yml"
$pipelineFolder = $ProductName.ToLower()

if ($PSCmdlet.ShouldProcess($repoName, "create pipeline")) {
    $pipeline = Invoke-Az "pipelines create `
        --project $ProjectName `
        --organization $OrganizationUrl `
        --name $($repo.name) `
        --repository $($repo.name) `
        --description $pipelineDescription `
        --folder-path $pipelineFolder `
        --repository-type 'tfsgit' `
        --yaml-path $pipelineYamlPath `
        --skip-first-run"
}

$protectedBranches = @( $MainBranchName )

if ($CreateNewDefaultBranch) {
    $protectedBranches += $NewDefaultBranchName
}

# 
# Create build policy for all protected branches
#
$protectedBranches | ForEach-Object {
    if ($PSCmdlet.ShouldProcess($_, "create build policy")) {
        Invoke-Az "repos policy build create `
            --project $ProjectName `
            --organization $OrganizationUrl `
            --repository-id $($repo.id) `
            --branch $($_) `
            --blocking true `
            --enabled true `
            --build-definition-id $($pipeline.id) `
            --display-name 'PR.Validation' `
            --manual-queue-only false `
            --queue-on-source-update-only false `
            --valid-duration 0" | Out-Null
    }
    if ($PSCmdlet.ShouldProcess($_, "create required reviewer policy")) {
        Invoke-Az "repos policy required-reviewer create `
            --project $ProjectName `
            --organization $OrganizationUrl `
            --repository-id $($repo.id) `
            --branch $($_) `
            --blocking true `
            --enabled true `
            --required-reviewer-ids '$($RequiredReviewers -join ';')' `
            --path-filter '$RequiredReviewersPathFilter' `
            --message ''" | Out-Null
    }
}

if ($PSCmdlet.ShouldProcess($defaultBranchName, "set default branch for pipeline")) {
    #
    # Set current default branch as default for the pipeline
    # 
    Invoke-Az "pipelines update --project $ProjectName --organization $OrganizationUrl --id $($pipeline.id) --branch $defaultBranchName" | Out-Null
}

Set-Location $currentDir
Remove-Item $templateLocalFolder -Recurse -Force -ErrorAction SilentlyContinue

if (-not $DoNotDenyRootBranchesCreation) {
    Write-Information "*** Denying root branch creation for repository '$($repo.name)'"
    & "$($PSScriptRoot)/Deny-RepoRootBranches.ps1" -OrganizationUrl $OrganizationUrl -ProjectName $ProjectName -RepositoryName $repo.name
}