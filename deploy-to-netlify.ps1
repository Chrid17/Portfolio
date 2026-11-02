# Publish every project to Netlify so it opens on any network (mobile data
# included), any device and any browser.
#
# Run from PowerShell:
#   powershell -ExecutionPolicy Bypass -File "C:\Users\OWER\OneDrive\Desktop\Portfolio-master\deploy-to-netlify.ps1"
#
# First run: a browser window opens once to log in to Netlify (use "GitHub").
# Safe to run again later to republish everything with your latest changes.

$ErrorActionPreference = 'Continue'
$Desktop = Join-Path $env:USERPROFILE 'OneDrive\Desktop'
if (-not (Test-Path $Desktop)) { $Desktop = Join-Path $env:USERPROFILE 'Desktop' }
$Portfolio = Join-Path $Desktop 'Portfolio-master'
$SitesFile = Join-Path $Portfolio 'netlify-sites.json'
$results = New-Object System.Collections.ArrayList
$urls = @{}
if (Test-Path $SitesFile) {
    try {
        $saved = Get-Content $SitesFile -Raw | ConvertFrom-Json
        foreach ($p in $saved.PSObject.Properties) { $urls[$p.Name] = $p.Value }
    } catch {}
}

function Step($t) { Write-Host ''; Write-Host "==> $t" -ForegroundColor Cyan }
function Info($t) { Write-Host "    $t" }
function Run($exe, [string[]]$a) {
    & $exe @a | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "'$exe $($a -join ' ')' failed (exit code $LASTEXITCODE)" }
}
function Write-Utf8($path, $text) {
    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
}
function Ensure-Clone($repo, $folder) {
    $dir = Join-Path $Desktop $folder
    if (-not (Test-Path $dir)) {
        Push-Location $Desktop
        Run 'git' @('clone', "https://github.com/Chrid17/$repo.git", $folder)
        Pop-Location
    }
    return $dir
}

# Single-page apps: every path serves index.html.
function Add-SpaRedirect($dir) {
    Write-Utf8 (Join-Path $dir '_redirects') "/*    /index.html   200`n"
}

# Deploys a folder to Netlify, creating the site on first use.
function Publish($key, $dir, [string[]]$names) {
    $candidates = @()
    if ($urls.ContainsKey($key)) {
        $candidates += ([uri]$urls[$key]).Host.Split('.')[0]
    }
    $candidates += $names
    foreach ($name in ($candidates | Select-Object -Unique)) {
        Info "Publishing to $name.netlify.app ..."
        $out = & netlify deploy --prod --no-build --dir "$dir" --site-name $name --message "Published by deploy-to-netlify.ps1" --json 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $url = "https://$name.netlify.app"
            try {
                $start = $out.IndexOf('{')
                if ($start -ge 0) {
                    $json = $out.Substring($start) | ConvertFrom-Json
                    if ($json.url) { $url = $json.url.TrimEnd('/') }
                }
            } catch {}
            $urls[$key] = $url
            Info "Live at $url"
            return $url
        }
        Info "Name $name is not available, trying the next one."
    }
    throw "Could not publish $key to Netlify. Last output:`n$out"
}

function Record($name, [scriptblock]$work) {
    Step $name
    try {
        $url = & $work
        [void]$results.Add([pscustomobject]@{ Project = $name; Result = 'OK'; Url = $url })
    } catch {
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Yellow
        [void]$results.Add([pscustomobject]@{ Project = $name; Result = 'FAILED'; Url = $_.Exception.Message.Split("`n")[0] })
    } finally {
        Set-Location $Desktop
    }
}

function Build-Flutter($dir) {
    Set-Location $dir
    Run 'flutter' @('pub', 'get')
    Run 'flutter' @('build', 'web', '--release', '--no-web-resources-cdn', '--base-href', '/')
    $out = Join-Path $dir 'build\web'
    Add-SpaRedirect $out
    return $out
}

function Build-Vite($dir, $legacyVersion, $importStyle) {
    Set-Location $dir
    Run 'npm' @('install')
    $cfg = Join-Path $dir 'vite.config.ts'
    $text = [IO.File]::ReadAllText($cfg)
    if (-not $text.Contains('plugin-legacy')) {
        Run 'npm' @('install', '-D', "@vitejs/plugin-legacy@$legacyVersion", 'terser')
        $targets = "legacy({ targets: ['defaults', 'not IE 11', 'iOS >= 12', 'Safari >= 12', 'Android >= 7'] })"
        if ($importStyle -eq 'single') {
            $text = $text.Replace("import react from '@vitejs/plugin-react-swc';",
                "import react from '@vitejs/plugin-react-swc';`nimport legacy from '@vitejs/plugin-legacy';")
            $text = $text.Replace('plugins: [react()],', "plugins: [react(), $targets],")
            $text = $text.Replace("target: 'esnext',", '')
        } else {
            $text = $text.Replace('import react from "@vitejs/plugin-react-swc";',
                "import react from `"@vitejs/plugin-react-swc`";`nimport legacy from `"@vitejs/plugin-legacy`";")
            $text = $text.Replace('react(),', "react(),`n    $targets,")
        }
        if (-not $text.Contains('legacy(')) { throw 'Could not add the browser-compatibility plugin to vite.config.ts' }
        Write-Utf8 $cfg $text
        & git add -A | Out-Host
        & git commit -m 'Support all browsers and devices (legacy build)' | Out-Host
        & git push | Out-Host
    }
    # Root path build for Netlify (GitHub Pages keeps its own sub-path build).
    Run 'npx' @('vite', 'build', '--base=/')
    $out = Join-Path $dir 'dist'
    Add-SpaRedirect $out
    return $out
}

# ---------------------------------------------------------------------------
Step 'Netlify command-line tool'
& netlify --version 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Info 'Installing netlify-cli (one time)...'
    Run 'npm' @('install', '-g', 'netlify-cli')
}
$status = & netlify status 2>&1 | Out-String
if ($status -match 'Not logged in' -or $LASTEXITCODE -ne 0) {
    Info 'A browser window will open: log in to Netlify (choose GitHub), then come back here.'
    Run 'netlify' @('login')
}

# ---------------------------------------------------------------------------
Record 'My Tasks' {
    $dir = Join-Path $Desktop 'MyTasks-main'
    if (-not (Test-Path $dir)) { $dir = Ensure-Clone 'MyTasks' 'MyTasks-main' }
    Publish 'mytasks' (Build-Flutter $dir) @('chrid17-mytasks', 'christian-mytasks', 'cb-mytasks-app')
}

Record 'Clock In Buddy' {
    $dir = Join-Path $Desktop 'clock-in-buddy-main\clock_in_buddy'
    Publish 'clockin' (Build-Flutter $dir) @('chrid17-clockinbuddy', 'christian-clockinbuddy', 'cb-clock-in-buddy')
}

Record 'CV Analyzer Pro' {
    $dir = Join-Path $Desktop 'cv_corrector app'
    Publish 'cvanalyzer' (Build-Flutter $dir) @('chrid17-cv-analyzer', 'christian-cv-analyzer', 'cb-cv-analyzer-pro')
}

Record 'Client Ticket App' {
    $dir = Ensure-Clone 'ticketing_app' 'ticketing_app'
    Set-Location $dir
    if (-not (Test-Path 'web')) { Run 'flutter' @('create', '--platforms=web', '.') }
    Publish 'tickets' (Build-Flutter $dir) @('chrid17-ticket-app', 'christian-ticket-app', 'cb-client-ticket-app')
}

Record 'Elite Barbershop Website' {
    $dir = Ensure-Clone 'Elite-Barbershop-Website' 'Elite-Barbershop-Website'
    Publish 'elite' (Build-Vite $dir '^7' 'single') @('chrid17-elite-barbershop', 'christian-elite-barbershop', 'cb-elite-barbershop')
}

Record 'XML to CSV Converter' {
    $dir = Ensure-Clone 'xml-csv-turbo-converter-main' 'xml-csv-turbo-converter-main'
    Publish 'xmlcsv' (Build-Vite $dir '^5' 'double') @('chrid17-xml-csv-converter', 'christian-xml-csv', 'cb-xml-csv-converter')
}

# ---------------------------------------------------------------------------
Record 'Portfolio' {
    Set-Location $Portfolio
    $index = Join-Path $Portfolio 'index.html'
    $html = [IO.File]::ReadAllText($index)
    $map = @{
        'https://chrid17.github.io/MyTasks/'                 = 'mytasks'
        'https://chrid17.github.io/clock-in-buddy-main/'     = 'clockin'
        'https://chrid17.github.io/cv_corrector-app/'        = 'cvanalyzer'
        'https://client-ticket-app-d3a45.web.app'            = 'tickets'
        'https://chrid17.github.io/Elite-Barbershop-Website/' = 'elite'
    }
    foreach ($old in $map.Keys) {
        $key = $map[$old]
        if ($urls.ContainsKey($key)) { $html = $html.Replace($old, $urls[$key] + '/') }
    }
    # Link the converter's live demo once it is published.
    if ($urls.ContainsKey('xmlcsv') -and -not $html.Contains($urls['xmlcsv'])) {
        $live = $urls['xmlcsv'] + '/'
        $gh = '<a href="https://github.com/Chrid17/xml-csv-turbo-converter-main" target="_blank" rel="noopener noreferrer" class="project-btn project-btn-ghost"><i class="fab fa-github"></i> Code</a>'
        $html = $html.Replace($gh, "<a href=`"$live`" target=`"_blank`" rel=`"noopener noreferrer`" class=`"project-btn project-btn-primary`"><i class=`"fas fa-play`"></i> Live Demo</a>`n                            $gh")
    }
    Write-Utf8 $index $html

    # Publish only the website files.
    $tmp = Join-Path $env:TEMP 'portfolio-netlify'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    New-Item -ItemType Directory $tmp | Out-Null
    foreach ($f in @('index.html', 'style.css', 'script.js', 'favicon.svg', 'Christian_Bwendo_CV.pdf')) {
        if (Test-Path $f) { Copy-Item $f $tmp }
    }
    $url = Publish 'portfolio' $tmp @('christianbwendo', 'christian-bwendo', 'christianbwendo-portfolio', 'chrid17-portfolio')

    # Keep the GitHub copy in sync too.
    & git add index.html script.js style.css | Out-Host
    & git commit -m 'Link projects to their Netlify sites' | Out-Host
    & git pull --rebase --autostash origin master | Out-Host
    & git push origin master | Out-Host
    return $url
}

# ---------------------------------------------------------------------------
Write-Utf8 $SitesFile ($urls | ConvertTo-Json)

Step 'Checking every site responds'
foreach ($r in $results) {
    if ($r.Result -ne 'OK') { continue }
    try {
        $resp = Invoke-WebRequest -Uri ($r.Url + '/') -UseBasicParsing -TimeoutSec 30
        $r.Result = "OK ($($resp.StatusCode))"
    } catch {
        $r.Result = 'Published, but not answering yet'
    }
}

Write-Host ''
Write-Host '================ Your live sites ================' -ForegroundColor Green
$results | Format-Table -AutoSize -Wrap | Out-String | Write-Host
Write-Host 'Open each address on your phone using MOBILE DATA to confirm.'
Write-Host 'To republish after changes, run this script again.'
