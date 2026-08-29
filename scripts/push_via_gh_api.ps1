[CmdletBinding()]
param(
    [string]$Repository = 'hongpengWu/rv32-dsp-core',
    [string]$Branch = 'main',
    [string]$GhPath = 'E:\DevTools\GitHubCLI\bin\gh.exe'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path -LiteralPath $GhPath)) {
    throw "GitHub CLI not found: $GhPath"
}

function Invoke-GhJson {
    param(
        [Parameter(Mandatory)] [string]$Endpoint,
        [Parameter(Mandatory)] [hashtable]$Body,
        [ValidateSet('POST', 'PATCH')] [string]$Method = 'POST'
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $GhPath
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.ArgumentList.Add('api')
    $startInfo.ArgumentList.Add($Endpoint)
    $startInfo.ArgumentList.Add('--method')
    $startInfo.ArgumentList.Add($Method)
    $startInfo.ArgumentList.Add('--input')
    $startInfo.ArgumentList.Add('-')

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $process.StandardInput.Write(($Body | ConvertTo-Json -Depth 10 -Compress))
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "gh api failed for $Endpoint`n$stderr"
    }

    return $stdout | ConvertFrom-Json
}

function Get-GitBlobBase64 {
    param([Parameter(Mandatory)] [string]$ObjectId)

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = (Get-Command git).Source
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.ArgumentList.Add('cat-file')
    $startInfo.ArgumentList.Add('blob')
    $startInfo.ArgumentList.Add($ObjectId)

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $memory = [System.IO.MemoryStream]::new()
    $process.StandardOutput.BaseStream.CopyTo($memory)
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "git cat-file failed for $ObjectId`n$stderr"
    }

    return [Convert]::ToBase64String($memory.ToArray())
}

$commits = @(& git -C $repoRoot rev-list --reverse $Branch)
if ($LASTEXITCODE -ne 0 -or $commits.Count -eq 0) {
    throw "No commits found on branch $Branch"
}

$uploadedBlobs = @{}
$remoteParent = $null

foreach ($commit in $commits) {
    $entries = @()
    foreach ($line in @(& git -C $repoRoot ls-tree -r $commit)) {
        if ($line -notmatch '^(\d+)\s+blob\s+([0-9a-f]+)\t(.+)$') {
            throw "Unexpected git ls-tree line: $line"
        }

        $mode = $Matches[1]
        $blobId = $Matches[2]
        $path = $Matches[3]

        if (-not $uploadedBlobs.ContainsKey($blobId)) {
            $blob = Invoke-GhJson -Endpoint "repos/$Repository/git/blobs" -Body @{
                content  = Get-GitBlobBase64 -ObjectId $blobId
                encoding = 'base64'
            }
            if ($blob.sha -ne $blobId) {
                throw "Blob SHA mismatch for ${path}: local=$blobId remote=$($blob.sha)"
            }
            $uploadedBlobs[$blobId] = $true
        }

        $entries += @{
            path = $path
            mode = $mode
            type = 'blob'
            sha  = $blobId
        }
    }

    $tree = Invoke-GhJson -Endpoint "repos/$Repository/git/trees" -Body @{
        tree = $entries
    }
    $localTree = (& git -C $repoRoot show -s --format=%T $commit).Trim()
    if ($tree.sha -ne $localTree) {
        throw "Tree SHA mismatch for commit ${commit}: local=$localTree remote=$($tree.sha)"
    }

    $message = (@(& git -C $repoRoot show -s --format=%B $commit) -join "`n").TrimEnd()
    $parents = [System.Collections.Generic.List[string]]::new()
    if ($null -ne $remoteParent) {
        $parents.Add($remoteParent)
    }
    $newCommit = Invoke-GhJson -Endpoint "repos/$Repository/git/commits" -Body @{
        message   = $message
        tree      = $tree.sha
        parents   = $parents
        author    = @{
            name  = (& git -C $repoRoot show -s --format=%an $commit).Trim()
            email = (& git -C $repoRoot show -s --format=%ae $commit).Trim()
            date  = (& git -C $repoRoot show -s --format=%aI $commit).Trim()
        }
        committer = @{
            name  = (& git -C $repoRoot show -s --format=%cn $commit).Trim()
            email = (& git -C $repoRoot show -s --format=%ce $commit).Trim()
            date  = (& git -C $repoRoot show -s --format=%cI $commit).Trim()
        }
    }

    if ($newCommit.sha -ne $commit) {
        throw "Commit SHA mismatch: local=$commit remote=$($newCommit.sha)"
    }
    $remoteParent = $newCommit.sha
    Write-Host "Uploaded commit $commit"
}

[void](Invoke-GhJson -Endpoint "repos/$Repository/git/refs/heads/$Branch" `
    -Method 'PATCH' -Body @{
        sha   = $remoteParent
        force = $true
    })

& git -C $repoRoot update-ref "refs/remotes/origin/$Branch" $remoteParent
& git -C $repoRoot config "branch.$Branch.remote" origin
& git -C $repoRoot config "branch.$Branch.merge" "refs/heads/$Branch"

Write-Host "Published $Repository branch $Branch at $remoteParent"
