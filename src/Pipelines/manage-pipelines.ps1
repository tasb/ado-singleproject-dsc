$___pipelines___ = @{}

function createPipelineFolder {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )

    $folderExists = az pipelines folder list --path "\$name" --project $project --org $org | ConvertFrom-Json

    if (!$folderExists) {
    Write-Verbose "[createPipelineFolder] Creating pipeline folder with name $name..." 
    $folder = az pipelines folder create --path "\$name" --project $project --org $org
    Write-Verbose "[createPipelineFolder] Creating pipeline folder with name $name... Done!" 

    $content = '{"path":"' + "\\$name" +'"}'
    $location = Get-Location
    
    [IO.File]::WriteAllLines($location.path + "\folder-body.tmp", $content)
    $folder = az devops invoke --only-show-errors --org $org --area release --resource folders --http-method POST --route-parameters project=$project --query-parameters path="\\$name" --api-version "5.1-preview" --in-file folder-body.tmp --output json | ConvertFrom-Json
    Remove-Item "folder-body.tmp"
    }
}
function createReleasePipeline {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$pat
    )

    $header = @{}
    $header.Add("content-type", "application/json")

    Write-Verbose "[createReleasePipeline] Initialize authentication context"
    $authToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
    $header.Add("authorization", "Basic $authToken")
    
    Write-Verbose "[createReleasePipeline] Initialize request Url"
    #POST https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/definitions?api-version=6.1-preview.4
    $baseUrl = $org -replace "dev", "vsrm.dev"
    $requestUrl = "$($baseUrl)/$($project)/_apis/release/definitions?api-version=5.1"
    Write-Verbose "[createReleasePipeline] Request Url: $requestUrl"

    $body = Get-Content ./Pipelines/release-definition.json

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Post -Headers $header -Body $body -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Write-Verbose "[createReleasePipeline] Error: $RestError"
        Throw $RestError
    }
    return $RestResponse.id
    
    #$ret = az devops invoke --org $org --area Security --resource AccessControlEntries --http-method DELETE --route-parameters $namespaceId --query-parameters token="$token" descriptors="$groupDescriptor"
}

function deleteReleasePipeline {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$pat,
        [Parameter(Mandatory=$true)][string]$definitionId
    )

    $header = @{}
    $header.Add("content-type", "application/json")

    Write-Verbose "[deleteReleasePipeline] Initialize authentication context"
    $authToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
    $header.Add("authorization", "Basic $authToken")
    
    Write-Verbose "[deleteReleasePipeline] Initialize request Url"
    # DELETE https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/definitions/{definitionId}?api-version=6.1-preview.4
    $baseUrl = $org -replace "dev", "vsrm.dev"
    $requestUrl = "$($baseUrl)/$($project)/_apis/release/definitions/$($definitionId)?api-version=5.1"
    Write-Verbose "[deleteReleasePipeline] Request Url: $requestUrl"

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Delete -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Write-Verbose "[createReleasePipeline] Error: $RestError"
        Throw $RestError
    }
}

function countReleasePipelines {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project
    )
    $count = $___pipelines___[$project]
    if (!$count) {
        Write-Verbose "[countReleasePipelines] Getting release pipelines for project $($project)"
        $res = az pipelines release definition list --org $org --project $project --query "[].id" | ConvertFrom-JSON
        $count = $res.length

        if ($count -ne 0) {
            $___pipelines___[$project] = $count    
        }
        Write-Verbose "[countReleasePipelines] Getting release pipelines for project $($project): $($count)"
    }
    return $count
}

