<#
.SYNOPSIS
    Populates iterations in Azure DevOps project using existing naming convention and duration.

.DESCRIPTION
    That script Populates additinal iterations using the existing naming convention and duration.
    It uses specified existing last iteration to learn naming convention and duration of the iteration.

    Script uses Azure CLI (https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) 
    and Azure DevOps CLI extension (https://learn.microsoft.com/en-us/azure/devops/cli/?view=azure-devops)

.PARAMETER OrgUrl
    Azure DevOps organization URL. For Azure DevOps projects organization URL should be specified as https://dev.azure.com/<org_name>.

.PARAMETER ProjectName
    Azure DevOps project name.

.PARAMETER IterationsToCreate
    Number of iterations to create. 

.PARAMETER LastIterationName
    Name of the last iteration in the project. This iteration will be used to learn naming convention and duration of the iteration.

.EXAMPLE    
    New-Iterations -OrgUrl https://dev.azure.com/myorg -ProjectName Checkers -IterationsToCreate 100 -LastIterationName "Sprint 20"

.EXAMPLE    
    New-Iterations -OrgUrl https://dev.azure.com/myorg -ProjectName Chess -IterationsToCreate 50 -LastIterationName "S100"
#>

Param
    (
    [parameter(Mandatory=$true)]
    [String]
    $OrgUrl,
    [parameter(Mandatory=$true)]
    [String]
    $ProjectName,
    [parameter(Mandatory=$true)]
    [String]
    $IterationsToCreate,
    [parameter(Mandatory=$true)]
    [String]
    $LastIterationName
    )

$iterationsToCreate = $IterationsToCreate

$iterations = az boards iteration project list --org "$OrgUrl" -p "$ProjectName" -o json | ConvertFrom-Json

$lastIteration = $iterations.children | Where-Object { $_.name -eq "$LastIterationName" }

$match = $lastIteration.name | Select-String "(?<LastIterationNumber>\d+$)" -AllMatches

if ($match.Matches.Count -lt 1 -or -not $match.Matches[0].Success)
{
    throw 'Unable to detect last iteration number from "' + $lastIteration.path + '" iteration'
}

$firstIterationNumber = [int]::Parse($match.Matches[0].Value) + 1
$baseName = $lastIteration.name.Substring(0, $match.Matches[0].Index)
$parentIteration = $lastIteration.path.Substring(0, $lastIteration.path.Length - $LastIterationName.Length - 1)

$startDate = $lastIteration.attributes.startDate
$iterationLength = $lastIteration.attributes.finishDate - $lastIteration.attributes.startDate
$iterationCycle = [TimeSpan]::FromDays([convert]::ToInt32($iterationLength.Days / 7) * 7)

Write-Debug "Start date: $startDate"
Write-Debug "Iteration length: $iterationLength"
Write-Debug "Iteration cycle: $iterationCycle"
Write-Debug "Base name: $baseName"
Write-Debug "Parent pathname: $parentIteration"
Write-Debug "First iteration number: $firstIterationNumber"

for ($i=0; $i -lt $iterationsToCreate; $i++)
{
    $startDate += $iterationCycle
    az boards iteration project create --org "$OrgUrl" -p "$ProjectName" --path "$parentIteration" --name ($baseName + ($firstIterationNumber + $i).ToString("D2")) --start-date $startDate --finish-date ($startDate + $iterationLength) -o json
}