. (Join-Path $PSScriptRoot ..\Utils\cli-query-utils.ps1)

$___iterationCache___ = @{}

function existsIteration {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )

    $iterationId = $___iterationCache___[$name]
    if ($iterationId) {
        Write-Verbose "[existsIteration] Identifier for iteration ($name) on cache"
    } else {
        Write-Verbose "[existsIteration] Get iteration ($name) identifier"
        $query = transformPathToJMESPath -path $name
        $iterationId = az boards iteration project list --org $org --project $project --depth 100  --output json --query $query
        $___iterationCache___[$name] = $iterationId
        Write-Verbose "[existsIteration] Get iteration ($name) identifier -> $iterationId"
    }

    return $iterationId
}

function createIteration {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )

    Write-Verbose "[createIteration] Create iteration ($name)"
    $nodes = $name -split '\\'
    $pathToCheck = "\"
    $parent = ""

    Write-Verbose "[createIteration] Need to check all path ($name)"
    foreach ($node in $nodes) {   
        if ($node) {
            $parent = $pathToCheck
            $pathToCheck = $pathToCheck + $node + "\"
            Write-Verbose "[createIteration] Check if iteration $pathToCheck exists..."
            if (!(existsIteration -org $org -project $project -name $pathToCheck)) {
                Write-Verbose "[createIteration] Iteration $pathToCheck doesn't exist. Creating with name $node and path $parent"
                $newIterationId = az boards iteration project create --name $node --org $org --project $project --path "\$project\Iteration$parent" --output json --query "identifier"

                if ($newIterationId) {
                    Write-Verbose "[createIteration] Iteration $pathToCheck created"
                }
            }
        }  
    }

    return $newIterationId
}

function createIterationWithDate {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$true)][string]$startDate,
        [Parameter(Mandatory=$true)][string]$finishDate
    )

    Write-Verbose "[createIterationWithDate] Create iteration ($name)"
    $nodes = $name -split '\\'
    $pathToCheck = "\"
    $parent = ""

    Write-Verbose "[createIterationWithDate] Need to check all path ($name)"
    foreach ($node in $nodes) {   
        if ($node) {
            $parent = $pathToCheck
            $pathToCheck = $pathToCheck + $node + "\"
            Write-Verbose "[createIterationWithDate] Check if iteration $pathToCheck exists..."
            if (!(existsIteration -org $org -project $project -name $pathToCheck)) {
                Write-Verbose "[createIterationWithDate] Iteration $pathToCheck doesn't exist. Creating with name $node and path $parent"
                $newIterationId = az boards iteration project create --name $node --org $org --project $project --path "\$project\Iteration$parent" --start-date $startDate --finish-date $finishDate --output json --query "identifier"

                if ($newIterationId) {
                    Write-Verbose "[createIterationWithDate] Iteration $pathToCheck created"
                }
            }
        }  
    }

    return $newIterationId
}

function getIterationsBetweenDates {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$baseIteration,
        [Parameter(Mandatory=$true)][string]$startDate,
        [Parameter(Mandatory=$true)][string]$endDate
    )
    #"children[] | [?name=='DIT'].children[] | [?name=='2Weeks'].children[] | [?attributes.startDate >= '2020-09-01T00:00:00Z'].{name:path, startDate:attributes.startDate, finishDate:attributes.finishDate} | [?finishDate <= '2020-11-20T00:00:00Z'].name"

    Write-Verbose "[getIterationsBetweenDates] Getting iteration list between $startDate and $endDate"
    $query = transformSimplePathToJMESPath -path $baseIteration
    $query = $query +  "[?attributes.startDate >= '%%%START%%%T00:00:00Z'].{id:identifier, startDate:attributes.startDate, finishDate:attributes.finishDate} | [?finishDate <= '%%%END%%%T00:00:00Z'].id"
    $query = $query -replace "%%%START%%%", $startDate
    $query = $query -replace "%%%END%%%", $endDate
    Write-Verbose "[getIterationsBetweenDates] Query: $query"

    $iterationList = az boards iteration project list --org $org --project $project --depth 5 --output json --query $query | ConvertFrom-Json
    Write-Verbose "[getIterationsBetweenDates] Getting iteration list. Found those: $iterationList"

    return $iterationList
}
