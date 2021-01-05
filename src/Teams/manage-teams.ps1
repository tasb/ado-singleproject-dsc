. (Join-Path $PSScriptRoot ..\Groups\manage-groups.ps1)


function existsTeam {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )

    Write-Verbose "[existsTeam] Get team ($name) identifier"
    $teamId = az devops team list --org $org --project $project --top 1000 --output json --query "[?name == '$($name)'].id | [0]"
    Write-Verbose "[existsTeam] Get team ($name) identifier -> $teamId"

    return $teamId
}

function createTeam {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name,
        [string]$description = " "
    )

    if (!$description) {
        $description = " "
    }

    Write-Verbose "[createTeam] Creating team with name $($name)..." 
    $team = az devops team create --only-show-errors --name $name --description $description --org $org --project $project --output json | ConvertFrom-Json
    Write-Verbose "[createTeam] Created team with name $($team.name) and Id $($team.id)"

    return $team.Id
}

function getDefaultAreaFromTeam {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )

    Write-Verbose "[getDefaultAreaFromTeam] Getting default area from team $($name)..." 
    $defaultArea = az boards area team list --team $name --org $org --project $project --output json --query "defaultValue"
    Write-Verbose "[getDefaultAreaFromTeam] Default area for team $($team.name): $defaultArea"

    return $defaultArea
}

function setDefaultAreaOnTeam {
    param(
        [Parameter(Mandatory=$true)][String]$org,
        [Parameter(Mandatory=$true)][String]$project,
        [Parameter(Mandatory=$true)][String]$name,
        [Parameter(Mandatory=$true)][String]$areaPath,
        [bool]$includeSubAreas=$false
    )

    $fullAreaPath = "$project$areaPath"
    $prevDefaultArea = getDefaultAreaFromTeam -org $org -project $project -name $name
    #$prevDefaultArea = $prevDefaultArea -replace '"', ""

    if (!$prevDefaultArea) {
        Write-Verbose "[setDefaultAreaOnTeam] Team don't have a default area"
        Write-Verbose "[setDefaultAreaOnTeam] Setting $fullAreaPath as default area for team $name..." 
        $ret = az boards area team add --path $fullAreaPath --set-as-default --team $name --org $org --project $project --include-sub-areas $includeSubAreas --output json | ConvertFrom-Json
        Write-Verbose "[setDefaultAreaOnTeam] Default area set to: $fullAreaPath"
    } else {
        Write-Verbose "[setDefaultAreaOnTeam] Setting $fullAreaPath as default area for team $name..." 
        $ret = az boards area team update --path $fullAreaPath --set-as-default --team $name --org $org --project $project --include-sub-areas $includeSubAreas --output json | ConvertFrom-Json
        Write-Verbose "[setDefaultAreaOnTeam] Default area of team $name set to $fullAreaPath"
    } 
}

function getBacklogIterationFromTeam {
    param(
        [Parameter(Mandatory=$true)][String]$org,
        [Parameter(Mandatory=$true)][String]$project,
        [Parameter(Mandatory=$true)][String]$name,
        [Parameter(Mandatory=$true)][String]$iteration
    )

    Write-Verbose "[getBacklogIterationFromTeam] Getting backlog iteration from team $($name)..." 
    $iteration = az boards iteration team show-backlog-iteration --org $org --project $project --team $name --query "defaultIteration"

    if ($iteration) {
        Write-Verbose "[getBacklogIterationFromTeam] Backlog iteration from team $($name): $iteration"
    } else {
        Write-Verbose "[getBacklogIterationFromTeam] No backlog iteration configured for team $name"
    }
    
    return $iteration
}

function setBacklogIterationOnTeam {
    param(
        [Parameter(Mandatory=$true)][String]$org,
        [Parameter(Mandatory=$true)][String]$project,
        [Parameter(Mandatory=$true)][String]$name,
        [Parameter(Mandatory=$true)][String]$iterationId
    )

    Write-Verbose "[setBacklogIterationOnTeam] Setting Current Backlog Iteration for team $name with iteration id ($iterationId)"
    $ret = az boards iteration team set-backlog-iteration --id $iterationId --team $name --org $org --project $project
    Write-Verbose "[setBacklogIterationOnTeam] Current backlog iteration set!"
}

function addUserToTeam {
    param(
        [Parameter(Mandatory=$true)][String]$org,
        [Parameter(Mandatory=$true)][String]$project,
        [Parameter(Mandatory=$true)][String]$name,
        [Parameter(Mandatory=$true)][String]$user
    )

    Write-Verbose "[addUserToTeam] Get descriptor for team $name"
    $myDescriptor = getSecurityGroupDescriptor -org $org -project $project -name $name
    Write-Verbose "[addUserToTeam] Get descriptor for team $name -> $myDescriptor"
    
    if ($myDescriptor) {
        Write-Verbose "[addUserToTeam] Add user $user to team $name ($myDescriptor)..."
        $addMember = az devops security group membership add --only-show-errors --group-id $myDescriptor --member-id $user --org $org --output json | ConvertFrom-Json 
        Write-Verbose "[addUserToTeam] Add user $user to team $name... Done!"
    } else {
        Write-Host "Team $name doesn't exist on project $project. User will not be added."
    }
    
}

function getTeamAdmin {
    param(
        [Parameter(Mandatory=$true)][String]$org,
        [Parameter(Mandatory=$true)][String]$project,
        [Parameter(Mandatory=$true)][String]$team
    )

    Write-Verbose "[getTeamAdmin] Getting team admin from team $team as team admin..."
    $teamAdmin = az devops team list-member --team $team --project $project --org $org --query "[?isTeamAdmin].identity.uniqueName" | ConvertFrom-Json
    Write-Verbose "[getTeamAdmin] Getting team admin from team $team as team admin...Done!"
    return $teamAdmin
}

function setTeamAdmin {
    param(
        [Parameter(Mandatory=$true)][String]$org,
        [Parameter(Mandatory=$true)][String]$projectID,
        [Parameter(Mandatory=$true)][String]$teamID,
        [Parameter(Mandatory=$true)][String]$userEmail
    )
    $securityToken = $projectID + '\' + $teamID
    $securityToken = $securityToken -replace '"', "" 

    Write-Verbose "[setTeamAdmin] Setting user $userEmail as team admin..."
    $updateIdentityPermissions = az devops security permission update --only-show-errors --allow-bit 31 --org $org --id 5a27515b-ccd7-42c9-84f1-54c998f03866 --token $securityToken --subject $userEmail --output json | ConvertFrom-Json
    Write-Verbose "[setTeamAdmin] Setting user $userEmail as team admin... Done!"
}

function removeTeamAdmin {
    param(
        [Parameter(Mandatory=$true)][String]$org,
        [Parameter(Mandatory=$true)][String]$projectID,
        [Parameter(Mandatory=$true)][String]$teamID,
        [Parameter(Mandatory=$true)][String]$userEmail
    )
    $securityToken = $projectID + '\' + $teamID
    $securityToken = $securityToken -replace '"', "" 

    Write-Verbose "[removeTeamAdmin] Removing user $userEmail as team admin..."
    $updateIdentityPermissions = az devops security permission update --only-show-errors --deny-bit 31 --org $org --id 5a27515b-ccd7-42c9-84f1-54c998f03866 --token $securityToken --subject $userEmail --output json | ConvertFrom-Json
    Write-Verbose "[removeTeamAdmin] Removing user $userEmail as team admin... Done!"
}

function addIterationsToTeam {
    param(
        [Parameter(Mandatory=$true)][String]$org,
        [Parameter(Mandatory=$true)][String]$project,
        [Parameter(Mandatory=$true)][String]$name,
        [Parameter(Mandatory=$true)][Array]$iterationList
    )

    Write-Verbose "[addIterationsToTeam] Adding $($iterationList.Count) iterations to team $name..."
    foreach ($identifier in $iterationList) {
        Write-Verbose "[addIterationsToTeam] Adding $identifier to team $name..."
        $ret = az boards iteration team add --org $org --project $project --id $identifier --team $name
        Write-Verbose "[addIterationsToTeam] Adding $identifier to team $name... Done!"
    }
    Write-Verbose "[addIterationsToTeam] Adding $($iterationList.Count) iterations to team $name... Done!"
}

