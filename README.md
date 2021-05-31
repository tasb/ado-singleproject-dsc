# Description 
Manage creation of new objects on Azure DevOps using a Excel as DSC (Desired State Configuration) file


# How to use
```powershell
./sync-dsc-file.ps1 -org (default = https://dev.azure.com/ptbcp)
                    -configFile (default = ./Config/AzDevOps-DIT.xlsx)
                    [-upnFilter] (default = employeeId)
                    [-full]
                    [-projects]
                    [-teams]
                    [-usersTeams]
                    [-repos]
                    [-witFields]
                    [-log]
                    [-tokenFile]
                    [-Verbose]
```

## Parameters
* **-org**: Organization (project collection) to login
* **-configFile**: Excel file with the data to be synchronized with Azure DevOps. Must follow the structure of file *AzDevOps-DSC.xlsx* on root folder
* **-upnFilter**: Define the variable to filter upn query.
* **-full**: Run all elements in the Excel configuration file except witfields option.
* **-projects**: Run only this element in the Excel configuration file.
* **-teams**: Run only this element in the Excel configuration file.
* **-usersTeams**: Run only this element in the Excel configuration file.
* **-repos**: Run only this element in the Excel configuration file.
* **-witFields**: (Work Item fields) Run only this element in the Excel configuration file.
* **-log**: Create a log file in the same directory with same name but with extension .log.
* **-tokenFile**: Text file with PAT to be used on login. If not provided, login will be interactive and user must provide a PAT token
* **-Verbose**: Provide verbose output about the execution


# Description 
Creates iterations for a given year using weekly, bi-weekly, tri-weekly or four-weekly period

# How to use
```powershell
./generate-iterations.ps1 -org (default = https://dev.azure.com/ptbcp)
                          -project (default = IT.DIT)
                          -prefix (default = \DIT)
                          -year (default = current year)
                          [-oneweek]
                          [-twoweeks]
                          [-threeweeks]
                          [-fourweeks]
                          [-log]
```

## Parameters
* **-org**: Organization (project collection) to login.
* **-project**: Name of the project where iterations will be created.
* **-prefix**: Iteration prefix.
* **-year**: Year to be used on iterations dates.
* **-oneweek**: One week iteration period.
* **-twoweek**: Two week iteration period.
* **-threeweek**: Three week iteration period.
* **-fourweek**: Four week iteration period.
* **-log**: Create a log file in the same directory with same name but with extension .log.
