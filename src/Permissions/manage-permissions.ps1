. (Join-Path $PSScriptRoot ..\Groups\manage-groups.ps1)
. (Join-Path $PSScriptRoot ..\Repos\manage-repos.ps1)
. (Join-Path $PSScriptRoot ..\Project\manage-project.ps1)
. (Join-Path $PSScriptRoot ..\Boards\manage-queries.ps1)


function getNamespaceIdByScope {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$scope
    )
    return az devops security permission namespace list --only-show-errors --org $org --query "[?dataspaceCategory=='$scope'].namespaceId | [0]" | ConvertFrom-Json
}

function getNamespaceIdByName {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$name
    )
    return az devops security permission namespace list --only-show-errors --org $org --query "[?name=='$name'].namespaceId | [0]" | ConvertFrom-Json
}

function resetPermissionOnReposForGroup {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$projectId,
        [Parameter(Mandatory=$true)][string]$groupName
    )

    Write-Verbose "[resetPermissionOnReposForGroup] Reset repos access for group $groupName..."

    #$namespaceId = "2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87"
    $namespaceId = getNamespaceIdByScope -org $org -scope 'Git'
    $token = "repoV2/$projectId"
    $groupDescriptor = getSecurityGroupDescriptor -org $org -project $project -name $groupName
    # 65535 all permissions bit
    $ret = az devops security permission update --only-show-errors --org $org --deny-bit 65535 --id $namespaceId --token $token --subject $groupDescriptor

    Write-Verbose "[resetPermissionOnReposForGroup] Reset repos access for group $groupName... Done!"
}

function removeGroupFromRepo {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$projectId,
        [Parameter(Mandatory=$true)][string]$groupName,
        [Parameter(Mandatory=$true)][string]$pat
    )

    $namespaceId = getNamespaceIdByScope -org $org -scope 'Git'
    $token = "repoV2/$projectId"
    $groupDescriptor = getSecurityGroupIdentity -org $org -project $project -name $groupName -pat $pat
    #$groupDescriptor = $groupDescriptor -replace "vssgp."
    #$groupDescriptor = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($groupDescriptor))
    #$groupDescriptor = "Microsoft.TeamFoundation.Identity;$($groupDescriptor)"
    
    $header = @{}
    $header.Add("content-type", "application/json")

    Write-Verbose "[removeGroupFromRepo] Initialize authentication context"
    $authToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
    $header.Add("authorization", "Basic $authToken")
    
    Write-Verbose "[removeGroupFromRepo] Initialize request Url"
    #GET https://dev.azure.com/{organization}/_apis/wit/fields/{fieldNameOrRefName}?api-version=6.0-preview.2
    $requestUrl = "$($org)/_apis/AccessControlEntries/$($namespaceId)?api-version=6.0&token=$($token)&descriptors=$($groupDescriptor)"
    Write-Verbose "[removeGroupFromRepo] Request Url: $requestUrl"

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Delete -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Write-Verbose "[removeGroupFromRepo] Error: $RestError"
        Throw $RestError
    }
    return $RestResponse
    #$ret = az devops invoke --org $org --area Security --resource AccessControlEntries --http-method DELETE --route-parameters $namespaceId --query-parameters token="$token" descriptors="$groupDescriptor"
}

function resetPermissionOnBaseAreaForGroup {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$areaId,
        [Parameter(Mandatory=$true)][string]$groupName
    )

    Write-Verbose "[resetPermissionOnReposForGroup] Reset base area access for group $groupName..."

    #$namespaceId = "83e28ad4-2d72-4ceb-97b0-c7726d5502c3"
    $namespaceId = getNamespaceIdByScope -org $org -scope 'Integration'
    $token = "vstfs:///Classification/Node/$areaId"
    $groupDescriptor = getSecurityGroupDescriptor -org $org -project $project -name $groupName
    # 65535 all permissions bit
    $ret = az devops security permission update --only-show-errors --org $org --deny-bit 255 --id $namespaceId --token $token --subject $groupDescriptor

    Write-Verbose "[resetPermissionOnReposForGroup] Reset repos access for group $groupName... Done!"
}

function setPermissionOnAreaForTeam {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$area,
        [Parameter(Mandatory=$true)][string]$team
    )

    Write-Verbose "[setPermissionOnAreaForTeam] Set permissions on area $areaId for team $team... start."

    #$namespaceId = "83e28ad4-2d72-4ceb-97b0-c7726d5502c3"
    $namespaceId = getNamespaceIdByScope -org $org -scope 'Integration'
    #$token = "vstfs:///Classification/Node/$areaId"
    $areasIds = getFullPathIds -org $org -project $project -area $area
    $token = ""
    foreach ($areaId in $areasIds) {
        $areaId = $areaId -replace '"'
        $token = "vstfs:///Classification/Node/" + $areaId + ":" + $token 
    }
    $token = $token.Substring(0,$token.Length-1)
    $groupDescriptor = getSecurityGroupDescriptor -org $org -project $project -name $team

    Write-Verbose "Token: $token | Namespace: $namespaceId"

    if ($groupDescriptor) {
        
        $bitMask = 255 #all permissions bit
        
        $ret = az devops security permission update --only-show-errors --org $org --allow-bit $bitMask --id $namespaceId --token $token --subject $groupDescriptor

        #Write-Host "Return: $ret"
        Write-Verbose "[setPermissionOnAreaForTeam] Set permission to $team on $areaId. Done!"
    } else {
        Write-Verbose "Team $team don't exists on project $project. Not added to area $areaId"
    }

    Write-Verbose "[setPermissionOnAreaForTeam] Set permissions on area $areaId for team $team... end."
}

function setPermissionOnRepoForUser {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$user,
        [bool]$contributor=$false,
        [bool]$managePermissions=$false,
        [bool]$admin=$false
    )

    Write-Verbose "[setPermissionOnRepoForUser] Set permission to $user on $repo (Contributor? $contributor)"

    #$namespaceId = "83e28ad4-2d72-4ceb-97b0-c7726d5502c3"
    $namespaceId = getNamespaceIdByScope -org $org -scope 'Git'
    $repoId = existsRepo -org $org -project $project -name $repo
    $projectId = existsProject -org $org -projectName $project
    $token = "repoV2/$projectId/$repoId"

    $bitMask = 16386 #reader permissions
    if ($contributor) {
        $bitMask = 16502
        if ($managePermissions) {
            $bitMask = $bitMask + 8192
        }
        if ($admin) {
            $bitmask = $bitMask + 47240
        }
    }

    # 65535 all permissions bit
    $ret = az devops security permission update --only-show-errors --org $org --allow-bit $bitMask --id $namespaceId --token $token --subject $user

    Write-Verbose "[setPermissionOnRepoForUser] Set permission to $user on $repo (Contributor? $contributor). Done!"
}

function setPermissionOnRepoForTeam {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$team,
        [bool]$contributor=$false,
        [bool]$managePermissions=$false
    )

    Write-Verbose "[setPermissionOnRepoForTeam] Set permission to $team on $repo (Contributor? $contributor)"

    #$namespaceId = "83e28ad4-2d72-4ceb-97b0-c7726d5502c3"
    $namespaceId = getNamespaceIdByScope -org $org -scope 'Git'
    $repoId = existsRepo -org $org -project $project -name $repo
    $projectId = existsProject -org $org -projectName $project
    $token = "repoV2/$projectId/$repoId"
    $groupDescriptor = getSecurityGroupDescriptor -org $org -project $project -name $team

    if ($groupDescriptor) {
        $bitMask = 16386 #reader permissions
        if ($contributor) {
            $bitMask = 16502
            if ($managePermissions) {
                $bitMask = $bitMask + 8192
            }
        }

        # 65535 all permissions bit
        $ret = az devops security permission update --only-show-errors --org $org --allow-bit $bitMask --id $namespaceId --token $token --subject $groupDescriptor

        Write-Verbose "[setPermissionOnRepoForTeam] Set permission to $team on $repo (Contributor? $contributor). Done!"
    } else {
        Write-Host "Team $team don't exists on project $project. Not added to repo $repo"
    }
}

function removeInheritanceOnQueryFolder {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$folderId,
        [Parameter(Mandatory=$true)][string]$pat
    )

    $header = @{}

    $header.Add("content-type", "application/json")

    Write-Verbose "[removeInheritanceOnQueryFolder] Initialize authentication context"
    $authToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
    $header.Add("authorization", "Basic $authToken")
    
    Write-Verbose "[removeInheritanceOnQueryFolder] Initialize request Url"
    #POST https://dev.azure.com/tiberna/_apis/Contribution/HierarchyQuery?api-version=5.1-preview
    $requestUrl = "$($org)/_apis/Contribution/HierarchyQuery?api-version=6.1-preview"
    Write-Verbose "[removeInheritanceOnQueryFolder] Request Url: $requestUrl"

    $body = Get-Content ./Permissions/query-inheritance.json
    $body = $body -replace "%%%FOLDER_ID%%%", $folderId
    $body = $body -replace "%%%PROJECT%%%", $project
    $body = $body -replace "%%%ORG%%%", $org

    Write-Verbose "[removeInheritanceOnQueryFolder] Body: $body"

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
} 


function removePermissionOnSharedQueriesFolder {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$group,
        [Parameter(Mandatory=$true)][string]$pat
    )

    Write-Verbose "[removePermissionOnSharedQueriesFolder] Remove permission to $group on query folder"

    $namespaceID = getNamespaceIdByName -org $org -name "WorkItemQueryFolders"
    $sharedFolderId = existsQueryFolder -org $org -project $project -name "Shared Queries"
    $projectId = existsProject -org $org -projectName $project
    $token = "$/$projectId/$sharedFolderId"
    $groupDescriptor = getSecurityGroupIdentity -org $org -project $project -name $group -pat $pat

    $header = @{}

    $header.Add("content-type", "application/json")

    Write-Verbose "[removePermissionOnSharedQueriesFolder] Initialize authentication context"
    $authToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
    $header.Add("authorization", "Basic $authToken")
    
    Write-Verbose "[removePermissionOnSharedQueriesFolder] Initialize request Url"
    #POST https://dev.azure.com/tiberna/_apis/Permissions/71356614-aad7-4757-8f2c-0fb3bff6f680/1?descriptor=$groupDescriptor&token=$token

    $requestUrl = "$($org)/_apis/Permissions/$($namespaceID)/1?api-version=5.1&descriptor=$($groupDescriptor)&token=$($token)"
    Write-Verbose "[removePermissionOnSharedQueriesFolder] Request Url: $requestUrl"

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Delete -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Write-Verbose "[removePermissionOnSharedQueriesFolder] Error: $RestError"
        Throw $RestError
    }
}

function removePermissionOnQueryFolder {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$folderId,
        [Parameter(Mandatory=$true)][string]$group,
        [Parameter(Mandatory=$true)][string]$pat
    )

    Write-Verbose "[removePermissionOnQueryFolder] Remove permission to $group on query folder"

    $namespaceID = getNamespaceIdByName -org $org -name "WorkItemQueryFolders"
    $sharedFolderId = existsQueryFolder -org $org -project $project -name "Shared Queries"
    $projectId = existsProject -org $org -projectName $project
    $token = "$/$projectId/$sharedFolderId/$folderId"
    $groupDescriptor = getSecurityGroupIdentity -org $org -project $project -name $group -pat $pat

    $header = @{}

    $header.Add("content-type", "application/json")

    Write-Verbose "[removePermissionOnQueryFolder] Initialize authentication context"
    $authToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
    $header.Add("authorization", "Basic $authToken")
    
    Write-Verbose "[removePermissionOnQueryFolder] Initialize request Url"
    #POST https://dev.azure.com/tiberna/_apis/Permissions/71356614-aad7-4757-8f2c-0fb3bff6f680/1?descriptor=$groupDescriptor&token=$token

    $requestUrl = "$($org)/_apis/Permissions/$($namespaceID)/1?api-version=5.1&descriptor=$($groupDescriptor)&token=$($token)"
    Write-Verbose "[removePermissionOnQueryFolder] Request Url: $requestUrl"

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Delete -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Write-Verbose "[removePermissionOnQueryFolder] Error: $RestError"
        Throw $RestError
    }
}

<#
function removePermissionOnQueryFolder {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$folderId,
        [Parameter(Mandatory=$true)][string]$group
    )

    Write-Verbose "[removePermissionOnQueryFolder] Remove permission to $group on query folder"

    $namespaceID = getNamespaceIdByName -org $org -name "WorkItemQueryFolders"
    $projectId = existsProject -org $org -projectName $project
    $sharedFolderId = existsQueryFolder -org $org -project $project -name "Shared Queries"
    $token = "$/$projectId/$sharedFolderId/$folderId"
    $groupDescriptor = getSecurityGroupDescriptor -org $org -project $project -name $group

    $ret = az devops security permission update --only-show-errors --org $org --deny-bit 1 --id $namespaceId --token $token --subject $groupDescriptor

    Write-Verbose "[removePermissionOnQueryFolder] Remove permission to $group on query folder. Done!"
}
#>

function grantPermissionOnQueryFolder {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$folderId,
        [Parameter(Mandatory=$true)][string]$group
    )

    Write-Verbose "[grantPermissionOnQueryFolder] Grant permission to $group on query folder"

    $namespaceID = getNamespaceIdByName -org $org -name "WorkItemQueryFolders"
    $projectId = existsProject -org $org -projectName $project
    $sharedFolderId = existsQueryFolder -org $org -project $project -name "Shared Queries"
    $token = "$/$projectId/$sharedFolderId/$folderId"
    $groupDescriptor = getSecurityGroupDescriptor -org $org -project $project -name $group

    $ret = az devops security permission update --only-show-errors --allow-bit 3 --id $namespaceId --token $token --subject $groupDescriptor

    Write-Verbose "[grantPermissionOnQueryFolder] Grant permission to $group on query folder. Done!"
}

function grantPermissionOnPipelineFolder {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$folder,
        [Parameter(Mandatory=$true)][string]$group
    )

    Write-Verbose "[grantPermissionOnPipelineFolder] Grant permission to $group on pipeline folder $folder"

    $namespaceID = getNamespaceIdByName -org $org -name 'Build'
    $projectId = existsProject -org $org -projectName $project
    $token = "$projectId/$folder"
    $groupDescriptor = getSecurityGroupDescriptor -org $org -project $project -name $group

    $ret = az devops security permission update --only-show-errors --allow-bit 1665 --id $namespaceId --token $token --subject $groupDescriptor

    Write-Verbose "[grantPermissionOnPipelineFolder] Grant permission to $group on pipeline folder $folder. Done!"
}

function removeGroupFromBuildPipelines {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$projectId,
        [Parameter(Mandatory=$true)][string]$groupName,
        [Parameter(Mandatory=$true)][string]$pat
    )

    $namespaceId = getNamespaceIdByName -org $org -name 'Build'
    $token = "$projectId"
    $groupDescriptor = getSecurityGroupIdentity -org $org -project $project -name $groupName -pat $pat
    
    $header = @{}

    $header.Add("content-type", "application/json")

    Write-Verbose "[removeGroupFromBuildPipelines] Initialize authentication context"
    $authToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
    $header.Add("authorization", "Basic $authToken")
    
    Write-Verbose "[removeGroupFromBuildPipelines] Initialize request Url"
    #GET https://dev.azure.com/{organization}/_apis/wit/fields/{fieldNameOrRefName}?api-version=6.0-preview.2
    $requestUrl = "$($org)/_apis/AccessControlEntries/$($namespaceId)?api-version=6.0&token=$($token)&descriptors=$($groupDescriptor)"
    Write-Verbose "[removeGroupFromBuildPipelines] Request Url: $requestUrl"

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Delete -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Write-Verbose "[removeGroupFromBuildPipelines] Error: $RestError"
        Throw $RestError
    }
    return $RestResponse
    
    #$ret = az devops invoke --org $org --area Security --resource AccessControlEntries --http-method DELETE --route-parameters $namespaceId --query-parameters token="$token" descriptors="$groupDescriptor"
}

function grantPermissionOnReleaseFolder {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$folder,
        [Parameter(Mandatory=$true)][string]$group
    )

    Write-Verbose "[grantPermissionOnReleaseFolder] Grant permission to $group on pipeline folder $folder"

    $namespaceID = "c788c23e-1b46-4162-8f5e-d7585343b5de" #getNamespaceIdByName -org $org -name 'Build'
    $projectId = existsProject -org $org -projectName $project
    $token = "$projectId/$folder"
    $groupDescriptor = getSecurityGroupDescriptor -org $org -project $project -name $group

    $ret = az devops security permission update --only-show-errors --allow-bit 2145 --id $namespaceId --token $token --subject $groupDescriptor

    Write-Verbose "[grantPermissionOnReleaseFolder] Grant permission to $group on pipeline folder $folder. Done!"
}

function removeGroupFromReleasePipelines {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$projectId,
        [Parameter(Mandatory=$true)][string]$groupName,
        [Parameter(Mandatory=$true)][string]$pat
    )

    $namespaceId = "c788c23e-1b46-4162-8f5e-d7585343b5de" #getNamespaceIdByName -org $org -name 'Build'
    $token = "$projectId"
    $groupDescriptor = getSecurityGroupIdentity -org $org -project $project -name $groupName -pat $pat
    
    $header = @{}

    $header.Add("content-type", "application/json")

    Write-Verbose "[removeGroupFromReleasePipelines] Initialize authentication context"
    $authToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
    $header.Add("authorization", "Basic $authToken")
    
    Write-Verbose "[removeGroupFromReleasePipelines] Initialize request Url"
    #GET https://dev.azure.com/{organization}/_apis/wit/fields/{fieldNameOrRefName}?api-version=6.0-preview.2
    $requestUrl = "$($org)/_apis/AccessControlEntries/$($namespaceId)?token=$($token)&descriptors=$($groupDescriptor)"
    Write-Verbose "[removeGroupFromReleasePipelines] Request Url: $requestUrl"

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Delete -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Write-Verbose "[removeGroupFromReleasePipelines] Error: $RestError"
        Throw $RestError
    }
    return $RestResponse
    
    #$ret = az devops invoke --org $org --area Security --resource AccessControlEntries --http-method DELETE --route-parameters $namespaceId --query-parameters token="$token" descriptors="$groupDescriptor"
}
