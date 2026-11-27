# Rawnaq rescue: brings the TV back to its original home screen immediately,
# turns off private DNS, then collects the real reason the launcher did not show.
param([string]$TvIp = "")
$ErrorActionPreference = "Continue"
$src = $PSScriptRoot
$out = Join-Path $src "rescue"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$log = Join-Path $out "rescue-log.txt"
try { Start-Transcript -Path $log -Force | Out-Null } catch {}
$pkg = "com.rawnaq"
function Step($t) { Write-Host ""; Write-Host "==> $t" -ForegroundColor Cyan }
function Info($t) { Write-Host "    $t" }
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
    # الشاشات المحفوظة على هذي الحاسبة بس (tvs.txt)
    $saved = @(); $f = Join-Path $PSScriptRoot "tvs.txt"
    if (Test-Path $f) { $saved = @(Get-Content $f | Where-Object { $_.Trim() }) }
    Write-Host "Which TV is stuck?"
    for ($i = 0; $i -lt $saved.Count; $i++) { Write-Host ("  {0}) {1}" -f ($i + 1), $saved[$i]) }
    $a = (Read-Host "Number or IP address").Trim()
    if ($a -match '^\d+$' -and [int]$a -ge 1 -and [int]$a -le $saved.Count) { $TvIp = ($saved[[int]$a - 1] -split '\s+')[0] } else { $TvIp = $a }
}
$ip = ($TvIp -split ':')[0]
$tv = "${ip}:5555"

Step "Connecting to $tv"
Adb kill-server | Out-Null
Adb start-server | Out-Null
$ok = $false
for ($i = 0; $i -lt 20 -and -not $ok; $i++) {
    $r = Adb connect $tv
    $st = Adb -s $tv get-state
    if ($st -eq "device") { $ok = $true; break }
    if ($i -eq 0) { Info "adb connect -> $r" ; Warn "If the TV shows 'Allow debugging?', tick 'Always allow' and press OK." }
    Start-Sleep -Seconds 3
}
if (-not $ok) {
    Write-Host "    Could not reach $tv. Unplug the TV power for 10 seconds, plug it back, wait 1 minute, then run rescue.bat again." -ForegroundColor Red
    try { Stop-Transcript | Out-Null } catch {}
    Read-Host "Enter to close"; exit 1
}
Good "Connected: $(Adb -s $tv shell getprop ro.product.manufacturer) $(Adb -s $tv shell getprop ro.product.model)  Android $(Adb -s $tv shell getprop ro.build.version.release)"

Step "1) Giving the TV its original home screen back"
foreach ($p in @("com.google.android.apps.tv.launcherx", "com.google.android.tvlauncher", "com.google.android.leanbacklauncher")) {
    $has = Adb -s $tv shell pm list packages -u $p
    if ($has -match [regex]::Escape("package:$p")) { Info (Adb -s $tv shell pm enable $p) }
}
$undo = Join-Path $src "undo-home.txt"
if (Test-Path $undo) {
    foreach ($l in Get-Content $undo) { if ($l -match "pm enable (\S+)") { Adb -s $tv shell pm enable $Matches[1] | Out-Null } }
}
Adb -s $tv shell settings put global private_dns_mode off | Out-Null
Good "Original home screen enabled, ad-blocking DNS off."

Step "2) Collecting the reason (saved in the 'rescue' folder)"
Adb -s $tv shell am force-stop $pkg | Out-Null
Adb -s $tv logcat -c | Out-Null
Info "Starting Rawnaq once and watching it for 25 seconds..."
Info (Adb -s $tv shell am start -W -n "$pkg/.MainActivity")
Start-Sleep -Seconds 25
$appPid = Adb -s $tv shell pidof $pkg
Info "Process: $(if ($appPid) { $appPid } else { 'NOT RUNNING (crashed)' })"
Info ("Resumed: " + ((Adb -s $tv shell dumpsys activity activities) -split "`n" | Where-Object { $_ -match 'mResumedActivity|topResumedActivity' } | Select-Object -First 2) -join ' | ')
Adb -s $tv shell screencap -p /sdcard/rawnaq-screen.png | Out-Null
Adb -s $tv pull /sdcard/rawnaq-screen.png (Join-Path $out "screen.png") | Out-Null
[IO.File]::WriteAllText((Join-Path $out "logcat-full.txt"), (Adb -s $tv logcat -d -v time))
[IO.File]::WriteAllText((Join-Path $out "logcat-crash.txt"), (Adb -s $tv logcat -d -b crash -v time))
$app = (Adb -s $tv logcat -d -v time) -split "`n" | Where-Object { $_ -match 'rawnaq|flutter|AndroidRuntime|FATAL|ANR|RAWNAQ-ERROR|Choreographer|OpenGLRenderer|lowmemorykiller' }
[IO.File]::WriteAllText((Join-Path $out "logcat-app.txt"), ($app -join "`r`n"))
Adb -s $tv pull "/sdcard/Android/data/$pkg/files/rawnaq-errors.log" (Join-Path $out "rawnaq-errors.log") | Out-Null
[IO.File]::WriteAllText((Join-Path $out "device.txt"), ((Adb -s $tv shell dumpsys package $pkg) + "`n`n" + (Adb -s $tv shell dumpsys meminfo $pkg) + "`n`n" + (Adb -s $tv shell getprop)))
Info "Crash lines:"
$app | Where-Object { $_ -match 'FATAL|AndroidRuntime|ANR|RAWNAQ-ERROR|Exception' } | Select-Object -First 25 | ForEach-Object { Info $_ }

Step "3) Back to the TV's own home screen"
Adb -s $tv shell am force-stop $pkg | Out-Null
Adb -s $tv shell cmd package set-home-activity com.google.android.apps.tv.launcherx/.home.HomeActivity | Out-Null
Adb -s $tv shell input keyevent KEYCODE_HOME | Out-Null
Good "Done. The TV is usable again. Send the whole 'rescue' folder (zip it) to Claude."
try { Stop-Transcript | Out-Null } catch {}
Read-Host "Press Enter to close"
