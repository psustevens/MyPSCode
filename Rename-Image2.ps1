Function Rename-Image {
<# 
    .SYNOPSIS Retrieve all of the image files matching a specific format and in a specific directory and rename them.
    
    .DESCRIPTION This will rename files named something like "Europe - Joel 2010 251_edited-1 (2017_04_18 23_37_20 UTC).JPG". 
    This script will remove the parenthesis, all characters within the parenthesis and the leading space before the parenthesis,
    so the file will be renamed to "Europe - Joel 2010 251_edited-1.JPG".

    .NOTES Author: David Stevens 

    .PARAMETER The FileFormat of the image(s). This is a required parameter. 
    .PARAMETER The Directory where the image(s) are/is located.  This is an optional parameter.
     
    .EXAMPLE 
    Rename-Image -FileFormat "Europe - Joel 2010 205_edited-1 (*).jpg" -Directory "C:\path\to\your\directory"
    
    .EXAMPLE 
    Rename-Image -FileFormat "Europe - Joel 2010 205_edited-1 (*).jpg"
#>

    param(
    [CmdletBinding()]
    [parameter(Mandatory = $true)]
        [System.String[]]${FileFormat},
        [System.String[]]${Directory}
    )

    # Specify the file format to match
    #$fileFormat = "Europe - Joel 2010 205_edited-1 *.jpg"
    
    # Specify the directory containing the files
    #$directory = "C:\path\to\your\directory"

    # Regular expression to capture the extension 
    $regexExtension = '\.([^\.]+)$'

    # Regular expression to capture the characters leading up to the parentheses including the leading space
    $regexLeading = '^(.*?)(?=\s+\()'

    if ($FileFormat[0] -match $regexLeading) { 
        # The characters leading up to the parentheses are captured in the first capturing group 
        $leadingCharacters = $matches[1] 
        Write-Verbose "The characters leading up to the parentheses are: $leadingCharacters" 
    } else { 
        Write-Verbose "No match found in the filename." 
    }

    # Parse out the file extension
    if ($FileFormat[0] -match $regexExtension) { 
        # The extension is captured in the first capturing group 
        $fileExtension = $matches[0] 
        Write-Verbose "The file extension is: $fileExtension" 
    } else { 
        Write-Verbose "No match found in the filename." 
    }

    # Get all files in the directory with the specified format
    $files = Get-ChildItem -Path $directory -Filter $($FileFormat)

    if ($files -eq $null) {
        Write-Host "Next time give me some files to work on!!" -Foregroundcolor Yellow
        Exit
    }

    # Loop through each file
    foreach ($file in $files) {
        # Extract the current file name
        $currentName = $file.Name
        
        # Create the new file name
        $newName = "$leadingCharacters$fileExtension"

        # Rename the file
        Rename-Item -Path $file.FullName -NewName $newName

        Write-Output "Renamed '$currentName' to '$newName'"
    }
}

Rename-Image -FileFormat "Europe - Joel 2010 205_edited-1 (*).jpg" -Directory "C:\Users\david\Documents\github\MyPSCode\test"
 