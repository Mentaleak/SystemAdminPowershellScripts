<#
.SYNOPSIS
    Updates the specified Active Directory extension attribute with ADFS logon time for users.

.DESCRIPTION
    This function retrieves ADFS logon events from the Security log and updates the specified Active Directory extension attribute
    with the logon time for each unique user within a specified time window.

.PARAMETER DomainShortHand
    The domain shorthand used in the UserID (e.g., "DomainName").

.PARAMETER ExtensionAttribute
    The Active Directory extension attribute to store the ADFS logon time (e.g., "ExtensionAttribute2").

.PARAMETER TimeWindowInMinutes
    The time window (in minutes) to search for logon events. Defaults to 6 minutes.

.PARAMETER LogFile
    The path to the log file where any errors will be recorded.

.EXAMPLE
    Update-ADFSLogonTime -DomainShortHand "DomainName" -ExtensionAttribute "ExtensionAttribute2" -LogFile "C:\Logs\ADFSLogonTimeUpdater.log"

.NOTES
    Author: Zachary-Fischer
    Repository: https://github.com/Mentaleak/SystemAdminPowershellScripts
#>

function Update-ADFSLogonTime {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DomainShortHand,

        [Parameter(Mandatory = $false)]
        [string]$ExtensionAttribute = "extensionAttribute2",

        [Parameter(Mandatory = $false)]
        [int]$TimeWindowInMinutes = 6,

        [Parameter(Mandatory = $false)]
        [string]$LogFile = "C:\Scripts\ADFSLogonTimeUpdater.log",
    )

    # Prerequisites:
    # This script requires the Active Directory module. Run `Import-Module ActiveDirectory` before executing the function.
    # The user must have appropriate permissions to read from the Security log and to modify Active Directory user attributes.

    $endTime = Get-Date
    $startTime = $endTime.AddMinutes(-$TimeWindowInMinutes)

    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        ID = 1200
        StartTime = $startTime
        EndTime = $endTime
    }

    $results = foreach ($event in $events) {
        $userId = [regex]::Match($event.message, '<UserId>(?<userId>[^<]+)').Groups['userId'].Value
        [PsCustomObject]@{
            Time = $event.TimeCreated
            UserId = ($userId.Replace("$DomainShortHand\",""))
        }
    }

    $uniqueResults = $results | Sort-Object -Property Time -Descending | Group-Object -Property UserId | ForEach-Object {
        $_.Group | Select-Object -First 1
    }

    foreach ($logon in $uniqueResults) {
        $ADuser = Get-ADUser -Identity $logon.UserId -ErrorAction SilentlyContinue
        if ($ADuser) {
            $updateProperties = @{}
            $updateProperties[$ExtensionAttribute] = $logon.Time.ToString("yyyy-MM-dd HH:mm:ss")
            $ADuser | Set-ADUser -Replace $updateProperties
        }
    }

    $error | Out-File -FilePath $LogFile -Append
}
