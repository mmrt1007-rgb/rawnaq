# Builds the Rawnaq launcher and produces a ready-to-install APK.
# - Creates the Android project (first time only)
# - Downloads the Arabic fonts listed in fonts.json from Google Fonts into the project
# - Builds a release APK
# Usage: run install.bat (it calls this), or:  powershell -ExecutionPolicy Bypass -File setup.ps1

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$src = $PSScriptRoot
# Build outside OneDrive/Desktop: syncing thousands of build files breaks Gradle.
$out = Join-Path $env:USERPROFILE "rawnaq_build"
$utf8 = New-Object System.Text.UTF8Encoding $false

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter is not installed or not on PATH." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "$out\pubspec.yaml")) {
    Write-Host "Creating Android project..." -ForegroundColor Cyan
    flutter create --org com --project-name rawnaq --platforms android $out
}

# ---------- Signing key (one fixed key = updates install over the old app without deleting it) ----------
# Flutter signs with %USERPROFILE%\.android\debug.keystore. We keep a safe copy in rawnaq_keys and restore it
# on a new PC, so every build (this PC, another PC, or GitHub Actions) carries the same signature.
$keyDir = Join-Path $env:USERPROFILE "rawnaq_keys"
$keySafe = Join-Path $keyDir "rawnaq-signing.keystore"
$keyLive = Join-Path $env:USERPROFILE ".android\debug.keystore"
New-Item -ItemType Directory -Force -Path $keyDir | Out-Null
# Same key as the old Al-Hafidh builds (hafidh_keys), so the GitHub secret and future updates keep working.
$keyOld = Join-Path $env:USERPROFILE "hafidh_keys\hafidh-signing.keystore"
if (-not (Test-Path $keySafe) -and (Test-Path $keyOld)) {
    Copy-Item $keyOld $keySafe -Force
    Write-Host "Signing key carried over from hafidh_keys." -ForegroundColor Green
}
if ((Test-Path $keyLive) -and -not (Test-Path $keySafe)) {
    Copy-Item $keyLive $keySafe -Force
    Write-Host "Signing key saved to $keySafe (keep a copy on a USB stick)." -ForegroundColor Green
} elseif ((Test-Path $keySafe) -and -not (Test-Path $keyLive)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $keyLive) | Out-Null
    Copy-Item $keySafe $keyLive -Force
    Write-Host "Signing key restored from $keySafe." -ForegroundColor Green
} elseif ((Test-Path $keySafe) -and (Test-Path $keyLive) -and ((Get-FileHash $keySafe).Hash -ne (Get-FileHash $keyLive).Hash)) {
    Write-Host "WARNING: $keyLive differs from the saved key. Restoring the saved key so updates keep working." -ForegroundColor Yellow
    Copy-Item $keyLive (Join-Path $keyDir ("replaced-" + (Get-Date -Format yyyyMMdd-HHmmss) + ".keystore")) -Force
    Copy-Item $keySafe $keyLive -Force
}

Write-Host "Copying launcher files..." -ForegroundColor Cyan
Remove-Item "$out\lib" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item "$src\lib" "$out\lib" -Recurse -Force
Copy-Item "$src\android\app\src\main\*" "$out\android\app\src\main\" -Recurse -Force
Remove-Item "$out\test" -Recurse -Force -ErrorAction SilentlyContinue

# ---------- Private release key (strong password, made once, kept in rawnaq_keys) ----------
# Rawnaq is signed with its own release key, not the shared development key whose password is public.
$relJks = Join-Path $keyDir "rawnaq-release.jks"
$relProps = Join-Path $keyDir "key.properties"
if (-not (Test-Path $relJks)) {
    $keytool = $null
    $kt = Get-Command keytool -ErrorAction SilentlyContinue
    if ($kt) { $keytool = $kt.Source }
    if (-not $keytool -and $env:JAVA_HOME -and (Test-Path "$env:JAVA_HOME\bin\keytool.exe")) { $keytool = "$env:JAVA_HOME\bin\keytool.exe" }
    if (-not $keytool) {
        $jb = (flutter doctor -v 2>$null | Select-String 'Java binary at:\s*(.+java\.exe)' | Select-Object -First 1)
        if ($jb) { $c = Join-Path (Split-Path $jb.Matches[0].Groups[1].Value.Trim()) "keytool.exe"; if (Test-Path $c) { $keytool = $c } }
    }
    if (-not $keytool) {
        foreach ($c in @("C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe", "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe")) { if (Test-Path $c) { $keytool = $c; break } }
    }
    if ($keytool) {
        $chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
        $pass = -join (1..32 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
        & $keytool -genkeypair -keystore $relJks -storetype PKCS12 -alias rawnaq -keyalg RSA -keysize 4096 -validity 10000 `
            -storepass $pass -keypass $pass -dname "CN=Rawnaq, O=Rawnaq, C=IQ" 2>&1 | Out-Null
        if (Test-Path $relJks) {
            $props = "storeFile=$($relJks -replace '\\','/')`nstorePassword=$pass`nkeyAlias=rawnaq`nkeyPassword=$pass`n"
            [IO.File]::WriteAllText($relProps, $props, $utf8)
            Write-Host "Private release key created in $keyDir" -ForegroundColor Green
            Write-Host "KEEP A COPY of this folder on a USB stick. Without it no future update can install over Rawnaq." -ForegroundColor Yellow
        } else { Write-Host "Could not create the release key; building with the development key." -ForegroundColor Yellow }
    } else { Write-Host "keytool not found (comes with Android Studio); building with the development key." -ForegroundColor Yellow }
}
# Release signing (Flutter's documented way): imports at the top, key.properties read before android { },
# and signingConfigs inside android { }. Works on old AGP and on AGP 9's new DSL.
# A build file patched by an older Rawnaq version is thrown away and regenerated clean by flutter create.
$gk = "$out\android\app\build.gradle.kts"
$gg = "$out\android\app\build.gradle"
if ((Test-Path $gk) -and ([IO.File]::ReadAllText($gk) -match 'RAWNAQ_SIGNING(:|2)')) {
    Remove-Item $gk -Force
    flutter create --org com --project-name rawnaq --platforms android $out | Out-Null
}
if (Test-Path $gk) {
    $txt = [IO.File]::ReadAllText($gk)
    if ($txt -notmatch 'RAWNAQ_SIGNING3') {
        $parts = [IO.File]::ReadAllText((Join-Path $src "tools\signing.gradle.kts.txt")) -split '#--INSIDE-ANDROID--\r?\n'
        $rx = [regex]'(?m)^android\s*\{[^\r\n]*\r?\n'
        if ($rx.IsMatch($txt) -and $parts.Count -eq 2) {
            $top = $parts[0]; $inside = $parts[1]
            $txt = $rx.Replace($txt, { param($m) $top + $m.Value + $inside }, 1)
            $txt = [regex]::Replace($txt, 'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)', 'signingConfig = signingConfigs.findByName("rawnaqRelease") ?: signingConfigs.getByName("debug")')
            $txt = "import java.io.FileInputStream`nimport java.util.Properties`n" + $txt
            [IO.File]::WriteAllText($gk, $txt, $utf8)
        } else { Write-Host "android { } not found in build.gradle.kts; building with the development key." -ForegroundColor Yellow }
    }
} elseif (Test-Path $gg) {
    $txt = [IO.File]::ReadAllText($gg)
    if ($txt -notmatch 'RAWNAQ_SIGNING') { [IO.File]::AppendAllText($gg, [IO.File]::ReadAllText((Join-Path $src "tools\signing.gradle.txt")), $utf8) }
}
if (Test-Path $relProps) { Copy-Item $relProps "$out\android\key.properties" -Force }
else { Remove-Item "$out\android\key.properties" -Force -ErrorAction SilentlyContinue }

# ---------- Fonts ----------
Write-Host "Preparing Arabic fonts (downloaded once, then reused)..." -ForegroundColor Cyan
$fontsDir = Join-Path $out "assets\fonts"
New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null
$list = Get-Content "$src\fonts.json" -Raw | ConvertFrom-Json
$families = @()

foreach ($f in $list) {
    $safe = $f.family -replace '[^A-Za-z0-9]', ''
    $q = $f.family -replace ' ', '+'
    $files = @()
    foreach ($w in $f.weights) {
        $dest = Join-Path $fontsDir "$safe-$w.ttf"
        if (-not (Test-Path $dest)) {
            $url = if ($w -eq 400) { "https://fonts.googleapis.com/css2?family=$q" } else { "https://fonts.googleapis.com/css2?family=${q}:wght@$w" }
            try {
                $css = (Invoke-WebRequest -Uri $url -UserAgent "curl/8.4.0" -UseBasicParsing -TimeoutSec 30).Content
                $fontUrl = $null
                foreach ($m in [regex]::Matches($css, "/\*\s*([\w\-]+)\s*\*/\s*@font-face\s*\{[^}]*?url\((https://[^)]+)\)")) {
                    if ($m.Groups[1].Value -eq 'arabic') { $fontUrl = $m.Groups[2].Value }
                }
                if (-not $fontUrl) {
                    $m2 = [regex]::Match($css, "url\((https://[^)]+)\)")
                    if ($m2.Success) { $fontUrl = $m2.Groups[1].Value }
                }
                if ($fontUrl) { Invoke-WebRequest -Uri $fontUrl -OutFile $dest -UseBasicParsing -TimeoutSec 90 }
            } catch { }
        }
        if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 1000)) {
            $files += [pscustomobject]@{ Path = "assets/fonts/$safe-$w.ttf"; Weight = $w }
        } else {
            Remove-Item $dest -Force -ErrorAction SilentlyContinue
        }
    }
    if ($files.Count -gt 0) {
        $families += [pscustomobject]@{ Family = $f.family; Files = $files }
        Write-Host ("  [ok] {0} ({1} weights)" -f $f.family, $files.Count) -ForegroundColor DarkGreen
    } else {
        Write-Host ("  [--] {0} not available, skipped" -f $f.family) -ForegroundColor DarkYellow
    }
}

# pubspec.yaml = base + generated fonts section
$yaml = (Get-Content "$src\pubspec.yaml" -Raw).TrimEnd() + "`n"
if ($families.Count -gt 0) {
    $yaml += "  fonts:`n"
    foreach ($fam in $families) {
        $yaml += "    - family: $($fam.Family)`n      fonts:`n"
        foreach ($file in $fam.Files) {
            $yaml += "        - asset: $($file.Path)`n          weight: $($file.Weight)`n"
        }
    }
}
[IO.File]::WriteAllText((Join-Path $out "pubspec.yaml"), $yaml, $utf8)

# Default update link (written by github-setup.ps1 into update-url.txt)
$uf = Join-Path $src "update-url.txt"
$uu = if (Test-Path $uf) { (Get-Content $uf -Raw).Trim() -replace "'", "" } else { "" }
[IO.File]::WriteAllText((Join-Path $out "lib\build_info.dart"), "// GENERATED by setup.ps1`nconst kUpdateUrl = '$uu';`n", $utf8)

# Dart list of the fonts that actually made it into the app
$dart = "// GENERATED by setup.ps1 - fonts bundled in this build.`nconst availableFonts = <String>[`n"
foreach ($fam in $families) { $dart += "  '$($fam.Family)',`n" }
$dart += "];`n"
[IO.File]::WriteAllText((Join-Path $out "lib\fonts_available.dart"), $dart, $utf8)
Write-Host ("Fonts bundled: {0}" -f $families.Count) -ForegroundColor Green

Set-Location $out

# Stop any leftover Gradle daemon and clear stale cache locks from a crashed build.
Write-Host "Cleaning old build locks..." -ForegroundColor Cyan
if (Test-Path "$out\android\gradlew.bat") { & "$out\android\gradlew.bat" -p "$out\android" --stop 2>$null | Out-Null }
Get-CimInstance Win32_Process -Filter "Name='java.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'GradleDaemon' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Remove-Item "$out\android\.gradle" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Getting packages..." -ForegroundColor Cyan
flutter pub get

Write-Host "Building release APK..." -ForegroundColor Cyan
# ARM only (every Android TV): smaller APK, faster install and start-up
# Full build output is also saved next to install.ps1 (build-output.txt) so errors can be read later
$buildLog = Join-Path $src "build-output.txt"
flutter build apk --release --target-platform android-arm,android-arm64 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $buildLog

$apk = Join-Path $out "build\app\outputs\flutter-apk\app-release.apk"
Write-Host ""
if (Test-Path $apk) {
    Write-Host "Done! APK:" -ForegroundColor Green
    Write-Host $apk
} else {
    Write-Host "Build did not produce an APK." -ForegroundColor Red
    # The lines that explain why (Dart errors, Gradle script errors, "What went wrong")
    $why = @(Get-Content $buildLog -ErrorAction SilentlyContinue | Where-Object { $_ -match 'error|Error:|What went wrong|Line \d+:|e: |Unresolved|FAILURE|Exception' } | Select-Object -First 40)
    if ($why.Count) { Write-Host "---- why it failed ----" -ForegroundColor Yellow; $why | ForEach-Object { Write-Host $_ } }
    Write-Host "Full output: $buildLog" -ForegroundColor Yellow
    exit 1
}
