<#
.SYNOPSIS
    Updates the latest logon time of Active Directory users in a specified attribute.

.DESCRIPTION
    This function retrieves the latest logon time for all Active Directory users from all domain controllers in the domain and updates a specified extension attribute with this information. The function can also take additional attributes to check for logon dates.

.PARAMETER LogFile
    Specifies the path to the log file where users with cleared logon times are recorded.

.PARAMETER LogonAttributes
    An array of attributes to check for logon dates, such as 'lastLogon', 'extensionAttribute2', etc.

.PARAMETER TargetAttribute
    The attribute in which to store the latest logon time, such as 'extensionAttribute3'.

.EXAMPLE
    Update-ADUserLogonTimes -LogFile "C:\Scripts\LogonTimeUpdater.log" -LogonAttributes @('lastLogon', 'extensionAttribute2') -TargetAttribute 'extensionAttribute3'

.NOTES
    Author: Zachary-Fischer
    Repository: https://github.com/Mentaleak/SystemAdminPowershellScripts

.PREREQUISITES
    Active Directory module must be installed and imported.
    User running the script must have the necessary permissions to read from and write to Active Directory user objects.
#>

function Update-ADUserLogonTimes {
    param (
        [string]$LogFile = "C:\Scripts\LogonTimeUpdater.log",
        [string[]]$LogonAttributes = @('lastLogon', 'extensionAttribute2'),
        [string]$TargetAttribute = 'extensionAttribute3'
    )

    # Import the Active Directory module
    Import-Module ActiveDirectory

    # Initialize the logfile
    if (Test-Path $LogFile) {
        Remove-Item $LogFile
    }
    New-Item -Path $LogFile -ItemType File | Out-Null

    # Initialize variables
    $DirectoryData = @()
    $DCS = Get-ADDomainController -Filter *
    $dcscount = 0

    # Retrieve user data from all domain controllers
    foreach ($dc in $DCS) {
        $DirectoryData += Get-ADUser -Filter * -Properties $LogonAttributes, samaccountname, $TargetAttribute -Server $dc.Name
        $dcscount++
    }

    # Group user data by SamAccountName
    $GroupedData = $DirectoryData | Group-Object -Property SamAccountName

    $usercount = 0

    # Check logon times for users
    foreach ($group in $GroupedData) {
        $samAccountName = $group.Name
        $logonTimes = @()

        foreach ($user in $group.Group) {
            foreach ($attribute in $LogonAttributes) {
                if ($user.$attribute) {
                    # Handle different types of date formats
                    if ($attribute -eq 'lastLogon') {
                        $logonTimes += [DateTime]::FromFileTime($user.$attribute)
                    } else {
                        $logonTimes += Get-Date $user.$attribute
                    }
                }
            }
        }

        # Get the latest logon time
        $latestLogonTime = $logonTimes | Sort-Object -Descending | Select-Object -First 1

        # Update the target attribute with the latest logon time for all users in the group
        if ($latestLogonTime) {
            Set-ADUser $user -Replace @{ $TargetAttribute = $latestLogonTime.ToString("yyyy-MM-dd HH:mm:ss") }
        } else {
            Set-ADUser $user -Clear $TargetAttribute
            $user.SamAccountName | Out-File $LogFile -Append
        }
        $usercount++
    }

    # Remove duplicate entries from the log file
    $logData = Get-Content $LogFile
    $logData | Sort-Object | Get-Unique | Out-File $LogFile
}

# Example usage of the function
# Update-ADUserLogonTimes -LogFile "C:\Scripts\LogonTimeUpdater.log" -LogonAttributes @('lastLogon', 'extensionAttribute2') -TargetAttribute 'extensionAttribute3'
