param(
    [Parameter(Mandatory=$true )][string]$org="https://dev.azure.com/tiberna",
    [Parameter(Mandatory=$true )][string]$dscFile="AzDevOps-DIT.xlsx",
    [Parameter(Mandatory=$true )][string]$tokenFile,
    [Parameter(Mandatory=$false)][string]$upnFilter,
    [Parameter(Mandatory=$false)][string]$processToUpdate="MyAgile",
    [Parameter(Mandatory=$false)][switch]$full,
    [Parameter(Mandatory=$false)][switch]$projects,
    [Parameter(Mandatory=$false)][switch]$teams,
    [Parameter(Mandatory=$false)][switch]$usersTeams,
    [Parameter(Mandatory=$false)][switch]$repos,
    [Parameter(Mandatory=$false)][switch]$witfields,
    [Parameter(Mandatory=$false)][switch]$log,
    [Parameter(Mandatory=$false)][switch]$fullSync
)

. (Join-Path $PSScriptRoot .\Org\manage-org.ps1)
. (Join-Path $PSScriptRoot .\Project\manage-areas.ps1)
. (Join-Path $PSScriptRoot .\Project\manage-iterations.ps1)
. (Join-Path $PSScriptRoot .\Project\manage-project.ps1)
. (Join-Path $PSScriptRoot .\Groups\manage-groups.ps1)
. (Join-Path $PSScriptRoot .\Teams\manage-teams.ps1)
. (Join-Path $PSScriptRoot .\Users\manage-users.ps1)
. (Join-Path $PSScriptRoot .\Repos\manage-repos.ps1)
. (Join-Path $PSScriptRoot .\Wikis\manage-wikis.ps1)
. (Join-Path $PSScriptRoot .\Permissions\manage-permissions.ps1)
. (Join-Path $PSScriptRoot .\Boards\manage-queries.ps1)
. (Join-Path $PSScriptRoot .\Pipelines\manage-pipelines.ps1)
. (Join-Path $PSScriptRoot .\Identity\identity-mgmt.ps1)
. (Join-Path $PSScriptRoot .\Fields\manage-fields.ps1)
. (Join-Path $PSScriptRoot .\Fields\manage-dependencies.ps1)


function quit() {
    [Console]::ResetColor()
    $VerbosePreference = "SilentlyContinue"

    if ($loggedIn) {
        logout -org $org
    }

    if ($upnFilter) {
        az logout
    }

    exit
}

function printError() {
    param (
        [Parameter(Mandatory=$true)][string]$message
    )

    [Console]::ResetColor()
    Write-Host ""
    Write-Host $("#" * $message.length) -ForegroundColor White -BackgroundColor Red
    Write-Host $message                 -ForegroundColor White -BackgroundColor Red
    Write-Host $("#" * $message.length) -ForegroundColor White -BackgroundColor Red
    Write-Host ""
    [Console]::ResetColor()
}

function publishWiki() {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$wikiRepoName,
        [Parameter(Mandatory=$true)][string]$team,
        [Parameter(Mandatory=$true)][array]$teamAdminList
    )
    if (!(existsRepo -org $org -project $project -name $wikiRepoName)) {
        Write-Verbose "Repo $wikiRepoName don't exists on project $($project). Creating..."
        $repoURL = createRepo -org $org -project $project -name $wikiRepoName
        initializeWikiRepo -repoURL $repoURL -name $wikiRepoName
        Write-Verbose "Repo $wikiRepoName don't exists on project $($project). Creating... Done!"

        Write-Verbose "Publishing wiki on repo $wikiRepoName..."
        publishCodeWiki -org $org -project $project -repo $wikiRepoName -name $wikiRepoName
        Write-Verbose "Publishing wiki on repo $wikiRepoName... Done!"
    }
    Write-Verbose "Set team $($team) as contributor on repo $($wikiRepoName)..."
    setPermissionOnRepoForTeam -org $org -project $project -repo $wikiRepoName -team $team -contributor $true
    Write-Verbose "Set team $($team) as contributor on repo $($wikiRepoName)... Done!"

    foreach ($teamAdmin in $teamAdminList) {
        $teamAdmin = $teamAdmin.Trim()
        $userUPN = getUPN -user $teamAdmin -upnFilter $upnFilter
                            
        Write-Verbose "Set team $($team.Name) as contributor on repo $($wikiRepoName)..."
        setPermissionOnRepoForUser -org $org -project $project -repo $wikiRepoName -user $userUPN -contributor $true -managePermissions $true
        Write-Verbose "Set team $($team.Name) as contributor on repo $($wikiRepoName)... Done!"
    }
}

function isRecordToUpdate() {
    param ( 
        [Parameter(Mandatory=$true)][object]$toCheck
    )
    return ($fullSync.IsPresent -or ($toCheck.Update -eq "YES"))
}

#
# Start Transcript
#
if($log.isPresent) {
    $MyPath = $MyInvocation.MyCommand.Definition.Substring(0,$MyInvocation.MyCommand.Definition.LastIndexOf('.'))
    $MyPath += ".log"
    Start-Transcript -Path $MyPath
}

#
# Check if a valid action was given
#
if ((!$full.IsPresent)  -and (!$projects.isPresent)   -and 
    (!$teams.isPresent) -and (!$usersTeams.isPresent) -and 
    (!$repos.isPresent) -and (!$witfields.isPresent)) {
        Write-Host "No action specified. You didn't specify an action. Enter a valid action: -full, -projects, -teams, -usersTeams, -repos, -witFields"
        quit
}

#
# Check if parameter '-Verbose' was set and must enable verbose output
#
if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
    $VerbosePreference = "Continue"
}

#
# Check if ImportExcel module is installed. If not, install it
#
Write-Verbose "Check if ImportExcel module is installed.."
if (!(Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Verbose "ImportExcel Module don't exists. Module will be installed"
    Install-Module -Name ImportExcel -AllowClobber -Confirm:$False -Force  
}
Write-Verbose "ImportExcel module installed on system"

#
# Check if Excel file exists
#
Write-Verbose "Check if Excel file $dscFile exists..."
if (!(Test-Path $dscFile -PathType Leaf)) {
    printError -message "Excel DSC file $dscFile doesn't exist. Please execute this script with a valida DSC Excel file."
    quit
}
Write-Verbose "Excel file $dscFile exists!"

#
# Check if token file was provided nad get its full path
#
Write-Verbose "Check if token file was provided..."
$tokenFileFullPath = ""
$personalToken = ""
if ($tokenFile) {
    $tokenFileFullPath = Resolve-Path -Path $tokenFile
    Write-Verbose "Token file provided. Full path: $tokenFileFullPath"
    $personalToken = Get-Content $tokenFile
}

#
# Perform login on Azure DevOps Server and set flags
#
$loggedIn = $false;
Write-Host "Logging in on $org..."
if (!(login -org $org -tokenFile $tokenFileFullPath)) {
    printError -message "Error logging on Azure DevOps Server: $org"
    quit
}
$loggedIn = $true;
Write-Host "Logged in successfully!"

#
# Perform login on Azure
#
if ($upnFilter) {
    Write-Host "Login on Azure to get users UPN..."
    az login --allow-no-subscriptions
    Write-Host "Login on Azure to get users UPN... Login done!"
}

#
# Manage Projects
#
if (($full.IsPresent) -or ($projects.isPresent)) {
    #
    # Getting projects data from Excel, check if they exist and ask to create new one if don't exists
    #
    Write-Host "Getting data from $dscFile..."
    $projectList = Import-Excel $dscFile -Sheet "Projects"
    $___projectCache___ = @{}
    Write-Host "Getting 'Projects' data..."
    foreach ($project in $projectList) {
        if (!$project.Name) { # Empty line
            continue;
        }
        if (!(isRecordToUpdate -toCheck $project)) {
            Write-Verbose "Project $($project.name) set to not be updated"
            continue;
        }

        $message = "=========  Start Working on Project: $($project.Name)  ========="
        Write-Host $("=" * $message.length)
        Write-Host $message
        Write-Host $("=" * $message.length)

        Write-Verbose "Check if project $($project.Name) exists..."
        $projectId = existsProject -org $org -projectName $project.Name
        if (!$projectId) {
            $name = $project.Name
            [Console]::ResetColor()
            $option = Read-Host "Project $name not found. Do you want to create this project? (Y/N)"
            if ($option.ToUpper() -eq "Y") {
                $projectId = createProject -projectName $project.Name -org $org -description $project.Description -process $project.Process -visibility $project.Visibility
                $year = get-date -Format yyyy
                $option = Read-Host "Do you want to create all iterations for year $($year)? (Y/N)"
                if ($option.ToUpper() -eq "Y") {
                    ./generate-iterations.ps1 -org $org -project $project.Name -prefix $project.DefaultIteration
                }
            }
        } else {
            Write-Verbose "Project $($project.Name) exists on $org"
        }
        $___projectCache___[$project.Name] = $projectId

        Write-Verbose "Set default team details. Name: $($project.DefaultTeam) | Description: $($project.DefaultTeamDescription)"
        $defaultTeamId = configureDefaultTeamDetails -org $org -project $project.Name -team $project.DefaultTeam -teamDescription $project.DefaultTeamDescription

        $defaultTeamAdmins = getTeamAdmin -org $org -project $project.Name -team $project.DefaultTeam
        foreach ($teamAdmin in $defaultTeamAdmins) {
            removeTeamAdmin  -org $org -projectID $projectId -teamID $defaultTeamId -userEmail $teamAdmin
        }

        $teamAdmins = $project.DefaultTeamAdmin -Split ";"
        foreach ($teamAdmin in $teamAdmins) {
            $userUPN = getUPN -user $teamAdmin -upnFilter $upnFilter
            addUserToTeam -org $org -project $project.Name -name $project.DefaultTeam -user $userUPN
            setTeamAdmin -org $org -projectID $projectId -teamID $defaultTeamId -userEmail $userUPN
        }
        
        # Check area
        $defaultArea = "\"+$project.DefaultTeam
        Write-Verbose "Check if area $($defaultArea) exists..."
        $areaId = existsArea -org $org -project $project.Name -name $defaultArea
        if (!$areaId) {
            Write-Host "Area $($defaultArea) not found. Starting to create..."
            $areaId = createArea -org $org -project $project.Name -name $defaultArea
            if ($areaId) {
                Write-Host "Area $($defaultArea) created successfully!"
            } else {
                printError -message "Error creating area $($defaultArea). Check log for more errors."
                quit
            }
        }

        Write-Host "Setting permission for team $($project.DefaultTeam) on area $($defaultArea)"
        setPermissionOnAreaForTeam -org $org -project $project.Name -area $defaultArea -team $project.DefaultTeam
        Write-Verbose "Default team details done!"
        
        Write-Verbose "Remove permission from group Contributors on all repos..."
        removeGroupFromRepo -org $org -project $project.Name -projectId $projectId -groupName "Contributors" -pat $personalToken
        Write-Verbose "Remove permission from group Contributors on all repos... Done!"

        Write-Verbose "Remove permission from group Contributors on all areas..."
        $baseAreaId = getBaseArea -org $org -project $project.Name
        resetPermissionOnBaseAreaForGroup -org $org -project $project.Name -areaId $baseAreaId -groupName "Contributors"
        Write-Verbose "Remove permission from group Contributors on all areas... Done!"

        Write-Verbose "Remove permission from group Contributors and Readers on all build pipelines..."
        removeGroupFromBuildPipelines -org $org -project $project.Name -projectId $projectId -groupName "Contributors" -pat $personalToken
        removeGroupFromBuildPipelines -org $org -project $project.Name -projectId $projectId -groupName "Readers" -pat $personalToken
        Write-Verbose "Remove permission from group Contributors and Readers on all build pipelines... Done!"

        Write-Verbose "Remove permission from group Contributors and Readers on all release pipelines..."
        $pipes = countReleasePipelines -org $org -project $project.Name

        $dummyPipelineId = -1
        if ($pipes -eq 0) {
            $dummyPipelineId = createReleasePipeline -org $org -project $project.Name -pat $personalToken
        }
        removeGroupFromReleasePipelines -org $org -project $project.Name -projectId $projectId -groupName "Contributors" -pat $personalToken
        removeGroupFromReleasePipelines -org $org -project $project.Name -projectId $projectId -groupName "Readers" -pat $personalToken

        if ($dummyPipelineId -ne -1) {
            deleteReleasePipeline -org $org -project $project.Name -pat $personalToken -definitionId $dummyPipelineId
        }

        Write-Verbose "Remove permission from group Contributors and Readers on Shared Queries..."
        removePermissionOnSharedQueriesFolder -org $org -project $project.Name -group "Contributors" -pat $personalToken
        removePermissionOnSharedQueriesFolder -org $org -project $project.Name -group "Readers" -pat $personalToken
        Write-Verbose "Remove permission from group Contributors and Readers on Shared Queries... Done!"
    }
    Write-Host "Projects done!"
}

#
# Manage Teams
#
if (($full.IsPresent) -or ($teams.isPresent)) {
    #
    # Getting teams data from Excel and perform the creation/update operations
    #
    $dummyPipelineId = -1
    $dummyPipelineProjectId = -1
    Write-Host "Getting 'Teams' from data..."
    $teamsList = Import-Excel $dscFile -Sheet "Teams"
    foreach ($team in $teamsList) {
        if (!$team.Name) { # Empty line
            continue;
        }
        if (!(isRecordToUpdate -toCheck $team)) {
            Write-Verbose "Team $($team.name) set to not be updated"
            continue;
        }

        $message = "=========  Start Working on Team: $($team.Name)  ========="
        Write-Host $("=" * $message.length)
        Write-Host $message
        Write-Host $("=" * $message.length)

        $projectId = existsProject -org $org -projectName $team.Project
        if ($projectId) {
            $pipes = countReleasePipelines -org $org -project $team.Project
            if ($pipes -eq 0) {
                $dummyPipelineId = createReleasePipeline -org $org -project $team.Project -pat $personalToken
                $dummyPipelineProjectId = $team.Project
            }
            # Check team
            Write-Verbose "Check if team $($team.Name) exists..."
            $teamID = existsTeam -org $org -project $team.Project -name $team.Name
            if (!$teamID) {
                Write-Host "Team $($team.Name) not found. Starting to create..."
                $teamID = createTeam -org $org -project $team.Project -name $team.Name -description $team.Description
                if ($teamID) {
                    Write-Host "Team $($team.Name) created successfully!"
                } else {
                    printError -message "Error creating team $($team.Name). Check log for more errors."
                    quit
                }
            }

            # Check iteration
            Write-Verbose "Check if iteration $($team.Iteration) exists..."
            $globalIterationId = existsIteration -org $org -project $team.Project -name $team.Iteration
            if (!$globalIterationId) {
                Write-Host "Iteration $($team.Iteration) not found. Starting to create..."
                $globalIterationId = createIteration -org $org -project $team.Project -name $team.Iteration
                if ($globalIterationId) {
                    Write-Host "Iteration $($team.Iteration) created successfully!"
                } else {
                    printError -message "Error creating iteration $($team.Iteration). Check log for more errors."
                    quit
                }
            }

            # Check area
            Write-Verbose "Check if area $($team.Area) exists..."
            $areaId = existsArea -org $org -project $team.Project -name $team.Area
            if (!$areaId) {
                Write-Host "Area $($team.Area) not found. Starting to create..."
                $areaId = createArea -org $org -project $team.Project -name $team.Area
                if ($areaId) {
                    Write-Host "Area $($team.Area) created successfully!"
                } else {
                    printError -message "Error creating area $($team.Area). Check log for more errors."
                    quit
                }
            }

            Write-Host "Setting permission for team $($team.Name) on area $($team.Area)"
            setPermissionOnAreaForTeam -org $org -project $team.Project -area $team.Area -team $team.Name

            Write-Verbose "Setting $($team.Area) as default area on team $($team.Name)"
            $subAreas = !($team.Type -eq 'Produto')
            setDefaultAreaOnTeam -org $org -project $team.Project -name $team.Name -areaPath $team.Area -includeSubAreas $subAreas

            Write-Verbose "Setting $($team.Iteration) [$globalIterationId] as current backlog iterarion on team $($team.Name)"
            setBacklogIterationOnTeam -org $org -project $team.Project -name $team.Name -iterationId $globalIterationId

            if (($team.StartDate) -and ($team.EndDate)) {
                Write-Verbose "Setting list of iterations on team $($team.Name)"
                $listOfIterations = getIterationsBetweenDates -org $org -project $team.Project -baseIteration $team.Iteration -startDate $team.StartDate -endDate $team.EndDate
                if ($listOfIterations) {
                    addIterationsToTeam -org $org -project $team.Project -name $team.Name -iterationList $listOfIterations
                } else {
                    Write-Warning "No Iterations found period $($team.StartDate) and $($team.EndDate)"
                }
            }

            Write-Verbose "Setting Contributors as default group for team $($team.Name)"
            addGroupOnTeamMembership -org $org -project $team.Project -group "Contributors" -teamId $teamID

            $teamAdminList = $team.TeamAdmin -Split ";"
            foreach ($teamAdmin in $teamAdminList) {
                $teamAdmin = $teamAdmin.Trim()
                $userUPN = getUPN -user $teamAdmin -upnFilter $upnFilter
                addUserToOrganization -org $org -userEmail $userUPN
                Write-Verbose "Add $($teamAdmin) to team $($team.Name) and set it as team admin"
                addUserToTeam -org $org -project $team.Project -name $team.Name -user $userUPN
                setTeamAdmin -org $org -projectID $projectId -teamID $teamID -userEmail $userUPN
            }

            if ($team.Type -eq 'Produto') {
                createPipelineFolder -org $org -project $($team.Project) -name $($team.Name)
                grantPermissionOnPipelineFolder -org $org -project $team.Project -folder $team.Name -group $team.Name
                grantPermissionOnReleaseFolder -org $org -project $team.Project -folder $team.Name -group $team.Name
            }

            if ($team.PublishedWiki -eq "Yes") {
                $wikiRepoName = "BCP.$($team.Name).Wiki"
                publishWiki -org $org -project $team.Project -wikiRepoName $wikiRepoName -team $team.Name -teamAdminList $teamAdminList
            }

            Write-Verbose "Create query folder on Shared Queries\$($team.Name) and set permissions only for team"
            $folderId = createQueryFolder -org $org -project $team.Project -name $team.Name
            removeInheritanceOnQueryFolder -org $org -project $team.Project -folderId $folderId -pat $personalToken
            grantPermissionOnQueryFolder -org $org -project $team.Project -folderId $folderId -group $team.Name
            removePermissionOnQueryFolder -org $org -project $team.Project -folderId $folderId -group "Contributors" -pat $personalToken
            #removePermissionOnQueryFolder -org $org -project $team.Project -folderId $folderId -group "Readers"
        } else {
            Write-Host "Project $($team.Project) doesn't exist. Skipping team."
        }
        Write-Host "Checking team $($team.Name)... Done!"
    }

    if ($dummyPipelineId -ne -1) {
        deleteReleasePipeline -org $org -project $dummyPipelineProjectId -pat $personalToken -definitionId $dummyPipelineId
    }
    Write-Host "Teams done!"
}

#
# Manage Users on Teams
#
if (($full.IsPresent) -or ($usersTeams.isPresent)) {
    #
    # Check relationship between users and teams
    #
    Write-Host "Getting relationship between 'Users' and 'Teams' from data..."
    $usersTeamsList = Import-Excel $dscFile -Sheet "UsersTeams"
    foreach ($userTeams in $usersTeamsList) {
        if (!$userTeams.User) { # Empty line
            continue;
        }
        if (!(isRecordToUpdate -toCheck $userTeams)) {
            Write-Verbose "User $($userTeams.User) set to not be updated"
            continue;
        }

        $message = "=========  Start Working on User: $($userTeams.User)  ========="
        Write-Host $("=" * $message.length)
        Write-Host $message
        Write-Host $("=" * $message.length)

        # Check group
        Write-Host "Check if user $($userTeams.User) is assinged to organization..."
        $userUPN = getUPN -user $userTeams.User -upnFilter $upnFilter
        addUserToOrganization -org $org -userEmail $userUPN

        Write-Verbose "Getting teams list to assign user..."
        $userTeamsList = $userTeams.PSObject.Properties 
        foreach ($teamAssigned in $userTeamsList) {
            if ($teamAssigned.Name.ToLower().StartsWith("team")) {
                $teamToAssign = $teamAssigned.Value
                if ($teamToAssign) {
                    Write-Verbose "Assign user $($userTeams.User) to team $teamToAssign..."
                    addUserToTeam -org $org -project $userTeams.Project -name $teamToAssign -user $userUPN
                    Write-Verbose "Assign user $($userTeams.User) to team $teamToAssign... Done!"
                }
            }
        }
    }
}

#
# Manage Repos
#
if (($full.IsPresent) -or ($repos.isPresent)) {
    #
    # Check repos
    #
    Write-Host "Getting 'Repos' from data..."
    $reposList = Import-Excel $dscFile -Sheet "Repos"
    foreach ($repo in $reposList) {
        if (!$repo.Name) { # Empty line
            continue;
        }
        if (!(isRecordToUpdate -toCheck $repo)) {
            Write-Verbose "Repo $($repo.Name) set to not be updated"
            continue;
        }

        $repoName = $repo.Name
        $message = "=========  Start Working on Repo: $($repoName)  ========="
        Write-Host $("=" * $message.length)
        Write-Host $message
        Write-Host $("=" * $message.length)

        if ($repo.Wiki -eq "Yes") {
            $repoName = $repo.Name + ".Wiki"
        }

        $validName = validateRepoName -name $repoName
        if ($validName) {
            if ($repo.Wiki -eq "Yes") {
                $teamAdminList = $repo.TeamOwnerAdmin -Split ";"
                publishWiki -org $org -project $repo.Project -wikiRepoName $repoName -team $repo.TeamOwner -teamAdminList $teamAdminList
            } else {
                Write-Verbose "Check if repo $($repoName) exists on project $($repo.Project)"
                if (!(existsRepo -org $org -project $repo.Project -name $repoName)) {
                    Write-Verbose "Repo $($repoName) don't exists on project $($repo.Project). Creating..."
                    $repoURL = createRepo -org $org -project $repo.Project -name $repoName
                    Write-Verbose "Repo $($repoName) don't exists on project $($repo.Project). Creating... Done!"

                    Write-Verbose "Initialize repo with base structure..."
                    initializeRepoFromZip -repoURL $repoURL -name $repoName
                    Write-Verbose "Initialize repo with base structure... Done!"
                }
                if ($repo.ApplySecurity -eq "Yes") {
                    Write-Verbose "Set team $($repo.TeamOwner) as owner on repo $($repoName)..."
                    setPermissionOnRepoForTeam -org $org -project $repo.Project -repo $repoName -team $repo.TeamOwner -contributor $true
                    Write-Verbose "Set team $($repo.TeamOwner) as owner on repo $($repoName)... Done!"

                    $teamAdminList = $repo.TeamOwnerAdmin -Split ";"
                    foreach ($teamAdmin in $teamAdminList) {
                        $teamAdmin = $teamAdmin.Trim()
                        $userUPN = getUPN -user $teamAdmin -upnFilter $upnFilter
                                            
                        Write-Verbose "Set team $($team.Name) as contributor on repo $($repoName)..."
                        setPermissionOnRepoForUser -org $org -project $repo.Project -repo $repoName -user $userUPN -contributor $true -managePermissions $true
                        Write-Verbose "Set team $($team.Name) as contributor on repo $($repoName)... Done!"
                    }
                    if ($repo.TeamType -eq "Produto") {
                        initRepoPolicies -org $org -project $repo.Project -name $repoName
                    }
                }
            }

            $contributors = $repo.OtherContributors -Split ";"
            if ($contributors) {
            foreach ($contributorTeam in $contributors) {
                $contributorTeam = $contributorTeam.Trim()
                    Write-Verbose "Set team $($contributorTeam) as contributor on repo $($repoName)..."
                    $ret = setPermissionOnRepoForTeam -org $org -project $repo.Project -repo $repoName -team $contributorTeam -contributor $true
                    
                    if (!$ret) {
                        Write-Verbose "No team $($contributorTeam) found. Trying to add user $($contributorTeam) as contributor on repo $($repoName)..."
                        setPermissionOnRepoForUser -org $org -project $repo.Project -repo $repoName -user $userUPN -contributor $true
                        Write-Verbose "Set user $($contributorTeam) as contributor on repo $($repoName)... Done!"
                    } else {
                        Write-Verbose "Set team $($contributorTeam) as contributor on repo $($repoName)... Done!"
                    }
                }
            }

            $readers = $repo.OtherReaders -Split ";"
            if ($readers) {
                foreach ($readerTeam in $readers) {
                    $readerTeam = $readerTeam.Trim()
                    Write-Verbose "Set team $($readerTeam) as reader on repo $($repoName)..."
                    setPermissionOnRepoForTeam -org $org -project $repo.Project -repo $repoName -team $readerTeam -contributor $false
                    if (!$ret) {
                        Write-Verbose "No team $($contributorTeam) found. Trying to add user $($contributorTeam) as reader on repo $($repoName)..."
                        setPermissionOnRepoForUser -org $org -project $repo.Project -repo $repoName -user $userUPN -contributor $false
                        Write-Verbose "Set user $($contributorTeam) as reader on repo $($repoName)... Done!"
                    } else {
                        Write-Verbose "Set team $($contributorTeam) as reader on repo $($repoName)... Done!"
                    }
                }
            }
        } else {
            Write-Host "Invalid repo name: $($repo.Name)"
        }
    } 
}

#
# Create Work Item Fields
#
if ($witfields.isPresent) {

    $CONST_CREATE_FIELD = "C"
    $CONST_UPDATE_FIELD = "U"
    $CONST_DELETE_FIELD = "D"
    $CONST_REQUIRED_FIELD = "Y"
    $CONST_MULTILINE_FIELD = "html"
    $CONST_PICKLIST_FIELD = "picklist"
    $CONST_FIELD_SEPARATOR = ";"

    if (!$processToUpdate) {
        printError -message "processToUpdate argument is mandatory when witFields is set"
        quit
    }

    #
    # Getting process Id. If not find, this code will not proceed
    #
    $processId = existProcess -org $org.trim() -processName $processToUpdate -personalToken $personalToken;

    if (!$processId) {
        printError -message "$processToUpdate doesn't exists on Organization $org"
        quit
    }

    $witRefNames = getWITRefNames -org $org.trim() -processId $processId -personalToken $personalToken

    #
    # Getting Fields data from Excel and perform the creation/update operations
    #
    Write-Host "Getting 'Work Item Fields' from data..."
    $fieldsList = Import-Excel $dscFile -Sheet "WitFields"
    foreach ($field in $fieldsList) {
        if ($field.Name) {
            $message = "=========  Start Working on Field: $($field.Name)  ========="
            Write-Host $("=" * $message.length)
            Write-Host $message
            Write-Host $("=" * $message.length)
    
            switch ($field.Action.ToUpper()) {
                $CONST_CREATE_FIELD  {
                    $fieldValues = $null

                    if ($field.Type.ToLower().StartsWith($CONST_PICKLIST_FIELD)) {
                        $fieldValues = $field.Values -Split "$CONST_FIELD_SEPARATOR\s*"
                    }

                    $fieldObject = createField -org $org.trim() -name ($field.Name).trim() -description ($field.Description).trim() -type ($field.Type).trim() -personalToken $personalToken -listValues $fieldValues
                    $requiredField = $field.Required.ToUpper() -eq $CONST_REQUIRED_FIELD;
                    $defaultValue = $field.Default
                    if ($defaultValue) {
                        $defaultValue = $defaultValue.trim()
                    }

                    $scope = $field.Scope -Split $CONST_FIELD_SEPARATOR
                    foreach ($witName in $scope) {
                        $witName = $witName.trim()
                        $witRefName = $witRefNames[$witName]
                        
                        associateField -org $org.trim() -processId $processId -witName $witRefName -referenceName $fieldObject -required $requiredField -type ($field.Type).trim() -personalToken $personalToken -defaultValue $defaultValue
                        $pageLayout = getPageLayout -org $org.trim() -processId $processId -witRefName $witRefName -personalToken $personalToken;
                        
                        # Get page details
                        $page = $pageLayout[($field.Page)];

                        if (!$page) {
                            createPage -org $org.trim() -processId $processId -witName $witRefName -name ($field.Page) -personalToken $personalToken
                            $pageLayout = getPageLayout -org $org.trim() -processId $processId -witRefName $witRefName -personalToken $personalToken -force $true
                            $page = $pageLayout[($field.Page)]
                        }
                        $pageId = $pageLayout[($field.Page)].id;

                        if ($field.Type.ToLower() -eq $CONST_MULTILINE_FIELD) {
                            if ($page.sections.Contains($field.Group)) {
                                setHtmlInGroup -org $org.trim() -processId $processId -witName $witRefName -pageId $pageId -sectionId $field.Group -referenceName $fieldObject -fieldName ($field.Name).trim() -personalToken $personalToken;
                            } else {
                                printError -message "$($field.Group) doesn't exists on page $($field.Page)"
                                continue;
                            }
                        } else {
                            # Get group details
                            $group = $pageLayout[($field.Page)].groups[($field.Group)]

                            if (!$group) {
                                createGroup -org $org.trim() -processId $processId -witName $witRefName -pageId $pageId -name $field.Group -personalToken $personalToken
                                $pageLayout = getPageLayout -org $org.trim() -processId $processId -witRefName $witRefName -personalToken $personalToken -force $true
                                $group = $pageLayout[($field.Page)].groups[($field.Group)]
                            }

                            $groupId = $pageLayout[($field.Page)].groups[($field.Group)].groupId
                            setFieldInGroup -org $org.trim() -processId $processId -witName $witRefName -groupId $groupId -referenceName $fieldObject -fieldName ($field.Name).trim() -personalToken $personalToken;
                        }
                    }

                    break;
                }
                $CONST_UPDATE_FIELD  {
                    $fieldObject = updateField -org $org.trim() -name ($field.Name).trim() -description ($field.Description).trim() -type ($field.Type).trim() -personalToken $personalToken -fieldObject $fieldObject; break
                }
                $CONST_DELETE_FIELD  {
                    $fieldObject = deleteField -org $org.trim() -name ($field.Name).trim() -personalToken $personalToken; break
                }
                default {"Do Nothing !"; break}
            }
        }
    }
    Write-Host "Fields done!"
}

# Stop Transcript
#
if($log.isPresent) {
    Stop-Transcript
}

#
# Perform a clean exit!
#
Quit
