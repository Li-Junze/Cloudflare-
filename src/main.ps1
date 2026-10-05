# ============================================================
#  Cloudflare Pages Deployer - 主程序
#  运行方式：start.bat  或  powershell -File src\main.ps1
# ============================================================
[CmdletBinding()]
param(
    [string]$DefaultDir,
    [switch]$NoWindow
)

$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $PSScriptRoot

# 加载所有模块
foreach ($mod in @('Ui.ps1', 'Wrangler.ps1', 'App.ps1')) {
    $p = Join-Path $PSScriptRoot $mod
    if (-not (Test-Path $p)) { throw "缺少模块：$p" }
    . $p
}

# 启动界面
Start-CfDeployer -DefaultDir $DefaultDir
