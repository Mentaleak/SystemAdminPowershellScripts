# Define the date 45 days ago
$lastActiveDate = (Get-Date).AddDays(-45)

# Get computers where OS contains "Server", is not disabled, and has been active in the last 45 days
$servers = Get-ADComputer -Filter {OperatingSystem -like "*Server*" -and Enabled -eq $true} -Property OperatingSystem, LastLogonDate |
    Where-Object { $_.LastLogonDate -ge $lastActiveDate }

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
            Status = 'Success'
            DomainEnabled   = $status.Domain
            PrivateEnabled  = $status.Private
            PublicEnabled   = $status.Public
            FWEnabled        = $fwEnabled
        }
    } catch {
        # Create a custom object to store the failed attempt
        $result = [PSCustomObject]@{
            ServerName = $serverName
            Status = 'Failed'
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

# Output the results
$firewallResults | Format-Table -AutoSize
