# ============================================================
#  Wrangler.ps1 —— wrangler CLI 调用封装
#  所有外部进程调用集中在此，便于测试与维护
# ============================================================

# 定位 wrangler 可执行文件。优先 .cmd（批处理包装器），ProcessStartInfo 调用最稳
function Get-WranglerPath {
    $cmd = Join-Path $env:APPDATA 'npm\wrangler.cmd'
    if (Test-Path $cmd) { return $cmd }
    $c = Get-Command wrangler.cmd -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $c = Get-Command wrangler -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}

# 构建 cmd /c 参数字符串
# 关键：必须用 "call"，不能写成 /c ""exe" args"（双引号嵌套会静默失败）
function New-WranglerCmdLine([string]$Exe, [string[]]$WrArgs) {
    $quoted = ($WrArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    return "/c call `"$Exe`" $quoted"
}

# 同步执行并返回文本（强制 UTF-8，避免 GBK 乱码破坏表格解析）
function Invoke-WranglerText {
    param(
        [Parameter(Mandatory)][string[]]$WrArgs,
        [int]$TimeoutSec = 120
    )
    $exe = Get-WranglerPath
    if (-not $exe) { return '' }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $env:ComSpec
    $psi.Arguments = New-WranglerCmdLine $exe $WrArgs
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $out = $proc.StandardOutput.ReadToEnd()
    $err = $proc.StandardError.ReadToEnd()
    if (-not $proc.WaitForExit($TimeoutSec * 1000)) { try { $proc.Kill() } catch {} }
    $script:LastExitCode = $proc.ExitCode
    return (($out + $err) -replace "\x1B\[[0-9;]*[a-zA-Z]", '')
}

# 流式执行：输出逐行回调给 $OnLine，用于实时日志
function Invoke-WranglerStream {
    param(
        [Parameter(Mandatory)][string[]]$WrArgs,
        [scriptblock]$OnLine,
        [scriptblock]$OnLog
    )
    $exe = Get-WranglerPath
    if (-not $exe) {
        if ($OnLog) { & $OnLog '找不到 wrangler，请先运行 init.bat 安装' 'err' }
        return -1
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $env:ComSpec
    $psi.Arguments = New-WranglerCmdLine $exe $WrArgs
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    [void]$proc.Start()

    $outLines = New-Object System.Collections.ArrayList
    $errLines = New-Object System.Collections.ArrayList
    $null = Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action {
        if ($null -ne $EventArgs.Data) { [void]$Event.MessageData.Add($EventArgs.Data) }
    } -MessageData $outLines
    $null = Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action {
        if ($null -ne $EventArgs.Data) { [void]$Event.MessageData.Add($EventArgs.Data) }
    } -MessageData $errLines

    $proc.BeginOutputReadLine()
    $proc.BeginErrorReadLine()
    $proc.WaitForExit()
    Start-Sleep -Milliseconds 250      # 等事件回调吐完最后几行
    Get-EventSubscriber | Where-Object { $_.SourceObject -eq $proc } | Unregister-Event -ErrorAction SilentlyContinue
    $sw.Stop()

    $noise = @('Proxy environment variables')
    foreach ($l in $outLines) {
        $clean = ($l -replace "\x1B\[[0-9;]*[a-zA-Z]", '').TrimEnd()
        if ([string]::IsNullOrWhiteSpace($clean)) { continue }
        $skip = $false
        foreach ($n in $noise) { if ($clean -match $n) { $skip = $true; break } }
        if ($skip) { continue }
        if ($OnLine) { & $OnLine $clean 'info' }
    }
    $errNoise = @('Proxy environment variables','CategoryInfo','FullyQualifiedErrorId','所在位置','^\s*\+','^\s*$')
    foreach ($l in $errLines) {
        $clean = ($l -replace "\x1B\[[0-9;]*[a-zA-Z]", '').TrimEnd()
        if ([string]::IsNullOrWhiteSpace($clean)) { continue }
        $skip = $false
        foreach ($n in $errNoise) { if ($clean -match $n) { $skip = $true; break } }
        if ($skip) { continue }
        if ($OnLine) { & $OnLine $clean 'err' }
    }
    if ($OnLog) { & $OnLog "耗时 $([math]::Round($sw.Elapsed.TotalSeconds,1)) 秒，退出码 $($proc.ExitCode)" 'info' }
    $script:LastExitCode = $proc.ExitCode
    return $proc.ExitCode
}

# 确保 wrangler 已就绪，返回 $true/$false
function Test-WranglerReady {
    return [bool](Get-WranglerPath)
}

# 查询登录状态，返回 @{ LoggedIn; Email; Raw }
function Get-LoginStatus {
    $raw = Invoke-WranglerText @('whoami')
    $loggedIn = [bool]($raw -match 'You are logged in with|associated with the email')
    $email = ''
    if ($raw -match 'email\s+([^\s]+@[^\s]+?)[\s\.]') { $email = $Matches[1] }
    return @{ LoggedIn = $loggedIn; Email = $email; Raw = $raw }
}

# 拉取 Pages 项目列表 -> @( @{Name; Domain} )
function Get-PagesProjects {
    $raw = Invoke-WranglerText @('pages','project','list')
    $list = @()
    foreach ($ln in ($raw -split "`r?`n")) {
        if ($ln -match '^\s*[│|]\s*([a-z0-9][a-z0-9-]*)\s*[│|]\s*(\S+)') {
            $nm = $Matches[1]; $dom = $Matches[2]
            if ($nm -match '^(Project|Total|Name)$') { continue }
            $list += [PSCustomObject]@{ Name = $nm; Domain = $dom }
        }
    }
    return $list
}

# 判断项目是否存在
function Test-PagesProjectExists([string]$Name) {
    $projects = Get-PagesProjects
    foreach ($p in $projects) { if ($p.Name -eq $Name) { return $true } }
    return $false
}
