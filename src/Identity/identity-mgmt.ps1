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
