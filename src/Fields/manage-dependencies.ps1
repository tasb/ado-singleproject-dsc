
$___int_pageLayout___ = @{}
function generateHeader{
    param (
        [Parameter(Mandatory=$true)][string]$personalToken
    )
    $header = @{}
    $header.Add("content-type", "application/json")
    Write-Verbose "[$($funcName)] Initialize authentication context"
    $token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($personalToken)"))
    $header.Add("authorization", "Basic $token")
    return $header
}

function existProcess {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$processName,
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Get process Id with name '$processName'..."

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = generateHeader $personalToken
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    #GET https://dev.azure.com/{organization}/_apis/work/processes?api-version=6.1-preview.1
    $requestUrl = "$($org)/_apis/work/processes?api-version=6.1-preview.1"
    
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Get -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Throw $RestError
    }

    $processId = $NULL
    foreach ($process in $RestResponse.value) {
        if ($process.name.ToUpper() -eq $processName.ToUpper()) {
            $processId = $process.typeId
            break;
        }
    }

    Write-Host "[$($funcName)] Get process Id with name '$processName': $processId"
    
    return $processId
}

function getWITRefNames {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$processId,
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Get WIT Ref Name for process Id '$processId'..."

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = generateHeader $personalToken
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    #GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workitemtypes?api-version=6.1-preview.1
    $requestUrl = "$($org)/_apis/work/processes/$($processId)/workitemtypes?api-version=6.1-preview.2"
    
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Get -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Throw $RestError
    }

    $witRefName = @{}
    foreach ($witDetails in $RestResponse.value) {
        $referenceName = $witDetails.referenceName
        if ($witDetails.customization -eq "system") {
            $referenceName = createInheritWIT -org $org -processId $processId -baseWit $witDetails -personalToken $personalToken
        }
        $witRefName[$witDetails.name] = $referenceName
    }

    Write-Verbose "[$($funcName)] Get WIT Ref Name for process Id '$processId'... Done!"
    
    return $witRefName
}

function createInheritWIT {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$processId,
        [Parameter(Mandatory=$true)][object]$baseWit,
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Create inherit WIT from base WIT Id '$($baseWit.referenceName)'..."

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = generateHeader $personalToken
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    #GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workitemtypes?api-version=6.1-preview.1
    $requestUrl = "$($org)/_apis/work/processes/$($processId)/workitemtypes?api-version=6.1-preview.2"

    $Body = @{}
    $Body.Add("name",$baseWit.name)
    $Body.Add("color",$baseWit.color)
    $Body.Add("description",$baseWit.description)
    $Body.Add("icon",$baseWit.icon)
    $Body.Add("inheritsFrom",$baseWit.referenceName)
    $Body.Add("isDisabled",$false)

    # Convert Body Object to JSON
    $JSONBody = ConvertTo-Json -InputObject $Body -Depth 100
    
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Post -Headers $header -Body $JSONBody -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Throw $RestError
    }

    Write-Verbose "[$($funcName)] Create inherit WIT from base WIT Id '$($baseWit.referenceName)' finished with referenceName $($RestResponse.referenceName)"

    return $RestResponse.referenceName
}

function getPageLayout {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$processId,
        [Parameter(Mandatory=$true)][string]$witRefName,
        [Parameter(Mandatory=$true)][string]$personalToken,
        [Parameter(Mandatory=$false)][bool]$force = $false
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Get Page Layout for wit '$witRefName'..."

    $pageLayout = $___int_pageLayout___[$witRefName];

    if (!$pageLayout -or $force) {
        Write-Verbose "[$($funcName)] Headers Construction"
        $header = generateHeader $personalToken
        
        Write-Verbose "[$($funcName)] Initialize request Url"
        #GET https://dev.azure.com/{{organization}}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout?api-version=6.1-preview.1
        $requestUrl = "$($org)/_apis/work/processes/$processId/workItemTypes/$witRefName/layout?api-version=6.1-preview.1"
        
        $oldEAP = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Get -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
        $ErrorActionPreference = $oldEAP
        if ($RestError)
        {
            Throw $RestError
        }

        $pageLayout = @{}
        foreach ($page in $RestResponse.pages) {
            $pageDetails = @{
                id = $page.id
                name = $page.label
                groups = @{}
                sections = New-Object 'System.Collections.Generic.List[String]'
            }

            foreach ($section in $page.sections) {
                $pageDetails.sections.Add($section.id)
                foreach ($group in $section.groups) {
                    $groupDetails = @{
                        groupId = $group.id
                        sectionId = $section.id
                        groupName = $group.label
                    }

                    $pageDetails.groups[$groupDetails.groupName] = $groupDetails
                }
            }

            $pageLayout[$page.label] = $pageDetails
        }

        $___int_pageLayout___[$witRefName] = $pageLayout
    }

    Write-Verbose "[$($funcName)] Get Page Layout for wit '$witRefName'... Done!"
    
    return $pageLayout
}

