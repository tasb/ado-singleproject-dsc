function existsRepo{
    param(
        [String]$org,
        [String]$project,
        [String]$name
    )

    Write-Verbose "[existsRepo] Check if repo with name $name exists on project $project..." 
    $repoExists = az repos list --org $org --project $project --query "[?name == '$name'].id | [0]" --output json | ConvertFrom-Json

    return $repoExists
}

function createRepo {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )


    Write-Verbose "[createRepo] Creating repo $name on project $project..." 
    $newRepo = az repos create --name $name --org $org --project $project --output json | ConvertFrom-Json
    Write-Verbose "[createRepo] Created repo $name on project $project successfully!"

    return $newRepo.remoteUrl
}

function getDefaultBranch {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )


    Write-Verbose "[getDefaultBranch] Getting default branch from repo $name on project $project..." 
    $branch = az repos show --repository $name --org $org --project $project --query "defaultBranch"
    Write-Verbose "[getDefaultBranch] Getting default branch from repo $name on project $project...Done!"

    return $branch
}

function validateRepoName {
    param (
        [Parameter(Mandatory=$true)][string]$name
    )
<#
    $check = $name.StartsWith("BCP.")

    if (!$check) {
        Write-Host "[validateRepoName] Repo name don't start with BCP."
        return $false
    }

    $check = $name -split '\.'

    if (!($check.count -ge 3)) {
        Write-Host "[validateRepoName] Repo name must have following format: BCP.<APPLICATION_TITLE>.<MODULE>"
        return $false
    }
#>
    return $true
}

function initializeRepoFromZip {
    param (
        [Parameter(Mandatory=$true)][string]$repoURL,
        [Parameter(Mandatory=$true)][string]$name
    )

    git clone $repoURL
    Set-Location $name
    New-Item ./.pipelines/.gitkeep -ItemType File -Force
    git add -A
    git commit -m "Repo Creation"
    git push
    git checkout -b "devops/pipelines"
    git push origin "devops/pipelines"
    git checkout master
    Expand-Archive -LiteralPath ../Repos/git-init-repo.zip -DestinationPath "."
    git add -A
    git commit -m "Initial commit"
    git push
    Set-Location ..
    Remove-Item -Recurse -Force $name
    #Remove-Item –path "./$($repo.Name)" –recurse
}

function initializeWikiRepo {
    param (
        [Parameter(Mandatory=$true)][string]$repoURL,
        [Parameter(Mandatory=$true)][string]$name
    )

    git clone $repoURL
    Copy-Item ./Wikis/WikiHomepage.md -Destination "./$name"
    Set-Location $name
    #Write-Output " " > .\.gitkeep
    git add -A
    git commit -m "Initial commit"
    git push
    Set-Location ..
    Remove-Item -Recurse -Force $name
    #Remove-Item –path "./$($repo.Name)" –recurse
}

function initRepoPolicies{
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )

    $repoId = existsRepo -org $org -project $project -name $name
    $defaultBranch = getDefaultBranch -org $org -project $project -name $name

    $dummy = az repos policy approver-count create --allow-downvotes false --blocking true --branch $defaultBranch --creator-vote-counts false --enabled true --reset-on-source-push true --minimum-approver-count 2 --repository-id $repoId  --org $org --project $project

    $dummy = az repos policy work-item-linking create --blocking true --branch $defaultBranch --enabled true --repository-id $repoId  --org $org --project $project

    $dummy = az repos policy comment-required create --blocking true --branch $defaultBranch --enabled true --repository-id $repoId  --org $org --project $project

    $dummy = az repos policy merge-strategy create --blocking true --branch $defaultBranch --enabled true --allow-no-fast-forward true --allow-squash true --allow-rebase false --allow-rebase-merge false --repository-id $repoId  --org $org --project $project
}