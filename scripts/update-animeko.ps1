[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repository = 'open-ani/animeko'
$manifestPath = Join-Path $PSScriptRoot '..\bucket\animeko.json'
$headers = @{
    Accept = 'application/vnd.github+json'
    'User-Agent' = 'private-scoop-bucket-maintainer'
}

if ($env:GH_TOKEN) {
    $headers.Authorization = "Bearer $($env:GH_TOKEN)"
}

$release = Invoke-RestMethod `
    -Uri "https://api.github.com/repos/$repository/releases/latest" `
    -Headers $headers

if ($release.draft -or $release.prerelease) {
    throw "Latest GitHub release is not a stable release: $($release.tag_name)"
}

$version = $release.tag_name -replace '^v', ''
$assets = [ordered]@{
    '64bit' = "ani-$version-windows-x86_64.zip"
    'arm64' = "ani-$version-windows-aarch64.zip"
}

$architecture = [ordered]@{}
foreach ($entry in $assets.GetEnumerator()) {
    $asset = @($release.assets | Where-Object name -eq $entry.Value)
    if ($asset.Count -ne 1) {
        throw "Expected exactly one release asset '$($entry.Value)', found $($asset.Count)."
    }

    if (-not $asset[0].digest -or $asset[0].digest -notmatch '^sha256:[0-9a-f]{64}$') {
        throw "Release asset '$($entry.Value)' does not provide a SHA-256 digest."
    }

    $architecture[$entry.Key] = [ordered]@{
        url = $asset[0].browser_download_url
        hash = $asset[0].digest
        extract_dir = 'Ani'
    }
}

$manifest = [ordered]@{
    version = $version
    description = 'Cross-platform anime tracking and playback platform'
    homepage = 'https://animeko.org/'
    license = 'AGPL-3.0-only'
    architecture = $architecture
    bin = 'Ani.exe'
    shortcuts = @(, @('Ani.exe', 'Animeko'))
    checkver = 'github'
    autoupdate = [ordered]@{
        architecture = [ordered]@{
            '64bit' = [ordered]@{
                url = 'https://github.com/open-ani/animeko/releases/download/v$version/ani-$version-windows-x86_64.zip'
            }
            arm64 = [ordered]@{
                url = 'https://github.com/open-ani/animeko/releases/download/v$version/ani-$version-windows-aarch64.zip'
            }
        }
        extract_dir = 'Ani'
    }
}

$json = $manifest | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText((Resolve-Path $manifestPath), "$json`n", [System.Text.UTF8Encoding]::new($false))
Write-Host "Updated Animeko manifest to $version."
