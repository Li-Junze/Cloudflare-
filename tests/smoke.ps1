# ============================================================
#  tests\smoke.ps1 —— 冒烟测试
#  用法：powershell -File tests\smoke.ps1
#  覆盖：模块加载、项目名规范化、wrangler 探测、登录状态、项目列表
# ============================================================
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root 'src'

$pass = 0; $fail = 0
function Check([string]$Name, [bool]$Ok, [string]$Detail = '') {
    if ($Ok) { Write-Host "  [PASS] $Name" -ForegroundColor Green; $script:pass++ }
    else     { Write-Host "  [FAIL] $Name  $Detail" -ForegroundColor Red; $script:fail++ }
}

Write-Host ""
Write-Host "Cloudflare Pages Deployer - 冒烟测试" -ForegroundColor Cyan
Write-Host ("-" * 56) -ForegroundColor DarkGray

# ---- 1. 模块文件存在 ----
Write-Host "[1] 模块文件" -ForegroundColor White
foreach ($m in @('main.ps1','Ui.ps1','Wrangler.ps1','App.ps1')) {
    Check $m (Test-Path (Join-Path $src $m))
}

# ---- 2. 语法解析 ----
Write-Host "[2] 语法检查" -ForegroundColor White
foreach ($m in @('main.ps1','Ui.ps1','Wrangler.ps1','App.ps1')) {
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $src $m), [ref]$null, [ref]$errs)
    $errText = if ($errs) { (($errs | ForEach-Object { $_.Message }) -join '; ') } else { '' }
    Check "$m 无语法错误" ($errs.Count -eq 0) $errText
}

# ---- 3. 加载纯逻辑模块（不用 WPF）----
Write-Host "[3] 逻辑函数" -ForegroundColor White
. (Join-Path $src 'Wrangler.ps1')
. (Join-Path $src 'App.ps1')   # 仅取 ConvertTo-CfProjectName，不会启动窗口

Check "ConvertTo-CfProjectName('index.html') = index-html" ((ConvertTo-CfProjectName 'index.html') -eq 'index-html')
Check "ConvertTo-CfProjectName('My Site!') = my-site"      ((ConvertTo-CfProjectName 'My Site!')   -eq 'my-site')
Check "ConvertTo-CfProjectName('---abc---') = abc"         ((ConvertTo-CfProjectName '---abc---')  -eq 'abc')
Check "ConvertTo-CfProjectName 限长 58"                    ((ConvertTo-CfProjectName ('x' * 100)).Length -eq 58)

# ---- 4. wrangler 探测 ----
Write-Host "[4] wrangler CLI" -ForegroundColor White
$wp = Get-WranglerPath
Check "定位到 wrangler" ([bool]$wp) "未找到，请运行 init.bat"
if ($wp) { Write-Host "        路径: $wp" -ForegroundColor DarkGray }

Check "Test-WranglerReady" (Test-WranglerReady)

if ($wp) {
    $ver = Invoke-WranglerText @('--version')
    Check "wrangler --version 有输出" ($ver -match '\d+\.\d+') $ver
    Write-Host "        版本: $(($ver -split "`n" | Where-Object { $_ -match '\d+\.\d+' } | Select-Object -First 1).Trim())" -ForegroundColor DarkGray
}

# ---- 5. 登录与项目列表 ----
Write-Host "[5] Cloudflare 连接" -ForegroundColor White
if ($wp) {
    $st = Get-LoginStatus
    Check "已登录 Cloudflare" $st.LoggedIn "请在界面中点「登录账号」"
    if ($st.LoggedIn) { Write-Host "        账号: $(if ($st.Email) { $st.Email } else { '已授权' })" -ForegroundColor DarkGray }

    if ($st.LoggedIn) {
        $projs = @(Get-PagesProjects)
        Check "拉取 Pages 项目列表" ($null -ne $projs)
        Write-Host "        共 $($projs.Count) 个项目：" -ForegroundColor DarkGray
        foreach ($p in $projs) { Write-Host "          - $($p.Name)  ($($p.Domain))" -ForegroundColor DarkGray }
    }
}

# ---- 汇总 ----
Write-Host ""
Write-Host ("-" * 56) -ForegroundColor DarkGray
$color = if ($fail -eq 0) { 'Green' } else { 'Red' }
Write-Host "结果：$pass 通过 / $fail 失败" -ForegroundColor $color
Write-Host ""
exit $fail
