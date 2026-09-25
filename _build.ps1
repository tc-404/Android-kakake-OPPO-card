# kakake build UI (saved as UTF-8 with BOM so Windows PowerShell reads 中文 correctly)
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $Host.UI.RawUI.WindowTitle = 'kakake · build' } catch {}
Set-Location -Path $PSScriptRoot
$env:npm_config_cache = Join-Path $PSScriptRoot '.npm-cache'

function Start-Cmd([string]$file, [string[]]$cmdArgs, [string]$log) {
  return Start-Process -FilePath $file -ArgumentList $cmdArgs -NoNewWindow -PassThru `
    -RedirectStandardOutput $log -RedirectStandardError ($log + '.err')
}

function Await([string]$title, $proc) {
  $frames = '|', '/', '-', '\'
  $i = 0
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  while (-not $proc.HasExited) {
    $fr = $frames[$i % 4]
    Write-Host ("`r    {0}  {1}   {2,5:0.0}s   " -f $fr, $title, $sw.Elapsed.TotalSeconds) -NoNewline -ForegroundColor Cyan
    Start-Sleep -Milliseconds 90
    $i++
  }
  $proc.WaitForExit()
  $sw.Stop()
  return @{ code = $proc.ExitCode; secs = $sw.Elapsed.TotalSeconds }
}

function Line-OK([string]$text, [double]$secs) {
  Write-Host ("`r    {0}  {1}   {2,5:0.0}s        " -f ([char]0x2714), $text, $secs) -ForegroundColor Green
}
function Line-Fail([string]$text) {
  Write-Host ("`r    x  {0}                         " -f $text) -ForegroundColor Red
}

$rule = ('    ' + ([string]([char]0x2500) * 42))
$total = [System.Diagnostics.Stopwatch]::StartNew()

# ---- Banner ----
Write-Host ''
Write-Host '    ' -NoNewline
Write-Host ([char]0x258C) -NoNewline -ForegroundColor Cyan
Write-Host ' kakake ' -NoNewline -ForegroundColor White
Write-Host ([char]0x8FDC + [string]([char]0x7A0B) + [char]0x76D1 + [string]([char]0x63A7)) -ForegroundColor White
Write-Host '    ' -NoNewline
Write-Host ([char]0x258C) -NoNewline -ForegroundColor Cyan
Write-Host ' QuickApp Desktop Widget  ' -ForegroundColor DarkGray
Write-Host $rule -ForegroundColor DarkCyan
Write-Host ''

# ---- Step 1 / 3 : dependencies ----
if (-not (Test-Path 'node_modules/hap-toolkit/bin/index.js')) {
  $npm = (Get-Command npm.cmd -ErrorAction SilentlyContinue).Source
  if (-not $npm) { $npm = 'npm.cmd' }
  $log = Join-Path $env:TEMP 'kakake_npm.log'
  $p = Start-Cmd $npm @('install') $log
  $r = Await '[1/3] 安装依赖 (首次较慢)' $p
  if ($r.code -ne 0 -or -not (Test-Path 'node_modules/hap-toolkit/bin/index.js')) {
    Line-Fail '[1/3] 安装依赖失败'
    Write-Host '       请检查网络后重试。' -ForegroundColor Yellow
    return
  }
  Line-OK '[1/3] 安装依赖' $r.secs
} else {
  Write-Host ("    {0}  [1/3] 依赖已就绪" -f ([char]0x2714)) -ForegroundColor Green
}

# ---- Step 2 / 3 : build ----
$blog = Join-Path $env:TEMP 'kakake_build.log'
$bp = Start-Cmd 'node' @('node_modules/hap-toolkit/bin/index.js', 'build') $blog
$br = Await '[2/3] 编译打包' $bp
$made = Get-ChildItem -Path 'dist' -Filter '*.rpk' -ErrorAction SilentlyContinue
if (-not $made) {
  Line-Fail '[2/3] 编译打包失败'
  if (Test-Path $blog) {
    Get-Content $blog -Tail 15 | ForEach-Object { Write-Host ('       ' + $_) -ForegroundColor DarkGray }
  }
  return
}
Line-OK '[2/3] 编译打包' $br.secs

# ---- Step 3 / 3 : collect artifact ----
$out = [string]([char]0x6210 + [char]0x54C1)   # 成品
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }
Get-ChildItem -Path $out -Filter '*.rpk' -ErrorAction SilentlyContinue | Remove-Item -Force
Move-Item -Force $made.FullName $out
Remove-Item -Recurse -Force 'dist', 'build' -ErrorAction SilentlyContinue
$rpk = Get-ChildItem -Path $out -Filter '*.rpk' | Select-Object -First 1
Write-Host ("    {0}  [3/3] 整理产物" -f ([char]0x2714)) -ForegroundColor Green

$total.Stop()
$sizeKB = [math]::Round($rpk.Length / 1KB, 1)

# ---- Result panel ----
Write-Host ''
Write-Host $rule -ForegroundColor DarkCyan
Write-Host '     ' -NoNewline
Write-Host ('[ ' + [string]([char]0x5B8C) + [char]0x6210 + ' ]') -ForegroundColor Green
Write-Host ('      ' + [char]0x5B89 + [string]([char]0x88C5) + [char]0x5305 + '  ') -NoNewline -ForegroundColor Gray
Write-Host ($out + '\' + $rpk.Name) -ForegroundColor White
Write-Host ('      ' + [char]0x5927 + [string]([char]0x5C0F) + '    ') -NoNewline -ForegroundColor Gray
Write-Host ("{0} KB" -f $sizeKB) -ForegroundColor White
Write-Host ('      ' + [char]0x7528 + [string]([char]0x65F6) + '    ') -NoNewline -ForegroundColor Gray
Write-Host ("{0:0.0}s" -f $total.Elapsed.TotalSeconds) -ForegroundColor White
Write-Host $rule -ForegroundColor DarkCyan
Write-Host ''
