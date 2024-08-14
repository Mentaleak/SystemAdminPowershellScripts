<#
.SYNOPSIS
    Removes a portgroup from all servers in a specified vCenter Cluster.

.DESCRIPTION
    This function connects to a vCenter server, retrieves all hosts within a specified cluster,
    and removes a virtual portgroup with the provided name from the specified vSwitch on each host.

.PARAMETER vcenterServerName
    The FQDN or IP address of the vCenter server.

.PARAMETER VcenterUsername
    The username for authenticating to the vCenter server.

.PARAMETER MyCluster
    The name of the vCenter cluster containing the target hosts.

.PARAMETER MyvSwitch
    The name of the vSwitch from which the portgroup will be removed.

.PARAMETER MyVLANname
    The name of the VLAN to be removed.

.EXAMPLE
    PS> Remove-PortGroupFromCluster -vcenterServerName "VC.domain.local" -VcenterUsername "administrator@vsphere.local" -MyCluster "ClusterName" -MyvSwitch "vSwitch0" -MyVLANname "VLAN999"
        
    This example removes the portgroup named "VLAN999" from all hosts in the "ClusterNAME" on the vSwitch0.

.NOTES
    Author: Zachary-Fischer
    Repository: https://github.com/Mentaleak/SystemAdminPowershellScripts
    Prerequisites: 
    - VMware PowerCLI module installed.
    - Appropriate permissions on the vCenter server to remove portgroups.

#>

function Remove-PortGroupFromCluster {
    param (
        [string]$vcenterServerName,
        [string]$VcenterUsername,
        [string]$MyCluster,
        [string]$MyvSwitch,
        [string]$MyVLANname
    )

    # Get vSphere credentials
    $vmcred = Get-Credential -UserName $VcenterUsername -Message "Enter vSphere credentials"

    # Connect to vCenter server
    Connect-VIServer -Server $vcenterServerName -Credential $vmcred

    # Retrieve all VM hosts in the specified cluster
    $MyVMHosts = Get-Cluster $MyCluster | Get-VMHost | Sort-Object Name

    # Loop through each host and remove the specified portgroup
    ForEach ($VMHost in $MyVMHosts) {
        Get-VirtualSwitch -VMHost $VMHost -Name $MyvSwitch | Get-VirtualPortGroup -Name $MyVLANname | Remove-VirtualPortGroup -Confirm:$false
    }

    # Disconnect from the vCenter server
    Disconnect-VIServer -Server $vcenterServerName -Confirm:$false
}
