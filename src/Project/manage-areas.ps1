. (Join-Path $PSScriptRoot ..\Utils\cli-query-utils.ps1)

$___areaCache___ = @{}

<#
    .SYNOPSIS
        Check if a area exists on a specific project.
		
    .DESCRIPTION
        Check if a area exists on a spectific project using its name make the search.
        If area is found, returns its Id.
 
    .PARAMETER org
        Azure DevOps organization where the search will be performed. Parameter must be on URL format.

	.PARAMETER project
        Project name where the aearch will be performed.

	.PARAMETER name
		Name of the area to be searched for.

    .INPUTS
        None
 
    .OUTPUTS
        System.String. Area Id (identifier on Azure DevOps model) on GUID format
#>
function existsArea {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )

    Write-Verbose "[existsArea] Get area ($name) identifier"
    $areaId = $___areaCache___[$name]

    if (!$areaId) {
        $query = transformPathToJMESPath -path $name
        $areaId = az boards area project list --only-show-errors --org $org --project $project --depth 100  --output json --query $query
        $___areaCache___[$name] = $areaId
    }
    Write-Verbose "[existsArea] Get area ($name) identifier -> $areaId"

    return $areaId
}

function createArea {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )

    Write-Verbose "[createArea] Create area ($name)"
    $nodes = $name -split '\\'
    $pathToCheck = "\"
    $parent = ""

    Write-Verbose "[createArea] Need to check all path ($name)"
    foreach ($node in $nodes) {   
        if ($node) {
            $parent = $pathToCheck
            $pathToCheck = $pathToCheck + $node + "\"
            Write-Verbose "[createArea] Check if area $pathToCheck exists..."
            if (!(existsArea -org $org -project $project -name $pathToCheck)) {
                Write-Verbose "[createArea] Area $pathToCheck doesn't exist. Creating with name $node and path $parent"
                az boards area project create --only-show-errors --name $node --org $org --project $project --path "\$project\Area$parent"
                Write-Verbose "[createArea] Area $pathToCheck created"
            }
        }  
    }
    
    $areaId = existsArea -org $org -project $project -name $name

    if ($areaId) {
        Write-Verbose "[createArea] Area $name create. Identifier -> $areaId"
    }
    
    return $areaId
}

function getBaseArea {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project
    )

    Write-Verbose "[getBaseArea] Get base area identifier"
    $areaId = az boards area project list --only-show-errors --org $org --project $project  --output json --query "identifier" | ConvertFrom-Json
    Write-Verbose "[getBaseArea] Get area identifier -> $areaId"

    return $areaId
}

function getFullPathIds {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$area
    )

    $toReturn = @();
    $actualArea = $area
    while ($actualArea -ne "\") {
        $areaId = existsArea -org $org -project $project -name $actualArea
        $toReturn += $areaId
        $actualArea = Split-Path -Path $actualArea
    }

    $toReturn += getBaseArea -org $org -project $project

    return ,$toReturn
}
