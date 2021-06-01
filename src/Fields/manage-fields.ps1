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

function getControlDefinition {
    param (
        [Parameter(Mandatory=$true)][string]$referenceName,
        [Parameter(Mandatory=$true)][string]$fieldName,
        [Parameter(Mandatory=$true)][bool]$readOnly,
        [Parameter(Mandatory=$true)][bool]$visible
    )
    $control = @{}
    $control.Add("id",$referenceName)
    $control.Add("label",$fieldName)
    $control.Add("contribution", $null)
    $control.Add("controlType", $null)
    $control.Add("height", $null)
    $control.Add("inherited", $null)
    $control.Add("isContribution", $false)
    $control.Add("metadata", $null)
    $control.Add("order", $null)
    $control.Add("overridden", $null)
    $control.Add("readOnly", $readOnly)
    $control.Add("visible", $visible)
    $control.Add("watermark", $null)
    return $control
}

function getSection{
    param (
        [Parameter(Mandatory=$true)][string]$id
    )
    $section = @{}
    $section.Add("id", $id)
    $section.Add("groups", @())
    $section.Add("overridden", $false)
    return $section
}

function createPage {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$processId,
        [Parameter(Mandatory=$true)][string]$witName,
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Creating Page with name '$name' ..."

    $header = generateHeader $personalToken
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    #POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/pages?api-version=6.1-preview.1
    $requestUrl = "$($org)/_apis/work/processes/$($processId)/workItemTypes/$($witName)/layout/pages?api-version=6.1-preview.1"
    
    Write-Verbose "[$($funcName)] Body Construction"
    $Body = @{}
    $Body.Add("id",$null)
    $Body.Add("inherited",$null)
    $Body.Add("label",$name)
    $Body.Add("locked",$false)
    $Body.Add("order",$null)
    $Body.Add("overridden",$null)
    $Body.Add("contribution",$null)
    $Body.Add("pageType","custom")
    $Body.Add("visible",$true)
    $section1 = getSection "Section1"
    $section2 = getSection "Section2"
    $section3 = getSection "Section3"
    $Body.Add("sections", @($section1, $section2, $section3))

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
    Write-Host "[$($funcName)] Created Page with name '$name'. Id -> '$($RestResponse.id)'"
    return $RestResponse
}

function createGroup {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$processId,
        [Parameter(Mandatory=$true)][string]$witName,
        [Parameter(Mandatory=$true)][string]$pageId,
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$true)][string]$personalToken,
        [Parameter(Mandatory=$false)][string]$sectionId = "Section1"
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Creating Group with name '$name' ..."

    $header = generateHeader $personalToken
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    #POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/pages/{pageId}/sections/{sectionId}/groups?api-version=6.1-preview.1
    $requestUrl = "$($org)/_apis/work/processes/$($processId)/workItemTypes/$($witName)/layout/pages/$($pageId)/sections/$($sectionId)/groups?api-version=6.1-preview.1"
    
    Write-Verbose "[$($funcName)] Body Construction"
    $Body = @{}
    $Body.Add("id",$null)
    $Body.Add("inherited",$null)
    $Body.Add("label",$name)
    $Body.Add("order",$null)
    $Body.Add("overridden",$null)
    $Body.Add("visible",$true)
    $Body.Add("controls",$null)

    # Convert Body Object to JSON
    $JSONBody = ConvertTo-Json -InputObject $Body -Depth 100
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Post -Headers $header -Body $JSONBody -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        $requestUrl
        Throw $RestError
    }
    Write-Host "[$($funcName)] Created Group with name '$name'. Id -> '$($RestResponse.id)'"
    return $RestResponse
}

function existsList {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Get list '$name' Reference Name"

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = generateHeader $personalToken
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    #GET https://dev.azure.com/{organization}/_apis/work/processes/lists?api-version=6.1-preview.1
    $requestUrl = "$($org)/_apis/work/processes/lists?api-version=6.1-preview.1"

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Get -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Throw $RestError
    }
    $listId = $null
    foreach ($val in $RestResponse.value) {
        if($val.name -eq $name){
            $listId = $val.id
            break
        }
    }
    if(!$listId){
        Write-Verbose "[$($funcName)]  List '$name' doesn't exist"
        return $null
    }
    #GET https://dev.azure.com/{organization}/_apis/work/processes/lists/{listId}?api-version=6.1-preview.1
    $requestUrl = "$($org)/_apis/work/processes/lists/$($listId)?api-version=6.1-preview.1"

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Get -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Throw $RestError
    }
    Write-Verbose "[$($funcName)] Got list '$name'"
    return $RestResponse
}

function createList {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$true)][string]$type,
        [Parameter(Mandatory=$true)][object[]]$values,
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    if(($type -ne 'picklistDouble') -and $type -ne ('picklistInteger') -and $type -ne ('picklistString')){
        Throw 'Invalid type for picklist'
    }

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Creating list with name '$name' ..."

    # Check if list already exists
    Write-Verbose "[$($funcName)] Check if list '$name' already exists..."
    $list = existsList -org $org -name $Name -personalToken $personalToken
    
    $listType = $type.Replace('picklist', '')
    if (!$list) { # Field doesn't exist let's create it
        Write-Host "[$($funcName)] List '$Name' not found. Starting to create it..."

        Write-Verbose "[$($funcName)] Headers Construction"
        $header = generateHeader $personalToken
        
        Write-Verbose "[$($funcName)] Initialize request Url"
        #POST https://dev.azure.com/{organization}/_apis/work/processes/lists?api-version=6.1-preview.1
        $requestUrl = "$($org)/_apis/work/processes/lists?api-version=6.1-preview.1"
        
        Write-Verbose "[$($funcName)] Body Construction"
        $Body = @{}
        $Body.Add("id",$null)
        $Body.Add("url",$null)
        $Body.Add("name",$name)
        $Body.Add("type",$listType)
        $Body.Add("isSuggested",$false)
        $Body.Add("items",$values)

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
        Write-Host "[$($funcName)] Created List with name '$name'. Id -> '$($RestResponse.Id)'"
        return $RestResponse
    }
    else{
        Write-Host "[$($funcName)] List '$name' already exists..."
        if($list.type -ne $listType){
            Throw "Type mismatch: existing list is '$($list.type)'"
        }
        return $list
    }
}

function existsField {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Get field '$name' Reference Name"

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = generateHeader $personalToken
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    #GET https://dev.azure.com/{organization}/_apis/wit/fields/{fieldNameOrRefName}?api-version=6.0
    $requestUrl = "$($org)/_apis/wit/fields/$($name)?api-version=6.0"

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Get -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        if ((($resterror[0].message | ConvertFrom-Json).message).split(':',2)[0] -ne 'TF51535') #TF51535: Cannot find field Batatas.
        {
            Throw $RestError
        }
        Write-Verbose "[$($funcName)]  Field '$name' doesn't exist"
    }
    Write-Verbose "[$($funcName)] Get field '$name' Reference Name -> '$($RestResponse.referenceName)'"
    return $RestResponse
}

function createField {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$true)][string]$description,
        [Parameter(Mandatory=$true)][string]$type,
        [Parameter(Mandatory=$true)][string]$personalToken,
        [Parameter(Mandatory=$false)][object[]]$listValues
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Creating field with name '$name' ..."

    # Check if field already exists
    Write-Verbose "[$($funcName)] Check if field '$name' already exists..."
    $fieldObject = existsField -org $org -name $Name -personalToken $personalToken
    
    if (!$fieldObject) { # Field doesn't exist let's create it
        Write-Host "[$($funcName)] Field '$Name' not found. Starting to create it..."

        Write-Verbose "[$($funcName)] Headers Construction"
        $header = generateHeader $personalToken
        
        Write-Verbose "[$($funcName)] Initialize request Url"
        #POST https://dev.azure.com/{organization}/_apis/wit/fields?api-version=6.0
        $requestUrl = "$($org)/_apis/wit/fields?api-version=6.0"
        
        Write-Verbose "[$($funcName)] Body Construction"
        $Body = @{}
        $Body.Add("name",$name)
        $Body.Add("description","(BCP) " + $description)
        $Body.Add("usage","workItem")
        $Body.Add("readOnly",$false)
        $Body.Add("canSortBy",$true)
        $Body.Add("isQueryable",$true)
        $Body.Add("url",$null)

        if ($type.StartsWith("picklist")) # Picklist (string) or Picklist (integer)
        {
            $list = createList $org $name $type $listValues $personalToken
            $Body.Add("isPicklist",$true)
            $Body.Add("isPicklistSuggested",$false)
            $Body.Add("picklistId",$list.id)
            $Body.Add("type",$type.Replace("picklist",""))
        }
        else {
            if($type -eq "identity"){
                $Body.Add("isIdentity",$true)
            }
            $Body.Add("type",$type)
        }

        $supportedOperations = @"
        [
            {"referenceName": "SupportedOperations.Equals","name": "="},
            {"referenceName": "SupportedOperations.NotEquals","name": "\u003c\u003e"},
            {"referenceName": "SupportedOperations.GreaterThan","name": "\u003e"},
            {"referenceName": "SupportedOperations.LessThan","name": "\u003c"},
            {"referenceName": "SupportedOperations.GreaterThanEquals","name":  "\u003e="},
            {"referenceName": "SupportedOperations.LessThanEquals","name":  "\u003c="},
            {"referenceName": "SupportedOperations.In","name": "In"},
            {"referenceName": "SupportedOperations.NotIn","name": "Not In"},
            {"referenceName": "SupportedOperations.Ever","name": "Was Ever"},
            {"referenceName": "SupportedOperations.EqualsField","name": "= [Field]"},
            {"referenceName": "SupportedOperations.NotEqualsField","name": "\u003c\u003e [Field]"},
            {"referenceName": "SupportedOperations.GreaterThanField","name": "\u003e [Field]"},
            {"referenceName": "SupportedOperations.LessThanField","name":  "\u003c [Field]"},
            {"referenceName": "SupportedOperations.GreaterThanEqualsField","name": "\u003e= [Field]"},
            {"referenceName": "SupportedOperations.LessThanEqualsField","name": "\u003c= [Field]"}
        ]
"@ | ConvertFrom-Json
        
        $Body.Add("supportedOperations",$supportedOperations)

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
        Write-Host "[$($funcName)] Created field with name '$name'. Reference Name -> '$($RestResponse.referenceName)'"
        return $RestResponse.referenceName
    }
    else{
        Write-Host "[$($funcName)] Field '$name' already exists..."
        if($fieldObject.type -ne $type){
            if(!$type.StartsWith("picklist") -or $fieldObject.Type -ne $type.Replace("picklist", "")){
                Throw "Type mismatch: existing field is '$($fieldObject.type)'"
            }
        }
        return $fieldObject.referenceName
    }
}

function associateField {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$processId,
        [Parameter(Mandatory=$true)][string]$witName,
        [Parameter(Mandatory=$true)][string]$referenceName,
        [Parameter(Mandatory=$true)][bool]$required,
        [Parameter(Mandatory=$true)][string]$type,
        [Parameter(Mandatory=$true)][string]$personalToken,
        [Parameter(Mandatory=$false)][string]$defaultValue = ""
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Associating field with reference name '$referenceName' to wit '$witName'..."

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = generateHeader $personalToken
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    #POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/fields?api-version=6.1-preview.2
    $requestUrl = "$($org)/_apis/work/processes/$($processId)/workItemTypes/$($witName)/fields?api-version=6.1-preview.2"

    Write-Verbose "[$($funcName)] Body Construction"
    $Body = @{}
    $Body.Add("referenceName",$referenceName)
    $Body.Add("required", $required)
    $Body.Add("defaultValue", $defaultValue)
    $Body.Add("readOnly", $false)
    $Body.Add("allowGroups", $null)
    $Body.Add("allowedValues", $null)
    
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
    Write-Host "[$($funcName)] Associated field with reference name '$referenceName' to wit '$witName'. Name -> '$($RestResponse.name)'"
    
    return $RestResponse.name
}

function removeFieldFromWIT {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$processId,
        [Parameter(Mandatory=$true)][string]$witName,
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    $fieldObject = existsField -org $org -name $name -personalToken $personalToken
    if(!$fieldObject){
        Write-Host "[$($funcName)] Field '$name' doesn't exists..."
        return
    }

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Removing field with reference name '$referenceName' from wit '$witName'..."

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = generateHeader $personalToken
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    #DELETE https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/fields/{fieldRefName}?api-version=6.1-preview.2
    $requestUrl = "$($org)/_apis/work/processes/$($processId)/workItemTypes/$($witName)/fields/$($fieldObject.referenceName)?api-version=6.1-preview.2"

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    Invoke-RestMethod -Uri $requestUrl -Method Delete -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Throw $RestError
    }
    Write-Host "[$($funcName)] Removed field with reference name '$name' from wit '$witName'."
}

function setFieldInGroup {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$processId,
        [Parameter(Mandatory=$true)][string]$witName,
        [Parameter(Mandatory=$true)][string]$groupId,
        [Parameter(Mandatory=$true)][string]$referenceName,
        [Parameter(Mandatory=$true)][string]$fieldName,
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Setting field with reference name '$referenceName' on wit '$witName' to group '$groupId'..."

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = generateHeader $personalToken
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    #PUT https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/groups/{groupId}/controls/{controlId}?api-version=6.1-preview.1
    $requestUrl = "$($org)/_apis/work/processes/$($processId)/workItemTypes/$($witName)/layout/groups/$($groupId)/controls/$($referenceName)?api-version=6.1-preview.1"

    Write-Verbose "[$($funcName)] Body Construction"
    $Body = getControlDefinition $referenceName $fieldName $false $true

    # Convert Body Object to JSON
    $JSONBody = ConvertTo-Json -InputObject $Body -Depth 100

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    Invoke-RestMethod -Uri $requestUrl -Method Put -Headers $header -Body $JSONBody -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Throw $RestError
    }
    Write-Host "[$($funcName)] Set field with reference name '$referenceName' on wit '$witName' to group '$groupId'."
}

function setHtmlInGroup {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$processId,
        [Parameter(Mandatory=$true)][string]$witName,
        [Parameter(Mandatory=$true)][string]$pageId,
        [Parameter(Mandatory=$true)][string]$sectionId,
        [Parameter(Mandatory=$true)][string]$referenceName,
        [Parameter(Mandatory=$true)][string]$fieldName,
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Setting field with reference name '$referenceName' on wit '$witName' to section '$sectionId'..."

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = generateHeader $personalToken
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    #POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/pages/{pageId}/sections/{sectionId}/groups/{groupId}?api-version=6.1-preview.1
    $requestUrl = "$($org)/_apis/work/processes/$($processId)/workItemTypes/$($witName)/layout/pages/$($pageId)/sections/$($sectionId)/Groups?api-version=6.1-preview.1"
    
    Write-Verbose "[$($funcName)] Body Construction"
    $Body = @{}
    $Body.Add("id",$null)
    $Body.Add("label",$fieldName)
    $Body.Add("contribution", $null)
    $Body.Add("height", $null)
    $Body.Add("inherited", $null)
    $Body.Add("isContribution", $false)
    $Body.Add("order", $null)
    $Body.Add("overridden", $null)
    $Body.Add("visible", $true)
    
    $Control = getControlDefinition $referenceName $fieldName $false $true
    $Controls = @($Control)

    $Body.Add("controls", $Controls)

    # Convert Body Object to JSON
    $JSONBody = ConvertTo-Json -InputObject $Body -Depth 100

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    Invoke-RestMethod -Uri $requestUrl -Method POST -Headers $header -Body $JSONBody -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Throw $RestError
    }
    Write-Host "[$($funcName)] Set field with reference name '$referenceName' on wit '$witName' to section '$sectionId'."
}

function updateField {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$true)][string]$description,
        [Parameter(Mandatory=$true)][string]$type,
        [Parameter(Mandatory=$true)][psobject]$fieldObject,
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Updating field with name '$name' ..."

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = generateHeader $personalToken
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    #PATCH https://dev.azure.com/{organization}/_apis/wit/fields/{fieldNameOrRefName}?api-version=6.0-preview.2
#    $requestUrl = "$($org)/_apis/wit/fields/$($name)?api-version=6.0-preview.2"
    #PATCH https://dev.azure.com/{organization}/_apis/wit/fields/{fieldNameOrRefName}?api-version=6.0
    $requestUrl = "$($org)/_apis/wit/fields/$($name)?api-version=6.0"
    
    Write-Verbose "[$($funcName)] Body Update"

    $fieldObject.name = $name
    $fieldObject.description = $description
    $fieldObject.type = $type
    $fieldObject.Add("isDeleted","false")

    # Convert Body Object to JSON
    $JSONBody = ConvertTo-Json -InputObject $fieldObject -Depth 100

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Patch -Headers $header -Body $JSONBody -ErrorVariable RestError #-ErrorAction SilentlyContinue
    $ErrorActionPreference = $oldEAP
    if ($RestError)
    {
        Throw $RestError
    }
    Write-Verbose "[$($funcName)] Updating field with name '($name)' Reference Name -> '$($RestResponse.referenceName)'"
    return $RestResponse.referenceName
}

function deleteField {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Delete field '$name' Reference Name"

    # Check if field already exists
    Write-Verbose "[$($funcName)] Check if field '$name' already exists..."
    $fieldObject = existsField -org $org -name $Name -personalToken $personalToken

    if ($fieldObject) { # Field exists let's delete it
        Write-Verbose "[$($funcName)] Headers Construction"
        $header = generateHeader $personalToken
        
        Write-Verbose "[$($funcName)] Initialize request Url"
        #DELETE https://dev.azure.com/{organization}/_apis/wit/fields/{fieldNameOrRefName}?api-version=6.0-preview.2
#        $requestUrl = "$($org)/_apis/wit/fields/$($name)?api-version=6.0-preview.2"
        #DELETE https://dev.azure.com/{organization}/_apis/wit/fields/{fieldNameOrRefName}?api-version=6.0
        $requestUrl = "$($org)/_apis/wit/fields/$($name)?api-version=6.0"

        $oldEAP = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $RestResponse = Invoke-RestMethod -Uri $requestUrl -Method Delete -Headers $header -ErrorVariable RestError #-ErrorAction SilentlyContinue
        $ErrorActionPreference = $oldEAP
        if ($RestError)
        {
            Throw $RestError
        }
        Write-Verbose "[$($funcName)] Deleted field '$name' Reference Name -> '$($RestResponse.referenceName)'"
    }
    else{
        Write-Host "[$($funcName)] Field '$name' doesn't exists..."
    }
    return $RestResponse
}
