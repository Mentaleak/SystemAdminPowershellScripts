<#
.SYNOPSIS
    Adds a portgroup to all servers in a specified vCenter Cluster.

.DESCRIPTION
    This function connects to a vCenter server, retrieves all hosts within a specified cluster,
    and adds a virtual portgroup with the provided VLAN ID to the specified vSwitch on each host.

.PARAMETER vcenterServerName
    The FQDN or IP address of the vCenter server.

.PARAMETER VcenterUsername
    The username for authenticating to the vCenter server.

.PARAMETER MyCluster
    The name of the vCenter cluster containing the target hosts.

.PARAMETER MyvSwitch
    The name of the vSwitch to which the portgroup will be added.

.PARAMETER MyVLANname
    The name of the VLAN to be created.

.PARAMETER MyVLANid
    The VLAN ID for the portgroup.

.EXAMPLE
    PS> Add-PortGroupToCluster -vcenterServerName "VC.domain.local" -VcenterUsername "administrator@vsphere.local" -MyCluster "ClusterName" -MyvSwitch "vSwitch0" -MyVLANname "VLAN999" -MyVLANid 999

    This example adds a portgroup named "VLAN999" with VLAN ID 999 to all hosts in the "ClusterName" on the vSwitch0.

.NOTES
    Author: Zachary-Fischer
    Repository: https://github.com/Mentaleak/SystemAdminPowershellScripts
    Prerequisites: 
    - VMware PowerCLI module installed.
    - Appropriate permissions on the vCenter server to create portgroups.

#>

function Add-PortGroupToCluster {
    param (
        [string]$vcenterServerName,
        [string]$VcenterUsername,
        [string]$MyCluster,
        [string]$MyvSwitch,
        [string]$MyVLANname,
        [int]$MyVLANid
    )

    # Get vSphere credentials
    $vmcred = Get-Credential -UserName $VcenterUsername -Message "Enter vSphere credentials"

    # Connect to vCenter server
    Connect-VIServer -Server $vcenterServerName -Credential $vmcred

    # Retrieve all VM hosts in the specified cluster
    $MyVMHosts = Get-Cluster $MyCluster | Get-VMHost | Sort-Object Name

    # Loop through each host and add the specified portgroup
    ForEach ($VMHost in $MyVMHosts) {
        Get-VirtualSwitch -VMHost $VMHost -Name $MyvSwitch | New-VirtualPortGroup -Name $MyVLANname -VLanId $MyVLANid
    }

    # Disconnect from the vCenter server
    Disconnect-VIServer -Server $vcenterServerName -Confirm:$false
}

