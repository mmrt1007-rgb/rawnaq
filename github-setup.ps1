# Rawnaq on GitHub: automatic builds + self-update for the TV.
#  First run : creates a public GitHub repository, uploads the project, stores your signing key
#              as a secret (so GitHub builds install over the app on your TV), and publishes the
#              current version as a release.
#  Later runs: publishes a new release after you raise "version:" in pubspec.yaml.
# Needs Git and GitHub CLI (the script offers to install them with winget).
param([string]$Repo = "")
$ErrorActionPreference = "Continue"
$src = $PSScriptRoot
Set-Location $src
function Step($t) { Write-Host ""; Write-Host "==> $t" -ForegroundColor Cyan }
function Info($t) { Write-Host "    $t" }
function Good($t) { Write-Host "    $t" -ForegroundColor Green }
function Warn($t) { Write-Host "    $t" -ForegroundColor Yellow }
function Bad($t)  { Write-Host "    $t" -ForegroundColor Red }
function Done { Read-Host "Enter to close"; exit }

# ---------- tools ----------
Step "Checking Git and GitHub CLI"
foreach ($t in @(@{cmd = "git"; id = "Git.Git"}, @{cmd = "gh"; id = "GitHub.cli"})) {
    if (-not (Get-Command $t.cmd -ErrorAction SilentlyContinue)) {
        Warn "$($t.cmd) is not installed."
        $a = Read-Host "    Install it now with winget? [Y/n]"
        if ($a -notmatch '^[nN]') {
            winget install --id $t.id -e --accept-source-agreements --accept-package-agreements
            $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        }
        if (-not (Get-Command $t.cmd -ErrorAction SilentlyContinue)) { Bad "$($t.cmd) still missing. Install it, reopen this window, and run github-setup.bat again."; Done }
    }
}
Good "git and gh are ready."

gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Step "Signing in to GitHub (a browser window opens)"
    gh auth login --web --git-protocol https
    gh auth status 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Bad "GitHub sign-in did not finish."; Done }
}
$owner = (gh api user --jq .login).Trim()
Good "Signed in as $owner"

# ---------- version ----------
$verLine = (Select-String -Path (Join-Path $src "pubspec.yaml") -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$version = ($verLine -split '\+')[0]
Info "Project version: $version"

# ---------- repository ----------
if (-not $Repo) {
    $existing = (git remote get-url origin 2>$null)
    if ($existing -match 'github\.com[:/](.+?)/(.+?)(\.git)?$') { $Repo = $Matches[2] }
}
if (-not $Repo) {
    $a = Read-Host "Repository name (Enter = rawnaq)"
    $Repo = if ($a.Trim()) { $a.Trim() } else { "rawnaq" }
}
$full = "$owner/$Repo"

if (-not (Test-Path (Join-Path $src ".gitignore"))) {
    @("build/", "cec/", "rescue/", "install-log.txt", "start-failure-*.txt", "undo-home.txt", "*.keystore", "*.jks", "key.properties", "tvs.txt", "install-royal.bat", "install-all.bat", "update-url.txt", "*.apk") | Set-Content (Join-Path $src ".gitignore") -Encoding utf8
}
if (-not (Test-Path (Join-Path $src ".git"))) {
    Step "Creating the local repository"
    git init -b main | Out-Null
    if (-not (git config user.name)) { git config user.name $owner }
    if (-not (git config user.email)) { git config user.email "$owner@users.noreply.github.com" }
}

# update link baked into builds made on this PC
$updateUrl = "https://github.com/$full/releases/latest/download/update.json"
Set-Content (Join-Path $src "update-url.txt") $updateUrl -Encoding utf8

git add -A | Out-Null
git commit -m "Rawnaq $version" 2>$null | Out-Null

gh repo view $full 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Step "Creating github.com/$full (public, so the TV can download updates without a password)"
    gh repo create $full --public --source $src --remote origin --push --description "Rawnaq Android TV launcher"
    if ($LASTEXITCODE -ne 0) { Bad "Could not create the repository."; Done }
} else {
    Step "Uploading to github.com/$full"
    if (-not (git remote get-url origin 2>$null)) { git remote add origin "https://github.com/$full.git" }
    git push -u origin main
    if ($LASTEXITCODE -ne 0) {
        # النسخة اللي بهذا المجلد هي الأصل: إذا تاريخ GitHub مختلف، نحدّثه بقوة
        Warn "GitHub has a different history. Replacing it with this folder (this folder is the source of truth)."
        git push -u origin main --force
        if ($LASTEXITCODE -ne 0) { Bad "Could not upload the code."; Done }
    }
}
Good "Code is on GitHub."

# ---------- private release key secrets ----------
$relJks = Join-Path $env:USERPROFILE "rawnaq_keys\rawnaq-release.jks"
$relProps = Join-Path $env:USERPROFILE "rawnaq_keys\key.properties"
if ((Test-Path $relJks) -and (Test-Path $relProps)) {
    Step "Storing your private release key as encrypted GitHub secrets"
    $pw = ((Get-Content $relProps | Where-Object { $_ -match '^storePassword=' }) -replace '^storePassword=', '').Trim()
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($relJks)) | gh secret set RAWNAQ_KEYSTORE_B64 --repo $full
    $ok1 = $LASTEXITCODE -eq 0
    $pw | gh secret set RAWNAQ_KEY_PASSWORD --repo $full
    if ($ok1 -and $LASTEXITCODE -eq 0) { Good "Release key saved. GitHub builds are signed exactly like the app on your TV." }
    else { Bad "Could not save the release key secrets." }
} else {
    Warn "No private release key yet. Run install.bat once (it creates it), then run github-setup.bat again."
}

# ---------- development key secret (fallback) ----------
Step "Storing the development key as a fallback secret"
$key = @((Join-Path $env:USERPROFILE "rawnaq_keys\rawnaq-signing.keystore"), (Join-Path $env:USERPROFILE "hafidh_keys\hafidh-signing.keystore"), (Join-Path $env:USERPROFILE ".android\debug.keystore")) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($key) {
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($key))
    $b64 | gh secret set ANDROID_DEBUG_KEYSTORE_B64 --repo $full
    if ($LASTEXITCODE -eq 0) { Good "Secret saved (from $key). GitHub builds now carry the same signature as the app on your TV." }
    else { Bad "Could not save the secret." }
} else {
    Warn "No signing key found yet. Run install.bat once (it builds and saves the key), then run github-setup.bat again."
}

# ---------- release ----------
$tag = "v$version"
git rev-parse $tag 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Warn "Release $tag already exists. To publish a new one: raise 'version:' in pubspec.yaml (for example 3.7.1+12), edit release-notes.txt, then run github-setup.bat again."
} else {
    $a = Read-Host "Publish version $version as a release now? (each newer release is then offered on the TV) [Y/n]"
    if ($a -notmatch '^[nN]') {
        git tag $tag
        git push origin $tag
        Good "Release $tag started. GitHub builds it in about 8 minutes."
    }
}

Step "Done"
Info "Builds:   https://github.com/$full/actions"
Info "Releases: https://github.com/$full/releases"
Info "Update link (already built into the app): $updateUrl"
Info "Run install.bat once now, so the app on the TV knows this update link."
Info "If a build fails, open the red run on the Actions page and send me the error lines."
Done
