# 参与开发

感谢你愿意改进这个项目。本文档说明开发约定与提交流程。

---

## 一、本地开发

```cmd
git clone https://github.com/Li-Junze/Cloudflare-.git
cd Cloudflare-
init.bat        :: 首次：安装 Node.js / wrangler 并登录
start.bat       :: 打开界面
test.bat        :: 跑冒烟测试
```

改界面不需要重新部署，直接改 `src/` 下的文件再 `start.bat` 即可。

---

## 二、目录约定

| 路径 | 职责 |
|---|---|
| `src/main.ps1` | 入口，加载模块后启动界面 |
| `src/Ui.ps1` | 所有 XAML 与主题色，**不含业务逻辑** |
| `src/Wrangler.ps1` | 所有外部进程调用（wrangler CLI）的唯一出口 |
| `src/App.ps1` | 事件绑定、部署流程、项目管理 |
| `tests/smoke.ps1` | 冒烟测试，改动后必须跑 |
| `tools/capture.ps1` | 界面截图（开发用） |

**改动原则**：想替换底层命令实现，只需要动 `Wrangler.ps1`；想换界面，只需要动 `Ui.ps1`。

---

## 三、编码红线（最容易踩的坑）

| 文件类型 | 要求 | 违反后果 |
|---|---|---|
| `*.ps1` | **UTF-8 with BOM** + CRLF | 中文乱码、脚本静默失败 |
| `*.bat` / `*.cmd` | **纯 ASCII** + CRLF | 双击闪退、`'xx' is not recognized` |
| `*.vbs` | **纯 ASCII** + CRLF | 同上 |
| `*.md` | UTF-8 无 BOM + LF | 一般无影响 |

`.gitattributes` 已强制 `*.ps1` / `*.bat` / `*.vbs` 使用 CRLF，但 **BOM 不会被 Git 管理**，
新增 `.ps1` 时请手动确认有 BOM。

改完 `.ps1` 后补 BOM：

```powershell
$f = 'src\App.ps1'
$t = [IO.File]::ReadAllText($f, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($f, $t, [Text.UTF8Encoding]::new($true))
```

---

## 四、提交前自检

```cmd
test.bat
```

必须 `0 失败`。测试覆盖：模块完整性、语法解析、项目名规范化、wrangler 探测、登录状态、项目列表。

> 未登录 Cloudflare 时，「已登录」一项会 FAIL，属正常现象——先跑一次 `wrangler login`。

---

## 五、几条已知的坑（别再踩一遍）

1. **调用 npm 全局命令**必须用 `cmd /c call "wrangler.cmd" <args>`。
   写成 `/c ""exe" args`（双引号嵌套）会**静默失败**。
2. **读取子进程输出**必须设 `StandardOutputEncoding = UTF8`，
   否则 GBK 环境下 `wrangler pages project list` 的表格会乱码，解析全废。
3. **`setlocal enabledelayedexpansion` 下**，`echo` 里的装饰性 `!` 会被当变量展开符吃掉。
4. **不要把账号信息写进任何文件**。`.wrangler/` 已在 `.gitignore` 中，切勿强行加入版本库。

---

## 六、提交信息

建议格式（中文或英文均可）：

```
fix: 修复项目列表在 GBK 环境下的解析失败
feat: 增加部署历史记录
docs: 补充无 winget 环境的手动安装步骤
```

---

## 七、安全问题

请勿在 Issue / PR 中粘贴：Cloudflare 账号 ID、邮箱、API Token、`.wrangler/` 目录内容。
如发现密钥泄露风险，请通过 Issue 描述现象即可，不要贴出真实凭据。
