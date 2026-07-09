param(
    [Parameter(Mandatory=$true)]
    [string]$FolderPath,

    [switch]$CsvLog,

    [int]$Throttle = 6   # number of parallel threads
)

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

# Get all files recursively
$files = Get-ChildItem -Path $FolderPath -File -Recurse

# Parallel block
$files | ForEach-Object -Parallel {

    param($FolderPath, $logFile, $CsvLog, $csvFile)

    # Each thread must create its own Shell COM instance
    $Shell = New-Object -ComObject Shell.Application

    # Get file info
    $file = $_
    $parentFolder = Split-Path $file.FullName -Parent
    $folderObj    = $Shell.NameSpace($parentFolder)
    $itemObj      = $folderObj.ParseName($file.Name)

    # 1️⃣ EXIF "Media Created"
    $mediaCreated = $itemObj.ExtendedProperty("System.Media.DateEncoded")

    # 2️⃣ EXIF "Date Taken"
    $dateTaken = $itemObj.ExtendedProperty("System.Photo.DateTaken")

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
        New-Item -ItemType Directory -Path $newFolderPath -WhatIf

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
    Move-Item -Path $file.FullName -Destination $destination -WhatIf

    if ($CsvLog) {
        '"' + $file.FullName + '","' +
        $dateSource + '","' +
        $finalDate + '","' +
        $newFolderPath + '","' +
        $destination + '","MoveFile"' | Add-Content -Path $csvFile
    }

    Add-Content -Path $logFile -Value ""

} -ArgumentList $FolderPath, $logFile, $CsvLog, $csvFile -ThrottleLimit $Throttle

Write-Host "Parallel processing complete. Log file: $logFile"
if ($CsvLog) { Write-Host "CSV log: $csvFile" }
