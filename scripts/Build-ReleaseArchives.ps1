[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "release-assets",

    # Keep comfortably below GitHub's strict 2 GiB-per-file limit.
    [Parameter(Mandatory = $false)]
    [long]$MaximumArchiveBytes = 2040109465,

    # Group source ZIPs into extraction batches.
    # This reduces temporary disk usage on GitHub-hosted runners.
    [Parameter(Mandatory = $false)]
    [long]$PreferredBatchSourceBytes = 1342177280
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepositoryRoot = (
    Resolve-Path (
        Join-Path $PSScriptRoot ".."
    )
).Path

$OutputDirectory = Join-Path `
    $RepositoryRoot `
    $OutputDirectory

$WorkingRoot = Join-Path `
    $env:RUNNER_TEMP `
    "nse-minute-release-builder"

$ManifestPath = Join-Path `
    $OutputDirectory `
    "RELEASE_MANIFEST.json"

$ChecksumPath = Join-Path `
    $OutputDirectory `
    "SHA256SUMS.txt"

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
            $resolved = Get-Command `
                $candidate `
                -ErrorAction Stop

            return $resolved.Source
        }
        catch {
            # Continue checking.
        }
    }

    throw "7-Zip was not found on this runner."
}

function Clear-Directory {
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

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [IO.Path]::GetRelativePath(
        $RepositoryRoot,
        $Path
    ).Replace("\", "/")
}

function Split-FilesIntoBatches {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$Files,

        [Parameter(Mandatory = $true)]
        [long]$MaximumSourceBytes
    )

    $batches = [System.Collections.Generic.List[object]]::new()
    $currentBatch = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    [long]$currentBytes = 0

    foreach ($file in $Files) {
        if (
            $currentBatch.Count -gt 0 -and
            ($currentBytes + $file.Length) -gt $MaximumSourceBytes
        ) {
            $batches.Add(
                @($currentBatch.ToArray())
            )

            $currentBatch = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
            $currentBytes = 0
        }

        $currentBatch.Add($file)
        $currentBytes += $file.Length
    }

    if ($currentBatch.Count -gt 0) {
        $batches.Add(
            @($currentBatch.ToArray())
        )
    }

    return $batches.ToArray()
}

function Expand-SourceArchives {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$SourceArchives,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [string]$SevenZip
    )

    Clear-Directory $Destination

    foreach ($sourceArchive in $SourceArchives) {
        Write-Host (
            "Extracting " +
            (Get-RelativePath $sourceArchive.FullName)
        )

        Invoke-ExternalCommand `
            -Command $SevenZip `
            -Arguments @(
                "x",
                $sourceArchive.FullName,
                "-o$Destination",
                "-y",
                "-bso0",
                "-bsp0"
            )
    }
}

function New-ZipArchive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$SevenZip
    )

    if (Test-Path $ArchivePath) {
        Remove-Item `
            -Path $ArchivePath `
            -Force
    }

    $sourceWildcard = Join-Path `
        $SourceDirectory `
        "*"

    Invoke-ExternalCommand `
        -Command $SevenZip `
        -Arguments @(
            "a",
            "-tzip",
            "-mx=7",
            "-mmt=on",
            $ArchivePath,
            $sourceWildcard,
            "-r",
            "-y",
            "-bso0",
            "-bsp0"
        )

    if (-not (Test-Path $ArchivePath -PathType Leaf)) {
        throw "Archive was not created: $ArchivePath"
    }

    $archive = Get-Item $ArchivePath

    if ($archive.Length -le 0) {
        throw "Archive is empty: $ArchivePath"
    }

    return $archive
}

function Build-ArchiveBatch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatasetName,

        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$SourceArchives,

        [Parameter(Mandatory = $true)]
        [int]$RequestedPartNumber,

        [Parameter(Mandatory = $true)]
        [string]$SevenZip,

        [Parameter(Mandatory = $true)]
        [long]$MaximumBytes
    )

    $results = [System.Collections.Generic.List[object]]::new()

    if ($SourceArchives.Count -eq 0) {
        return $results.ToArray()
    }

    $batchIdentity = (
        $DatasetName +
        "-" +
        $RequestedPartNumber +
        "-" +
        [Guid]::NewGuid().ToString("N")
    )

    $extractDirectory = Join-Path `
        $WorkingRoot `
        $batchIdentity

    Expand-SourceArchives `
        -SourceArchives $SourceArchives `
        -Destination $extractDirectory `
        -SevenZip $SevenZip

    $archiveName = "{0}-part-{1:D3}.zip" -f `
        $DatasetName, `
        $RequestedPartNumber

    $archivePath = Join-Path `
        $OutputDirectory `
        $archiveName

    $archive = New-ZipArchive `
        -SourceDirectory $extractDirectory `
        -ArchivePath $archivePath `
        -SevenZip $SevenZip

    Remove-Item `
        -Path $extractDirectory `
        -Recurse `
        -Force

    if ($archive.Length -lt $MaximumBytes) {
        $results.Add(
            [PSCustomObject]@{
                dataset            = $DatasetName
                temporaryPart      = $RequestedPartNumber
                archivePath        = $archive.FullName
                archiveName        = $archive.Name
                archiveBytes       = $archive.Length
                sourceArchiveCount = $SourceArchives.Count
                firstSource        = $SourceArchives[0].Name
                lastSource         = $SourceArchives[-1].Name
            }
        )

        return $results.ToArray()
    }

    Write-Warning (
        "$archiveName is too large: " +
        "$($archive.Length) bytes. Splitting the batch."
    )

    Remove-Item `
        -Path $archive.FullName `
        -Force

    if ($SourceArchives.Count -le 1) {
        throw @"
A single daily source archive produces a consolidated asset larger than the
configured release limit.

Source: $($SourceArchives[0].FullName)
Generated size: $($archive.Length)
Limit: $MaximumBytes
"@
    }

    $middle = [Math]::Floor(
        $SourceArchives.Count / 2
    )

    $left = @(
        $SourceArchives[0..($middle - 1)]
    )

    $right = @(
        $SourceArchives[$middle..($SourceArchives.Count - 1)]
    )

    $leftResults = Build-ArchiveBatch `
        -DatasetName $DatasetName `
        -SourceArchives $left `
        -RequestedPartNumber $RequestedPartNumber `
        -SevenZip $SevenZip `
        -MaximumBytes $MaximumBytes

    foreach ($result in $leftResults) {
        $results.Add($result)
    }

    $nextNumber = (
        $RequestedPartNumber +
        $leftResults.Count
    )

    $rightResults = Build-ArchiveBatch `
        -DatasetName $DatasetName `
        -SourceArchives $right `
        -RequestedPartNumber $nextNumber `
        -SevenZip $SevenZip `
        -MaximumBytes $MaximumBytes

    foreach ($result in $rightResults) {
        $results.Add($result)
    }

    return $results.ToArray()
}

function Rename-ArchiveParts {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$ArchiveResults,

        [Parameter(Mandatory = $true)]
        [string]$DatasetName
    )

    $renamed = [System.Collections.Generic.List[object]]::new()
    $ordered = @(
        $ArchiveResults |
        Sort-Object `
            firstSource, `
            lastSource
    )

    for ($index = 0; $index -lt $ordered.Count; $index++) {
        $partNumber = $index + 1

        $newName = "{0}-part-{1:D3}.zip" -f `
            $DatasetName, `
            $partNumber

        $newPath = Join-Path `
            $OutputDirectory `
            $newName

        if (
            $ordered[$index].archivePath -ne $newPath
        ) {
            if (Test-Path $newPath) {
                Remove-Item `
                    -Path $newPath `
                    -Force
            }

            Move-Item `
                -Path $ordered[$index].archivePath `
                -Destination $newPath `
                -Force
        }

        $file = Get-Item $newPath

        $renamed.Add(
            [PSCustomObject]@{
                dataset            = $DatasetName
                part               = $partNumber
                archiveName        = $file.Name
                archivePath        = $file.FullName
                archiveBytes       = $file.Length
                sourceArchiveCount = $ordered[$index].sourceArchiveCount
                firstSource        = $ordered[$index].firstSource
                lastSource         = $ordered[$index].lastSource
            }
        )
    }

    return $renamed.ToArray()
}

function Build-DatasetArchives {
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
        [long]$BatchSourceBytes
    )

    if (-not (Test-Path $SourceDirectory -PathType Container)) {
        throw "Dataset directory does not exist: $SourceDirectory"
    }

    $sourceArchives = @(
        Get-ChildItem `
            -Path $SourceDirectory `
            -Filter "*.zip" `
            -File |
        Sort-Object Name
    )

    if ($sourceArchives.Count -eq 0) {
        throw "No source ZIP files found in $SourceDirectory"
    }

    Write-Host ""
    Write-Host "Building dataset: $DatasetName"
    Write-Host "Source archives: $($sourceArchives.Count)"

    $sourceBytes = (
        $sourceArchives |
        Measure-Object `
            -Property Length `
            -Sum
    ).Sum

    Write-Host "Source compressed bytes: $sourceBytes"

    $batches = Split-FilesIntoBatches `
        -Files $sourceArchives `
        -MaximumSourceBytes $BatchSourceBytes

    $allResults = [System.Collections.Generic.List[object]]::new()
    $partNumber = 1

    foreach ($batch in $batches) {
        $batchFiles = @($batch)

        Write-Host ""
        Write-Host (
            "Processing batch with " +
            "$($batchFiles.Count) daily source archives."
        )

        $batchResults = Build-ArchiveBatch `
            -DatasetName $DatasetName `
            -SourceArchives $batchFiles `
            -RequestedPartNumber $partNumber `
            -SevenZip $SevenZip `
            -MaximumBytes $MaximumBytes

        foreach ($result in $batchResults) {
            $allResults.Add($result)
        }

        $partNumber += $batchResults.Count
    }

    return Rename-ArchiveParts `
        -ArchiveResults $allResults.ToArray() `
        -DatasetName $DatasetName
}

$SevenZip = Get-SevenZipExecutable

Clear-Directory $OutputDirectory
Clear-Directory $WorkingRoot

$NseSource = Join-Path `
    $RepositoryRoot `
    "Minute\NSE"

$IndexSource = Join-Path `
    $RepositoryRoot `
    "Minute\NSE_IDX"

$allAssets = [System.Collections.Generic.List[object]]::new()

# NSE stock data: one or more archives, each safely below 2 GiB.
$nseAssets = Build-DatasetArchives `
    -DatasetName "NSE-Minute" `
    -SourceDirectory $NseSource `
    -SevenZip $SevenZip `
    -MaximumBytes $MaximumArchiveBytes `
    -BatchSourceBytes $PreferredBatchSourceBytes

foreach ($asset in $nseAssets) {
    $allAssets.Add($asset)
}

# NSE index data: always maintained separately from stock data.
$indexAssets = Build-DatasetArchives `
    -DatasetName "NSE-Index-Minute" `
    -SourceDirectory $IndexSource `
    -SevenZip $SevenZip `
    -MaximumBytes $MaximumArchiveBytes `
    -BatchSourceBytes $PreferredBatchSourceBytes

foreach ($asset in $indexAssets) {
    $allAssets.Add($asset)
}

$manifestAssets = [System.Collections.Generic.List[object]]::new()
$checksumLines = [System.Collections.Generic.List[string]]::new()

foreach ($asset in $allAssets) {
    $file = Get-Item $asset.archivePath

    if ($file.Length -ge $MaximumArchiveBytes) {
        throw (
            "Generated asset exceeds the configured limit: " +
            "$($file.Name)"
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
            sha256             = $hash.Hash.ToLower()
            sourceArchiveCount = $asset.sourceArchiveCount
            firstSourceArchive = $asset.firstSource
            lastSourceArchive  = $asset.lastSource
        }
    )
}

$manifest = [ordered]@{
    generatedAtUtc = (
        Get-Date
    ).ToUniversalTime().ToString("o")

    maximumArchiveBytes = $MaximumArchiveBytes

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

Write-Host ""
Write-Host "Release archives created:"
Write-Host ""

foreach ($asset in $manifestAssets) {
    Write-Host (
        " - " +
        $asset.file +
        " (" +
        $asset.gibibytes +
        " GiB)"
    )
}

Write-Host ""
Write-Host "Manifest: $ManifestPath"
Write-Host "Checksums: $ChecksumPath"

if ($env:GITHUB_ENV) {
    "RELEASE_ASSET_DIRECTORY=$OutputDirectory" >> $env:GITHUB_ENV
    "RELEASE_MANIFEST=$ManifestPath" >> $env:GITHUB_ENV
    "RELEASE_CHECKSUMS=$ChecksumPath" >> $env:GITHUB_ENV
    "RELEASE_ASSET_COUNT=$($manifestAssets.Count)" >> $env:GITHUB_ENV
}