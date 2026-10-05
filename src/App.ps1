# ============================================================
#  App.ps1 —— 应用逻辑（事件绑定 / 部署流程 / 项目管理）
# ============================================================

# 项目名规范化：Cloudflare 要求 1-58 位小写字母/数字/连字符，不能首尾为连字符
function ConvertTo-CfProjectName([string]$Raw) {
    if (-not $Raw) { return '' }
    $n = $Raw.ToLower() -replace '\s+', '-' -replace '[^a-z0-9-]', '-'
    $n = ($n -replace '-+', '-').Trim('-')
    if ($n.Length -gt 58) { $n = $n.Substring(0, 58).Trim('-') }
    return $n
}

function Start-CfDeployer {
    param([string]$DefaultDir)

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms

    $win = [Windows.Markup.XamlReader]::Parse((Get-MainWindowXaml))

    # 控件引用（脚本作用域，供内部函数使用）
    $names = @('TxtDir','TxtDirHint','TxtName','TxtNameHint','TxtUrl','TxtLog','PBar',
               'BtnDeploy','BtnBrowse','BtnLogin','BtnManage','BtnOpen','BtnClear',
               'DotState','TxtState','TxtLinkText','BtnOpenUrl','BtnCopy')
    $script:Ui = @{}
    foreach ($n in $names) { $script:Ui[$n] = $win.FindName($n) }
    $script:LastUrl = $null

    # ---------------- 日志 ----------------
    function Write-Log {
        param([string]$Msg, [string]$Kind = 'info')
        $stamp = (Get-Date).ToString('HH:mm:ss')
        $prefix = switch ($Kind) {
            'ok'   { '[OK]   ' }
            'err'  { '[错误] ' }
            'warn' { '[提示] ' }
            'step' { '[执行] ' }
            default { '[信息] ' }
        }
        $line = "$stamp $prefix$Msg"
        $tb = $script:Ui['TxtLog']
        if ($tb) { $tb.AppendText($line + "`r`n"); $tb.ScrollToEnd() }
        else { Write-Host $line }
    }

    function Set-Busy([bool]$Busy) {
        foreach ($k in @('BtnDeploy','BtnBrowse','BtnLogin','BtnManage')) { $script:Ui[$k].IsEnabled = -not $Busy }
        $bar = $script:Ui['PBar']
        $bar.Visibility = if ($Busy) { 'Visible' } else { 'Hidden' }
        $bar.IsIndeterminate = $Busy
    }

    function Update-UrlPreview {
        $n = ConvertTo-CfProjectName $script:Ui['TxtName'].Text
        $script:Ui['TxtUrl'].Text = if ($n) { "→ https://$n.pages.dev" } else { '' }
    }

    # 部署成功后，把线上地址显示到常驻的「线上地址」栏
    function Show-DeployedUrl([string]$Url) {
        $script:LastUrl = $Url
        $tb = $script:Ui['TxtLinkText']
        $tb.Text = $Url
        $tb.Foreground = (New-Object Windows.Media.BrushConverter).ConvertFromString('#2563EB')
        $tb.ToolTip = '点击全选，或用右侧按钮复制 / 打开'
        foreach ($k in @('BtnCopy','BtnOpenUrl')) { $script:Ui[$k].IsEnabled = $true }
    }

    function Update-DirHint {
        $d = $script:Ui['TxtDir'].Text.Trim().Trim('"')
        $hint = $script:Ui['TxtDirHint']
        if (-not (Test-Path $d)) { $hint.Text = '文件夹里要有 index.html'; $hint.Foreground = '#6B7280'; return }
        if (Test-Path (Join-Path $d 'index.html')) {
            $hint.Text = '已检测到 index.html ✓'; $hint.Foreground = '#16A34A'
        } else {
            $hint.Text = '该目录没有 index.html（部署后首页可能 404）'; $hint.Foreground = '#D97706'
        }
    }

    function Update-LoginState {
        if (-not (Test-WranglerReady)) {
            $script:Ui['DotState'].Fill = [Windows.Media.Brushes]::Gray
            $script:Ui['TxtState'].Text = '未安装 wrangler'
            return
        }
        $st = Get-LoginStatus
        if ($st.LoggedIn) {
            $script:Ui['DotState'].Fill = [Windows.Media.Brushes]::SeaGreen
            $script:Ui['TxtState'].Text = "已登录：$(if ($st.Email) { $st.Email } else { '已授权' })"
        } else {
            $script:Ui['DotState'].Fill = [Windows.Media.Brushes]::OrangeRed
            $script:Ui['TxtState'].Text = '未登录，请点左下角「登录账号」'
        }
    }

    # ---------------- 事件 ----------------
    $script:Ui['BtnClear'].Add_Click({ $script:Ui['TxtLog'].Clear() })
    $script:Ui['TxtName'].Add_TextChanged({ Update-UrlPreview })

    # 「线上地址」栏：复制 / 打开 / 点击全选
    $script:Ui['BtnCopy'].Add_Click({
        if (-not $script:LastUrl) { return }
        Set-Clipboard -Value $script:LastUrl
        $script:Ui['BtnCopy'].Content = '已复制 ✓'
        Write-Log '链接已复制到剪贴板，可直接粘贴分享。' 'ok'
        $script:CopyTimer = New-Object Windows.Threading.DispatcherTimer
        $script:CopyTimer.Interval = [TimeSpan]::FromSeconds(1.6)
        $script:CopyTimer.Add_Tick({
            $script:Ui['BtnCopy'].Content = '复制链接'
            $script:CopyTimer.Stop()
        })
        $script:CopyTimer.Start()
    })
    $script:Ui['BtnOpenUrl'].Add_Click({
        if ($script:LastUrl) { Start-Process $script:LastUrl }
    })
    $script:Ui['TxtLinkText'].Add_GotFocus({ $script:Ui['TxtLinkText'].SelectAll() })

    $script:Ui['TxtDir'].Add_TextChanged({
        $d = $script:Ui['TxtDir'].Text.Trim().Trim('"')
        Update-DirHint
        if ((Test-Path $d) -and -not $script:Ui['TxtName'].Text) {
            $script:Ui['TxtName'].Text = ConvertTo-CfProjectName (Split-Path (Resolve-Path $d) -Leaf)
        }
    })

    $script:Ui['BtnBrowse'].Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = '选择要部署的网站文件夹（作为站点根目录）'
        $dlg.ShowNewFolderButton = $false
        if ($dlg.ShowDialog() -eq 'OK') {
            $script:Ui['TxtDir'].Text = $dlg.SelectedPath
            $script:Ui['TxtName'].Text = ConvertTo-CfProjectName (Split-Path $dlg.SelectedPath -Leaf)
            Update-UrlPreview
        }
    })

    $script:Ui['BtnLogin'].Add_Click({
        Set-Busy $true
        Write-Log '打开浏览器进行 Cloudflare 授权…' 'step'
        try {
            Start-Process (Get-WranglerPath) -ArgumentList 'login' -Wait -NoNewWindow
            Write-Log '授权流程结束，刷新状态…' 'info'
        } catch { Write-Log "登录失败：$($_.Exception.Message)" 'err' }
        Set-Busy $false
        Update-LoginState
    })

    $script:Ui['BtnOpen'].Add_Click({ Start-Process 'https://dash.cloudflare.com' })

    $script:Ui['BtnManage'].Add_Click({
        $win2 = [Windows.Markup.XamlReader]::Parse((Get-ProjectsWindowXaml))
        $lb = $win2.FindName('LbProjects')
        $script:ProjList = @()

        $reload = {
            $lb.Items.Clear()
            $items = Get-PagesProjects
            $script:ProjList = @($items)
            foreach ($p in $items) { [void]$lb.Items.Add(("{0,-24} {1}" -f $p.Name, $p.Domain)) }
            if ($lb.Items.Count -eq 0) { [void]$lb.Items.Add('（无项目，或读取失败）') }
        }

        $win2.FindName('BRefresh').Add_Click($reload)
        $win2.FindName('BClose').Add_Click({ $win2.Close() })

        $win2.FindName('BOpenSite').Add_Click({
            $i = $lb.SelectedIndex
            if ($i -ge 0 -and $i -lt $script:ProjList.Count) {
                Start-Process "https://$($script:ProjList[$i].Domain)"
            }
        })

        $win2.FindName('BDelete').Add_Click({
            $i = $lb.SelectedIndex
            if ($i -lt 0 -or $i -ge $script:ProjList.Count) { return }
            $p = $script:ProjList[$i]
            $r = [System.Windows.MessageBox]::Show(
                "确定删除项目 '$($p.Name)' 吗？`n`n线上站点将立即失效，不可恢复。",
                '危险操作确认', 'YesNo', 'Warning')
            if ($r -eq 'Yes') {
                [void](Invoke-WranglerText @('pages','project','delete',$p.Name,'--yes'))
                Write-Log "已删除项目 $($p.Name)" 'warn'
                & $reload
            }
        })

        & $reload
        $win2.Owner = $win
        [void]$win2.ShowDialog()
    })

    # ---------------- 部署流程 ----------------
    $script:Ui['BtnDeploy'].Add_Click({
        $dirRaw = $script:Ui['TxtDir'].Text.Trim().Trim('"')
        if (-not $dirRaw) {
            [System.Windows.MessageBox]::Show('请先选择要部署的网站文件夹。', '缺少信息', 'OK', 'Warning') | Out-Null
            return
        }
        $dir = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($dirRaw))
        if (-not (Test-Path $dir)) {
            [System.Windows.MessageBox]::Show("文件夹不存在：`n$dir", '路径错误', 'OK', 'Warning') | Out-Null
            return
        }
        $name = ConvertTo-CfProjectName $script:Ui['TxtName'].Text
        if (-not $name) {
            [System.Windows.MessageBox]::Show('项目名不合法（只能小写字母、数字、连字符）。', '项目名错误', 'OK', 'Warning') | Out-Null
            return
        }
        $script:Ui['TxtName'].Text = $name

        Set-Busy $true
        try {
            $script:Ui['TxtLog'].Clear()
            Write-Log '开始部署' 'info'
            Write-Log "源目录 : $dir" 'info'
            Write-Log "项目名 : $name" 'info'

            if (Test-PagesProjectExists $name) {
                Write-Log '项目已存在，直接部署新版本。' 'info'
            } else {
                Write-Log "项目 $name 不存在，先创建…" 'step'
                $code = Invoke-WranglerStream -WrArgs @('pages','project','create',$name,'--production-branch=main') `
                    -OnLine { param($l, $k) Write-Log $l $k } -OnLog { param($l, $k) Write-Log $l $k }
                if ($code -ne 0) { Write-Log '项目创建失败，请检查项目名是否被占用。' 'err'; return }
            }

            $code = Invoke-WranglerStream -WrArgs @('pages','deploy',$dir,"--project-name=$name") `
                -OnLine { param($l, $k) Write-Log $l $k } -OnLog { param($l, $k) Write-Log $l $k }

            if ($code -eq 0) {
                Show-DeployedUrl "https://$name.pages.dev"
                Write-Log '部署成功！线上地址（首次生效可能有几十秒缓存）：' 'ok'
                Write-Log $script:LastUrl 'ok'
                Write-Log '地址已显示在上方「线上地址」栏，可一键复制或打开。' 'ok'
            } else {
                Write-Log '部署失败，请查看上方日志。' 'err'
            }
        } catch {
            Write-Log "发生异常：$($_.Exception.Message)" 'err'
        } finally {
            Set-Busy $false
        }
    })

    # ---------------- 初始化 ----------------
    $win.Add_Loaded({
        Write-Log 'Cloudflare 网页部署工具已就绪' 'ok'
        if (Test-WranglerReady) {
            Write-Log "wrangler : $(Get-WranglerPath)" 'info'
        } else {
            Write-Log '未找到 wrangler！请先运行项目根目录的 init.bat' 'err'
        }
        if ($DefaultDir) {
            $script:Ui['TxtDir'].Text = $DefaultDir
            $script:Ui['TxtName'].Text = ConvertTo-CfProjectName (Split-Path $DefaultDir -Leaf)
        }
        Update-UrlPreview
        Update-LoginState
    })

    $win.ShowDialog() | Out-Null
}
