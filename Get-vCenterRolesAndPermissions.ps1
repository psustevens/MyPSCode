function Get-DSRolesAndPermissions{
<# 
    .SYNOPSIS Retrieve all of the folders and corresponding permissions in a VMware virtual center.
    
    .DESCRIPTION This function will retrieve all of the DataCenters being managed by a VMware Virtual Center. 
    For each DataCenter all of the VM folders and the corresponding permissions will be retrieved and listed in CSV format.

    .NOTES Author: David Stevens 

    .PARAMETER The Name of the vCenter Server, preferably the fully qualified domain name. This is a required parameter. 
     
    .EXAMPLE 
    Get-vCenterRolesAndPermissions -Name vCenter.vsphere.local

#>
    param(
    [CmdletBinding()]
    [parameter(Mandatory = $true)]
    [System.String[]]${Name}
    )
    
    process{
        if((Get-PowerCLIConfiguration).DefaultVIServerMode -eq "Multiple"){
            $vCenters = $defaultVIServers
                <#foreach ($vCenter in $vCenters) {
                    $DataCenters = Get-Datacenter -Server $vCenter
                }#>
            
        }
        else{
            $vCenters = $defaultVIServers[0]
            $DataCenters = Get-Datacenter -Server $vCenters
        }

        foreach ($vCenter in $vCenters){
            foreach ($DataCenter in $DataCenters){
                Write-Output "vCenter: " $vCenter  "DataCenter:"  $DataCenter
            }

        }
   
    }
}


$vcs = "tpm-vc.tpmtxt.lab"

Connect-VIServer $vcs -User administrator@tpmtxt.lab -Password <PASSWORD> | out-null
Get-DSRolesAndPermissions -Name $vcs

