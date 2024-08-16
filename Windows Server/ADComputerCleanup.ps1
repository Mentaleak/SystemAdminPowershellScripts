<#
.SYNOPSIS
    Get unused computers from Active Directory, backup LAPS and BitLocker data, and disable selected computers.

.DESCRIPTION
    This script is composed of three functions:
    - `Get-UnusedComputers`: Retrieves a list of computers that have not been used within a specified number of days.
    - `Backup-LapsAndBitlocker`: Backs up the LAPS and BitLocker data for the selected computers.
    - `Disable-Computers`: Disables selected computers and moves them to a specified Organizational Unit (OU).

.PARAMETER daysSinceLogon
    The number of days since the last logon to filter computers.

.PARAMETER DisabledComputersOU
    The distinguished name of the OU where disabled computers will be moved.

.EXAMPLE
    Get-UnusedComputers -daysSinceLogon 185
    Backup-LapsAndBitlocker -Computers $unusedComputers
    Disable-Computers -Computers $BackupImport -DisabledComputersOU 'OU=Disabled Computers,DC=Domain,DC=COM'

.NOTES
    Author: Zachary-Fischer
    Repository: https://github.com/Mentaleak/SystemAdminPowershellScripts
    Prerequisites: Active Directory PowerShell Module, BitLocker Recovery Information

#>

function Get-UnusedComputers {
    <#
    .SYNOPSIS
        Retrieves computers that haven't logged in within a specified number of days.

    .PARAMETER daysSinceLogon
        The number of days since the last logon to filter computers.

    .OUTPUTS
        Array of computer objects from Active Directory that have not been used.

    .EXAMPLE
        $unusedComputers = Get-UnusedComputers -daysSinceLogon 185
    #>
    
    param (
        [int]$daysSinceLogon = 185
    )
    
    # Calculate the threshold date for comparison
    $howOLD = (Get-Date).AddDays(-1 * $daysSinceLogon)

    # Show initial progress
    Write-Progress -Activity "Processing" -Status "0% Complete:" -PercentComplete 0 -CurrentOperation "Getting Computers that Have not Logged in $($daysSinceLogon) days"

    # Query Active Directory for Windows computers and select relevant properties
    $winComputers = Get-ADComputer -Filter {OperatingSystem -like "*Windows*" -and enabled -eq $true} -Properties whenCreated,whenChanged,PasswordLastSet,modifyTimeStamp,samaccountname,ms-Mcs-AdmPwdExpirationTime,OperatingSystem,IPV4Address, lastlogondate, enabled, ms-Mcs-AdmPwd, distinguishedname |
    Select-Object samaccountname,
        @{Name="whenCreated";Expression={$_.whenCreated.ToString("yyyy-MM-dd")}},
        @{Name="whenChanged";Expression={$_.whenChanged.ToString("yyyy-MM-dd")}},
        @{Name="PasswordLastSet";Expression={$_.PasswordLastSet.ToString("yyyy-MM-dd")}},
        @{Name="modifyTimeStamp";Expression={$_.modifyTimeStamp.ToString("yyyy-MM-dd")}},
        @{Name="LAPSExpirationTime";Expression={
            $expirationTimeTicks = $_."ms-Mcs-AdmPwdExpirationTime"
            $epochStart = New-Object DateTime 1601, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)
            $dateTime = $epochStart.AddTicks($expirationTimeTicks)
            if ($dateTime.Year -gt 1900) {
                $dateTime.ToString("yyyy-MM-dd")
            } else {
                ""
            }
        }},
        OperatingSystem,
        IPV4Address, lastlogondate, enabled, ms-Mcs-AdmPwd, distinguishedname

    # Filter out computers that are no longer in use based on the calculated threshold date
    $winComputersOLD = $winComputers | Where-Object {
        ([datetime]$_.whenChanged) -lt $howOLD -and
        ([datetime]$_.PasswordLastSet) -lt $howOLD -and
        (-not $_.LAPSExpirationTime -or ([datetime]$_.LAPSExpirationTime) -lt $howOLD)
    }

    # Return the filtered list of computers
    return $winComputersOLD
}

function Backup-LapsAndBitlocker {
    <#
    .SYNOPSIS
        Backs up LAPS and BitLocker data for a list of computers.

    .PARAMETER Computers
        The array of computer objects to back up.

    .OUTPUTS
        The file path of the backup file.

    .EXAMPLE
        $BackupPath = Backup-LapsAndBitlocker -Computers $unusedComputers
    #>
    
    param (
        [array]$Computers
    )

    # Load Windows Forms for the SaveFileDialog
    Add-Type -AssemblyName System.Windows.Forms
    
    # Generate a timestamp for the backup file
    $dt = "$(Get-Date -Format 'yyyyMMdd-hhmmss')"
    
    # Configure the SaveFileDialog
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.InitialDirectory = "C:\"
    $saveFileDialog.Filter = "clixml (*.clixml)|*.clixml|All Files (*.*)|*.*"
    $saveFileDialog.FileName = "DisabledComputerAccounts_$($dt).clixml"

    # Show progress for retrieving BitLocker data
    Write-Progress -Activity "Processing" -Status "20% Complete:" -PercentComplete 20 -CurrentOperation "Getting BitLocker Data"

    # Retrieve BitLocker data from Active Directory
    $BitlockerData = Get-ADObject -Filter 'objectClass -eq "msFVE-RecoveryInformation"' -Properties *
    $count = 0

    # Add BitLocker data to each computer object
    foreach ($computer in $Computers) {
        $computer | Add-Member -MemberType NoteProperty -Name "BitlockerData" -Value ($BitlockerData | Where-Object { $_.'DistinguishedName' -match $computer.DistinguishedName }) -Force
        $count++
        Write-Progress -Activity "Processing" -Status "$(($count / $Computers.count) * 100)% Complete:" -PercentComplete $(($count / $Computers.count) * 100) -CurrentOperation "Merging Bitlocker Data"
    }

    # Display the SaveFileDialog and save the backup file
    $saveFileDialog.ShowDialog() | Out-Null
    $BackupfileName = $saveFileDialog.FileName
    
    # Export the computer objects with LAPS and BitLocker data to a CLIXML file
    $Computers | Select-Object Samaccountname, distinguishedname, ms-Mcs-AdmPwd, BitlockerData | Export-Clixml -Path $BackupfileName
    
    # Return the path of the backup file
    return $BackupfileName
}

function Disable-Computers {
    <#
    .SYNOPSIS
        Disables selected computers and moves them to a specified OU.

    .PARAMETER Computers
        The array of computer objects to disable.

    .PARAMETER DisabledComputersOU
        The distinguished name of the OU where disabled computers will be moved.

    .EXAMPLE
        Disable-Computers -Computers $BackupImport -DisabledComputersOU 'OU=Disabled Computers,DC=Domain,DC=COM'
    #>
    
    param (
        [array]$Computers,
        [string]$DisabledComputersOU
    )

    # Generate a timestamp to name the new OU
    $dt = "$(Get-Date -Format 'yyyyMMdd-hhmmss')"
    
    # Create a new Organizational Unit (OU) for the disabled computers
    New-ADOrganizationalUnit -Name $dt -Path $DisabledComputersOU
    $OutOU = "OU=$($dt),$($DisabledComputersOU)"

    # Disable each selected computer and move it to the new OU
    foreach ($computer in $Computers) {
        Disable-ADAccount -Identity $computer.DistinguishedName
        Move-ADObject -Identity $computer.DistinguishedName -TargetPath $OutOU
    }
}

# Example usage:
# $unusedComputers = Get-UnusedComputers -daysSinceLogon 185
# $ComputersToBackUp = $unusedComputers | Out-GridView -OutputMode Multiple -Title "Choose Machines to backup data"
# $BackupPath = Backup-LapsAndBitlocker -Computers $ComputersToBackUp
# $BackupImport = Import-Clixml -Path $BackupPath | Out-GridView -OutputMode Multiple -Title "Choose Machines to Disable"
# Disable-Computers -Computers $BackupImport -DisabledComputersOU 'OU=Disabled Computers,DC=Domain,DC=COM'
