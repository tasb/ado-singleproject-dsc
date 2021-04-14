function transformPathToJMESPath {
    param (
        [Parameter(Mandatory=$true)][string]$path
    )
    # children[] | [?name=='DIT'].children[] | [?name=='ADM-Channels'].children[] | [?name=='CDRD'].identifier | [0]
    $jmesPath = ""
    if ($path -eq '\') {
        $jmesPath = "identifier"
    } else {
        $nodes = $path -split '\\'
        foreach ($node in $nodes) {   
            if ($node) {
                if ($jmesPath) {
                    $jmesPath = $jmesPath + ".children[] | "
                } else {
                    $jmesPath = "children[] | "
                }
    
                $jmesPath = $jmesPath + "[?name=='$node']"
            }  
        }
        $jmesPath = $jmesPath + ".identifier | [0]"
    }
    Write-Verbose "transformPathToJMESPath: $path -> $jmesPath"
    return $jmesPath
}

function transformSimplePathToJMESPath {
    param (
        [Parameter(Mandatory=$true)][string]$path
    )
    # children[] | [?name=='DIT'].children[] | [?name=='ADM-Channels'].children[] 
    $nodes = $path -split '\\'
    $jmesPath = ""
    foreach ($node in $nodes) {   
        if ($node) {
            if (!$jmesPath) {
                $jmesPath = "children[] | "
            }

            $jmesPath = $jmesPath + "[?name=='$node'].children[] | "
        }  
    }

    Write-Verbose "transformSimplePathToJMESPath: $path -> $jmesPath"

    return $jmesPath
}