[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "release-assets",

    # Keep each GitHub release asset safely below 2 GiB.
    # 2,040,109,465 bytes is approximately 1.90 GiB.
    [Parameter(Mandatory = $false)]
    [long]$MaximumArchiveBytes = 2040109465,

    # Maximum extracted CSV size accumulated in one archive part.
    # Start conservatively and increase after observing compression ratios.
    [Parameter(Mandatory = $false)]
    [long]$TargetUncompressedBytes = 1800000000
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# --------------------------------------------------------------------
# Resolve repository paths
# --------------------------------------------------------------------

$RepositoryRoot = (
    Resolve-Path (
        Join-Path $PSScriptRoot ".."
    )
).Path

if ([IO.Path]::IsPathRooted($OutputDirectory)) {
    $ReleaseDirectory = $OutputDirectory
}
else {
    $ReleaseDirectory = Join-Path `
        $RepositoryRoot `
        $OutputDirectory
}

if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
    $TemporaryRoot = Join-Path `
        ([IO.Path]::GetTempPath()) `
        "nse-minute-release-builder"
}
else {
    $TemporaryRoot = Join-Path `
        $env:RUNNER_TEMP `
        "nse-minute-release-builder"
}

$ExtractionDirectory = Join-Path `
    $TemporaryRoot `
    "current-extraction"

$PartDirectory = Join-Path `
    $TemporaryRoot `
    "current-part"

$ManifestPath = Join-Path `
    $ReleaseDirectory `
    "RELEASE_MANIFEST.json"

$ChecksumPath = Join-Path `
    $ReleaseDirectory `
    "SHA256SUMS.txt"

# --------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------

if ($MaximumArchiveBytes -le 0) {
    throw "MaximumArchiveBytes must be greater than zero."
}

if ($TargetUncompressedBytes -le 0) {
    throw "TargetUncompressedBytes must be greater than zero."
}

if ($TargetUncompressedBytes -ge 20GB) {
    throw (
        "TargetUncompressedBytes is unexpectedly large: " +
        "$TargetUncompressedBytes"
    )
}

# --------------------------------------------------------------------
# Helper functions
# --------------------------------------------------------------------

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    Write-Host ""
    Write-Host "Executing:"
    Write-Host "$Command $($Arguments -join ' ')"

    & $Command @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw (
            "External command failed with exit code " +
            "$LASTEXITCODE`: $Command"
        )
    }
}

function Get-SevenZipExecutable {
    $candidates = @(
        "7z",
        "7z.exe",
        "C:\Program Files\7-Zip\7z.exe"
    )

    foreach ($candidate in $candidates) {
        try {
            $command = Get-Command `
                $candidate `
                -ErrorAction Stop

            return $command.Source
        }
        catch {
            # Continue checking candidates.
        }
    }

    throw @"
7-Zip was not found.

Expected one of:
- 7z
- 7z.exe
- C:\Program Files\7-Zip\7z.exe
"@
}

function Reset-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path $Path) {
        Remove-Item `
            -Path $Path `
            -Recurse `
            -Force
    }

    New-Item `
        -Path $Path `
        -ItemType Directory `
        -Force |
        Out-Null
}

function Get-DirectorySize {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path -PathType Container)) {
        return [long]0
    }

    $files = @(
        Get-ChildItem `
            -Path $Path `
            -File `
            -Recurse
    )

    if ($files.Count -eq 0) {
        return [long]0
    }

    return [long](
        $files |
        Measure-Object `
            -Property Length `
            -Sum
    ).Sum
}

function Get-ChronologicalArchiveDate {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$Archive
    )

    $baseName = $Archive.BaseName

    if ($baseName -match '^\d{8}$') {
        try {
            return [datetime]::ParseExact(
                $baseName,
                "ddMMyyyy",
                [Globalization.CultureInfo]::InvariantCulture
            )
        }
        catch {
            Write-Warning (
                "Unable to parse archive date from filename: " +
                $Archive.Name
            )
        }
    }

    # Unknown filenames are placed after date-named archives.
    return [datetime]::MaxValue
}

function Expand-DailyArchive {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$Archive,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [string]$SevenZip
    )

    Reset-Directory $Destination

    Write-Host ""
    Write-Host "Extracting source archive: $($Archive.Name)"

    Invoke-ExternalCommand `
        -Command $SevenZip `
        -Arguments @(
            "x",
            $Archive.FullName,
            "-o$Destination",
            "-y",
            "-bso0",
            "-bsp0"
        )

    $files = @(
        Get-ChildItem `
            -Path $Destination `
            -File `
            -Recurse
    )

    if ($files.Count -eq 0) {
        throw (
            "Source archive contains no extracted files: " +
            $Archive.FullName
        )
    }

    return $files
}

function Move-ExtractedFiles {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$Files,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [string]$SourceArchiveName
    )

    foreach ($file in $Files) {
        $destinationPath = Join-Path `
            $Destination `
            $file.Name

        # Protect against duplicate CSV member names.
        if (Test-Path $destinationPath) {
            $sourcePrefix = [IO.Path]::GetFileNameWithoutExtension(
                $SourceArchiveName
            )

            $destinationName = (
                $sourcePrefix +
                "-" +
                $file.Name
            )

            $destinationPath = Join-Path `
                $Destination `
                $destinationName
        }

        Move-Item `
            -Path $file.FullName `
            -Destination $destinationPath `
            -Force
    }
}

function New-ConsolidatedArchive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatasetName,

        [Parameter(Mandatory = $true)]
        [int]$PartNumber,

        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string[]]$SourceArchives,

        [Parameter(Mandatory = $true)]
        [string]$SevenZip,

        [Parameter(Mandatory = $true)]
        [long]$MaximumBytes
    )

    if ($SourceArchives.Count -eq 0) {
        throw "Cannot create an archive without source archive names."
    }

    $sourceFiles = @(
        Get-ChildItem `
            -Path $SourceDirectory `
            -File `
            -Recurse
    )

    if ($sourceFiles.Count -eq 0) {
        throw "Cannot create an archive without extracted files."
    }

    $archiveName = "{0}-part-{1:D3}.zip" -f `
        $DatasetName, `
        $PartNumber

    $archivePath = Join-Path `
        $ReleaseDirectory `
        $archiveName

    if (Test-Path $archivePath) {
        Remove-Item `
            -Path $archivePath `
            -Force
    }

    $sourceWildcard = Join-Path `
        $SourceDirectory `
        "*"

    Write-Host ""
    Write-Host "Creating consolidated archive: $archiveName"

    Invoke-ExternalCommand `
        -Command $SevenZip `
        -Arguments @(
            "a",
            "-tzip",
            "-mx=7",
            "-mmt=on",
            $archivePath,
            $sourceWildcard,
            "-r",
            "-y",
            "-bso0",
            "-bsp0"
        )

    if (-not (Test-Path $archivePath -PathType Leaf)) {
        throw "Consolidated ZIP was not created: $archivePath"
    }

    $archive = Get-Item $archivePath

    if ($archive.Length -le 0) {
        throw "Consolidated ZIP is empty: $archiveName"
    }

    if ($archive.Length -ge $MaximumBytes) {
        throw @"
Generated archive exceeds the configured release limit.

Archive: $archiveName
Size: $($archive.Length) bytes
Limit: $MaximumBytes bytes

Reduce TargetUncompressedBytes and run the workflow again.
"@
    }

    # Validate archive integrity before publishing.
    Invoke-ExternalCommand `
        -Command $SevenZip `
        -Arguments @(
            "t",
            $archive.FullName,
            "-bso0",
            "-bsp0"
        )

    $uncompressedBytes = Get-DirectorySize `
        -Path $SourceDirectory

    Write-Host ""
    Write-Host "Archive created successfully:"
    Write-Host " - Name: $archiveName"
    Write-Host " - Source daily ZIPs: $($SourceArchives.Count)"
    Write-Host " - First source: $($SourceArchives[0])"
    Write-Host " - Last source: $($SourceArchives[-1])"
    Write-Host " - Uncompressed bytes: $uncompressedBytes"
    Write-Host " - Compressed bytes: $($archive.Length)"

    return [PSCustomObject]@{
        dataset            = $DatasetName
        part               = $PartNumber
        file               = $archive.Name
        path               = $archive.FullName
        bytes              = $archive.Length
        uncompressedBytes  = $uncompressedBytes
        sourceArchiveCount = $SourceArchives.Count
        firstSourceArchive = $SourceArchives[0]
        lastSourceArchive  = $SourceArchives[-1]
    }
}

function Build-Dataset {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatasetName,

        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$SevenZip,

        [Parameter(Mandatory = $true)]
        [long]$MaximumBytes,

        [Parameter(Mandatory = $true)]
        [long]$TargetBytes
    )

    if (-not (Test-Path $SourceDirectory -PathType Container)) {
        throw "Dataset directory does not exist: $SourceDirectory"
    }

    $dailyArchives = @(
        Get-ChildItem `
            -Path $SourceDirectory `
            -Filter "*.zip" `
            -File |
        Sort-Object `
            @{ Expression = { Get-ChronologicalArchiveDate $_ } }, `
            @{ Expression = { $_.Name } }
    )

    if ($dailyArchives.Count -eq 0) {
        throw "No daily ZIP files found in: $SourceDirectory"
    }

    Write-Host ""
    Write-Host "======================================================"
    Write-Host "Building dataset: $DatasetName"
    Write-Host "Source directory: $SourceDirectory"
    Write-Host "Daily source ZIPs: $($dailyArchives.Count)"
    Write-Host "======================================================"

    $results = [System.Collections.Generic.List[object]]::new()
    $currentSources = [System.Collections.Generic.List[string]]::new()

    Reset-Directory $PartDirectory
    Reset-Directory $ExtractionDirectory

    [long]$currentPartBytes = 0
    [int]$partNumber = 1

    foreach ($dailyArchive in $dailyArchives) {
        $extractedFiles = @(
            Expand-DailyArchive `
                -Archive $dailyArchive `
                -Destination $ExtractionDirectory `
                -SevenZip $SevenZip
        )

        $extractedBytes = [long](
            $extractedFiles |
            Measure-Object `
                -Property Length `
                -Sum
        ).Sum

        if ($extractedBytes -le 0) {
            throw (
                "Extracted source archive has zero bytes: " +
                $dailyArchive.Name
            )
        }

        if ($extractedBytes -ge $TargetBytes) {
            throw @"
A single daily source archive expands beyond the configured part target.

Archive: $($dailyArchive.Name)
Extracted bytes: $extractedBytes
Target bytes: $TargetBytes
"@
        }

        # Finalize the current part before adding a daily archive that
        # would exceed the target extracted size.
        if (
            $currentSources.Count -gt 0 -and
            ($currentPartBytes + $extractedBytes) -gt $TargetBytes
        ) {
            $result = New-ConsolidatedArchive `
                -DatasetName $DatasetName `
                -PartNumber $partNumber `
                -SourceDirectory $PartDirectory `
                -SourceArchives $currentSources.ToArray() `
                -SevenZip $SevenZip `
                -MaximumBytes $MaximumBytes

            $results.Add($result)

            $partNumber++
            $currentSources.Clear()
            $currentPartBytes = 0

            Reset-Directory $PartDirectory
        }

        Move-ExtractedFiles `
            -Files $extractedFiles `
            -Destination $PartDirectory `
            -SourceArchiveName $dailyArchive.Name

        $currentSources.Add($dailyArchive.Name)
        $currentPartBytes += $extractedBytes

        Write-Host (
            "Current part extracted bytes: " +
            "$currentPartBytes / $TargetBytes"
        )

        Reset-Directory $ExtractionDirectory
    }

    # Finalize the last part.
    if ($currentSources.Count -gt 0) {
        $result = New-ConsolidatedArchive `
            -DatasetName $DatasetName `
            -PartNumber $partNumber `
            -SourceDirectory $PartDirectory `
            -SourceArchives $currentSources.ToArray() `
            -SevenZip $SevenZip `
            -MaximumBytes $MaximumBytes

        $results.Add($result)
    }

    Reset-Directory $PartDirectory
    Reset-Directory $ExtractionDirectory

    return $results.ToArray()
}

# --------------------------------------------------------------------
# Main execution
# --------------------------------------------------------------------

$SevenZip = Get-SevenZipExecutable

Reset-Directory $ReleaseDirectory
Reset-Directory $TemporaryRoot

$NseDirectory = Join-Path `
    $RepositoryRoot `
    "Minute\NSE"

$IndexDirectory = Join-Path `
    $RepositoryRoot `
    "Minute\NSE_IDX"

$allAssets = [System.Collections.Generic.List[object]]::new()

# NSE stock and exchange-traded instrument dataset.
$nseAssets = Build-Dataset `
    -DatasetName "NSE-Minute" `
    -SourceDirectory $NseDirectory `
    -SevenZip $SevenZip `
    -MaximumBytes $MaximumArchiveBytes `
    -TargetBytes $TargetUncompressedBytes

foreach ($asset in $nseAssets) {
    $allAssets.Add($asset)
}

# NSE index dataset remains completely separate.
$indexAssets = Build-Dataset `
    -DatasetName "NSE-Index-Minute" `
    -SourceDirectory $IndexDirectory `
    -SevenZip $SevenZip `
    -MaximumBytes $MaximumArchiveBytes `
    -TargetBytes $TargetUncompressedBytes

foreach ($asset in $indexAssets) {
    $allAssets.Add($asset)
}

if ($allAssets.Count -eq 0) {
    throw "No consolidated release archives were generated."
}

# --------------------------------------------------------------------
# Generate checksums and manifest
# --------------------------------------------------------------------

$manifestAssets = [System.Collections.Generic.List[object]]::new()
$checksumLines = [System.Collections.Generic.List[string]]::new()

foreach ($asset in $allAssets) {
    $file = Get-Item $asset.path

    if ($file.Length -le 0) {
        throw "Generated release archive is empty: $($file.Name)"
    }

    if ($file.Length -ge $MaximumArchiveBytes) {
        throw (
            "Generated archive exceeds the configured limit: " +
            $file.Name
        )
    }

    $hash = Get-FileHash `
        -Path $file.FullName `
        -Algorithm SHA256

    $checksumLines.Add(
        "$($hash.Hash.ToLower())  $($file.Name)"
    )

    $manifestAssets.Add(
        [PSCustomObject]@{
            dataset            = $asset.dataset
            part               = $asset.part
            file               = $file.Name
            bytes              = $file.Length
            gibibytes          = [Math]::Round(
                $file.Length / 1GB,
                4
            )
            uncompressedBytes  = $asset.uncompressedBytes
            sha256             = $hash.Hash.ToLower()
            sourceArchiveCount = $asset.sourceArchiveCount
            firstSourceArchive = $asset.firstSourceArchive
            lastSourceArchive  = $asset.lastSourceArchive
        }
    )
}

$manifest = [ordered]@{
    generatedAtUtc = (
        Get-Date
    ).ToUniversalTime().ToString("o")

    maximumArchiveBytes     = $MaximumArchiveBytes
    targetUncompressedBytes = $TargetUncompressedBytes

    source = [ordered]@{
        nseDirectory   = "Minute/NSE"
        indexDirectory = "Minute/NSE_IDX"
    }

    assets = $manifestAssets.ToArray()
}

$manifest |
    ConvertTo-Json `
        -Depth 10 |
    Set-Content `
        -Path $ManifestPath `
        -Encoding utf8

$checksumLines |
    Set-Content `
        -Path $ChecksumPath `
        -Encoding ascii

if (-not (Test-Path $ManifestPath -PathType Leaf)) {
    throw "Release manifest was not created."
}

if (-not (Test-Path $ChecksumPath -PathType Leaf)) {
    throw "Checksum file was not created."
}

# --------------------------------------------------------------------
# Final output
# --------------------------------------------------------------------

Write-Host ""
Write-Host "======================================================"
Write-Host "Release package completed"
Write-Host "======================================================"

foreach ($asset in $manifestAssets) {
    Write-Host (
        " - " +
        $asset.file +
        " | " +
        $asset.gibibytes +
        " GiB | " +
        $asset.sourceArchiveCount +
        " source ZIPs"
    )
}

Write-Host ""
Write-Host "Release directory: $ReleaseDirectory"
Write-Host "Manifest: $ManifestPath"
Write-Host "Checksums: $ChecksumPath"

# Export values for subsequent GitHub Actions steps.
if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_ENV)) {
    "RELEASE_ASSET_DIRECTORY=$ReleaseDirectory" >> $env:GITHUB_ENV
    "RELEASE_MANIFEST=$ManifestPath" >> $env:GITHUB_ENV
    "RELEASE_CHECKSUMS=$ChecksumPath" >> $env:GITHUB_ENV
    "RELEASE_DATA_ASSET_COUNT=$($manifestAssets.Count)" >> $env:GITHUB_ENV
}