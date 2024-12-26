function Test-PowerShellSeven {
    <#
    .SYNOPSIS
    Test if the PowerShell version is 7 or higher
    .DESCRIPTION
    Many functions and options within the Entrust PowerShell SDK utilize specific PowerShell v7.x commands. 
    This function is used to determine the users version of PowerShell in order to provide the best experience.
    #>
    
    $PSVersionTable.PSVersion.Major -ge 5
}