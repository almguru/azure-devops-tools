<#
.SYNOPSIS
    Provsions new repository and pipleine

.DESCRIPTION
    This script disallows creation of new branches in the root of git repository.
    
    Prerequisites:
    - Visual Studio with Azure DevOps admin tools

.PARAMETER ProjectName
    Azure DevOps project name.

.PARAMETER RepositoryName
    Repository name. 

.NOTES
    Author: Vladimir Gusarov
#>
param (
    [Parameter(Mandatory, Position = 0, HelpMessage = "Azure DevOps project name")]
    [string] $ProjectName,
    
    [Parameter(Mandatory, Position = 1, HelpMessage = "Repository name")]
    [string] $RepositoryName,

    [Parameter(Mandatory = $false, HelpMessage = "Azure DevOps Service organization or Azure DevOps Server project collection URL")]
    [string] $OrganizationUrl = "https://dev.azure.com/almpro"
)

$InformationPreference = "Continue"

function Invoke-ShellCommand {
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]
        $Command
    )

    Write-Host -ForegroundColor 'cyan' "$Command"
    Invoke-Expression "& $($Command)"
    if (-not $?) {
        Write-Error "Failed to invoke shell command. Exit code: $($LastExitCode)"
    }
}

# $organizationName = $OrganizationUrl -replace 'https://dev.azure.com/', ''
# $projectNameNoSpaces = $ProjectName.Replace(" ", "")
# $groupNamePrefix = "Azure.DevOps.($organizationName).$($projectNameNoSpaces)"
# $adminGroupName = "$($groupNamePrefix).Admin"
# $contributorGroupName = "$($groupNamePrefix).Contribute"
$groupNamePrefix = "[$($ProjectName)]"
$adminGroupName = "$($groupNamePrefix)\Project Administrators"
$contributorGroupName = "$($groupNamePrefix)\Contributors"

Install-Module VSSetup -Scope CurrentUser -Repository PSGallery -SkipPublisherCheck
$vsSetup = Get-VSSetupInstance | Select-Object -Last 1 

if ($null -eq $vsSetup) {
    Write-Error "Visual Studio is not installed"
}

$tf = "`"$($vsSetup.InstallationPath)\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\tf.exe`""
$commonOptions = "git permission /collection:`"$($OrganizationUrl)`" /teamproject:`"$($ProjectName)`" /repository:`"$($RepositoryName)`""

Write-Information "*** Updating permission for project '$($ProjectName)' and repository '$($RepositoryName)'"

Invoke-ShellCommand "$($tf) $($commonOptions) /group:`"$($adminGroupName)`" /allow:CreateBranch"
Invoke-ShellCommand "$($tf) $($commonOptions) /group:`"$($contributorGroupName)`" /deny:CreateBranch"

$allowedBranches = @("feature", "release", "hotfix", "bugfix", "support", 'dependabot')

$allowedBranches | ForEach-Object {
    Invoke-ShellCommand "$($tf) $($commonOptions) /group:`"$($contributorGroupName)`" /allow:CreateBranch /branch:$($_)"
}