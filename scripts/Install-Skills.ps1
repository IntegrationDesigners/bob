<#
.SYNOPSIS
    Installs the skills in this repository into Bob's (or Claude Code's) skill directories.

.DESCRIPTION
    Bob discovers a skill by the FOLDER NAME it sits under - not by the `name:` in the
    SKILL.md frontmatter. It reads, in this order:

        <workspace folder>\.bob\skills\<name>\SKILL.md      (workspace scope)
        <workspace folder>\.claude\skills\<name>\SKILL.md
        %USERPROFILE%\.bob\skills\<name>\SKILL.md           (global scope)
        %USERPROFILE%\.agents\skills\<name>\SKILL.md
        %USERPROFILE%\.claude\skills\<name>\SKILL.md

    Workspace scope means one VS Code *workspace folder*, not the .code-workspace file. A
    task is bound to a single folder (New Task asks which one when a workspace has several),
    and only that folder's .bob\skills is in scope. Global scope is the same for every
    folder, every workspace and every window - which is why it is the default here.

    Phase 1 is the point of this script: the folder name, the SKILL.md `name:` and the
    .bobmodes `slug:` must be the same string, and that string must be a valid Bob skill
    name (kebab-case, max 64 characters). Bob silently drops a skill whose folder name is
    not valid kebab-case, so a folder called flow_builder never loads and never says why.
    If any skill disagrees, NOTHING is installed.

    Foreign entries in the target directory - real directories from other sources, links
    pointing outside this repository - are never touched. A real directory that shadows one
    of our skills is moved to a skills-backup folder beside it, never deleted.

.PARAMETER Agent
    Bob (default), Claude, or Both. Bob also reads ~\.claude\skills, so -Agent Bob is
    enough unless you want the skills to outlive Bob being uninstalled.

.PARAMETER ProjectPath
    Install into <ProjectPath>\.bob\skills instead of the global directory. Use this to ship
    a skill with a repository; anyone opening that folder in Bob gets it. It only applies to
    that folder, and only when the workspace is trusted.

.PARAMETER Method
    Junction (default for a global install) links to this repository, so edits here are
    live. Copy (default for a project install) makes a standalone copy you can commit.

.PARAMETER Name
    Install only the named skills. Validation still runs over all of them.

.PARAMETER Prune
    Also remove junctions for skills that no longer exist here (leftovers from a rename).
    Copies are never pruned - a copy is indistinguishable from a hand-installed skill.

.EXAMPLE
    .\scripts\Install-Skills.ps1 -WhatIf
    Preview a global install into %USERPROFILE%\.bob\skills. Changes nothing.

.EXAMPLE
    .\scripts\Install-Skills.ps1 -Agent Both -Prune
    Install/refresh into ~\.bob\skills and ~\.claude\skills, clearing renamed leftovers.

.EXAMPLE
    .\scripts\Install-Skills.ps1 -ProjectPath D:\Projects\MyApp -Name ace-review
    Copy just ace-review into D:\Projects\MyApp\.bob\skills so it ships with that project.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('Bob', 'Claude', 'Both')]
    [string]$Agent = 'Bob',

    [string]$ProjectPath,

    [ValidateSet('Junction', 'Copy')]
    [string]$Method,

    [string[]]$Name,

    [switch]$Prune
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
# Skills live under these roots. Anything else in the repository (CI config, the mode import
# script, graphify output) is not a skill and is never scanned.
$skillRoots = @('ace_modes', 'general_modes')
# Trailing separator matters: without it a sibling directory whose name merely starts with
# this one (bob-github2) would be mistaken for ours.
$repoPrefix = $repoRoot.TrimEnd('\') + '\'

# Never copied into a target project. These hold real customer or personal detail; they are
# gitignored here, but a local working copy still has them on disk.
$excludedFromCopy = @('.env', 'customer_profile.md')
$excludedDirsFromCopy = @('log')

# Bob's own rule (bob-code: isValidSkillName). A name that fails this is dropped in silence.
$validSkillName = '^[a-z0-9]+(-[a-z0-9]+)*$'
$reservedNames = @('builtin', 'global', 'workspace')

function Get-FrontmatterName {
    param([string]$SkillMd)
    foreach ($line in Get-Content $SkillMd -TotalCount 20) {
        if ($line -match '^name:\s*(.+?)\s*$') { return $Matches[1] }
    }
    return $null
}

function Get-BobmodesSlug {
    param([string]$Bobmodes)
    foreach ($line in Get-Content $Bobmodes -TotalCount 40) {
        if ($line -match '^\s*-?\s*slug:\s*(.+?)\s*$') { return $Matches[1] }
    }
    return $null
}

function Install-Junction {
    param([string]$Link, [string]$Source)
    cmd /c mklink /J "$Link" "$Source" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not create junction $Link -> $Source. Re-run with -Method Copy if the target is not on NTFS."
    }
}

function Install-Copy {
    param([string]$Link, [string]$Source)
    Copy-Item -Path $Source -Destination $Link -Recurse -Force
    Get-ChildItem $Link -Recurse -Force |
        Where-Object { ($excludedFromCopy -contains $_.Name) -or ($_.PSIsContainer -and $excludedDirsFromCopy -contains $_.Name) } |
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
}

# --- Phase 1: discover and validate -----------------------------------------
# Nothing is touched until every skill passes. A mismatch here is a hard failure, not a
# warning: installing a skill whose folder and frontmatter disagree means typing one name
# while every document describes another.

$desired = @{}
# Every skill in the repository, unaffected by -Name. The leftover pass below compares
# against this, so `-Name one-skill -Prune` prunes renamed leftovers, not the eight skills
# this run was simply not asked to install.
$allSkills = @{}
$problems = @()
$modeOnly = @()

foreach ($root in $skillRoots) {
    $rootPath = Join-Path $repoRoot $root
    if (-not (Test-Path $rootPath)) { continue }

    Get-ChildItem $rootPath -Recurse -Directory -Force |
        Where-Object { (Test-Path (Join-Path $_.FullName 'SKILL.md')) -or (Test-Path (Join-Path $_.FullName '.bobmodes')) } |
        ForEach-Object {
            $folder = $_.Name
            $skillMd = Join-Path $_.FullName 'SKILL.md'
            $bobmodes = Join-Path $_.FullName '.bobmodes'

            if (-not (Test-Path $skillMd)) {
                # A .bobmodes with no SKILL.md is a Bob mode only - importable with
                # Import-BobModes.ps1, not installable as a skill.
                $modeOnly += $_.FullName.Substring($repoRoot.Length + 1)
                return
            }

            $declared = Get-FrontmatterName $skillMd
            if (-not $declared) {
                $problems += "$folder : SKILL.md has no 'name:' in its frontmatter"
            } elseif ($declared -ne $folder) {
                $problems += "$folder : folder name vs SKILL.md name: '$declared'"
            }

            if (Test-Path $bobmodes) {
                $slug = Get-BobmodesSlug $bobmodes
                if ($slug -and $slug -ne $folder) {
                    $problems += "$folder : folder name vs .bobmodes slug: '$slug'"
                }
            }

            if ($folder -cnotmatch $validSkillName) {
                $problems += "$folder : not a valid skill name - kebab-case, lower-case letters and digits only (Bob drops it in silence)"
            } elseif ($folder.Length -gt 64) {
                $problems += "$folder : name is longer than 64 characters"
            } elseif ($reservedNames -contains $folder.ToLower()) {
                $problems += "$folder : name is reserved by Bob"
            }

            if ($desired.ContainsKey($folder)) {
                $problems += "$folder : duplicate skill name (also at $($desired[$folder]))"
            } else {
                $desired[$folder] = $_.FullName
                $allSkills[$folder] = $_.FullName
            }
        }
}

if ($problems.Count -gt 0) {
    Write-Host ''
    Write-Host 'Name drift detected - nothing was installed:' -ForegroundColor Red
    $problems | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host ''
    Write-Host 'Folder name, SKILL.md name: and .bobmodes slug: must be identical and kebab-case.'
    exit 1
}

if ($desired.Count -eq 0) { Write-Host 'No skills found.'; exit 1 }
Write-Host "Validated $($desired.Count) skills - folder name, frontmatter name and slug agree."

if ($modeOnly.Count -gt 0) {
    Write-Host "Bob-mode only, no SKILL.md (use Import-BobModes.ps1): $($modeOnly -join ', ')" -ForegroundColor DarkGray
}

if ($Name) {
    $unknown = @($Name | Where-Object { -not $desired.ContainsKey($_) })
    if ($unknown.Count -gt 0) {
        Write-Host "Unknown skill name(s): $($unknown -join ', ')" -ForegroundColor Red
        Write-Host "Available: $(($desired.Keys | Sort-Object) -join ', ')"
        exit 1
    }
    $filtered = @{}
    foreach ($n in $Name) { $filtered[$n] = $desired[$n] }
    $desired = $filtered
    Write-Host "Installing $($desired.Count) of them: $(($desired.Keys | Sort-Object) -join ', ')"
}

# --- Destinations -----------------------------------------------------------

if ($ProjectPath) {
    if (-not (Test-Path $ProjectPath)) { throw "Project path not found: $ProjectPath" }
    $projectFull = (Resolve-Path $ProjectPath).Path
    $scopeLabel = "project ($projectFull)"
    $agentDirs = @()
    if ($Agent -eq 'Bob' -or $Agent -eq 'Both') { $agentDirs += (Join-Path $projectFull '.bob') }
    if ($Agent -eq 'Claude' -or $Agent -eq 'Both') { $agentDirs += (Join-Path $projectFull '.claude') }
    if (-not $Method) { $Method = 'Copy' }
} else {
    $scopeLabel = 'global'
    $agentDirs = @()
    if ($Agent -eq 'Bob' -or $Agent -eq 'Both') { $agentDirs += (Join-Path $env:USERPROFILE '.bob') }
    if ($Agent -eq 'Claude' -or $Agent -eq 'Both') { $agentDirs += (Join-Path $env:USERPROFILE '.claude') }
    if (-not $Method) { $Method = 'Junction' }
}

$targets = ($agentDirs | ForEach-Object { Join-Path $_ 'skills' }) -join ', '
Write-Host "Scope: $scopeLabel   Method: $Method"
Write-Host "Target: $targets"

# A blanket ".bob/" line in a project's .gitignore also lands in the exclude list Bob builds
# for its own file search, so project skills can go unseen on the initial scan.
if ($ProjectPath) {
    $gitignore = Join-Path $projectFull '.gitignore'
    if (Test-Path $gitignore) {
        $hits = @(Get-Content $gitignore | Where-Object { $_.Trim() -match '^\.(bob|claude)/?$' })
        if ($hits.Count -gt 0) {
            Write-Host ''
            Write-Host "Warning: $gitignore ignores $($hits -join ', ') wholesale." -ForegroundColor Yellow
            Write-Host '  Bob derives its file-search excludes from .gitignore, so skills under that' -ForegroundColor Yellow
            Write-Host '  directory can be missed on the initial scan. Ignore the noisy subfolders' -ForegroundColor Yellow
            Write-Host '  instead (.bob/tasks/, .bob/.bob-errors/) and keep .bob/skills/ visible.' -ForegroundColor Yellow
        }
    }
}

# --- Phase 2 and 3: classify what is installed, then apply ------------------
# A dangling junction is invisible to Test-Path (it resolves the target, which is gone)
# while the directory entry still exists and still blocks mklink. So enumerate the parent
# and read the reparse data instead of testing the path.

$exitCode = 0

foreach ($agentDir in $agentDirs) {
    $skillsDir = Join-Path $agentDir 'skills'
    $backupDir = Join-Path $agentDir 'skills-backup'

    Write-Host ''
    Write-Host "=== $skillsDir ===" -ForegroundColor Cyan

    if (-not (Test-Path $skillsDir)) {
        if ($PSCmdlet.ShouldProcess($skillsDir, 'create skills directory')) {
            New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
        }
    }

    $existing = @{}
    Get-ChildItem $skillsDir -Force -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $existing[$_.Name] = $_
    }

    $actions = New-Object System.Collections.Generic.List[object]

    foreach ($skillName in $desired.Keys | Sort-Object) {
        $source = $desired[$skillName]

        if (-not $existing.ContainsKey($skillName)) {
            $actions.Add([pscustomobject]@{ Name = $skillName; Action = 'Create'; Detail = $source })
            continue
        }

        $entry = $existing[$skillName]
        $isLink = [bool]($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)

        if ($isLink) {
            # Windows PowerShell hands back a string[] here, PowerShell 7 a string. Take the
            # first element either way rather than relying on member enumeration to hide it.
            $target = @($entry.Target)[0]
            if ($target) { $target = $target.TrimEnd('\') }
            $ours = $target -and $target.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)
            if (-not $ours) {
                $actions.Add([pscustomobject]@{ Name = $skillName; Action = 'Skip-Foreign'; Detail = "link points outside this repository -> $target" })
            } elseif ($Method -eq 'Copy') {
                $actions.Add([pscustomobject]@{ Name = $skillName; Action = 'Replace'; Detail = "was a junction -> $target" })
            } elseif ($target -eq $source.TrimEnd('\')) {
                $actions.Add([pscustomobject]@{ Name = $skillName; Action = 'Unchanged'; Detail = $target })
            } else {
                $actions.Add([pscustomobject]@{ Name = $skillName; Action = 'Recreate'; Detail = "was -> $target" })
            }
            continue
        }

        # A real directory. Only replace it if it is a copy of one of OUR skills - decided by
        # reading its frontmatter, never by comparing folder names. A stale copy can sit under
        # a differently-spelled folder than the name it declares.
        $itsSkillMd = Join-Path $entry.FullName 'SKILL.md'
        $itsName = $null
        if (Test-Path $itsSkillMd) { $itsName = Get-FrontmatterName $itsSkillMd }
        if ($itsName -and $desired.ContainsKey($itsName)) {
            if ($Method -eq 'Copy') {
                $actions.Add([pscustomobject]@{ Name = $skillName; Action = 'Refresh'; Detail = 'existing copy replaced from this repository' })
            } else {
                $actions.Add([pscustomobject]@{ Name = $skillName; Action = 'Replace'; Detail = "stale real copy (declares '$itsName') -> backed up" })
            }
        } else {
            $actions.Add([pscustomobject]@{ Name = $skillName; Action = 'Skip-Foreign'; Detail = 'real directory, not one of ours' })
        }
    }

    # Leftovers under a name we no longer use. Two kinds:
    #   - a junction into this repository whose skill was renamed
    #   - a real COPY of one of our skills sitting under its old folder name. Folder-name
    #     comparison cannot find these (the copy is called flow_builder while it declares
    #     ace-flow-builder), so match on the declared frontmatter name. Left alone, such a
    #     copy keeps being discovered as a second, stale skill.
    foreach ($skillName in $existing.Keys | Sort-Object) {
        if ($allSkills.ContainsKey($skillName)) { continue }
        $entry = $existing[$skillName]
        $isLink = [bool]($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)

        if ($isLink) {
            $target = @($entry.Target)[0]
            if ($target -and $target.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                if ($Prune) {
                    $actions.Add([pscustomobject]@{ Name = $skillName; Action = 'Prune'; Detail = "stale junction -> $target" })
                } else {
                    $actions.Add([pscustomobject]@{ Name = $skillName; Action = 'Stale'; Detail = 'points into this repository but no such skill; re-run with -Prune' })
                }
            }
            continue
        }

        $itsSkillMd = Join-Path $entry.FullName 'SKILL.md'
        if (-not (Test-Path $itsSkillMd)) { continue }
        $itsName = Get-FrontmatterName $itsSkillMd
        if ($itsName -and $allSkills.ContainsKey($itsName)) {
            $actions.Add([pscustomobject]@{ Name = $skillName; Action = 'Backup-Stale'; Detail = "real copy declaring '$itsName' under an old folder name" })
        }
    }

    foreach ($a in $actions) {
        $link = Join-Path $skillsDir $a.Name
        $source = $null
        if ($desired.ContainsKey($a.Name)) { $source = $desired[$a.Name] }

        switch ($a.Action) {
            'Create' {
                if ($PSCmdlet.ShouldProcess($link, "install ($Method)")) {
                    if ($Method -eq 'Junction') { Install-Junction $link $source } else { Install-Copy $link $source }
                }
            }
            'Recreate' {
                if ($PSCmdlet.ShouldProcess($link, 'recreate junction')) {
                    cmd /c rmdir "$link" | Out-Null
                    Install-Junction $link $source
                }
            }
            'Refresh' {
                if ($PSCmdlet.ShouldProcess($link, 'refresh copy from this repository')) {
                    Remove-Item -Path $link -Recurse -Force
                    Install-Copy $link $source
                }
            }
            'Replace' {
                if ($PSCmdlet.ShouldProcess($link, "back up what is there and install ($Method)")) {
                    $wasLink = [bool]((Get-Item $link -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)
                    if ($wasLink) {
                        cmd /c rmdir "$link" | Out-Null
                    } else {
                        # Move OUT of the skills directory - a backup left in place would itself
                        # be discovered as a skill.
                        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
                        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                        Move-Item -Path $link -Destination (Join-Path $backupDir "$($a.Name)-$stamp") -Force
                    }
                    if ($Method -eq 'Junction') { Install-Junction $link $source } else { Install-Copy $link $source }
                }
            }
            'Prune' {
                if ($PSCmdlet.ShouldProcess($link, 'remove stale junction')) {
                    # cmd /c rmdir removes the link only. Remove-Item -Recurse has historically
                    # followed junctions and deleted the target's contents.
                    cmd /c rmdir "$link" | Out-Null
                }
            }
            'Backup-Stale' {
                if ($PSCmdlet.ShouldProcess($link, 'move stale copy out of the skills directory')) {
                    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
                    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                    Move-Item -Path $link -Destination (Join-Path $backupDir "$($a.Name)-$stamp") -Force
                }
            }
        }
    }

    Write-Host ''
    $actions | Sort-Object Action, Name | Format-Table -AutoSize Name, Action, Detail
    $summary = $actions | Group-Object Action | ForEach-Object { "$($_.Name)=$($_.Count)" }
    Write-Host ("Summary: " + ($summary -join ', '))

    $conflicts = @($actions | Where-Object { $_.Action -eq 'Skip-Foreign' -and $desired.ContainsKey($_.Name) })
    if ($conflicts.Count -gt 0) {
        Write-Host ''
        Write-Host "$($conflicts.Count) skill(s) could not be installed - a foreign entry occupies the name:" -ForegroundColor Yellow
        $conflicts | ForEach-Object { Write-Host "  $($_.Name): $($_.Detail)" -ForegroundColor Yellow }
        $exitCode = 1
    }

    $stale = @($actions | Where-Object { $_.Action -eq 'Stale' })
    if ($stale.Count -gt 0) {
        Write-Host ''
        Write-Host "$($stale.Count) stale junction(s) left in place. Re-run with -Prune to remove them." -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host 'Bob watches these directories and picks changes up without a restart; if a new skill'
Write-Host 'does not show up under Settings > Skills, reload the window (Developer: Reload Window).'
Write-Host 'Claude Code enumerates skills at session start - start a new session there.'
if ($ProjectPath) {
    Write-Host ''
    Write-Host 'Project-scope skills only apply to tasks running in THAT folder, and only when the'
    Write-Host 'workspace is trusted. In a multi-root workspace, New Task asks which folder you are in.'
}

exit $exitCode
