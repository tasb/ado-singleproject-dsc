$CONST_RULES_ACTION_TYPE_MAKE_READONLY = "makeReadOnly"
$CONST_RULES_ACTION_TYPE_MAKE_HIDDEN = "hideTargetField"

function generateRuleName{
    param (
        [Parameter(Mandatory = $true)][string]$actionType,
        [Parameter(Mandatory = $true)][string]$fieldId,
        [Parameter(Mandatory = $true)][string]$groupId
    )
    return "$($actionType)_$($fieldId)_$($groupId)"
}

function generateHeader {
    param (
        [Parameter(Mandatory = $true)][string]$personalToken
    )
    $header = @{}
    $header.Add("content-type", "application/json")
    Write-Verbose "[$($funcName)] Initialize authentication context"
    $token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($personalToken)"))
    $header.Add("authorization", "Basic $token")
    return $header
}

function getRules {
    param (
        [Parameter(Mandatory = $true)][string]$org,
        [Parameter(Mandatory = $true)][string]$processId,
        [Parameter(Mandatory = $true)][string]$witRefName,
        [Parameter(Mandatory = $true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Get rules for work item"

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = generateHeader $personalToken
        
    Write-Verbose "[$($funcName)] Initialize request Url"
    # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/rules?api-version=6.0-preview.2
    $requestUrl = "$($org)/_apis/work/processes/$($processId)/workItemTypes/$($witRefName)/rules?api-version=6.0-preview.2"
    
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Get -Headers $header -Body $JSONBody -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError) {
        Throw $RestError
    }
    Write-Host "[$($funcName)] Got rules for work item"
    return $RestResponse
}

function createVisibilityRule {
    param (
        [Parameter(Mandatory = $true)][string]$org,
        [Parameter(Mandatory = $true)][string]$processId,
        [Parameter(Mandatory = $true)][string]$witRefName,
        [Parameter(Mandatory = $true)][string]$fieldId,
        [Parameter(Mandatory = $true)][string]$groupId,
        [Parameter(Mandatory = $true)][string]$personalToken
    )
    return createSetRule -org $org -processId $processId -witRefName $witRefName -fieldId $fieldId -groupId $groupId -actionType $CONST_RULES_ACTION_TYPE_MAKE_HIDDEN -personalToken $personalToken
}

function createEditRule {
    param (
        [Parameter(Mandatory = $true)][string]$org,
        [Parameter(Mandatory = $true)][string]$processId,
        [Parameter(Mandatory = $true)][string]$witRefName,
        [Parameter(Mandatory = $true)][string]$fieldId,
        [Parameter(Mandatory = $true)][string]$groupId,
        [Parameter(Mandatory = $true)][string]$personalToken
    )
    return createSetRule -org $org -processId $processId -witRefName $witRefName -fieldId $fieldId -groupId $groupId -actionType $CONST_RULES_ACTION_TYPE_READONLY -personalToken $personalToken
}

function createSetRule {
    param (
        [Parameter(Mandatory = $true)][string]$org,
        [Parameter(Mandatory = $true)][string]$processId,
        [Parameter(Mandatory = $true)][string]$witRefName,
        [Parameter(Mandatory = $true)][string]$fieldId,
        [Parameter(Mandatory = $true)][string]$groupId,
        [Parameter(Mandatory = $true)][string]$actionType,
        [Parameter(Mandatory = $true)][string]$personalToken
    )
    
    $name = generateRuleName -actionType $actionType -fieldId $fieldId -groupId $groupId
    $action = @{}
    $action.Add("actionType", $actionType)
    $action.Add("targetField", $fieldId)
    $action.Add("value", "")

    $condition = @{}
    $condition.Add("conditionType", "whenCurrentUserIsNotMemberOfGroup")
    $condition.Add("field", $fieldId)
    $condition.Add("value", $groupId)
    return createRule -org $org -processId $processId -witRefName $witRefName -name $name -action $action -condition $condition -personalToken $personalToken
}

function createRule {
    param (
        [Parameter(Mandatory = $true)][string]$org,
        [Parameter(Mandatory = $true)][string]$processId,
        [Parameter(Mandatory = $true)][string]$witRefName,
        [Parameter(Mandatory = $true)][string]$name,
        [Parameter(Mandatory = $true)][object]$action,
        [Parameter(Mandatory = $true)][object]$condition,
        [Parameter(Mandatory = $true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Creating Rule with name '$name' ..."

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = generateHeader $personalToken
        
    Write-Verbose "[$($funcName)] Initialize request Url"
    #POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/rules?api-version=6.0-preview.2
    $requestUrl = "$($org)/_apis/work/processes/$($processId)/workItemTypes/$($witRefName)/rules?api-version=6.0-preview.2"
        
    Write-Verbose "[$($funcName)] Body Construction"
    $Body = @{}
    $Body.Add("name", $name)
    $Body.Add("isDisabled", $false)
    $Body.Add("conditions", @($condition))
    $Body.Add("actions", @($action))
    
    # Convert Body Object to JSON
    $JSONBody = ConvertTo-Json -InputObject $Body -Depth 100

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Post -Headers $header -Body $JSONBody -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError) {
        Throw $RestError
    }
    Write-Host "[$($funcName)] Created rule with name '$name'."
    return $RestResponse
}

function deleteRule {
    param (
        [Parameter(Mandatory = $true)][string]$org,
        [Parameter(Mandatory = $true)][string]$processId,
        [Parameter(Mandatory = $true)][string]$witRefName,
        [Parameter(Mandatory = $true)][string]$ruleId,
        [Parameter(Mandatory = $true)][string]$personalToken
    )
    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Deleting Rule with id '$ruleId' ..."

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = generateHeader $personalToken
        
    Write-Verbose "[$($funcName)] Initialize request Url"
    # DELETE https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/rules/{ruleId}?api-version=6.0-preview.2
    $requestUrl = "$($org)/_apis/work/processes/$($processId)/workItemTypes/$($witRefName)/rules/$($ruleId)?api-version=6.0-preview.2"
    
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Delete -Headers $header -Body $JSONBody -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError) {
        Throw $RestError
    }
    Write-Host "[$($funcName)] Deleted rule with id '$ruleId'."
    return $RestResponse
}
