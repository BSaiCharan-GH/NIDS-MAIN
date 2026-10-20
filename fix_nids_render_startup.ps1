$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath '.\app.py')) {
    throw 'app.py was not found. Open PowerShell in the NIDS-MAIN repository folder and run this script again.'
}

$path = (Resolve-Path -LiteralPath '.\app.py').Path
$text = [System.IO.File]::ReadAllText($path)
$original = $text

# Fix the malformed duplicated conditional that prevents Gunicorn from importing app.py.
$badConditional = '(?m)^    if kind not in \{"syn_dos", "portscan"\}:\r?\n    if kind not in \{"syn_dos", "portscan"\}:\r?\n        return \{"running": False, "error": "unsupported packet test"\}'
$goodConditional = '    if kind not in {"syn_dos", "portscan"}:' + "`n" + '        return {"running": False, "error": "unsupported packet test"}'
$count = [regex]::Matches($text, $badConditional).Count
if ($count -ne 1) {
    throw "Expected to find the known indentation defect exactly once, but found $count. No file changes were written. Confirm your local repository is synced to commit 29fdf1a or newer, then share the current app.py around _run_attack_test."
}
$text = [regex]::Replace($text, $badConditional, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $goodConditional }, 1)

# Remove deployment-patch duplicate statements without altering their surrounding logic.
$duplicatePatterns = @(
    @{
        Name = 'duplicate file-handler sid assignment'
        Pattern = '(?m)^(    sid = request\.sid\r?\n    if PUBLIC_DEMO_MODE:\r?\n        emit\("system", \{"msg": "File sharing is disabled in the public demo\. Do not upload private files\."\}\)\r?\n        return\r?\n)    sid = request\.sid\r?\n(?=    content = data\.get\("content", ""\))'
    },
    @{
        Name = 'duplicate DNS runner source_ip assignment'
        Pattern = '(?m)^(    if PUBLIC_DEMO_MODE:\r?\n        return \{"running": False, "status": "disabled", "error": PUBLIC_DEMO_NOTICE\}\r?\n    source_ip = str\(source_ip or client_meta\.get\(sid, \{\}\)\.get\("source_ip"\) or "local-test"\)\r?\n)    source_ip = str\(source_ip or client_meta\.get\(sid, \{\}\)\.get\("source_ip"\) or "local-test"\)\r?\n'
    },
    @{
        Name = 'duplicate attack-handler sid assignment'
        Pattern = '(?m)^(    sid = request\.sid\r?\n    if PUBLIC_DEMO_MODE:\r?\n        emit\("attack_test_started", \{"ok": False, "error": PUBLIC_DEMO_NOTICE\}\)\r?\n        return\r?\n)    sid = request\.sid\r?\n(?=    if not session_registry\.is_attacker\(sid\):)'
    },
    @{
        Name = 'duplicate login record lookup'
        Pattern = '(?m)^(    if PUBLIC_DEMO_MODE:\r?\n        return jsonify\(\{"ok": False, "error": PUBLIC_DEMO_NOTICE\}\), 403\r?\n    record = _current_login\(\)\r?\n)    record = _current_login\(\)\r?\n(?=    if not record or record\["role"\] != ATTACKER:)'
    }
)
$cleaned = @()
foreach ($item in $duplicatePatterns) {
    $n = [regex]::Matches($text, $item.Pattern).Count
    if ($n -eq 1) {
        $text = [regex]::Replace($text, $item.Pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Groups[1].Value }, 1)
        $cleaned += $item.Name
    } elseif ($n -gt 1) {
        throw "Found more than one match for $($item.Name). No changes were written."
    }
}

if ($text -eq $original) { throw 'No changes were made. app.py may already be fixed.' }
[System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))

Write-Host 'Patched app.py. Checking Python syntax...' -ForegroundColor Cyan
python -m py_compile .\app.py
if ($LASTEXITCODE -ne 0) {
    [System.IO.File]::WriteAllText($path, $original, [System.Text.UTF8Encoding]::new($false))
    throw 'Python syntax check failed; original app.py has been restored. Send the new error output.'
}

Write-Host 'SUCCESS: app.py passes Python syntax checking.' -ForegroundColor Green
Write-Host 'Changes applied:' -ForegroundColor Cyan
Write-Host ' - Removed the duplicate conditional causing the Render crash.'
foreach ($name in $cleaned) { Write-Host " - Cleaned $name." }
Write-Host ''
Write-Host 'Next run these commands to push the fix and trigger Render auto-deploy:' -ForegroundColor Yellow
Write-Host '  git add app.py'
Write-Host '  git commit -m "Fix NIDS Render startup indentation"'
Write-Host '  git push origin main'
Write-Host ''
Write-Host 'Do not rerun the original publish_nids_render.ps1 patch script.'
