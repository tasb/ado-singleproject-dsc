
function existsQueryFolder {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )

    Write-Verbose "[existsQueryFolder] Check if query folder already exists for team $name"
    $queryFolderId = az devops invoke --only-show-errors --org $org --area wit --resource queries --http-method GET --route-parameters project=$project --query-parameters query="$name" --output json --query "id"  2> error.out | ConvertFrom-Json
    Remove-Item error.out

    return $queryFolderId
}


function createQueryFolder {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )

    $folderId = existsQueryFolder -org $org -project $project -name "Shared Queries/$name"

    if (! ($folderId)) {
        Write-Verbose "[createQueryFolder] Query folder for team $name do not exist! Creating folder..."
        $content = '{"name":"' + $name + '","isFolder":true}'
        $location = Get-Location

        [IO.File]::WriteAllLines($location.path + "\query-body.tmp", $content)
        $folder = az devops invoke --only-show-errors --org $org --area wit --resource queries --http-method POST --route-parameters project=$project --query-parameters query="Shared Queries" --in-file query-body.tmp --output json | ConvertFrom-Json
        Remove-Item "query-body.tmp"
        Write-Verbose "[createQueryFolder] Query folder for team $name do not exist! Creating folder... Done!"
        $folderId = $folder.Id
    }

    return $folderId
}