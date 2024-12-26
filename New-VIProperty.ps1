Function New-VIProperty -Name 'BlueFolderPath' -ObjectType 'VirtualMachine' -Value {
<# .SYNOPSIS Assign a new property to a folder 
    .DESCRIPTION This is an in-progress script to assign a new property to a vCenter folder. 
    .NOTES Author: David Stevens 
    .PARAMETER Path The path to the folder. This is a required parameter. 
    .PARAMETER Separator The character that is used to separate the leaves in the path. The default is '/' 
    .EXAMPLE 
    PS> New-VIProperty -Path "Folder1/Datacenter/Folder2"
    .EXAMPLE
    PS> New-VIProperty -Path "Folder1>Folder2" -Separator '>'
#>

    param(
    [CmdletBinding()]
    [parameter(Mandatory = $true)]
    [System.String[]]${Name},
    [char]${Separator} = '/'
    )

    param($vm)

    function Get-ParentName{
    param($object)

        if($object.Folder){
            $blue = Get-ParentName $object.Folder
            $Name = $object.Folder.Name
        }
        elseif($object.Parent -and $object.Parent.GetType().Name -like "Folder*"){
            $blue = Get-ParentName $object.Parent
            $Name = $object.Parent.Name
        }
        elseif($object.ParentFolder){
            $blue = Get-ParentName $object.ParentFolder
            $Name = $object.ParentFolder.Name
        }

        if("vm","Datacenters" -notcontains $Name){
            $blue + "/" + $Name
        }
        else{
            $blue
        }
    }   

    (Get-ParentName $vm).Remove(0,1)

} # -Force | Out-Null

# New-VIProperty -Name 'BlueFolderPath' -ObjectType 'VirtualMachine' -Value