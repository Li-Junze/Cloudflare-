# ============================================================
#  tools\capture.ps1 —— 界面截图（开发用）
#  无需人工交互即可截取界面，用于排版目检
#  用法：powershell -File tools\capture.ps1 [-OutFile preview.png]
# ============================================================
param(
    [string]$OutFile = "$PSScriptRoot\..\preview.png",
    [string]$FillDir  = '',
    [string]$FillName = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root 'src'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

. (Join-Path $src 'Ui.ps1')
. (Join-Path $src 'Wrangler.ps1')

$win = [Windows.Markup.XamlReader]::Parse((Get-MainWindowXaml))

# 预填内容（可选）
if ($FillDir)  { $win.FindName('TxtDir').Text  = $FillDir }
if ($FillName) { $win.FindName('TxtName').Text = $FillName }

$win.Show()
for ($i = 0; $i -lt 20; $i++) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 120 }
$win.UpdateLayout()

$w = [int]$win.ActualWidth; $h = [int]$win.ActualHeight
if ($w -le 0) { $w = 940 }; if ($h -le 0) { $h = 740 }

$rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
$rtb.Render($win)
$enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
$enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))

$outFull = [System.IO.Path]::GetFullPath($OutFile)
$fs = [System.IO.File]::Create($outFull)
$enc.Save($fs); $fs.Close()
$win.Close()

Write-Host "截图已保存: $outFull  ($w x $h)" -ForegroundColor Green
