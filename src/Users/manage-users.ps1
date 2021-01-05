<#
    Hashmap working as cache to speed up groups fetching
#>
$___usersCache___ = @{}

function addUserToOrganization {
    param(
        [Parameter(Mandatory=$true)][String]$org,
        [Parameter(Mandatory=$true)][String]$userEmail
    )

    Write-Verbose "[addUserToOrganization] Adding user $userEmail to organiztion $org..." 
    $user = az devops user add --only-show-errors --org $org --email-id $userEmail --license-type stakeholder
    Write-Verbose "[addUserToOrganization] User $userEmail added to organiztion $org!" 
    
    #return $user
}