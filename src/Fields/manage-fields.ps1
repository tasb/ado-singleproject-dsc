function existsField {
    param (
        [Parameter(Mandatory=$true)][string]$org,
        [Parameter(Mandatory=$true)][string]$name,
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Get field '$name' Reference Name"

    Write-Verbose "[$($funcName)] Headers Construction"
    $header = @{}
    $header.Add("content-type", "application/json")

    Write-Verbose "[$($funcName)] Initialize authentication context"
    $token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($personalToken)"))
    $header.Add("authorization", "Basic $token")
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    #GET https://dev.azure.com/{organization}/_apis/wit/fields/{fieldNameOrRefName}?api-version=6.0-preview.2
    $requestUrl = "$($org)/_apis/wit/fields/$($name)?api-version=6.0-preview.2"

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
        [Parameter(Mandatory=$true)][string]$personalToken
    )

    $funcName = (Get-PSCallStack)[0].Command
    Write-Verbose "[$($funcName)] Creating field with name '$name' ..."

    # Check if field already exists
    Write-Verbose "[$($funcName)] Check if field '$name' already exists..."
    $fieldObject = existsField -org $org -name $Name -personalToken $personalToken

    if (!$fieldObject) { # Field doesn't exist let's create it
        Write-Host "[$($funcName)] Field '$Name' not found. Starting to create it..."

        Write-Verbose "[$($funcName)] Headers Construction"
        $header = @{}
        $header.Add("content-type", "application/json")

        Write-Verbose "[$($funcName)] Initialize authentication context"
        $token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($personalToken)"))
        $header.Add("authorization", "Basic $token")
        
        Write-Verbose "[$($funcName)] Initialize request Url"
        #POST https://dev.azure.com/{organization}/_apis/wit/fields?api-version=6.0-preview.2
        $requestUrl = "$($org)/_apis/wit/fields?api-version=6.0-preview.2"
        
        Write-Verbose "[$($funcName)] Body Construction"
        $Body = @{}
        $Body.Add("name",$name)
        $Body.Add("description","(BCP) " + $description)
        $Body.Add("usage","workItem")
        $Body.Add("readOnly","false")
        $Body.Add("canSortBy","true")
        $Body.Add("isQueryable","true")
        $Body.Add("url",$null)

        $va,$vb = $Type.split('(',2)

        if ($va.trim() -eq 'Picklist' ) # Picklist (string) or Picklist (integer)
        {
            $Body.Add("type",$vb.split(')',2)[0])
            $Body.Add("isPicklist","true")
            $Body.Add("isPicklistSuggested","false")
        }
        else {
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
    }
    else{
        Write-Host "[$($funcName)] Field '$name' already exists..."
    }
    return $RestResponse.referenceName
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
    $header = @{}
    $header.Add("content-type", "application/json")

    Write-Verbose "[$($funcName)] Initialize authentication context"
    $token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($personalToken)"))
    $header.Add("authorization", "Basic $token")
    
    Write-Verbose "[$($funcName)] Initialize request Url"
    # PATCH https://dev.azure.com/{organization}/_apis/wit/fields/{fieldNameOrRefName}?api-version=6.0-preview.2
    $requestUrl = "$($org)/_apis/wit/fields/$($name)?api-version=6.0-preview.2"
    
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
        $header = @{}
        $header.Add("content-type", "application/json")

        Write-Verbose "[$($funcName)] Initialize authentication context"
        $token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($personalToken)"))
        $header.Add("authorization", "Basic $token")
        
        Write-Verbose "[$($funcName)] Initialize request Url"
        #DELETE https://dev.azure.com/{organization}/_apis/wit/fields/{fieldNameOrRefName}?api-version=6.0-preview.2
        $requestUrl = "$($org)/_apis/wit/fields/$($name)?api-version=6.0-preview.2"

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
