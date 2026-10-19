<##
.SYNOPSIS
Organizes files in a folder by date into subfolders named by date.

.DESCRIPTION
This script scans all files under the specified folder recursively and 
determines a date for each file using file metadata.

It first checks EXIF Media Created (System.Media.DateEncoded), then EXIF Date Taken (System.Photo.DateTaken), 
and finally falls back to LastWriteTime.

Files are moved into subfolders named using the format yyyy-MM-dd inside the target folder.
A plain text log is written to the target folder, and an optional CSV log can also be generated.

.PARAMETER FolderPath
The root folder that contains the files to organize.

.PARAMETER CsvLog
Switch to generate a CSV log file in addition to the plain text log.

.EXAMPLE
.
    .\Organize-ByDate.ps1 -FolderPath C:\Users\david\Pictures

This will organize all files under C:\Users\david\Pictures into date-based subfolders and create a log file.

.EXAMPLE
.
    .\Organize-ByDate.ps1 -FolderPath C:\Users\david\Pictures -CsvLog

This will do the same organization and also generate a CSV log file with file details.

.NOTES
The script excludes its own generated log files from processing.
    Author: David Stevens
    Created: 2026-07-09
    Last Modified: 2026-08-09
    Tested On: Windows 10/11, PowerShell 7.x
##>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string]$FolderPath,

    [switch]$CsvLog
)

$mediaCreated = $null
$dateTaken = $null
$finalDate = $null
$files = $null
$file = $null

# Validate folder
if (-not (Test-Path $FolderPath)) {
    Write-Error "Folder does not exist: $FolderPath"
    exit
}

# Create log files
$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$logFile = Join-Path $FolderPath "OrganizeByDate_Log_$timestamp.txt"

"Organize By Date Log - $timestamp" | Out-File $logFile
"----------------------------------------" | Out-File $logFile -Append
"" | Out-File $logFile -Append

if ($CsvLog) {
    $csvFile = Join-Path $FolderPath "OrganizeByDate_Log_$timestamp.csv"
    "File,DateSource,DateValue,DestinationFolder,DestinationFile,Action" | Out-File $csvFile
}

# Get all files recursively, excluding the generated log files
$csvFile = $null
if ($CsvLog) {
    $csvFile = Join-Path $FolderPath "OrganizeByDate_Log_$timestamp.csv"
}

$files = Get-ChildItem -Path $FolderPath -File -Recurse |
    Where-Object {
        $name = $_.Name
        $fullName = $_.FullName
        $isLogFile = $name -like 'OrganizeByDate_Log_*.txt' -or $name -like 'OrganizeByDate_Log_*.csv'
        $isCurrentLogFile = $fullName -eq $logFile
        $isCurrentCsvFile = $fullName -eq $csvFile

        -not ($isLogFile -or $isCurrentLogFile -or $isCurrentCsvFile)
    }

# Process files sequentially
foreach ($file in $files) {
    # Each iteration uses its own Shell COM instance
    $Shell = New-Object -ComObject Shell.Application
    $parentFolder = Split-Path $file.FullName -Parent
    $folderObj    = $Shell.NameSpace($parentFolder)
    $itemObj      = $folderObj.ParseName($file.Name)

    # 1️⃣ EXIF "Media Created"
    $mediaCreated = $itemObj.ExtendedProperty("System.Media.DateEncoded")

    if ($mediaCreated -is [datetime]) {
        $mediaCreated = $mediaCreated.ToLocalTime()
    }

    # 2️⃣ EXIF "Date Taken"
    $dateTaken = $itemObj.ExtendedProperty("System.Photo.DateTaken")
    
    if ($dateTaken -is [datetime]) {
        $dateTaken = $dateTaken.ToLocalTime()
    }

    # 3️⃣ Fallback: Date Modified
    $finalDate = $mediaCreated
    $dateSource = "MediaCreated"

    if (-not $finalDate) {
        $finalDate = $dateTaken
        $dateSource = "DateTaken"
    }

    if (-not $finalDate) {
        $finalDate = $file.LastWriteTime
        $dateSource = "DateModified"
    }

    # Format folder name
    $folderName = $finalDate.ToString("yyyy-MM-dd")
    $newFolderPath = Join-Path $FolderPath $folderName
    $destination = Join-Path $newFolderPath $file.Name

    # Thread-safe logging
    $logEntry = @(
        "File: $($file.FullName)"
        "Date Source: $dateSource ($finalDate)"
        "Destination Folder: $newFolderPath"
        "Destination File: $destination"
    ) -join "`n"

    Add-Content -Path $logFile -Value $logEntry

    # CSV base line
    if ($CsvLog) {
        $csvBase = '"' + $file.FullName + '","' +
                   $dateSource + '","' +
                   $finalDate + '","' +
                   $newFolderPath + '","' +
                   $destination + '","'
    }

    # Create folder
    if (-not (Test-Path $newFolderPath)) {
        Add-Content -Path $logFile -Value "Action: Create folder"
        New-Item -ItemType Directory -Path $newFolderPath

        if ($CsvLog) {
            ($csvBase + "CreateFolder") | Add-Content -Path $csvFile
        }
    }
    else {
        Add-Content -Path $logFile -Value "Action: Folder exists"

        if ($CsvLog) {
            ($csvBase + "FolderExists") | Add-Content -Path $csvFile
        }
    }

    # Move file
    Add-Content -Path $logFile -Value "Action: Move file"
    Move-Item -Path $file.FullName -Destination $destination

    if ($CsvLog) {
        '"' + $file.FullName + '","' +
        $dateSource + '","' +
        $finalDate + '","' +
        $newFolderPath + '","' +
        $destination + '","MoveFile"' | Add-Content -Path $csvFile
    }

    Add-Content -Path $logFile -Value ""
    $mediaCreated = $null
    $dateTaken = $null
    $finalDate = $null
}

$files = $null
$file = $null

Write-Host "Processing complete. Log file: $logFile"
if ($CsvLog) { Write-Host "CSV log: $csvFile" }
