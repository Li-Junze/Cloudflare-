' ============================================================
'  Cloudflare Pages Deployer - Silent Launcher
'  Starts the GUI without showing a console window.
'
'  Usage: double-click this file.
'  NOTE: keep this file ASCII-only for maximum portability.
' ============================================================
Option Explicit

Dim fso, shell, root, ps, cmd, problems
Set fso   = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

root = fso.GetParentFolderName(WScript.ScriptFullName)
ps   = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"

' ---------- preflight: report problems with a dialog instead of failing silently ----------
problems = ""

If Not fso.FileExists(root & "\src\main.ps1") Then
    problems = problems & "- src\main.ps1 is missing (incomplete extraction?)" & vbCrLf
End If

If Not fso.FileExists(ps) Then
    problems = problems & "- PowerShell not found (Windows 10/11 required)" & vbCrLf
End If

If fso.FileExists(root & "\src\main.ps1") Then
    ' check node and wrangler using the PATH from cmd (where.exe)
    If Not HasCommand(shell, "node") Then
        problems = problems & "- Node.js is not installed" & vbCrLf
    End If
    If Not HasCommand(shell, "wrangler") Then
        problems = problems & "- wrangler is not installed" & vbCrLf
    End If
End If

If Len(problems) > 0 Then
    If MsgBox("Cannot start - required components are missing:" & vbCrLf & vbCrLf & _
              problems & vbCrLf & _
              "Run init.bat to install everything automatically." & vbCrLf & vbCrLf & _
              "Run init.bat now?", _
              vbYesNo + vbExclamation, "Cloudflare Pages Deployer") = vbYes Then
        If fso.FileExists(root & "\init.bat") Then
            shell.Run """" & root & "\init.bat""", 1, False
        Else
            MsgBox "init.bat is also missing. Please re-download the package.", _
                   16, "Cloudflare Pages Deployer"
        End If
    End If
    WScript.Quit 1
End If

' ---------- launch hidden ----------
cmd = """" & ps & """ -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & root & "\src\main.ps1"""

' 0 = hidden window, False = do not wait
shell.Run cmd, 0, False
WScript.Quit 0

' ---------- helpers ----------
Function HasCommand(sh, name)
    Dim exitCode
    HasCommand = False
    On Error Resume Next
    exitCode = sh.Run("%ComSpec% /c where " & name & " >nul 2>&1", 0, True)
    If Err.Number = 0 Then
        If exitCode = 0 Then HasCommand = True
    End If
    On Error GoTo 0
End Function
