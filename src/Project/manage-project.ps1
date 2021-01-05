

$___int_projectCache___ = @{}
function existsProject{
    param(
        [String]$org,
        [String]$projectName
    )

    Write-Verbose "[existsProject] Check if project with name $($projectName) exists..." 

    $projectExists = $___int_projectCache___[$projectName]

    if (!$projectExists) {
        $projectExists = az devops project list --org $org --query "value[] | [?name == '$projectName'].id | [0]" --output json | ConvertFrom-Json
        $___int_projectCache___[$projectName] = $projectExists
    }

    return $projectExists
}


function createProject {
    param (
        [Parameter(Mandatory=$true)][string]$projectName,
        [Parameter(Mandatory=$true)][string]$org,
        [string]$description=" ",
        [string]$process="Scrum",
        [string]$visibility="private"
    )

    if ([string]::IsNullOrEmpty($description)) {
        $description = $projectName
    }

    Write-Verbose "[createProject] Creating project with name $($projectName) . . . " 
    $newProject = az devops project create --only-show-errors --name $projectName.Trim() --description $description.Trim() --org $org --process $process.Trim() --source-control git --visibility $visibility.Trim()  --output json | ConvertFrom-Json
    Write-Verbose "[createProject] Created project with name $($newProject.name) and Id $($newProject.id)"

    return $newProject.id
}

function configureDefaultTeamDetails {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$team,
        [string]$teamDescription=" "
    )

    Write-Verbose "[configureDefaultTeamDetails] Getting project $project default team details"
    $defaultTeam = az devops project show --only-show-errors --project $project --org $org --output json --query "{id: defaultTeam.id, name: defaultTeam.name}" | ConvertFrom-Json
    Write-Verbose "[configureDefaultTeamDetails] Default team name: $($defaultTeam.name)"

    if (!($defaultTeam.name -eq $team)) {
        Write-Verbose "[configureDefaultTeamDetails] Need to change default team details"
        $defaultTeam = az devops team update --only-show-errors --team $defaultTeam.id --description $teamDescription --name $team --org $org --project $project --output json | ConvertFrom-Json
        Write-Verbose "[configureDefaultTeamDetails] Deafult team details changed for name $team and descriprion $teamDescription" 
    }
    
    return $defaultTeam.id
}

