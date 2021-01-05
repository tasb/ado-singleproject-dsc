function publishCodeWiki {
    param(
        [String]$org,
        [String]$project,
        [String]$repo,
        [String]$name
    )

    $createCodeWiki = az devops wiki create --only-show-errors --name $name --type codewiki --version "master" --mapped-path "/" --repository $repo --org $org --project $project --output json | ConvertFrom-Json
    Write-Verbose "New code wiki published with ID : $($createCodeWiki.id)"
}