<#
.SYNOPSIS
	Updates metadata tags for one MP3 file or every MP3 file in a directory.

.DESCRIPTION
	This script updates an MP3 file's Title, Contributing artists, Album Artist,
	Album, Year, track Number, Part of a set, and Genre using FFmpeg.

	REQUIRED DEPENDENCY: FFmpeg (ffmpeg.exe) must be installed and available
	on PATH. The script cannot update MP3 metadata without it.

	Album Artist, Album, PartOfSet, and Genre are required. Title and Number
	may be specified explicitly; otherwise, they are inferred from the filename.
	For example, "01 - Song Title.mp3" gives track number 1 and title "Song
	Title". Only the initial track number and separator are removed from the
	title. Thus, "01 - Official Music Video - Come A Little Closer - Kelly
	Boesch.mp3" gives the title "Official Music Video - Come A Little Closer
	- Kelly Boesch".

	When Path is a directory, the script processes the MP3 files directly in
	that directory (not subdirectories). Each file's track number and title
	are inferred separately unless Number or Title is explicitly supplied;
	an explicitly supplied value is used for every file. Existing metadata is
	preserved for optional fields that are not supplied.

	The values being set are displayed for each file. Use LogPath to append
	successfully updated metadata values to a CSV file for later review.
	Use -Verbose to see processing details, including file discovery, inferred
	values, and update/logging progress.

.PARAMETER Path
	Path to a single MP3 file or a directory containing MP3 files.

.PARAMETER AlbumArtist
Required. Name of the music artist for the album.

.PARAMETER Album
Required. Name of the album associated with the song.

.PARAMETER Number
Optional. Track number to set. If omitted, the track number is inferred
from the filename's initial number.

.PARAMETER PartOfSet
Required. Disc number or part of the set, such as '1/2' for the first disc
of a two-disc album.

.PARAMETER Genre
Required. Genre of the song.

.PARAMETER Title
Optional. Song title. If omitted, the title is derived from the filename
by removing only an initial track number and separator.

.PARAMETER ContributingArtists
Optional. Artist or artists who contributed to creating the song. If omitted,
the existing contributing artists metadata is preserved.

.PARAMETER Year
Optional. Year the song was created. If omitted, the existing year metadata
is preserved.

.PARAMETER LogPath
Optional. Path to a CSV file to which successfully updated metadata values
are appended.

.EXAMPLE
	.\Update-YouTubeDownloadMetadata.ps1 -Path '.\01 - Song Title.mp3' `
		-AlbumArtist 'Example Artist' -Album 'Example Album' `
		-PartOfSet '1/1' -Genre 'Pop'

	Infers track number 1 and title "Song Title" from the filename.

.EXAMPLE
	.\Update-YouTubeDownloadMetadata.ps1 -Path '.\downloads' `
		-AlbumArtist 'Example Artist' -Album 'Example Album' `
		-PartOfSet '1/1' -Genre 'Pop' -Year 2024 `
		-LogPath '.\metadata-updates.csv'

	Updates every MP3 file directly in the directory, inferring each track
	number and title from its filename. Displays the metadata values and
	appends successfully updated values to the CSV log.

.EXAMPLE
	.\Update-YouTubeDownloadMetadata.ps1 -Path '.\download.mp3' `
		-AlbumArtist 'Example Artist' -Album 'Example Album' -Number 1 `
		-PartOfSet '1/1' -Genre 'Pop' -Title 'Song Title' `
		-ContributingArtists 'Featured Artist' -Year 2024 -Verbose

	Provides the required values and all optional values explicitly, and shows
	verbose processing details.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param (
	[Parameter(Mandatory, Position = 0)]
	[ValidateNotNullOrEmpty()]
	[string]$Path,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$AlbumArtist,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$Album,

	[ValidateRange(1, [int]::MaxValue)]
	[int]$Number,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$PartOfSet,

	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$Genre,

	[ValidateNotNullOrEmpty()]
	[string]$Title,

	[ValidateNotNullOrEmpty()]
	[string]$ContributingArtists,

	[ValidateNotNullOrEmpty()]
	[string]$Year,

	[ValidateNotNullOrEmpty()]
	[string]$LogPath
)

Set-StrictMode -Version Latest

function Get-TrackMetadataFromFileName {
	param (
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$FileName
	)

	$baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
	if ($baseName -match '^\s*(?<Number>\d+)\s*-\s*(?<Title>.+?)\s*$') {
		return [PSCustomObject]@{
			Number = [int]$Matches.Number
			Title  = $Matches.Title.Trim()
		}
	}

	return [PSCustomObject]@{
		Number = $null
		Title  = $baseName
	}
}

$ffmpeg = Get-Command -Name ffmpeg -CommandType Application -ErrorAction Stop |
	Select-Object -First 1
Write-Verbose "Using FFmpeg executable '$($ffmpeg.Source)'."

$resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
$target = Get-Item -LiteralPath $resolvedPath -ErrorAction Stop
Write-Verbose "Resolved input path to '$resolvedPath'."

$resolvedLogPath = if ($PSBoundParameters.ContainsKey('LogPath')) {
	[System.IO.Path]::GetFullPath($LogPath)
}
if ($resolvedLogPath) {
	Write-Verbose "CSV logging is enabled at '$resolvedLogPath'."
	$logDirectory = Split-Path -Path $resolvedLogPath -Parent
	if (-not (Test-Path -LiteralPath $logDirectory -PathType Container)) {
		throw "The log directory does not exist: '$logDirectory'."
	}
	if (Test-Path -LiteralPath $resolvedLogPath -PathType Container) {
		throw "The log path must be a file path, not a directory: '$resolvedLogPath'."
	}
}

if ($target.PSIsContainer) {
	$files = @(Get-ChildItem -LiteralPath $target.FullName -File -Filter '*.mp3' -ErrorAction Stop)
	if ($files.Count -eq 0) {
		throw "No MP3 files were found directly in directory '$resolvedPath'."
	}
	Write-Verbose "Found $($files.Count) MP3 file(s) directly in '$resolvedPath'."
}
else {
	if ($target.Extension -ine '.mp3') {
		throw "The file '$resolvedPath' is not an MP3 file."
	}
	$files = @($target)
	Write-Verbose "Processing the single MP3 file '$($target.FullName)'."
}

foreach ($file in $files) {
	Write-Verbose "Preparing metadata values for '$($file.FullName)'."

	if ($resolvedLogPath -and [string]::Equals(
			$resolvedLogPath,
			$file.FullName,
			[System.StringComparison]::OrdinalIgnoreCase
		)) {
		throw "The log path cannot be the same as an MP3 file: '$($file.FullName)'."
	}

	$inferredMetadata = Get-TrackMetadataFromFileName -FileName $file.Name

	if ($PSBoundParameters.ContainsKey('Number')) {
		$trackNumber = $Number
	}
	elseif ($null -ne $inferredMetadata.Number) {
		$trackNumber = $inferredMetadata.Number
	}
	else {
		throw "Could not infer a track number from '$($file.Name)'. Supply -Number."
	}

	if ($PSBoundParameters.ContainsKey('Title')) {
		$trackTitle = $Title
	}
	else {
		$trackTitle = $inferredMetadata.Title
	}

	if ([string]::IsNullOrWhiteSpace($trackTitle)) {
		throw "Could not infer a title from '$($file.Name)'. Supply -Title."
	}
	Write-Verbose "Inferred track number $trackNumber and title '$trackTitle' from '$($file.Name)' unless explicitly supplied."

	$metadataValues = [ordered]@{
		Title        = $trackTitle
		AlbumArtist  = $AlbumArtist
		Album        = $Album
		Number       = $trackNumber
		PartOfSet    = $PartOfSet
		Genre        = $Genre
	}
	if ($PSBoundParameters.ContainsKey('ContributingArtists')) {
		$metadataValues.ContributingArtists = $ContributingArtists
	}
	if ($PSBoundParameters.ContainsKey('Year')) {
		$metadataValues.Year = $Year
	}

	Write-Host "Metadata values for '$($file.FullName)':"
	foreach ($entry in $metadataValues.GetEnumerator()) {
		Write-Host ("  {0}: {1}" -f $entry.Key, $entry.Value)
	}

	if ($PSCmdlet.ShouldProcess($file.FullName, "Update MP3 metadata")) {
		Write-Verbose "Starting FFmpeg metadata update for '$($file.FullName)'."
		$tempPath = Join-Path -Path $file.DirectoryName -ChildPath ".$([guid]::NewGuid().ToString('N')).tmp.mp3"

		try {
			$ffmpegArguments = @(
				'-hide_banner'
				'-loglevel', 'error'
				'-y'
				'-i', $file.FullName
				'-map', '0'
				'-map_metadata', '0'
				'-c', 'copy'
				'-metadata', "title=$trackTitle"
				'-metadata', "album_artist=$AlbumArtist"
				'-metadata', "album=$Album"
				'-metadata', "track=$trackNumber"
				'-metadata', "disc=$PartOfSet"
				'-metadata', "genre=$Genre"
				'-id3v2_version', '3'
			)

			if ($PSBoundParameters.ContainsKey('ContributingArtists')) {
				$ffmpegArguments += @('-metadata', "artist=$ContributingArtists")
			}
			if ($PSBoundParameters.ContainsKey('Year')) {
				$ffmpegArguments += @('-metadata', "date=$Year")
			}

			& $ffmpeg.Source @ffmpegArguments $tempPath
			if ($LASTEXITCODE -ne 0) {
				throw "FFmpeg failed to update metadata for '$($file.FullName)' (exit code $LASTEXITCODE)."
			}
			if (-not (Test-Path -LiteralPath $tempPath -PathType Leaf)) {
				throw "FFmpeg did not create the updated MP3 file for '$($file.FullName)'."
			}

			Move-Item -LiteralPath $tempPath -Destination $file.FullName -Force -ErrorAction Stop
			Write-Verbose "Successfully updated metadata for '$($file.FullName)'."
		}
		finally {
			if (Test-Path -LiteralPath $tempPath -PathType Leaf) {
				Remove-Item -LiteralPath $tempPath -Force -ErrorAction Stop
				Write-Verbose "Removed temporary file '$tempPath'."
			}
		}

		$updatedMetadata = [PSCustomObject]@{
			Timestamp           = Get-Date
			Path                = $file.FullName
			Title               = $trackTitle
			AlbumArtist         = $AlbumArtist
			Album               = $Album
			Number              = $trackNumber
			PartOfSet           = $PartOfSet
			Genre               = $Genre
			ContributingArtists = if ($PSBoundParameters.ContainsKey('ContributingArtists')) {
				$ContributingArtists
			}
			else {
				$null
			}
			Year                = if ($PSBoundParameters.ContainsKey('Year')) { $Year } else { $null }
		}
		if ($resolvedLogPath) {
			Write-Verbose "Appending updated metadata for '$($file.FullName)' to the CSV log."
			$updatedMetadata |
				Export-Csv -LiteralPath $resolvedLogPath -NoTypeInformation -Append -ErrorAction Stop
			Write-Host "Appended metadata values to '$resolvedLogPath'."
		}
		$updatedMetadata
	}
	else {
		Write-Verbose "Skipped metadata update for '$($file.FullName)' because WhatIf was specified or confirmation was declined."
	}
}
