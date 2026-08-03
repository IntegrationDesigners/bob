<#
.SYNOPSIS
    Imports Bob modes from a source directory into a target project's custom_modes.yaml file.

.DESCRIPTION
    This script recursively scans a source directory for .bobmodes files, extracts the mode
    definitions, and imports them into the target project's .bob/custom_modes.yaml file.
    If the custom_modes.yaml file doesn't exist, it creates it. If it exists, it merges
    the modes, avoiding duplicates based on the mode slug.

.PARAMETER SourcePath
    The path to the directory containing .bobmodes files (default: current directory)

.PARAMETER TargetProjectPath
    The path to the target project where custom_modes.yaml should be created/updated

.EXAMPLE
    .\Import-BobModes.ps1 -SourcePath "D:\git\i8c_bobmodes\ace_modes" -TargetProjectPath "D:\Projects\MyProject"

.EXAMPLE
    .\Import-BobModes.ps1 -TargetProjectPath "D:\Projects\MyProject"
    # Uses current directory as source

.NOTES
    Author: Bob Mode Import Script
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = (Get-Location).Path,
    
    [Parameter(Mandatory=$true)]
    [string]$TargetProjectPath
)

# Function to parse YAML-like content from .bobmodes files
function Parse-BobModesFile {
    param([string]$FilePath)
    
    try {
        $content = Get-Content -Path $FilePath -Raw
        
        # Simple YAML parsing - extract the customModes array
        # This assumes the .bobmodes file has a "customModes:" section
        if ($content -match 'customModes:\s*\n([\s\S]*)') {
            return $content
        }
        
        return $null
    }
    catch {
        Write-Warning "Failed to parse $FilePath : $_"
        return $null
    }
}

# Function to extract mode slugs from YAML content
function Get-ModeSlugs {
    param([string]$YamlContent)
    
    $slugs = @()
    
    # Extract all slug values using regex
    $matches = [regex]::Matches($YamlContent, '^\s*-?\s*slug:\s*(.+)$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    
    foreach ($match in $matches) {
        $slug = $match.Groups[1].Value.Trim()
        $slugs += $slug
    }
    
    return $slugs
}

# Main script execution
Write-Host "Bob Modes Import Script" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host ""

# Validate source path
if (-not (Test-Path -Path $SourcePath)) {
    Write-Error "Source path does not exist: $SourcePath"
    exit 1
}

# Validate target project path
if (-not (Test-Path -Path $TargetProjectPath)) {
    Write-Error "Target project path does not exist: $TargetProjectPath"
    exit 1
}

Write-Host "Source Path: $SourcePath" -ForegroundColor Green
Write-Host "Target Project: $TargetProjectPath" -ForegroundColor Green
Write-Host ""

# Find all .bobmodes files recursively
Write-Host "Scanning for .bobmodes files..." -ForegroundColor Yellow
$bobmodesFiles = Get-ChildItem -Path $SourcePath -Filter ".bobmodes" -Recurse -File

if ($bobmodesFiles.Count -eq 0) {
    Write-Warning "No .bobmodes files found in $SourcePath"
    exit 0
}

Write-Host "Found $($bobmodesFiles.Count) .bobmodes file(s)" -ForegroundColor Green
Write-Host ""

# Parse all .bobmodes files and collect modes
$allModes = @()
$allModeSlugs = @()

foreach ($file in $bobmodesFiles) {
    Write-Host "  Processing: $($file.FullName)" -ForegroundColor Gray
    
    $content = Parse-BobModesFile -FilePath $file.FullName
    
    if ($content) {
        $slugs = Get-ModeSlugs -YamlContent $content
        
        if ($slugs.Count -gt 0) {
            $allModes += @{
                FilePath = $file.FullName
                Content = $content
                Slugs = $slugs
            }
            $allModeSlugs += $slugs
            
            Write-Host "    Found mode(s): $($slugs -join ', ')" -ForegroundColor Cyan
        }
    }
}

Write-Host ""
Write-Host "Total modes discovered: $($allModeSlugs.Count)" -ForegroundColor Green
Write-Host "  Modes: $($allModeSlugs -join ', ')" -ForegroundColor Cyan
Write-Host ""

# Check if .bob directory exists in target project
$bobDir = Join-Path -Path $TargetProjectPath -ChildPath ".bob"
$customModesFile = Join-Path -Path $bobDir -ChildPath "custom_modes.yaml"

# Create .bob directory if it doesn't exist
if (-not (Test-Path -Path $bobDir)) {
    Write-Host "Creating .bob directory..." -ForegroundColor Yellow
    New-Item -Path $bobDir -ItemType Directory -Force | Out-Null
}

# Check if custom_modes.yaml exists
$existingModes = @()
$existingSlugs = @()

if (Test-Path -Path $customModesFile) {
    Write-Host "Found existing custom_modes.yaml" -ForegroundColor Yellow
    
    $existingContent = Get-Content -Path $customModesFile -Raw
    $existingSlugs = Get-ModeSlugs -YamlContent $existingContent
    
    if ($existingSlugs.Count -gt 0) {
        Write-Host "  Existing modes: $($existingSlugs -join ', ')" -ForegroundColor Cyan
    }
    
    # Filter out modes that already exist
    $newModes = $allModes | Where-Object {
        $modeFile = $_
        $hasNewSlug = $false
        
        foreach ($slug in $modeFile.Slugs) {
            if ($slug -notin $existingSlugs) {
                $hasNewSlug = $true
                break
            }
        }
        
        return $hasNewSlug
    }
    
    if ($newModes.Count -eq 0) {
        Write-Host ""
        Write-Host "All modes already exist in custom_modes.yaml. No changes needed." -ForegroundColor Green
        exit 0
    }
    
    Write-Host ""
    Write-Host "Modes to add: $($newModes.Count)" -ForegroundColor Yellow
    
    # Append new modes to existing file
    $existingContent = Get-Content -Path $customModesFile -Raw
    
    # Remove the trailing content after customModes array if any
    # and prepare to append new modes
    $newContent = $existingContent.TrimEnd()
    
    foreach ($mode in $newModes) {
        # Extract just the mode definitions (skip the "customModes:" header)
        $modeContent = $mode.Content -replace '(?s)^customModes:\s*\n', ''
        
        # Add proper indentation for array items
        $newContent += "`n" + $modeContent.TrimEnd()
    }
    
    # Write the merged content
    Set-Content -Path $customModesFile -Value $newContent -NoNewline
    
    Write-Host ""
    Write-Host "Successfully merged modes into: $customModesFile" -ForegroundColor Green
    
} else {
    Write-Host "Creating new custom_modes.yaml..." -ForegroundColor Yellow
    
    # Create new file with all modes
    $newContent = "customModes:`n"
    
    foreach ($mode in $allModes) {
        # Extract just the mode definitions (skip the "customModes:" header)
        $modeContent = $mode.Content -replace '(?s)^customModes:\s*\n', ''
        $newContent += $modeContent.TrimEnd() + "`n"
    }
    
    # Write the new file
    Set-Content -Path $customModesFile -Value $newContent.TrimEnd() -NoNewline
    
    Write-Host ""
    Write-Host "Successfully created: $customModesFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "Import complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open VS Code in the target project: $TargetProjectPath" -ForegroundColor Gray
Write-Host "  2. Reload the window (Ctrl+Shift+P -> 'Reload Window')" -ForegroundColor Gray
Write-Host "  3. The new modes should now be available in Bob's mode selector" -ForegroundColor Gray

# Made with Bob
