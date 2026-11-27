# Rawnaq TV power fix (HDMI-CEC + smart plug)
# Problem it solves: the Google TV Streamer goes to sleep but the TV stays on with a blue
# "no signal" screen. This script reads what the TV says over HDMI-CEC, then tries every
# CEC combination the Streamer supports (control mode x CEC version x method) one by one,
# asks you after each try whether the TV really turned off / on, and keeps the first one
# that works. If the TV ignores every CEC standby command, it tests a smart plug instead.
# Results go to the "cec" folder next to this script.
param([string]$TvIp = "", [string]$PlugIp = "")
$ErrorActionPreference = "Continue"
$src = $PSScriptRoot
$out = Join-Path $src "cec"
New-Item -ItemType Directory -Force -Path $out | Out-Null
try { Start-Transcript -Path (Join-Path $out "cec-log.txt") -Force | Out-Null } catch {}
function Step($t) { Write-Host ""; Write-Host "==> $t" -ForegroundColor Cyan }
function Info($t) { Write-Host "    $t" }
function Good($t) { Write-Host "    $t" -ForegroundColor Green }
function Warn($t) { Write-Host "    $t" -ForegroundColor Yellow }
function Bad($t)  { Write-Host "    $t" -ForegroundColor Red }
function Ask($q)  { $a = Read-Host "    $q [y/n]"; return ($a.Trim().ToLower() -in @("y", "yes", "1")) }

# ---------- adb ----------
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) {
    $adb = @("$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe", "$env:ANDROID_HOME\platform-tools\adb.exe",
             (Join-Path $env:USERPROFILE "rawnaq_build\platform-tools\adb.exe")) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $adb) { Bad "adb not found. Run install.bat once first (it downloads adb)."; Read-Host "Enter to close"; exit 1 }
function Adb { $o = & $script:adb @args 2>&1 | ForEach-Object { "$_" }; return (($o -join "`n").Trim()) }
function Sh([string]$c) { return (Adb -s $script:tv shell $c) }

if (-not $TvIp) {
    $f = Join-Path $PSScriptRoot "tvs.txt"
    $first = if (Test-Path $f) { ((Get-Content $f | Where-Object { $_.Trim() } | Select-Object -First 1) -split '\s+')[0] } else { "" }
    Write-Host "TV IP address$(if ($first) { " (Enter = $first)" }):"
    $a = Read-Host "IP"
    $TvIp = if ($a.Trim()) { $a.Trim() } else { $first }
}
$ip = ($TvIp -split ':')[0]
$tv = "${ip}:5555"

function Connect([int]$tries = 20) {
    for ($i = 0; $i -lt $tries; $i++) {
        Adb connect $script:tv | Out-Null
        if ((Adb -s $script:tv get-state) -eq "device") { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

Step "Connecting to $tv"
Adb start-server | Out-Null
if (-not (Connect)) { Bad "Could not reach $tv. Check the IP and that the Streamer is awake, then run again."; try { Stop-Transcript | Out-Null } catch {}; Read-Host "Enter to close"; exit 1 }
$sdk = [int](Sh "getprop ro.build.version.sdk")
Good "Connected: $(Sh 'getprop ro.product.model'), Android $(Sh 'getprop ro.build.version.release') (SDK $sdk)"

# ---------- 1) what the TV says over CEC ----------
Step "1) Reading HDMI-CEC state (full dump saved to cec\hdmi_control.txt)"
$dump = Sh "dumpsys hdmi_control"
[IO.File]::WriteAllText((Join-Path $out "hdmi_control.txt"), $dump)
$lines = $dump -split "`n"
$lines | Where-Object { $_ -match 'mHdmiControlEnabled|hdmi_cec_enabled|power_control_mode|hdmi_cec_version|mCecVersion|PowerStatus|mPowerStatus|DeviceInfo|vendor|Vendor|physical|logical' } |
    Select-Object -First 30 | ForEach-Object { Info $_.Trim() }
$tvSeen = ($dump -match 'logical_address: 0x0|Device: TV|deviceType: 0|TV\b')
if ($dump -match 'mHdmiControlEnabled: false') { Warn "CEC is OFF on the Streamer. Turning it on." }
if (-not $tvSeen) { Warn "The TV did not identify itself over CEC. It may still accept commands; we will test anyway." }

function CecGet([string]$n) { return (Sh "cmd hdmi_control cec_setting get $n") }
function CecSet([string]$n, [string]$v) {
    $r = Sh "cmd hdmi_control cec_setting set $n $v"
    if ($r -match 'rror|xception|nvalid|nknown') { return $false }
    return $true
}

# ---------- 2) make sure CEC is on and the Streamer is allowed to control the TV ----------
Step "2) Enabling CEC control on the Streamer"
$legacy = @{ "hdmi_control_enabled" = 1; "hdmi_control_auto_wakeup_enabled" = 1; "hdmi_control_auto_device_off_enabled" = 1 }
foreach ($k in $legacy.Keys) { Sh "settings put global $k $($legacy[$k])" | Out-Null }
$base = [ordered]@{ "hdmi_cec_enabled" = "1"; "tv_wake_on_one_touch_play" = "1"; "tv_send_standby_on_sleep" = "1" }
foreach ($k in $base.Keys) {
    if (CecSet $k $base[$k]) { Good "$k = $(CecGet $k)" } else { Info "$k not available on this firmware (skipped)" }
}
$before = [ordered]@{ power_control_mode = (CecGet "power_control_mode"); hdmi_cec_version = (CecGet "hdmi_cec_version") }
Info "Current: power_control_mode = $($before.power_control_mode), hdmi_cec_version = $($before.hdmi_cec_version)"

# ---------- 3) try every combination ----------
function SleepStreamer { Sh "input keyevent KEYCODE_SLEEP" | Out-Null }
function WakeStreamer {
    Start-Sleep -Seconds 2
    if (-not (Connect 6)) {
        Warn "Lost the connection while sleeping. Press any button on the Streamer remote now."
        Read-Host "    Press Enter after you pressed the remote"
        Connect | Out-Null
    }
    Sh "input keyevent KEYCODE_WAKEUP" | Out-Null
    Sh "cmd hdmi_control onetouchplay" | Out-Null
}
function TvPowerKey { Sh "input keyevent KEYCODE_TV_POWER" | Out-Null }

$modes = @("broadcast", "to_tv", "to_tv_and_audio_system")
$versions = @("5", "6")   # 5 = CEC 1.4b (older/Chinese TVs answer this best), 6 = CEC 2.0
$methods = @("sleep", "tvpower")
$winner = $null
$tryNo = 0

Step "3) Testing. Watch the TV after each try and answer honestly."
Warn "Each try puts the Streamer to sleep, so the picture will go away for a few seconds."
:outer foreach ($ver in $versions) {
    $verOk = CecSet "hdmi_cec_version" $ver
    foreach ($mode in $modes) {
        $modeOk = CecSet "power_control_mode" $mode
        if (-not $modeOk -and $mode -ne "broadcast") { continue }
        foreach ($m in $methods) {
            $tryNo++
            Write-Host ""
            Write-Host "    Try $tryNo : CEC $(if ($ver -eq '5') {'1.4'} else {'2.0'})$(if (-not $verOk) {' (version fixed by firmware)'}) | mode $mode | $(if ($m -eq 'sleep') {'Streamer sleep'} else {'TV power key'})" -ForegroundColor White
            if ($m -eq "sleep") { SleepStreamer } else { TvPowerKey }
            Start-Sleep -Seconds 8
            $off = Ask "Did the TV turn fully OFF (no blue screen, standby light only)?"
            WakeStreamer
            Start-Sleep -Seconds 10
            $on = Ask "Did the TV turn back ON and show the Streamer by itself?"
            Add-Content (Join-Path $out "results.txt") "try=$tryNo version=$ver mode=$mode method=$m off=$off on=$on"
            if ($off) {
                $winner = @{ version = $ver; mode = $mode; method = $m; wakes = $on }
                break outer
            }
        }
    }
}

# ---------- 4) result ----------
Step "4) Result"
if ($winner) {
    CecSet "hdmi_cec_version" $winner.version | Out-Null
    CecSet "power_control_mode" $winner.mode | Out-Null
    Good "WORKS: CEC $(if ($winner.version -eq '5') {'1.4'} else {'2.0'}), mode '$($winner.mode)', method '$($winner.method)'. Saved on the Streamer."
    if ($winner.method -eq "tvpower") {
        Warn "Sleep alone does not turn the TV off; the TV power command does. Rawnaq's 'TV & power' screen will send it before every sleep."
    }
    if (-not $winner.wakes) {
        Warn "The TV turns off but does not turn back on by itself."
        Warn "On the TV: settings -> HDMI CEC (or 'Device control') -> turn on 'Auto power on' / 'TV auto power on'."
        Warn "Or use the TV remote's power button in the morning; the Streamer will already be on the right input."
    }
    "version=$($winner.version)`nmode=$($winner.mode)`nmethod=$($winner.method)`nwakes=$($winner.wakes)" | Set-Content (Join-Path $out "winner.txt")
} else {
    if ($before.hdmi_cec_version) { CecSet "hdmi_cec_version" $before.hdmi_cec_version | Out-Null }
    if ($before.power_control_mode) { CecSet "power_control_mode" $before.power_control_mode | Out-Null }
    Bad "The TV ignored every CEC standby command. This is common on assembled (Chinese) TVs: they accept 'turn on' but not 'standby'."
    Write-Host ""
    Write-Host "    Check these on the TV before giving up on CEC:" -ForegroundColor White
    Info "a) TV settings -> HDMI CEC = On, and 'Auto standby' / 'Device auto power off' = On."
    Info "b) Move the Streamer to HDMI 1 or the HDMI marked ARC. Many boards only run CEC on one port."
    Info "c) Use the original short HDMI cable. Cheap cables often drop the CEC wire (pin 13)."
    Info "d) TV settings -> 'No signal power off' / 'Auto sleep' = the shortest time (5 min)."
    Info "   This alone removes the blue screen: the TV turns itself off 5 minutes after the Streamer sleeps."
    Write-Host ""
    Write-Host "    The forced way that always works: a Wi-Fi smart plug (Shelly or Tasmota) on the TV power." -ForegroundColor White
    Info "Rawnaq sends CEC standby, waits 10 seconds, then cuts the TV power; on wake it restores power."
    Info "On the TV set 'Power on mode' / 'Power on status' = On (or Last), so it starts when power returns."
}

# ---------- 5) optional smart plug test ----------
Step "5) Smart plug test (optional)"
if (-not $PlugIp) { $PlugIp = (Read-Host "    Smart plug IP (Enter to skip)").Trim() }
if ($PlugIp) {
    function Http($u) { try { return (Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri $u).Content } catch { return $null } }
    $kind = $null
    if (Http "http://$PlugIp/rpc/Shelly.GetDeviceInfo") { $kind = "shelly2" }
    elseif (Http "http://$PlugIp/shelly") { $kind = "shelly1" }
    elseif (Http "http://$PlugIp/cm?cmnd=Status") { $kind = "tasmota" }
    if (-not $kind) { Bad "No Shelly or Tasmota plug answered at $PlugIp. Check the IP (the plug's own app shows it)." }
    else {
        Good "Found: $kind"
        $offUrl = switch ($kind) { "shelly2" { "http://$PlugIp/rpc/Switch.Set?id=0&on=false" } "shelly1" { "http://$PlugIp/relay/0?turn=off" } "tasmota" { "http://$PlugIp/cm?cmnd=Power%20Off" } }
        $onUrl  = switch ($kind) { "shelly2" { "http://$PlugIp/rpc/Switch.Set?id=0&on=true" }  "shelly1" { "http://$PlugIp/relay/0?turn=on" }  "tasmota" { "http://$PlugIp/cm?cmnd=Power%20On" } }
        Warn "Full sequence: Streamer sleep -> 10 s -> plug OFF -> 15 s -> plug ON -> wake Streamer."
        if (Ask "Run it now?") {
            SleepStreamer; Start-Sleep -Seconds 10
            Http $offUrl | Out-Null; Info "Power cut."; Start-Sleep -Seconds 15
            Http $onUrl | Out-Null; Info "Power restored."; Start-Sleep -Seconds 6
            WakeStreamer; Start-Sleep -Seconds 12
            $offOk = Ask "Was the TV fully dark while the power was cut?"
            $onOk = Ask "Did the TV come back on and show the Streamer?"
            "kind=$kind`nip=$PlugIp`noff=$offOk`non=$onOk" | Set-Content (Join-Path $out "plug.txt")
            if ($offOk -and $onOk) { Good "Smart plug works. Enter $PlugIp in Rawnaq: Settings -> TV & power -> Smart plug." }
            elseif ($offOk) { Warn "Power returns but the TV stays in standby: set the TV's 'Power on mode' to On / Last." }
        }
    }
} else { Info "Skipped." }

Step "Done. Everything is in the 'cec' folder: send cec-log.txt if you want me to read it."
try { Stop-Transcript | Out-Null } catch {}
Read-Host "Enter to close"
