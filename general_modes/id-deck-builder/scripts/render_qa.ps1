# render_qa.ps1 - export every slide of a .pptx to PNG through PowerPoint COM, so the
# deck can be LOOKED AT (Read the PNGs) instead of trusted from python-pptx's report.
# No LibreOffice or poppler on this box does not mean no render: PowerPoint is installed.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File render_qa.ps1 -Path C:\out\deck.pptx [-OutDir C:\out\png] [-Width 1600] [-Height 900]
#
# Writes Slide1.PNG .. SlideN.PNG into -OutDir (default: <deck folder>\<deck name>-png) and
# prints the count. Close the deck in PowerPoint first: Office locks the file exclusively.
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$OutDir,
    [int]$Width = 1600,
    [int]$Height = 900
)
$ErrorActionPreference = 'Stop'
$full = (Resolve-Path $Path).Path
if (-not $OutDir) {
    $OutDir = Join-Path (Split-Path $full) ([IO.Path]::GetFileNameWithoutExtension($full) + '-png')
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

$pp = New-Object -ComObject PowerPoint.Application
try {
    # Open(FileName, ReadOnly, Untitled, WithWindow)
    $pres = $pp.Presentations.Open($full, -1, 0, 0)
    try {
        $pres.Export($OutDir, 'PNG', $Width, $Height)
        $count = $pres.Slides.Count
    } finally {
        $pres.Close()
    }
} finally {
    $pp.Quit()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($pp)
}
$pngs = @(Get-ChildItem $OutDir -Filter *.PNG)
Write-Output ("rendered {0} of {1} slides to {2}" -f $pngs.Count, $count, $OutDir)
if ($pngs.Count -ne $count) { exit 1 }
