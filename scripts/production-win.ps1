# scripts/production-win.ps1
# Provision: MCR + docker compose (no ELK) on Windows Server 2022 production node
$ErrorActionPreference = "Stop"

# ── 1. Hyper-V ───────────────────────────────────────────────────────────────
Write-Host "[prod] Enabling Hyper-V..."
$hv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
if ($hv.State -ne "Enabled") {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart
} else {
    Write-Host "[prod] Hyper-V already enabled."
}

# ── 2. MCR ───────────────────────────────────────────────────────────────────
Write-Host "[prod] Installing MCR..."
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Invoke-WebRequest -UseBasicParsing `
        "https://get.mirantis.com/install.ps1" `
        -OutFile "$env:TEMP\mcr-install.ps1"
    & "$env:TEMP\mcr-install.ps1" -Channel "stable" | Out-Null
} else {
    Write-Host "[prod] Docker already present."
}

# ── 3. daemon.json — Linux containers mode ───────────────────────────────────
$daemonConfig = @{
    experimental = $true
    hosts        = @("npipe:////./pipe/docker_engine", "tcp://0.0.0.0:2376")
} | ConvertTo-Json

$daemonPath = "C:\ProgramData\docker\config\daemon.json"
New-Item -Path (Split-Path $daemonPath) -ItemType Directory -Force | Out-Null
Set-Content -Path $daemonPath -Value $daemonConfig -Encoding ASCII

Restart-Service docker -Force
Start-Sleep -Seconds 10
docker version | Out-Null
Write-Host "[prod] Docker daemon running."

# ── 4. docker compose plugin ─────────────────────────────────────────────────
$composeVersion = "v2.27.0"
$composeDest    = "C:\Program Files\Docker\cli-plugins"
New-Item -Path $composeDest -ItemType Directory -Force | Out-Null
Invoke-WebRequest -UseBasicParsing `
    "https://github.com/docker/compose/releases/download/$composeVersion/docker-compose-windows-x86_64.exe" `
    -OutFile "$composeDest\docker-compose.exe"

# ── 5. App directory ─────────────────────────────────────────────────────────
$appDir = "C:\app"
New-Item -Path $appDir          -ItemType Directory -Force | Out-Null
New-Item -Path "$appDir\nginx"  -ItemType Directory -Force | Out-Null
Write-Host "[prod] App directory ready at $appDir"

# Files are copied via Vagrant file provisioner before this script runs.
# Expected layout:
#   C:\app\docker-compose.windows.yml
#   C:\app\nginx\nginx.conf

# ── 6. .env file for compose ─────────────────────────────────────────────────
$envContent = @"
BASE_REGISTRY=$env:BASE_REGISTRY
REGISTRY_USER=$env:REGISTRY_USER
REGISTRY_PASSWORD=$env:REGISTRY_PASSWORD
WATCHTOWER_TOKEN=$env:WATCHTOWER_TOKEN
"@
Set-Content -Path "$appDir\.env" -Value $envContent -Encoding ASCII
Write-Host "[prod] .env written."

# ── 7. Registry login ────────────────────────────────────────────────────────
Write-Host "[prod] Logging into registry..."
$env:REGISTRY_PASSWORD | docker login $env:BASE_REGISTRY.Split("/")[0] `
    -u $env:REGISTRY_USER --password-stdin
Write-Host "[prod] Registry login OK."

# ── 8. docker compose up ─────────────────────────────────────────────────────
Write-Host "[prod] Starting services..."
Set-Location $appDir
docker compose -f docker-compose.windows.yml --env-file .env up -d
Write-Host "[prod] Services started."

# ── 9. Firewall rules ────────────────────────────────────────────────────────
Write-Host "[prod] Opening firewall ports..."
$rules = @(
    @{ Name = "HTTP";      Port = 80   },
    @{ Name = "Watchtower"; Port = 8080 }
)
foreach ($r in $rules) {
    if (-not (Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule `
            -DisplayName $r.Name `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort $r.Port `
            -Action Allow | Out-Null
        Write-Host "[prod] Firewall rule '$($r.Name)' added."
    }
}

Write-Host "[prod] Provisioning complete."
