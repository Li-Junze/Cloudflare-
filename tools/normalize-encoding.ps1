#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = 'C:\Users\39969\WorkBuddy\cloudflare-pages-deployer'
$log  = 'C:\Users\39969\WorkBuddy\cloudflare-pages-deployer\.tmp\normalize.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
$out = New-Object System.Collections.ArrayList

function Say($s) { [void]$out.Add($s) }

# ---- 1. .ps1 -> UTF-8 with BOM + CRLF ----
$psFiles = @(
  'src\main.ps1','src\Ui.ps1','src\Wrangler.ps1','src\App.ps1',
  'tests\smoke.ps1','tools\capture.ps1'
)
foreach ($rel in $psFiles) {
  $f = Join-Path $root $rel
  $t = [IO.File]::ReadAllText($f, [Text.UTF8Encoding]::new($false))
  $t = ($t -replace "`r`n", "`n") -replace "`n", "`r`n"
  [IO.File]::WriteAllText($f, $t, [Text.UTF8Encoding]::new($true))
  Say "  [PS  BOM+CRLF] $rel"
}

# ---- 2. .bat/.cmd/.vbs -> ASCII + CRLF ----
$cfgFiles = @('init.bat','start.bat','test.bat','start-silent.vbs')
foreach ($rel in $cfgFiles) {
  $f = Join-Path $root $rel
  $t = [IO.File]::ReadAllText($f, [Text.UTF8Encoding]::new($false))
  $t = ($t -replace "`r`n", "`n") -replace "`n", "`r`n"
  [IO.File]::WriteAllText($f, $t, [Text.ASCIIEncoding]::new())
  Say "  [ASC CRLF    ] $rel"
}

# ---- 3. text -> UTF-8 no BOM + LF ----
$txtFiles = @('.gitignore','.gitattributes','.editorconfig','.encoding-note.txt',
              'requirements.txt','LICENSE','CONTRIBUTING.md','README.md',([char]0x4F7F+[char]0x7528+[char]0x8BF4+[char]0x660E+'.md'))
foreach ($rel in $txtFiles) {
  $f = Join-Path $root $rel
  if (-not (Test-Path $f)) { Say "  [MISSING     ] $rel"; continue }
  $bytes = [IO.File]::ReadAllBytes($f)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $bytes = $bytes[3..($bytes.Length-1)]
  }
  $t = [Text.Encoding]::UTF8.GetString($bytes)
  $t = $t -replace "`r`n", "`n"
  [IO.File]::WriteAllText($f, $t, [Text.UTF8Encoding]::new($false))
  Say "  [TXT noBOM+LF] $rel"
}

Say ""
Say "NORMALIZE-DONE"

$out -join "`r`n" | Set-Content -Path $log -Encoding UTF8
