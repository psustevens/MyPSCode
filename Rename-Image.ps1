Function Rename-Image {
<# 
    .SYNOPSIS Retrieve all of the folders and corresponding permissions in a VMware virtual center.
    
    .DESCRIPTION This will rename files in a directory that were renamed using Windows Explorer's "Rename" feature.
    The orignal files will something like "2024 04 08_Solar Eclipse_(7).NEF" or "2024 04 08_Solar Eclipse_(27).NEF" 
    and this script will remove the parenthesis and add zeros, so the file will be renamed to 
    "2024 04 08_Solar Eclipse_(0007).NEF".  If the number in the parenthesis is 2 digits, then it will be renamed to
    "2024 04 08_Solar Eclipse_(0027).NEF".

    .NOTES Author: David Stevens 

    .PARAMETER The FileFormat of the image(s). This is a required parameter. 
    .PARAMETER The Directory where the image(s) are/is located.  This is an optional parameter.
     
    .EXAMPLE 
    Rename-Image -FileFormat "2024 04 08_Solar Eclipse_(*).NEF" -Directory "C:\path\to\your\directory"
    
    .EXAMPLE 
    Rename-Image -FileFormat "2024 04 08_Solar Eclipse_(*).NEF"
#>

    param(
    [CmdletBinding()]
    [parameter(Mandatory = $true)]
        [System.String[]]${FileFormat},
        [System.String[]]${Directory}
    )

    # Specify the file format to match
    #$fileFormat = "2024 04 08_Solar Eclipse_(*).NEF"
    
    # Specify the directory containing the files
    #$directory = "C:\path\to\your\directory"

    # Regular expression to capture the extension 
    $regexExtension = '\.([^\.]+)$'

    # Regular expression to capture the characters leading up to the parentheses 
    $regexLeading = '^(.*?)[(]' 

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
        
        # Use regex to capture the number in parentheses
        # if ($currentName -match "2024 04 08_Solar Eclipse_\((\d+)\)\.NEF") {
        if ($currentName -match "$leadingCharacters\((\d+)\)\$fileExtension") {
            $number = $matches[1]

            # Format the number with leading zeros to ensure it has at least 4 digits
            $formattedNumber = $number.PadLeft(4, '0')

            # Create the new file name
            $newName = "$leadingCharacters$formattedNumber$fileExtension"

            # Rename the file
            Rename-Item -Path $file.FullName -NewName $newName

            Write-Output "Renamed '$currentName' to '$newName'"
        }
    }
}

Rename-Image -FileFormat "2024 08 07_Weekend in Bethlehem, NH_(*).NEF" -Directory "P:\2024\2024 08 07 Weekend in Bethlehem, NH"
#Rename-Image -FileFormat "2024 04 08_Solar Eclipse_(*).NEF" 