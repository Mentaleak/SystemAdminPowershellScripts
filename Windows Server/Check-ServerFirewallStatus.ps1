<#
.SYNOPSIS
Checks the firewall status of active servers within a specified number of days.

.DESCRIPTION
This cmdlet retrieves the list of servers where the operating system contains "Server", the account is not disabled, and the server has been active within the specified number of days. It then checks the firewall status for each server and returns the results.

.PARAMETER LastActiveDays
Specifies the number of days ago to check for server activity. Defaults to 45 days if not specified.

.PARAMETER ComputerName
Specifies the name of the server to check. If not specified, it defaults to checking all relevant servers.

.EXAMPLE
Check-ServerFirewallStatus -LastActiveDays 30

.EXAMPLE
Check-ServerFirewallStatus -ComputerName "Server01"

.NOTES
File Name      : Check-ServerFirewallStatus.ps1
Author          : Zachary Fischer
Prerequisites   : Requires Active Directory module and NetSecurity module.
Repository      : https://github.com/Mentaleak/SystemAdminPowershellScripts
#>

function Check-ServerFirewallStatus {
    [CmdletBinding()]
    param (
        [int]$LastActiveDays = 45,
        [string]$ComputerName
    )

    # Define the date based on LastActiveDays parameter
    $lastActiveDate = (Get-Date).AddDays(-$LastActiveDays)

    # Get computers where OS contains "Server", is not disabled, and has been active in the last specified days
    $servers = Get-ADComputer -Filter {OperatingSystem -like "*Server*" -and Enabled -eq $true} -Property OperatingSystem, LastLogonDate |
        Where-Object { $_.LastLogonDate -ge $lastActiveDate }

    if ($ComputerName) {
        $servers = $servers | Where-Object { $_.Name -eq $ComputerName }
    }

    # Array to store firewall status results
    $firewallResults = @()

    # Define the script block to check firewall status
    $firewallScriptBlock = {
        $profiles = Get-NetFirewallProfile | Select-Object Name, Enabled
        $domain = $profiles | Where-Object { $_.Name -eq 'Domain' } | Select-Object -ExpandProperty Enabled
        $private = $profiles | Where-Object { $_.Name -eq 'Private' } | Select-Object -ExpandProperty Enabled
        $public = $profiles | Where-Object { $_.Name -eq 'Public' } | Select-Object -ExpandProperty Enabled

        [PSCustomObject]@{
            Domain   = $domain
            Private  = $private
            Public   = $public
        }
    }

    # Total number of servers for the progress bar
    $totalServers = $servers.Count
    $counter = 0

    # Run the script block on each server and store the results in the array
    foreach ($server in $servers) {
        $serverName = $server.Name
        $counter++

        Write-Progress -PercentComplete (($counter / $totalServers) * 100) -Status "Checking $serverName" -CurrentOperation "Retrieving firewall status" -Activity "$counter / $totalServers"

        try {
            $status = Invoke-Command -ComputerName $serverName -ScriptBlock $firewallScriptBlock -ErrorAction Stop

            # Determine if all firewalls are enabled
            $fwEnabled = $status.Domain -and $status.Private -and $status.Public

            # Create a custom object to store the results
            $result = [PSCustomObject]@{
                ServerName = $serverName
                CommunicationStatus = 'Success'
                DomainEnabled   = $status.Domain
                PrivateEnabled  = $status.Private
                PublicEnabled   = $status.Public
                FWEnabled        = $fwEnabled
            }
        } catch {
            # Create a custom object to store the failed attempt
            $result = [PSCustomObject]@{
                ServerName = $serverName
                CommunicationStatus = 'Failed'
                DomainEnabled   = 'N/A'
                PrivateEnabled  = 'N/A'
                PublicEnabled   = 'N/A'
                FWEnabled        = 'N/A'
                ErrorMessage    = $_.Exception.Message
            }
        }

        # Add the result to the array
        $firewallResults += $result
    }

    # Return the sorted results
    $firewallResults | Sort-Object ServerName
}
