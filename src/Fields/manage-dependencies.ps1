
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
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Get -Headers $header -Body $JSONBody -ErrorVariable RestError #-ErrorAction SilentlyContinue
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
        $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Get -Headers $header -Body $JSONBody -ErrorVariable RestError #-ErrorAction SilentlyContinue
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

