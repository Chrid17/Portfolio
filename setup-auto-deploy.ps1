# One-time setup: after this, every "git push" also republishes the project
# to Cloudflare Pages automatically (as well as GitHub Pages).
#
# Run from PowerShell:
#   powershell -ExecutionPolicy Bypass -File "C:\Users\OWER\OneDrive\Desktop\Portfolio-master\setup-auto-deploy.ps1"
#
# It adds .github/workflows/cloudflare.yml to each project, stores your
# Cloudflare token and account ID as GitHub repository secrets (never in the
# code), and pushes. Safe to run again, e.g. after you change the token.

$ErrorActionPreference = 'Continue'
$Desktop = Join-Path $env:USERPROFILE 'OneDrive\Desktop'
if (-not (Test-Path $Desktop)) { $Desktop = Join-Path $env:USERPROFILE 'Desktop' }
$results = New-Object System.Collections.ArrayList

function Step($t) { Write-Host ''; Write-Host "==> $t" -ForegroundColor Cyan }
function Info($t) { Write-Host "    $t" }
function Run($exe, [string[]]$a) {
    & $exe @a | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "'$exe $($a -join ' ')' failed (exit code $LASTEXITCODE)" }
}
function Write-Utf8($path, $text) {
    [IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n"), (New-Object Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------------------
Step 'Cloudflare token and account ID'
$token = $env:CLOUDFLARE_API_TOKEN
if (-not $token) { $token = [Environment]::GetEnvironmentVariable('CLOUDFLARE_API_TOKEN', 'User') }
$account = $env:CLOUDFLARE_ACCOUNT_ID
if (-not $account) { $account = [Environment]::GetEnvironmentVariable('CLOUDFLARE_ACCOUNT_ID', 'User') }
if (-not $token -or -not $account) {
    throw 'CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID are not set. Run the setx commands first, then open a new PowerShell window.'
}
Info 'Found both.'

Step 'GitHub command-line tool (gh)'
& gh --version 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Info 'Installing GitHub CLI (one time)...'
    Run 'winget' @('install', '--id', 'GitHub.cli', '-e', '--accept-source-agreements', '--accept-package-agreements')
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Info 'Log in to GitHub: choose GitHub.com > HTTPS > Login with a web browser.'
    Info 'Copy the one-time code it shows, press Enter, paste the code in the browser.'
    & gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { throw 'GitHub login failed. Run the script again.' }
}

# ---------------------------------------------------------------------------
# Workflow templates. __NAME__, __DIR__, and __BRANCHES__ are filled per project.
$flutterWf = @'
name: Deploy to Cloudflare Pages

on:
  push:
    branches: [__BRANCHES__]
  workflow_dispatch:

jobs:
  cloudflare:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: __DIR__
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - name: Add web support if missing
        run: if [ ! -d web ]; then flutter create --platforms=web .; fi
      - run: flutter pub get
      - name: Build
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
          GROQ_API_KEY: ${{ secrets.GROQ_API_KEY }}
        run: |
          ARGS=""
          if [ -n "$SUPABASE_URL" ]; then ARGS="$ARGS --dart-define=SUPABASE_URL=$SUPABASE_URL"; fi
          if [ -n "$SUPABASE_ANON_KEY" ]; then ARGS="$ARGS --dart-define=SUPABASE_KEY=$SUPABASE_ANON_KEY"; fi
          if [ -n "$GROQ_API_KEY" ]; then ARGS="$ARGS --dart-define=GROQ_API_KEY=$GROQ_API_KEY"; fi
          flutter build web --release --no-web-resources-cdn --base-href / $ARGS
      - name: Single-page app routing
        run: rm -f build/web/404.html build/web/_redirects
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy __DIR__/build/web --project-name=__NAME__ --branch=main --commit-dirty=true
'@

$viteWf = @'
name: Deploy to Cloudflare Pages

on:
  push:
    branches: [__BRANCHES__]
  workflow_dispatch:

jobs:
  cloudflare:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm install
      - run: npx vite build --base=/
      - name: Single-page app routing
        run: rm -f dist/404.html dist/_redirects
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy dist --project-name=__NAME__ --branch=main --commit-dirty=true
'@

$staticWf = @'
name: Deploy to Cloudflare Pages

on:
  push:
    branches: [__BRANCHES__]
  workflow_dispatch:

jobs:
  cloudflare:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Collect the website files
        run: |
          mkdir _site
          for f in index.html style.css script.js favicon.svg Christian_Bwendo_CV.pdf; do
            if [ -f "$f" ]; then cp "$f" _site/; fi
          done
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy _site --project-name=__NAME__ --branch=main --commit-dirty=true
'@

function Setup($label, $folder, $repo, $template, $name, $dir, $extra) {
    Step $label
    try {
        $path = Join-Path $Desktop $folder
        if (-not (Test-Path $path)) {
            Push-Location $Desktop
            Run 'git' @('clone', "https://github.com/Chrid17/$repo.git", $folder)
            Pop-Location
        }
        Set-Location $path
        if (-not (Test-Path '.git')) {
            Run 'git' @('init', '-b', 'main')
            Run 'git' @('remote', 'add', 'origin', "https://github.com/Chrid17/$repo.git")
            Run 'git' @('fetch', 'origin')
            Run 'git' @('reset', 'origin/main')
            Run 'git' @('branch', '--set-upstream-to=origin/main')
        }
        $branch = (& git rev-parse --abbrev-ref HEAD).Trim()
        $branches = if ($branch -eq 'main') { 'main' } else { "main, $branch" }

        if ($label -eq 'Portfolio') {
            # Download CV button points to Christian_Bwendo_CV.pdf: use the newest CV.
            if (Test-Path 'CV Updated.pdf') { Copy-Item 'CV Updated.pdf' 'Christian_Bwendo_CV.pdf' -Force }
        }

        $envFile = Join-Path $path (Join-Path $dir '.env')
        if (Test-Path $envFile) {
            foreach ($line in Get-Content $envFile) {
                if ($line -match '^\s*(SUPABASE_URL|SUPABASE_ANON_KEY)\s*=\s*(.+?)\s*$') {
                    Info "Saving $($Matches[1]) in the GitHub repository..."
                    Run 'gh' @('secret', 'set', $Matches[1], '--repo', "Chrid17/$repo", '--body', $Matches[2].Trim('"'))
                }
            }
        }
        Info 'Saving Cloudflare secrets in the GitHub repository...'
        Run 'gh' @('secret', 'set', 'CLOUDFLARE_API_TOKEN', '--repo', "Chrid17/$repo", '--body', $token)
        Run 'gh' @('secret', 'set', 'CLOUDFLARE_ACCOUNT_ID', '--repo', "Chrid17/$repo", '--body', $account)

        $wf = $template.Replace('__NAME__', $name).Replace('__DIR__', $dir).Replace('__BRANCHES__', $branches)
        New-Item -ItemType Directory -Force '.github\workflows' | Out-Null
        Write-Utf8 (Join-Path $path '.github\workflows\cloudflare.yml') $wf

        & git add '.github/workflows/cloudflare.yml' | Out-Host
        if ($label -eq 'Portfolio' -and (Test-Path 'Christian_Bwendo_CV.pdf')) { & git add 'Christian_Bwendo_CV.pdf' | Out-Host }
        & git diff --cached --quiet
        if ($LASTEXITCODE -ne 0) { Run 'git' @('commit', '-m', 'Deploy to Cloudflare Pages on every push') }
        & git pull --rebase --autostash origin $branch | Out-Host
        Run 'git' @('push', 'origin', $branch)
        [void]$results.Add([pscustomobject]@{ Project = $label; Result = 'OK'; Site = "https://$name.pages.dev/"; Actions = "https://github.com/Chrid17/$repo/actions" })
    } catch {
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Yellow
        [void]$results.Add([pscustomobject]@{ Project = $label; Result = 'FAILED'; Site = $_.Exception.Message.Split("`n")[0]; Actions = '' })
    } finally {
        Set-Location $Desktop
    }
}

# ---------------------------------------------------------------------------
Setup 'My Tasks' 'MyTasks-main' 'MyTasks' $flutterWf 'chrid17-mytasks' '.' ''
Setup 'Clock In Buddy' 'clock-in-buddy-main' 'clock-in-buddy-main' $flutterWf 'chrid17-clockinbuddy' 'clock_in_buddy' ''
Setup 'CV Analyzer Pro' 'cv_corrector app' 'cv_corrector-app' $flutterWf 'chrid17-cv-analyzer' '.' ''
Setup 'Client Ticket App' 'ticketing_app' 'ticketing_app' $flutterWf 'chrid17-ticket-app' '.' ''
Setup 'Elite Barbershop Website' 'Elite-Barbershop-Website' 'Elite-Barbershop-Website' $viteWf 'chrid17-elite-barbershop' '.' ''
Setup 'Portfolio' 'Portfolio-master' 'Portfolio' $staticWf 'christianbwendo' '.' ''

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '================ Automatic deploys ================' -ForegroundColor Green
$results | Format-Table -AutoSize -Wrap | Out-String | Write-Host
Write-Host 'From now on: git push = GitHub Pages + Cloudflare updated in about 3-6 minutes.'
Write-Host 'Watch progress in each repo''s Actions tab (links above).'
