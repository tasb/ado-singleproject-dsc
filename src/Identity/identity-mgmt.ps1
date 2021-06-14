$___identityCache___ = @{}

function getUPN {
    param (
        [Parameter(Mandatory=$true)][string]$user,
        [Parameter(Mandatory=$true)][string]$upnFilter
    )

    if ("NULL" -eq $upnFilter) {
        return $user
    }

    $userUPN = $___identityCache___[$user]

    if ($userUPN) {
        Write-Verbose "[getUPN] UPN from IdentityCache [$user] --> $userUPN"
    } else {
        Write-Verbose "[getUPN] Getting User UPN from AAD for User: $user..."
        $toFilter = $user.substring(1)
        $AADUser = az ad user list --filter "$upnFilter eq '$toFilter'" --query "[0]" | ConvertFrom-Json
        if (!$AADUser){ # employeeId is null lets try 'mailNickname'
            $AADUser = az ad user list --filter "mailNickname eq '$user'" --query "[0]" | ConvertFrom-Json
        }
        #$userUPN = az ad user list --filter "$upnFilter eq '$employeeId'" --query "[0] | userPrincipalName" | ConvertFrom-Json
        $userUPN = $AADUser.userPrincipalName
        $___identityCache___[$user] = $userUPN
        Write-Verbose "[getUPN] Getting User UPN from AAD for User: $user, UPN: $userUPN, Name: $($AADUser.displayName) ...Done"
    }
    return $userUPN
}

function getGroupIdentity {
    param (
        [Parameter(Mandatory = $true)][string]$org,
        [Parameter(Mandatory = $true)][string]$groupName,
        [Parameter(Mandatory = $true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Searching groups with name '$groupName' ..."

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = @{}
    $header.Add("content-type", "application/json")
    Write-Verbose "[$($funcName)] Initialize authentication context"
    $token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($personalToken)"))
    $header.Add("authorization", "Basic $token")
        
    Write-Verbose "[$($funcName)] Initialize request Url"
    #GET https://vssps.dev.azure.com/{organization}/_apis/identities?api-version=6.0
    $requestUrl = "https://vssps.dev.azure.com/$($org)/_apis/identities?api-version=6.0&searchFilter=LocalGroupName&filterValue=$($groupName)"
        
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Get -Headers $header -Body $JSONBody -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError) {
        Throw $RestError
    }
    Write-Host "[$($funcName)] Searched groups with name '$groupName'."
    $group = $RestResponse.value[0]
    if(!$group){
        throw "Group '$groupName' not found!"
    }
    return $group
}