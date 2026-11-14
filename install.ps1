# One-step installer for the Rawnaq launcher.
# Type ANY TV address (or pick a saved one). The script connects to exactly that address,
# builds once, installs only on that TV, grants permissions, copies wallpapers and makes it
# the default home screen.
#   install.bat                      -> menu: saved TVs or type any IP
#   install.bat -TvIp 192.168.0.50   -> straight to that TV (also "ip:port" or "ip1,ip2")
#   install-royal.bat / install-all.bat -> shortcuts for the two known TVs
#
# Connection order for every address:
#   1) Network debugging on port 5555 (Android 9-10 TVs, or any TV after step 2/3 once).
#   2) A TV plugged by USB cable  -> switched to network mode automatically (adb tcpip 5555).
#   3) Android 11+ "Wireless debugging" -> found by mDNS, or paired with the 6-digit code.
# Every adb command is sent with -s <that exact address>, so another TV or phone on the
# network can never receive the install by mistake.

param([string]$TvIp = "", [switch]$SkipBuild)

# Native tools (adb, flutter) print normal messages to stderr; keep going on them.
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$src = $PSScriptRoot
$log = Join-Path $src "install-log.txt"
try { Start-Transcript -Path $log -Force | Out-Null } catch {}
$build = Join-Path $env:USERPROFILE "rawnaq_build"
$apk = Join-Path $build "build\app\outputs\flutter-apk\app-release.apk"
$pkg = "com.rawnaq"
# The launcher was called Al-Hafidh before; its settings move over and the old app is removed.
$oldPkg = "com.hafidh.hafidh_launcher"
$savedFile = Join-Path $src "tvs.txt"

function Step($t) { Write-Host ""; Write-Host "==> $t" -ForegroundColor Cyan }
function Info($t) { Write-Host "    $t" }
function Warn($t) { Write-Host "    $t" -ForegroundColor Yellow }
function Good($t) { Write-Host "    $t" -ForegroundColor Green }
function Fail($t) {
    Write-Host $t -ForegroundColor Red
    Write-Host "Log saved to: $log"
    try { Stop-Transcript | Out-Null } catch {}
    Read-Host "Press Enter to close"
    exit 1
}

# Runs adb and returns its whole output (stdout + stderr) as one trimmed string.
# Nothing leaks into the pipeline, so functions return exactly what they mean to.
function Adb {
    $o = & $script:adb @args 2>&1 | ForEach-Object { "$_" }
    return (($o -join "`n").Trim())
}

# ---------- Address parsing ----------
function Test-Ip([string]$ip) {
    $parts = $ip.Split('.')
    if ($parts.Count -ne 4) { return $false }
    foreach ($p in $parts) {
        if ($p -notmatch '^\d{1,3}$') { return $false }
        if ([int]$p -gt 255) { return $false }
    }
    return $true
}

# "192.168.0.5" -> 192.168.0.5:5555 ; "192.168.0.5:41231" keeps the port.
function Parse-Target([string]$t) {
    $t = $t.Trim()
    $port = 5555
    if ($t -match '^(.+):(\d{1,5})$') { $t = $Matches[1]; $port = [int]$Matches[2] }
    if (-not (Test-Ip $t)) { return $null }
    if ($port -lt 1 -or $port -gt 65535) { return $null }
    return [pscustomobject]@{ Ip = $t; Port = $port }
}

function Get-Saved {
    # شاشاتك تنحفظ بـ tvs.txt على حاسبتك بس (ما ينرفع لـ GitHub)
    $list = @()
    if (Test-Path $savedFile) {
        foreach ($l in (Get-Content $savedFile -ErrorAction SilentlyContinue)) {
            $ip = ($l -split '\s+')[0]
            if ((Test-Ip $ip) -and -not ($list | Where-Object { $_.StartsWith("$ip ") })) { $list += $l.Trim() }
        }
    }
    return , $list
}

function Save-Target([string]$ip, [string]$model) {
    $lines = @()
    if (Test-Path $savedFile) { $lines = @(Get-Content $savedFile | Where-Object { $_ -and -not $_.StartsWith("$ip ") }) }
    $lines += "$ip  $model"
    Set-Content -Path $savedFile -Value $lines -Encoding ASCII
}

# ---------- 0. Which TV? ----------
if (-not $TvIp) {
    $saved = Get-Saved
    Write-Host ""
    Write-Host "Which TV do you want to install on?" -ForegroundColor Cyan
    for ($i = 0; $i -lt $saved.Count; $i++) { Write-Host ("  {0}) {1}" -f ($i + 1), $saved[$i]) }
    Write-Host "  A) All of the above"
    Write-Host ""
    Write-Host "Type a number from the list, or type the TV address directly" -ForegroundColor Cyan
    Write-Host "(TV: Settings > Network > your Wi-Fi > IP address), e.g. 192.168.1.20"
    $choice = (Read-Host "TV").Trim()
    if (-not $choice) { Fail "No TV chosen." }
    $picked = @()
    foreach ($c in ($choice -split '[,; ]+' | Where-Object { $_ })) {
        if ($c -match '^[aA]$') { $picked += $saved | ForEach-Object { ($_ -split '\s+')[0] } }
        elseif ($c -match '^\d{1,2}$' -and [int]$c -ge 1 -and [int]$c -le $saved.Count) { $picked += ($saved[[int]$c - 1] -split '\s+')[0] }
        else { $picked += $c }
    }
    $TvIp = ($picked | Select-Object -Unique) -join ','
}
$targets = @()
foreach ($t in ($TvIp -split '[,; ]+' | Where-Object { $_ })) {
    $p = Parse-Target $t
    if (-not $p) { Fail "Not a valid TV address: '$t'  (expected something like 192.168.1.20)" }
    $targets += $p
}
Write-Host ("Target TV(s): " + (($targets | ForEach-Object { "$($_.Ip):$($_.Port)" }) -join ', ')) -ForegroundColor Green

# ---------- 1. Find adb (download it if missing) ----------
Step "Looking for adb"
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) {
    $candidates = @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:ANDROID_HOME\platform-tools\adb.exe",
        "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe",
        (Join-Path $build "platform-tools\adb.exe")
    )
    $adb = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $adb) {
    Warn "adb not found - downloading Google's platform-tools (about 7 MB)"
    New-Item -ItemType Directory -Force -Path $build | Out-Null
    $zip = Join-Path $build "platform-tools.zip"
    try {
        Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zip -UseBasicParsing -TimeoutSec 300
        Expand-Archive -Path $zip -DestinationPath $build -Force
        $adb = Join-Path $build "platform-tools\adb.exe"
    } catch {}
    if (-not (Test-Path $adb)) { Fail "adb not found and could not be downloaded. Install 'Android SDK Platform-Tools' from Android Studio > SDK Manager." }
}
Info "adb: $adb"
Info ((Adb version) -split "`n" | Select-Object -First 1)
# A stuck adb server is the most common reason for "cannot connect": start clean.
Adb kill-server | Out-Null
Adb start-server | Out-Null

# ---------- 2. Build once ----------
if (-not $SkipBuild -or -not (Test-Path $apk)) {
    Step "Building the launcher (first build takes a few minutes, later builds are fast)"
    Remove-Item $apk -Force -ErrorAction SilentlyContinue
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $src "setup.ps1")
    if (-not (Test-Path $apk)) { Fail "Build failed. Send install-log.txt to Claude." }
}
Info "APK: $apk"

# ---------- 3. Wallpapers on the laptop (prepared once) ----------
$wallSrc = Join-Path $src "wallpapers"
New-Item -ItemType Directory -Force -Path $wallSrc | Out-Null
$imgs = @(Get-ChildItem $wallSrc -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(jpe?g|png|webp)$' })
if ($imgs.Count -eq 0) {
    $ans = Read-Host "The 'wallpapers' folder is empty. Download 30 real 4K photos (3 per category, Wikimedia Commons featured pictures)? [Y/n]"
    if ($ans -notmatch '^[nN]') {
        Step "Downloading 4K wallpapers from Wikimedia Commons (10 categories)"
        $ua = "RawnaqLauncher/3.0 (Android TV home screen; personal use)"
        $cats = @(
            @('landscapes', 'Featured pictures of landscapes'),
            @('mountains', 'Featured pictures of mountains'),
            @('coasts', 'Featured pictures of coasts'),
            @('water', 'Featured pictures of bodies of water'),
            @('plants', 'Featured pictures of plants'),
            @('mammals', 'Featured pictures of mammals'),
            @('birds', 'Featured pictures of birds'),
            @('food', 'Featured pictures of food'),
            @('astronomy', 'Featured pictures of astronomy'),
            @('mosques', 'Quality images of mosques')
        )
        $credits = @{}
        foreach ($c in $cats) {
            $q = "https://commons.wikimedia.org/w/api.php?action=query&format=json&formatversion=2&generator=categorymembers" +
                 "&gcmtitle=" + [uri]::EscapeDataString("Category:" + $c[1]) + "&gcmtype=file&gcmlimit=50" +
                 "&prop=imageinfo&iiprop=url%7Csize%7Cmime%7Cextmetadata&iiurlwidth=3840&iiextmetadatafilter=Artist%7CLicenseShortName%7CObjectName"
            $r = $null
            for ($try = 0; $try -lt 3 -and -not $r; $try++) {
                try { $r = Invoke-RestMethod -Uri $q -UserAgent $ua -TimeoutSec 60 } catch { Start-Sleep -Seconds (5 * ($try + 1)) }
            }
            if (-not $r -or -not $r.query) { Warn "$($c[0]): could not reach Wikimedia Commons, skipped"; continue }
            # Some members come back without imageinfo: skip them quietly.
            $pages = @($r.query.pages | Where-Object {
                if (-not $_.imageinfo -or @($_.imageinfo).Count -eq 0) { return $false }
                $ii = @($_.imageinfo)[0]
                $ii.width -ge 2400 -and $ii.height -gt 0 -and ($ii.width / [double]$ii.height) -ge 1.3 -and $ii.mime -eq 'image/jpeg' -and $ii.thumburl
            })
            if ($pages.Count -eq 0) { Warn "$($c[0]): no wide photos found, skipped"; continue }
            $pick = @($pages | Get-Random -Count ([Math]::Min(3, $pages.Count)))
            foreach ($pg in $pick) {
                $ii = @($pg.imageinfo)[0]
                $name = "auto-$($c[0])-$($pg.pageid).jpg"
                $dest = Join-Path $wallSrc $name
                $ok = $false
                for ($try = 0; $try -lt 4 -and -not $ok; $try++) {
                    try {
                        Invoke-WebRequest -Uri $ii.thumburl -OutFile $dest -UserAgent $ua -UseBasicParsing -TimeoutSec 180
                        $ok = $true
                    } catch {
                        # 429 = too many requests: wait longer each time, then retry
                        $wait = 8 * [Math]::Pow(2, $try)
                        Info "$($c[0]): Wikimedia is busy, waiting $wait s..."
                        Start-Sleep -Seconds $wait
                    }
                }
                try {
                    if (-not $ok) { throw "download failed" }
                    $artist = (($ii.extmetadata.Artist.value -replace '<[^>]+>', ' ') -replace '\s+', ' ').Trim()
                    if ($artist.Length -gt 60) { $artist = $artist.Substring(0, 57) + '...' }
                    $title = (($ii.extmetadata.ObjectName.value -replace '<[^>]+>', ' ') -replace '\s+', ' ').Trim()
                    $credits[$name] = @{ t = $title; a = $artist; l = "$($ii.extmetadata.LicenseShortName.value)"; c = $c[0] }
                    Info "$($c[0]): $name"
                    Start-Sleep -Milliseconds 2500
                } catch { Remove-Item $dest -Force -ErrorAction SilentlyContinue; Warn "failed: $name" }
            }
        }
        if ($credits.Count -gt 0) {
            # UTF-8 without BOM so the app can read it
            [IO.File]::WriteAllText((Join-Path $wallSrc 'credits-install.json'), ($credits | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
        }
        $imgs = @(Get-ChildItem $wallSrc -File | Where-Object { $_.Extension -match '^\.(jpe?g|png|webp)$' })
    }
}
$askedAds = $null

# ---------- Connection helpers ----------
function Test-Port([string]$ip, [int]$port, [int]$ms = 2500) {
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $c.ConnectAsync($ip, $port)
        if ($task.Wait($ms) -and $c.Connected) { return $true }
        return $false
    } catch { return $false } finally { $c.Close() }
}

function Get-State([string]$serial) {
    foreach ($l in ((Adb devices) -split "`n")) {
        $cols = $l.Trim() -split '\s+'
        if ($cols.Count -ge 2 -and $cols[0] -eq $serial) { return $cols[1] }
    }
    return "none"
}

# Connects to ip:port and waits until the TV accepts. Returns "device", "unauthorized" or "failed".
function Connect-Serial([string]$serial, [int]$seconds = 70) {
    Adb disconnect $serial | Out-Null
    $out = Adb connect $serial
    Info "adb connect $serial -> $out"
    $warned = $false
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        $st = Get-State $serial
        if ($st -eq "device") { return "device" }
        if ($st -eq "unauthorized" -and -not $warned) {
            Write-Host ""
            Write-Host "    >>> Look at the TV now: 'Allow debugging?' -> tick 'Always allow' and press OK <<<" -ForegroundColor Yellow
            $warned = $true
        }
        if ($st -eq "offline" -or $st -eq "none") {
            Start-Sleep -Seconds 2
            Adb disconnect $serial | Out-Null
            Adb connect $serial | Out-Null
        }
        Start-Sleep -Seconds 2
    }
    if ((Get-State $serial) -eq "unauthorized") { return "unauthorized" }
    return "failed"
}

# Every IPv4 address the connected TV reports for itself.
function Get-TvIps([string]$serial) {
    $txt = Adb -s $serial shell "ip -4 -o addr 2>/dev/null; ifconfig 2>/dev/null"
    return , @([regex]::Matches($txt, '(?:inet |inet addr:)(\d+\.\d+\.\d+\.\d+)') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne '127.0.0.1' })
}

# Android 11+ wireless debugging: the TV announces its random port over mDNS.
function Find-MdnsPort([string]$ip) {
    $svc = Adb mdns services
    foreach ($l in ($svc -split "`n")) {
        if ($l -match '_adb-tls-connect\._tcp\.?\s+([\d\.]+):(\d+)' -and $Matches[1] -eq $ip) { return [int]$Matches[2] }
    }
    return 0
}

# Returns the adb serial to use for this TV, or $null.
function Connect-Tv($t) {
    $ip = $t.Ip
    $serial = "$($ip):$($t.Port)"
    Step "TV $ip : connecting"

    if (-not (Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
        Warn "$ip does not answer ping (some TVs block ping - trying anyway)."
    }

    # 1) The given port (5555 by default) is open: plain network debugging.
    if (Test-Port $ip $t.Port) {
        $r = Connect-Serial $serial
        if ($r -eq "device") { return $serial }
        if ($r -eq "unauthorized") { Warn "The TV did not allow this laptop. Accept the prompt on the TV and run the installer again."; return $null }
    } else {
        Warn "Port $($t.Port) on $ip is closed (network debugging is off on the TV)."
    }

    # 2) A TV on USB cable: check it is the same TV, then switch it to network mode.
    $usb = @(((Adb devices) -split "`n") | Where-Object { $_ -match '^\S+\s+device$' -and $_ -notmatch ':' } | ForEach-Object { ($_ -split '\s+')[0] })
    foreach ($u in $usb) {
        $ips = Get-TvIps $u
        if ($ips -contains $ip) {
            Info "Found this TV on the USB cable ($u). Switching it to network debugging on port 5555..."
            Adb -s $u tcpip 5555 | Out-Null
            Start-Sleep -Seconds 4
            $serial = "$($ip):5555"
            if ((Connect-Serial $serial) -eq "device") { return $serial }
        }
    }

    # 3) Android 11+ wireless debugging (random port, needs pairing once).
    $port = Find-MdnsPort $ip
    if ($port -gt 0) {
        Info "Wireless debugging found on port $port"
        $serial = "$($ip):$port"
        if ((Connect-Serial $serial 25) -eq "device") { return $serial }
    }
    Write-Host ""
    Write-Host "    Could not reach $ip automatically. On the TV open:" -ForegroundColor Yellow
    Write-Host "      Settings > System > Developer options" -ForegroundColor Yellow
    Write-Host "      - Android 9/10 TV: turn on 'Network debugging' (or 'ADB over network'), then press Enter here." -ForegroundColor Yellow
    Write-Host "      - Android 11+ TV : turn on 'Wireless debugging' > 'Pair device with pairing code'." -ForegroundColor Yellow
    $ans = (Read-Host "    Type the pairing PORT shown on the TV (or just press Enter to retry port 5555)").Trim()
    if (-not $ans) {
        $serial = "$($ip):5555"
        if ((Connect-Serial $serial) -eq "device") { return $serial }
        return $null
    }
    if ($ans -notmatch '^\d{2,5}$') { Warn "Not a port number: $ans"; return $null }
    $code = (Read-Host "    Type the 6-digit pairing CODE shown on the TV").Trim()
    $pair = Adb pair "$($ip):$ans" $code
    Info "adb pair -> $pair"
    if ($pair -notmatch 'Successfully paired') { Warn "Pairing failed. Check the code and try again (the code changes every time)."; return $null }
    Start-Sleep -Seconds 2
    $port = Find-MdnsPort $ip
    if ($port -eq 0) {
        $cp = (Read-Host "    Now type the PORT shown under 'IP address & Port' on the Wireless debugging screen").Trim()
        if ($cp -match '^\d{2,5}$') { $port = [int]$cp }
    }
    if ($port -gt 0) {
        $serial = "$($ip):$port"
        if ((Connect-Serial $serial 30) -eq "device") {
            # Make next time instant: keep a fixed port 5555 open until the TV reboots.
            Adb -s $serial tcpip 5555 | Out-Null
            Start-Sleep -Seconds 4
            if ((Connect-Serial "$($ip):5555" 20) -eq "device") { return "$($ip):5555" }
            if ((Connect-Serial $serial 20) -eq "device") { return $serial }
        }
    }
    return $null
}

# Installs the APK on exactly this serial, fixing the usual errors on the way.
function Install-Apk([string]$tv) {
    for ($try = 1; $try -le 4; $try++) {
        if ((Get-State $tv) -ne "device") { Connect-Serial $tv 30 | Out-Null }
        $args1 = @("-s", $tv, "install", "-r", "-d")
        if ($try -ge 3) { $args1 += "--no-streaming" }
        $out = Adb @args1 $apk
        Info ($out -split "`n" | Select-Object -Last 2 | Out-String).Trim()
        if ($out -match 'Success') { return $true }

        if ($out -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match|INSTALL_FAILED_VERSION_DOWNGRADE') {
            Warn "The old copy was signed differently - removing it first (launcher settings on this TV will reset)."
            Adb -s $tv uninstall $pkg | Out-Null
            continue
        }
        if ($out -match 'INSUFFICIENT_STORAGE|not enough space') {
            Warn "The TV is low on storage - clearing app caches and retrying."
            Adb -s $tv shell pm trim-caches 4096M | Out-Null
            continue
        }
        if ($try -eq 4) {
            # Last resort: copy the file to the TV and install it from there.
            Warn "Trying the copy-then-install method..."
            Adb -s $tv push $apk /data/local/tmp/rawnaq.apk | Out-Null
            $out = Adb -s $tv shell pm install -r -d /data/local/tmp/rawnaq.apk
            Adb -s $tv shell rm -f /data/local/tmp/rawnaq.apk | Out-Null
            Info $out
            if ($out -match 'Success') { return $true }
        }
        Start-Sleep -Seconds 3
    }
    return $false
}

# ---------- 4. Install on each TV ----------
function Install-OnTv($t) {
    $ip = $t.Ip
    $tv = Connect-Tv $t
    if (-not $tv) {
        Write-Host "    Could not connect to $ip. Check: the TV is on, on the same Wi-Fi as this laptop, and the address is right." -ForegroundColor Red
        return $false
    }

    # Make sure the device answering is really the TV whose address was typed.
    $ips = Get-TvIps $tv
    $model = (Adb -s $tv shell getprop ro.product.model)
    $brand = (Adb -s $tv shell getprop ro.product.manufacturer)
    $sdk = (Adb -s $tv shell getprop ro.build.version.sdk)
    $rel = (Adb -s $tv shell getprop ro.build.version.release)
    if ($ips.Count -gt 0 -and -not ($ips -contains $ip)) {
        Warn "The device at $ip reports address(es) $($ips -join ', ')."
        $ans = Read-Host "    Install on '$brand $model' anyway? [y/N]"
        if ($ans -notmatch '^[yY]') { return $false }
    }
    Good "Connected: $brand $model  (Android $rel, SDK $sdk)  at $tv"
    Save-Target $ip "$brand $model"

    Step "TV $ip : installing"
    if (-not (Install-Apk $tv)) {
        Write-Host "    Install failed on $ip. Send install-log.txt to Claude." -ForegroundColor Red
        return $false
    }
    $path = Adb -s $tv shell pm path $pkg
    if ($path -notmatch 'package:') { Write-Host "    The launcher is not on the TV after install." -ForegroundColor Red; return $false }
    Good "Installed."

    Step "TV $ip : permissions and system screensaver"
    Adb -s $tv shell pm grant $pkg android.permission.WRITE_SECURE_SETTINGS | Out-Null
    Adb -s $tv shell appops set $pkg SYSTEM_ALERT_WINDOW allow | Out-Null
    Adb -s $tv shell pm grant $pkg android.permission.READ_EXTERNAL_STORAGE | Out-Null
    Adb -s $tv shell pm grant $pkg android.permission.READ_MEDIA_IMAGES | Out-Null
    Adb -s $tv shell pm grant $pkg android.permission.POST_NOTIFICATIONS | Out-Null
    # Home guard (accessibility), notification center and self-update (v3.7)
    $guard = "$pkg/$pkg.HomeGuardService"
    $acc = (Adb -s $tv shell settings get secure enabled_accessibility_services).Trim()
    if ($acc -notmatch [regex]::Escape($guard)) {
        $newAcc = if (-not $acc -or $acc -eq "null") { $guard } else { "${acc}:$guard" }
        Adb -s $tv shell settings put secure enabled_accessibility_services "$newAcc" | Out-Null
    }
    Adb -s $tv shell settings put secure accessibility_enabled 1 | Out-Null
    Adb -s $tv shell cmd notification allow_listener "$pkg/$pkg.NotifListener" | Out-Null
    Adb -s $tv shell appops set $pkg REQUEST_INSTALL_PACKAGES allow | Out-Null
    Good "Home guard, notification center and self-update enabled."
    # Sleep timer: lets the launcher turn the screen off (only the "force-lock" policy)
    Adb -s $tv shell dpm set-active-admin --user 0 "$pkg/.AdminReceiver" | Out-Null
    Adb -s $tv shell settings put secure screensaver_enabled 0 | Out-Null
    Adb -s $tv shell settings put secure screensaver_activate_on_sleep 0 | Out-Null
    Adb -s $tv shell settings put secure screensaver_activate_on_dock 0 | Out-Null
    Good "done"

    # Moving from the old name: copy its backups and wallpapers so Rawnaq restores everything on first start.
    $hadOld = (Adb -s $tv shell pm path $oldPkg) -match 'package:'
    if ($hadOld) {
        Step "TV $ip : moving settings, layout and wallpapers from Al-Hafidh"
        $from = "/sdcard/Android/data/$oldPkg/files"
        $to = "/sdcard/Android/data/$pkg/files"
        Adb -s $tv shell am force-stop $pkg | Out-Null
        Adb -s $tv shell mkdir -p "$to/backups" "$to/wallpapers" | Out-Null
        Adb -s $tv shell "cp -r $from/backups/. $to/backups/ 2>/dev/null; cp -r $from/wallpapers/. $to/wallpapers/ 2>/dev/null" | Out-Null
        $n = (Adb -s $tv shell "ls $to/backups 2>/dev/null | wc -l").Trim()
        if ($n -match '^\d+$' -and [int]$n -gt 0) { Good "Copied $n backup(s); Rawnaq restores the newest one when it starts." }
        else { Warn "No backup was found in Al-Hafidh. Make one there first (Settings -> backup) to keep your layout, or set Rawnaq up fresh." }
    }

    if ($imgs.Count -gt 0) {
        Step "TV $ip : copying $($imgs.Count) wallpapers"
        $remote = "/sdcard/Android/data/$pkg/files/wallpapers"
        Adb -s $tv shell mkdir -p $remote | Out-Null
        foreach ($img in $imgs) {
            $r = Adb -s $tv push $img.FullName "$remote/$($img.Name)"
            if ($r -match 'error|failed') { Warn "$($img.Name): $r" } else { Info $img.Name }
        }
        $cr = Join-Path $wallSrc 'credits-install.json'
        if (Test-Path $cr) { Adb -s $tv push $cr "$remote/credits-install.json" | Out-Null }
    }

    # Safety check: start Rawnaq and make sure it really runs and shows before it becomes the home screen.
    Step "TV $ip : test-starting Rawnaq (20 seconds)"
    Adb -s $tv shell am force-stop $pkg | Out-Null
    Adb -s $tv logcat -c | Out-Null
    Adb -s $tv shell am start -W -n "$pkg/.MainActivity" | Out-Null
    $alive = $false
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Seconds 2
        $procId = Adb -s $tv shell pidof $pkg
        $top = (Adb -s $tv shell dumpsys activity activities) -split "`n" | Where-Object { $_ -match 'ResumedActivity' } | Select-Object -First 1
        $alive = [bool]$procId -and ($top -match [regex]::Escape($pkg))
        if (-not $procId) { break }
    }
    if (-not $alive) {
        $diag = Join-Path $src "start-failure-$ip.txt"
        $lc = (Adb -s $tv logcat -d -v time) -split "`n" | Where-Object { $_ -match 'rawnaq|flutter|AndroidRuntime|FATAL|ANR|RAWNAQ-ERROR' }
        [IO.File]::WriteAllText($diag, (($lc -join "`r`n") + "`r`n`r`n" + (Adb -s $tv logcat -d -b crash -v time)))
        Write-Host "    Rawnaq did not start correctly on $ip, so the TV keeps its own home screen." -ForegroundColor Red
        Write-Host "    Details saved to $diag - send it with install-log.txt to Claude." -ForegroundColor Red
        $lc | Where-Object { $_ -match 'FATAL|AndroidRuntime|Exception|RAWNAQ-ERROR' } | Select-Object -First 15 | ForEach-Object { Info $_ }
        return $false
    }
    Good "Rawnaq is running and visible."

    Step "TV $ip : setting the default home screen"
    Adb -s $tv shell cmd package set-home-activity "$pkg/.MainActivity" | Out-Null
    $homeOut = Adb -s $tv shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
    if ($homeOut -notmatch [regex]::Escape($pkg)) {
        Warn "The TV still prefers its original home screen:"
        Info $homeOut
        Info "Answer N to keep Google's interface hidden (its Google Home smart-home panel keeps working) - the Rawnaq guard brings Rawnaq back whenever it appears."
        $ans = Read-Host "    Disable the original home screen on $ip? (you can undo this later) [y/N]"
        if ($ans -match '^[yY]') {
            $orig = (($homeOut -split "`n" | Where-Object { $_ -match '/' } | Select-Object -Last 1) -split '/')[0].Trim()
            if ($orig -and $orig -ne $pkg) {
                Info (Adb -s $tv shell pm disable-user --user 0 $orig)
                Good "Disabled $orig. To undo:  adb -s $tv shell pm enable $orig"
                Add-Content -Path (Join-Path $src "undo-home.txt") -Value "adb -s $tv shell pm enable $orig"
            }
        }
    } else { Good "Rawnaq is the home screen." }

    if ($hadOld) {
        Step "TV $ip : removing the old Al-Hafidh app"
        $guardOld = "$oldPkg/$oldPkg.HomeGuardService"
        $acc2 = (Adb -s $tv shell settings get secure enabled_accessibility_services).Trim()
        if ($acc2 -match [regex]::Escape($guardOld)) {
            $left = ($acc2 -split ':' | Where-Object { $_ -and $_ -ne $guardOld }) -join ':'
            Adb -s $tv shell settings put secure enabled_accessibility_services "$left" | Out-Null
        }
        Adb -s $tv shell dpm remove-active-admin --user 0 "$oldPkg/.AdminReceiver" | Out-Null
        $u = Adb -s $tv shell pm uninstall $oldPkg
        if ($u -match 'Success') { Good "Al-Hafidh removed; Rawnaq replaces it." } else { Warn "Could not remove Al-Hafidh: $u" }
    }

    if ($null -eq $script:askedAds) {
        $script:askedAds = Read-Host "Turn on system-wide ad blocking (AdGuard DNS) on the TVs? [y/N]"
    }
    if ($script:askedAds -match '^[yY]') {
        Adb -s $tv shell settings put global private_dns_mode hostname | Out-Null
        Adb -s $tv shell settings put global private_dns_specifier dns.adguard-dns.com | Out-Null
        # Some networks block private DNS (port 853). Without this check the TV loses internet and everything hangs.
        Start-Sleep -Seconds 4
        $ping = Adb -s $tv shell ping -c 1 -W 5 www.google.com
        if ($ping -match 'bytes from|1 received|1 packets received') {
            Good "ad blocking on (undo: adb -s $tv shell settings put global private_dns_mode off)"
        } else {
            Adb -s $tv shell settings put global private_dns_mode off | Out-Null
            Warn "This network blocks private DNS, so ad blocking was turned back off (the TV keeps its internet)."
        }
    }

    Adb -s $tv shell am start -a android.intent.action.MAIN -c android.intent.category.HOME | Out-Null
    Good "TV $ip done."

    # Security: network debugging lets any device on the Wi-Fi control the TV. Updates now come from GitHub, so turn it off.
    if ($null -eq $script:askedAdbOff) {
        $script:askedAdbOff = Read-Host "Turn OFF network debugging on the TVs now? (safer; Rawnaq keeps updating itself from GitHub; turn it on again only for the next install.bat) [Y/n]"
    }
    if ($script:askedAdbOff -notmatch '^[nN]') {
        Adb -s $tv shell settings put global adb_wifi_enabled 0 | Out-Null
        Adb -s $tv usb | Out-Null
        Good "Network debugging is off on $ip."
    } else {
        Warn "Network debugging stays on for $ip. Turn it off from Developer options when you finish."
    }
    return $true
}

$results = @()
foreach ($t in $targets) {
    $r = Install-OnTv $t
    $ok = (@($r) | Select-Object -Last 1) -eq $true
    $results += [pscustomobject]@{ TV = "$($t.Ip)"; Result = $(if ($ok) { 'OK' } else { 'FAILED' }) }
}

Step "Summary"
$results | Format-Table -AutoSize | Out-Host
try { Stop-Transcript | Out-Null } catch {}
Read-Host "Press Enter to close"
