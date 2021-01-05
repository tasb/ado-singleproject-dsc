param(
    [Parameter(Mandatory=$true )][string]$org = "https://dev.azure.com/ptbcp",
    [Parameter(Mandatory=$true )][string]$project = "IT.DIT",
    [Parameter(Mandatory=$true )][string]$prefix = "\DIT",
    [Parameter(Mandatory=$true )][Int]$year,
    [Parameter(Mandatory=$false)][switch]$oneweek,
    [Parameter(Mandatory=$false)][switch]$twoweeks,
    [Parameter(Mandatory=$false)][switch]$threeweeks,
    [Parameter(Mandatory=$false)][switch]$fourweeks,
    [Parameter(Mandatory=$false)][switch]$log
)

. (Join-Path $PSScriptRoot .\Project\manage-iterations.ps1)


if ((!$oneweek.IsPresent)  -and (!$twoweeks.isPresent)   -and 
    (!$threeweeks.isPresent) -and (!$usefourweeksrsTeams.isPresent)) {
        Write-Host "No period specified. Select at least one valid period: -oneweek, -twoweeks, -threeweeks, -fourweeks"
        quit
}

function getFirstMondayOfTheYear {
    param(
        [Parameter(Mandatory=$true)][Int]$year
    )

    $internal_date = Get-Date -year $year -month 1 -day 1 

    while (!($internal_date.DayOfWeek -like "Monday")) {
        $internal_date = $internal_date.AddDays(1)
    }

    return $internal_date
}

#
# Start Transcript
#
if($log.isPresent) {
    $MyPath = $MyInvocation.MyCommand.Definition.Substring(0,$MyInvocation.MyCommand.Definition.LastIndexOf('.'))
    $MyPath += ".log"
    Start-Transcript -Path $MyPath
}

if (!$year) {
    $year = get-date -Format yyyy
}

Write-Host "Creating iterations for the year $year"
Write-Host "Creating iterations on prefix $prefix"

if ($oneweek.IsPresent) {
#
    # Create base iteration for weekly sprints
#
    Write-Host "Creating base iteration 1Week..."
    $ret = createIteration -org $org -project $project -name "$prefix\1Week"
    Write-Host "Creating base iteration 1Week... Done!"

    $firstMonday = getFirstMondayOfTheYear -year $year

#
    # Generate 4Weeks iterarions
#
    $firstDayFor1Week = $firstMonday
    $iterNumber = 1
    Write-Host "Creating recursive iterations for 1Weeks..."
    while ($firstDayFor1Week.year -eq $year) {
        $startDate = $firstDayFor1Week.ToString('yyyy-MM-dd')
        $endDate = $firstDayFor1Week.AddDays(4).ToString('yyyy-MM-dd')
        $iteration="{0:00}" -f $iterNumber

        Write-Host "Creating iteration for 1Week. Start Date: $startDate. End Date: $endDate..."
        $ret = createIterationWithDate -org $org -project $project -name "$prefix\1Week\1W.$year.$iteration" -startDate $startDate -finishDate $endDate
        Write-Host "Creating iteration for 1Week. Start Date: $startDate. End Date: $endDate... Done!"

        $firstDayFor1Week = $firstDayFor1Week.AddDays(7)
        $iterNumber = $iterNumber + 1
    }
}

if ($twoweeks.IsPresent) {
#
    # Create base iteration for bi-weekly sprints
#
    Write-Host "Creating base iteration 2Weeks..."
    $ret = createIteration -org $org -project $project -name "$prefix\2Weeks"
    Write-Host "Creating base iteration 2Weeks... Done!"

#
# Generate 2Weeks iterarions
#
$firstDayFor2Weeks = $firstMonday
$iterNumber = 1

Write-Host "Creating recursive iterations for 2Weeks..."
while ($firstDayFor2Weeks.year -eq $year) {
    $startDate = $firstDayFor2Weeks.ToString('yyyy-MM-dd')
    $endDate = $firstDayFor2Weeks.AddDays(11).ToString('yyyy-MM-dd')
    $iteration="{0:00}" -f $iterNumber

    Write-Host "Creating iteration for 2Weeks. Start Date: $startDate. End Date: $endDate..."
    $ret = createIterationWithDate -org $org -project $project -name "$prefix\2Weeks\2W.$year.$iteration" -startDate $startDate -finishDate $endDate
    Write-Host "Creating iteration for 2Weeks. Start Date: $startDate. End Date: $endDate... Done!"

    $firstDayFor2Weeks = $firstDayFor2Weeks.AddDays(14)
    $iterNumber = $iterNumber + 1
}
}

if ($threeweeks.IsPresent) {
    #
    # Create base iteration for tri-weekly sprints
    #
    Write-Host "Creating base iteration 3Weeks..."
    $ret = createIteration -org $org -project $project -name "$prefix\3Weeks"
    Write-Host "Creating base iteration 3Weeks... Done!"

#
# Generate 3Weeks iterarions
#
$firstDayFor3Weeks = $firstMonday
$iterNumber = 1
Write-Host "Creating recursive iterations for 3Weeks..."
while ($firstDayFor3Weeks.year -eq $year) {
    $startDate = $firstDayFor3Weeks.ToString('yyyy-MM-dd')
    $endDate = $firstDayFor3Weeks.AddDays(18).ToString('yyyy-MM-dd')
    $iteration="{0:00}" -f $iterNumber

    Write-Host "Creating iteration for 3Weeks. Start Date: $startDate. End Date: $endDate..."
    $ret = createIterationWithDate -org $org -project $project -name "$prefix\3Weeks\3W.$year.$iteration" -startDate $startDate -finishDate $endDate
    Write-Host "Creating iteration for 3Weeks. Start Date: $startDate. End Date: $endDate... Done!"

    $firstDayFor3Weeks = $firstDayFor3Weeks.AddDays(21)
    $iterNumber = $iterNumber + 1
}
}

if ($fourweeks.IsPresent) {
    #
    # Create base iteration for monthly sprints
    #
    Write-Host "Creating base iteration 4Weeks..."
    $ret = createIteration -org $org -project $project -name "$prefix\4Weeks"
    Write-Host "Creating base iteration 4Weeks... Done!"

    $firstMonday = getFirstMondayOfTheYear -year $year


#
# Generate 4Weeks iterarions
#
$firstDayFor4Weeks = $firstMonday
$iterNumber = 1
    Write-Host "Creating recursive iterations for 4Weeks..."
while ($firstDayFor4Weeks.year -eq $year) {
    $startDate = $firstDayFor4Weeks.ToString('yyyy-MM-dd')
    $endDate = $firstDayFor4Weeks.AddDays(25).ToString('yyyy-MM-dd')
    $iteration="{0:00}" -f $iterNumber

    Write-Host "Creating iteration for 4Weeks. Start Date: $startDate. End Date: $endDate..."
    $ret = createIterationWithDate -org $org -project $project -name "$prefix\4Weeks\4W.$year.$iteration" -startDate $startDate -finishDate $endDate
    Write-Host "Creating iteration for 4Weeks. Start Date: $startDate. End Date: $endDate... Done!"

    $firstDayFor4Weeks = $firstDayFor4Weeks.AddDays(28)
    $iterNumber = $iterNumber + 1
}
}

#
# Stop Transcript
#
if($log.isPresent) {
    Stop-Transcript
}
