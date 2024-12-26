<#
.Synopsis
    Recursively search a folder structure ACL entries for a target account

    Script Title: Search-ACL
    Author      : Konrad Tjaden
    Date        : 10/13/2015
    Version     : 1.0
    Client      : Generic

.DESCRIPTION

    Date        Version Initials Description
	----------- ------- -------- --------------------------------------------
	10/13/2015   1.0    KT       Initial Script Written

.PARAMETER TargetFolder
    Target folder to search : Mandatory

.PARAMETER Account
    Account to search for : Optional

    Default value if not specified: 'Builtin\Administrators'

.EXAMPLE
   .\Search-ACL.ps1 -TargetFolder c:\temp\temp -Account domain\Account -Verbose

   This will recursively search a target directories folders and files outputting the target account searched 
   for in the output log

.OUTPUTS
    $LogFile     : C:\WINDOWS\temp\Search-ACL-Results 13-10-15.log (Default location if not specified)
    $ErrorLogFile: C:\WINDOWS\temp\Search-ACL-Error 13-10-15.log (Default location if not specified)
#>  

    Param
    (
        # Folder to search
        [Parameter(Mandatory=$true, 
                   Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        $TargetFolder,

        # Account to search for
        [Parameter(Mandatory=$true, 
                   Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        $Account,

        # Log file
        [Parameter(Mandatory=$false, 
                   Position=0)]
        $LogFile = "$env:windir\temp\Search-ACL-Results $((get-date -Format dd-MM-yy)).log",

        # Error Log file
        [Parameter(Mandatory=$false, 
                   Position=0)]
        $ErrorLogFile = "$env:windir\temp\Search-ACL-Error $((get-date -Format dd-MM-yy)).log"
    )

function Live-Log ($LogPrefix,$LogMessage,$Log) {

    "$((Get-Date).ToString()) [$LogPrefix] $LogMessage" | Out-File $Log -append

}# Live logging for CM-trace / Trace32 log tool

function Search-ACL {

<#
.Synopsis
    SetAcl custom function for setting specific ACE on files only recurse through target directory

    Script Title: (Redacted)
    Author      : Konrad Tjaden
    Date        : 10/13/2015
    Version     : 1.0
    Client      : Generic

.DESCRIPTION

    Date        Version Initials Description
	----------- ------- -------- --------------------------------------------
	10/13/2015   1.0    KT       Initial Script Written

.PARAMETER Path
    The target folder

.PARAMETER Account
    Optional parameter to change owner of a file or folder to specified account.

    Default value is 'Builtin\Administrators'

#>

    Param (
            [parameter()]
            [Alias('FullName')]
            [string]$Path,
            [parameter()]
            [string]$Account = 'Builtin\Administrators',
            [parameter()]
            [string]$Log = $LogFile,
            [parameter()]
            [string]$ErrLog = $ErrorLogFile
        )

    Begin{
        
    }
    Process{

        try{
            #Cycle through each file skipping directories as this gets done on the set owner function
            #Setting ACE if not exist and modifying ACE if exist.
            Get-ChildItem $path -recurse -Force | % {
        
                $GetACL = Get-Acl -LiteralPath $_.FullName

                Write-Verbose "Searching $($_.FullName)"

                #Check directories
                If (($_.PSIsContainer)){
                    if ($GetACL.Access | Where {$_.IdentityReference -eq $Account}) {
                        #Live Log
                        $Message = "$Account exists on folder $($_.FullName)"
                        Live-Log 'Folder' $Message $Log
                    }                  
                }else{
                    if ($GetACL.Access | Where {$_.IdentityReference -eq $Account}) {
                    #Live Log
                    $Message = "$Account exists file object $($_.FullName)"
                    Live-Log 'File' $Message $Log
                    }  
                }
            }
        }catch{
            Write-Warning "$($Item): $($_.Exception.Message)"

            #Live Log
            $Message = "$($Item): $($_.Exception.Message)"
            Live-Log 'Error' $Message $ErrLog
        }
    }
    End{
        Write-Verbose "Results $LogFile"
        Write-Verbose "Errors $ErrorLogFile"
    }
} # Seach Folder Structure ACL`s for account

Search-ACL -Path $TargetFolder -Account $Account -Log $LogFile -ErrLog $ErrorLogFile