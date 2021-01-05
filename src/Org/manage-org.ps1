function login {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [string]$tokenFile
    )

    if (Test-Path $tokenFile -PathType Leaf) {
        Get-Content $tokenFile | az devops login --organization $org
    } else {
        az devops login --organization $org
    }

    $ret = az devops project list --only-show-errors --org $org

    return ($ret.length -gt 0)
}

function logout {
    param (
        [Parameter(Mandatory=$true)][string]$org
    )

    az devops logout --org $org
}