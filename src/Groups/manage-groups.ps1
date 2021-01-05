<#
    Hashmap working as cache to speed up groups fetching
#>
$___groupsCache___ = @{}
$___groupsIdsCache___ = @{}

<#
    .SYNOPSIS
        Get group/team descriptor
		
    .DESCRIPTION
        Get descriptor for a given display name of a security group/team
 
    .PARAMETER org
        Azure DevOps organization where the search will be performed. Parameter must be on URL format.

	.PARAMETER project
        Project name where the aearch will be performed.

	.PARAMETER name
		Groups display name

    .INPUTS
        None
 
    .OUTPUTS
        System.String. Group/team description
#>
function getSecurityGroupDescriptor {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )

    $groupDescriptor = $___groupsCache___[$name]
    if ($groupDescriptor) {
        Write-Verbose "[getSecurityGroupDescriptor] Descriptor for group ($name) on cache"
    } else {
        Write-Verbose "[getSecurityGroupDescriptor] Getting descriptor for group ($name) from server"
        $groupDescriptor = az devops security group list --only-show-errors --org $org --project $project --output json --query "graphGroups[?displayName=='$name'].descriptor" | ConvertFrom-Json
        $___groupsCache___[$name] = $groupDescriptor
        Write-Verbose "[getSecurityGroupDescriptor] Setting descriptior from group $name on groups cache"
    }

    Write-Verbose "[getSecurityGroupDescriptor] Descriptor for group ($name)-> $groupDescriptor"

    return $groupDescriptor
}


function getSecurityGroupIdentity {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$true)][string]$pat
    )

    $groupIdentity = $___groupsIdsCache___[$name]
    if ($groupIdentity) {
        Write-Verbose "[getSecurityGroupIdentity] Identity for group ($name) on cache"
    } else {
        Write-Verbose "[getSecurityGroupIdentity] Getting descriptor for group ($name) from server"
        $identityId = az devops security group list --only-show-errors --org $org --project $project --output json --query "graphGroups[?displayName=='$name'].originId" | ConvertFrom-Json
        $header = @{}
        $header.Add("content-type", "application/json")

        Write-Verbose "[getSecurityGroupIdentity] Initialize authentication context"
        $authToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
        $header.Add("authorization", "Basic $authToken")
        
        Write-Verbose "[getSecurityGroupIdentity] Initialize request Url"
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/ims/identities/read%20identities?view=azure-devops-rest-6.1#by-identitydescriptors
        # https://vssps.dev.azure.com/<ORG>/_apis/identities?api-version=5.1&identityIds=<GROUP_ID>
        $baseUrl = $org -replace "dev", "vssps.dev"
        $requestUrl = "$($baseUrl)/_apis/identities?api-version=5.1&identityIds=$($identityId)"
        Write-Verbose "[getSecurityGroupIdentity] Request Url: $requestUrl"

        $oldEAP = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Get -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
        $ErrorActionPreference = $oldEAP
        if ($RestError)
        {
            Write-Verbose "[getSecurityGroupIdentity] Error: $RestError"
            Throw $RestError
        }
        $groupIdentity = $RestResponse.value[0].descriptor
        $___groupsIdsCache___[$name] = $groupIdentity
        Write-Verbose "[getSecurityGroupIdentity] Setting identity from group $name on groups cache"
    }

    Write-Verbose "[getSecurityGroupDescriptor] Descriptor for group ($name)-> $groupIdentity"

    return $groupIdentity
}


<#
    .SYNOPSIS
        Add team to a group membership
		
    .DESCRIPTION
        Add a team as member of a group to inherit permissions
 
    .PARAMETER org
        Azure DevOps organization where the search will be performed. Parameter must be on URL format.

	.PARAMETER project
        Project name where the aearch will be performed.

	.PARAMETER group
		Group display name

	.PARAMETER teamId
		Team identifier

    .INPUTS
        None
 
    .OUTPUTS
        None
#>
function addGroupOnTeamMembership {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$group,
        [Parameter(Mandatory=$true)][string]$teamId
    )
    
    Write-Verbose "[addGroupOnTeamMembership] Get descriptor for group $group"
    $myGroupDescriptor = getSecurityGroupDescriptor -org $org -project $project -name $group
    Write-Verbose "[addGroupOnTeamMembership] Get descriptor for group $group -> $myGroupDescriptor"

    Write-Verbose "[addGroupOnTeamMembership] Add team on group membership..."
    $ret = az devops security group membership add --only-show-errors --member-id $teamId --group-id $myGroupDescriptor --org $org --output json | ConvertFrom-Json
    Write-Verbose "[addGroupOnTeamMembership] Add team on group membership... Done!"
}


<#
    .SYNOPSIS
        Add team to a group membership
		
    .DESCRIPTION
        Add a team as member of a group to inherit permissions
 
    .PARAMETER org
        Azure DevOps organization where the search will be performed. Parameter must be on URL format.

	.PARAMETER project
        Project name where the aearch will be performed.

	.PARAMETER group
		Group display name where group will be added to membership

	.PARAMETER groupMemberOf
		Group to be added display name 

    .INPUTS
        None
 
    .OUTPUTS
        None
#>
function addGroupOnGroupMembership {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$group,
        [Parameter(Mandatory=$true)][string]$groupMemberOf
    )
    
    Write-Verbose "[addGroupOnTeamMembership] Get descriptor for group $group"
    $groupDescToAdd = getSecurityGroupDescriptor -org $org -project $project -name $group
    Write-Verbose "[addGroupOnTeamMembership] Get descriptor for group $group -> $groupDescToAdd"

    Write-Verbose "[addGroupOnTeamMembership] Get descriptor for group $groupMemberOf"
    $groupDescToBeAdd = getSecurityGroupDescriptor -org $org -project $project -name $groupMemberOf
    Write-Verbose "[addGroupOnTeamMembership] Get descriptor for group $groupMemberOf -> $groupDescToBeAdd"

    Write-Verbose "[addGroupOnTeamMembership] Add team on group membership..."
    $ret = az devops security group membership add --only-show-errors --member-id $groupDescToBeAdd --group-id $groupDescToAdd --org $org --output json | ConvertFrom-Json
    Write-Verbose "[addGroupOnTeamMembership] Add team on group membership... Done!"
}

function existsGroup {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name
    )

    Write-Verbose "[existsGroup] Get group ($name) identifier"
    $_groupId = getSecurityGroupDescriptor -org $org -project $project -name $name
    Write-Verbose "[existsGroup] Get group ($name) identifier -> $_groupId"

    return $_groupId
}

function createGroup {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$project,
        [Parameter(Mandatory=$true)][string]$name,
        [string]$groupMemberOf
    )

    if (![string]::IsNullOrEmpty($groupMemberOf)) {
        $groupDescToAddMemebership = getSecurityGroupDescriptor -org $org -project $project -name $groupMemberOf
    }

    Write-Verbose "[createGroup] Creating group with name $($name) . . . " 
    if($groupDescToAddMemebership) {
        $_newGroup = az devops security group create --only-show-errors --name $name.Trim() --org $org --project $project --groups $groupDescToAddMemebership  --output json | ConvertFrom-Json
    } else {
        $_newGroup = az devops security group create --only-show-errors --name $name.Trim() --org $org --project $project  --output json | ConvertFrom-Json
    }
    Write-Verbose "[createGroup] Created project with name $($_newGroup.principalName)"

    return $_newGroup
}

function addUserToGroup {
    param(
        [Parameter(Mandatory=$true)][String]$org,
        [Parameter(Mandatory=$true)][String]$project,
        [Parameter(Mandatory=$true)][String]$name,
        [Parameter(Mandatory=$true)][String]$user
    )

    Write-Verbose "[addUserToGroup] Get descriptor for group $name"
    $myDescriptor = getSecurityGroupDescriptor -org $org -project $project -name $name
    Write-Verbose "[addUserToGroup] Get descriptor for group $name -> $myDescriptor"
    
    Write-Verbose "[addUserToGroup] Add user $user to group $name ($myDescriptor)..."
    $addMember = az devops security group membership add --only-show-errors --group-id $myDescriptor --member-id $user --org $org --output json | ConvertFrom-Json 
    Write-Verbose "[addUserToGroup] Add user $user to group $name... Done!"
}



 

