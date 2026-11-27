# Rawnaq TV check: collects what is needed to fix drawing problems (overlapping shapes, icons, text)
# on a specific TV: model, Android version, graphics chip, screen size, Rawnaq version, errors, and screenshots.
# Everything is saved in the tv-check folder next to this file. Nothing is changed on the TV.
param([string]$TvIp = "")
$ErrorActionPreference = "Continue"
$src = $PSScriptRoot
$pkg = "com.rawnaq"
function Step($t) { Write-Host ""; Write-Host "==> $t" -ForegroundColor Cyan }
function Good($t) { Write-Host "    $t" -ForegroundColor Green }
function Warn($t) { Write-Host "    $t" -ForegroundColor Yellow }

$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) {
    $adb = @("$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe", "$env:ANDROID_HOME\platform-tools\adb.exe",
             (Join-Path $env:USERPROFILE "rawnaq_build\platform-tools\adb.exe")) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $adb) { Write-Host "adb not found. Run install.bat once first." -ForegroundColor Red; Read-Host "Enter to close"; exit 1 }
function Adb { $o = & $script:adb @args 2>&1 | ForEach-Object { "$_" }; return (($o -join "`n").Trim()) }

if (-not $TvIp) {
    $saved = @(); $f = Join-Path $src "tvs.txt"
    if (Test-Path $f) { $saved = @(Get-Content $f | Where-Object { $_.Trim() }) }
    Write-Host "Which TV shows the problem?"
    for ($i = 0; $i -lt $saved.Count; $i++) { Write-Host ("  {0}) {1}" -f ($i + 1), $saved[$i]) }
    $a = (Read-Host "Number or IP address").Trim()
    if ($a -match '^\d+$' -and [int]$a -ge 1 -and [int]$a -le $saved.Count) { $TvIp = ($saved[[int]$a - 1] -split '\s+')[0] } else { $TvIp = $a }
}
$ip = ($TvIp -split ':')[0]
$tv = "${ip}:5555"
$out = Join-Path $src ("tv-check\" + ($ip -replace '\.', '-'))
New-Item -ItemType Directory -Force -Path $out | Out-Null
$report = Join-Path $out "report.txt"

Step "Connecting to $tv"
$ok = $false
for ($i = 0; $i -lt 10 -and -not $ok; $i++) {
    Adb connect $tv | Out-Null
    if ((Adb -s $tv get-state) -eq "device") { $ok = $true; break }
    if ($i -eq 0) { Warn "If the TV shows 'Allow debugging?', tick 'Always allow' and press OK." }
    Start-Sleep -Seconds 3
}
if (-not $ok) { Write-Host "    Could not reach $tv." -ForegroundColor Red; Read-Host "Enter to close"; exit 1 }

Step "Reading the TV details"
$r = New-Object System.Collections.Generic.List[string]
function Add($k, $v) { $r.Add(("{0,-14} {1}" -f $k, $v)); Write-Host ("    {0,-14} {1}" -f $k, $v) }
Add "Brand"     (Adb -s $tv shell getprop ro.product.manufacturer)
Add "Model"     (Adb -s $tv shell getprop ro.product.model)
Add "Android"   ("{0} (SDK {1})" -f (Adb -s $tv shell getprop ro.build.version.release), (Adb -s $tv shell getprop ro.build.version.sdk))
Add "Board"     ("{0} / {1}" -f (Adb -s $tv shell getprop ro.board.platform), (Adb -s $tv shell getprop ro.hardware))
$gles = (Adb -s $tv shell "dumpsys SurfaceFlinger | grep -i -m 2 GLES") -replace "`n", " | "
Add "Graphics"  $gles
Add "OpenGL ES" (Adb -s $tv shell getprop ro.opengles.version)
Add "Vulkan"    ((Adb -s $tv shell "pm list features | grep -i vulkan") -replace "`n", " ")
Add "Screen"    ((Adb -s $tv shell wm size) -replace "`n", " ")
Add "Density"   ((Adb -s $tv shell wm density) -replace "`n", " ")
Add "Font scale" (Adb -s $tv shell settings get system font_scale)
Add "Rawnaq"    ((Adb -s $tv shell "dumpsys package $pkg | grep -m 2 -E 'versionName|versionCode'") -replace "`n", " ")
Add "Memory"    ((Adb -s $tv shell "grep -E 'MemTotal|MemAvailable' /proc/meminfo") -replace "`n", " | ")
[IO.File]::WriteAllLines($report, $r)

Step "Taking screenshots of Rawnaq"
Adb -s $tv shell am start -a android.intent.action.MAIN -c android.intent.category.HOME | Out-Null
Start-Sleep -Seconds 4
function Shot($name) {
    Adb -s $tv shell screencap -p "/sdcard/rawnaq-$name.png" | Out-Null
    Adb -s $tv pull "/sdcard/rawnaq-$name.png" (Join-Path $out "$name.png") | Out-Null
    Adb -s $tv shell rm -f "/sdcard/rawnaq-$name.png" | Out-Null
    if (Test-Path (Join-Path $out "$name.png")) { Good "$name.png" } else { Warn "could not take $name" }
}
Shot "1-home"
Write-Host ""
Write-Host "    Now, with the TV remote, open the screen where you saw the overlapping." -ForegroundColor Yellow
Read-Host "    Press Enter here when that screen is showing"
Shot "2-problem"
$more = Read-Host "    Another screen with the problem? Open it and press Enter (or type n to finish)"
if ($more -ne 'n') { Shot "3-problem" }

Step "Collecting Rawnaq errors"
$log = Adb -s $tv shell "logcat -d -t 3000 | grep -i -E 'flutter|RAWNAQ|rawnaq|OpenGL|EGL|GLES|skia|impeller' | tail -n 400"
[IO.File]::WriteAllText((Join-Path $out "errors.txt"), $log)

Write-Host ""
Good "Done. Send everything in this folder to Claude:"
Write-Host "    $out" -ForegroundColor White
Start-Process explorer.exe $out
