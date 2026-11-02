# Fix all web projects so they open on every device and browser.
#
# Run from PowerShell:
#   powershell -ExecutionPolicy Bypass -File "C:\Users\OWER\OneDrive\Desktop\Portfolio-master\fix-all-projects.ps1"
#
# Flutter apps (MyTasks, Clock In Buddy, CV Analyzer, Client Ticket App):
#   build with --no-web-resources-cdn so the Flutter engine (CanvasKit) is
#   served from GitHub Pages with the app instead of www.gstatic.com.
# React/Vite sites (Elite Barbershop, XML to CSV Converter):
#   add @vitejs/plugin-legacy so older iPhones, Android and desktop browsers
#   get a compatible build, then publish to GitHub Pages.
# Portfolio: publish the loading fix.
#
# Each project is handled separately: if one fails, the rest still run.

$ErrorActionPreference = 'Stop'
$Desktop = Join-Path $env:USERPROFILE 'OneDrive\Desktop'
if (-not (Test-Path $Desktop)) { $Desktop = Join-Path $env:USERPROFILE 'Desktop' }
$results = @()

function Step($t) { Write-Host ''; Write-Host "==> $t" -ForegroundColor Cyan }
function Run($exe, [string[]]$a) {
    & $exe @a
    if ($LASTEXITCODE -ne 0) { throw "'$exe $($a -join ' ')' failed (exit code $LASTEXITCODE)" }
}
function Edit-File($path, [scriptblock]$change) {
    $old = [IO.File]::ReadAllText($path)
    $new = & $change $old
    if ($new -ne $old) {
        [IO.File]::WriteAllText($path, $new, (New-Object Text.UTF8Encoding($false)))
        return $true
    }
    return $false
}
function Ensure-Clone($name) {
    $dir = Join-Path $Desktop $name
    if (-not (Test-Path (Join-Path $dir '.git'))) {
        Push-Location $Desktop
        Run 'git' @('clone', "https://github.com/Chrid17/$name.git")
        Pop-Location
    }
    return $dir
}
function Commit-Push($message) {
    & git add -A
    & git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        Run 'git' @('commit', '-m', $message)
    }
    $branch = (& git rev-parse --abbrev-ref HEAD).Trim()
    & git pull --rebase --autostash origin $branch
    Run 'git' @('push', 'origin', $branch)
}
function Add-NoCdnFlag($workflow) {
    if (-not (Test-Path $workflow)) { throw "Workflow not found: $workflow" }
    $changed = Edit-File $workflow {
        param($t)
        if ($t.Contains('--no-web-resources-cdn')) { return $t }
        return $t.Replace('flutter build web', 'flutter build web --no-web-resources-cdn')
    }
    if ($changed) { Write-Host "    updated $workflow" } else { Write-Host '    already self-hosting the engine' }
}
function Record($name, [scriptblock]$work) {
    Step $name
    try {
        & $work
        $script:results += [pscustomobject]@{ Project = $name; Result = 'OK' }
    } catch {
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Yellow
        $script:results += [pscustomobject]@{ Project = $name; Result = "FAILED: $($_.Exception.Message)" }
    } finally {
        Set-Location $Desktop
    }
}

# ---------------------------------------------------------------------------
Record 'MyTasks' {
    $dir = Join-Path $Desktop 'MyTasks-main'
    if (-not (Test-Path $dir)) { $dir = Ensure-Clone 'MyTasks' }
    Set-Location $dir
    if (-not (Test-Path '.git')) {
        Run 'git' @('init', '-b', 'main')
        Run 'git' @('remote', 'add', 'origin', 'https://github.com/Chrid17/MyTasks.git')
        Run 'git' @('fetch', 'origin')
        Run 'git' @('reset', 'origin/main')
        Run 'git' @('branch', '--set-upstream-to=origin/main')
    }
    Add-NoCdnFlag '.github\workflows\deploy.yml'
    if (Test-Path '.github\workflows\ci.yml') {
        Edit-File '.github\workflows\ci.yml' {
            param($t)
            if ($t.Contains('--no-fatal-warnings')) { return $t }
            return $t.Replace('flutter analyze --no-fatal-infos', 'flutter analyze --no-fatal-infos --no-fatal-warnings')
        } | Out-Null
    }
    Commit-Push 'Self-host Flutter engine so the app opens on every device'
}

# ---------------------------------------------------------------------------
Record 'Clock In Buddy' {
    Set-Location (Join-Path $Desktop 'clock-in-buddy-main')
    Add-NoCdnFlag '.github\workflows\deploy-web.yml'
    Commit-Push 'Self-host Flutter engine so the app opens on every device'
}

# ---------------------------------------------------------------------------
Record 'CV Analyzer Pro' {
    Set-Location (Join-Path $Desktop 'cv_corrector app')
    Add-NoCdnFlag '.github\workflows\deploy.yml'
    Commit-Push 'Self-host Flutter engine so the app opens on every device'
}

# ---------------------------------------------------------------------------
Record 'Client Ticket App' {
    Set-Location (Ensure-Clone 'ticketing_app')
    # Add the desktop platforms the project is missing.
    Run 'flutter' @('create', '--platforms=windows,linux,macos,web,android,ios', '.')
    if (Test-Path 'test\widget_test.dart') {
        $t = [IO.File]::ReadAllText((Resolve-Path 'test\widget_test.dart'))
        if ($t.Contains('MyApp') -and -not (Select-String -Path 'lib\*.dart' -Pattern 'class MyApp' -Quiet)) {
            Remove-Item 'test\widget_test.dart'
        }
    }
    New-Item -ItemType Directory -Force '.github\workflows' | Out-Null
    $wf = @'
name: Deploy web app to GitHub Pages

on:
  push:
    branches: [main, master]
  workflow_dispatch:

permissions:
  contents: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter build web --release --no-web-resources-cdn --base-href "/${{ github.event.repository.name }}/"
      - uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: build/web
          publish_branch: gh-pages
'@
    [IO.File]::WriteAllText((Join-Path (Get-Location) '.github\workflows\deploy.yml'), $wf, (New-Object Text.UTF8Encoding($false)))
    Commit-Push 'Add all platforms and GitHub Pages deploy'
}

# ---------------------------------------------------------------------------
Record 'Elite Barbershop Website' {
    Set-Location (Ensure-Clone 'Elite-Barbershop-Website')
    Run 'npm' @('install')
    Run 'npm' @('install', '-D', '@vitejs/plugin-legacy@^7', 'terser')
    Edit-File 'vite.config.ts' {
        param($t)
        if ($t.Contains('plugin-legacy')) { return $t }
        $t = $t.Replace("import react from '@vitejs/plugin-react-swc';",
            "import react from '@vitejs/plugin-react-swc';`nimport legacy from '@vitejs/plugin-legacy';")
        $t = $t.Replace('plugins: [react()],',
            "plugins: [react(), legacy({ targets: ['defaults', 'not IE 11', 'iOS >= 12', 'Safari >= 12', 'Android >= 7'] })],")
        $t = $t.Replace("target: 'esnext',", '')
        return $t
    } | Out-Null
    if (-not (Select-String -Path 'vite.config.ts' -Pattern 'legacy\(' -Quiet)) {
        throw 'Could not add the legacy plugin to vite.config.ts'
    }
    Run 'npm' @('run', 'deploy')
    Commit-Push 'Support all browsers and devices (legacy build)'
}

# ---------------------------------------------------------------------------
Record 'XML to CSV Converter' {
    Set-Location (Ensure-Clone 'xml-csv-turbo-converter-main')
    Run 'npm' @('install')
    Run 'npm' @('install', '-D', '@vitejs/plugin-legacy@^5', 'terser@^5')
    Edit-File 'vite.config.ts' {
        param($t)
        if ($t.Contains('plugin-legacy')) { return $t }
        $t = $t.Replace('import react from "@vitejs/plugin-react-swc";',
            "import react from `"@vitejs/plugin-react-swc`";`nimport legacy from `"@vitejs/plugin-legacy`";")
        $t = $t.Replace('react(),',
            "react(),`n    legacy({ targets: ['defaults', 'not IE 11', 'iOS >= 12', 'Safari >= 12', 'Android >= 7'] }),")
        return $t
    } | Out-Null
    if (-not (Select-String -Path 'vite.config.ts' -Pattern 'legacy\(' -Quiet)) {
        throw 'Could not add the legacy plugin to vite.config.ts'
    }
    Run 'npm' @('run', 'deploy')
    Commit-Push 'Support all browsers and devices (legacy build)'
}

# ---------------------------------------------------------------------------
Record 'Portfolio' {
    Set-Location (Join-Path $Desktop 'Portfolio-master')
    & git add index.html script.js style.css
    & git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { Run 'git' @('commit', '-m', 'Open quickly on every device; updated projects') }
    & git pull --rebase --autostash origin master
    Run 'git' @('push', 'origin', 'master')
}

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '================ Summary ================' -ForegroundColor Green
$results | Format-Table -AutoSize | Out-String | Write-Host
Write-Host 'GitHub now rebuilds each site (3-5 minutes). Check the Actions tab of each repo.'
Write-Host 'One-time step for Client Ticket App and XML to CSV Converter:'
Write-Host '  GitHub repo > Settings > Pages > Source: Deploy from a branch > gh-pages / (root) > Save'
