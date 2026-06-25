# scripts/runner-win.ps1
# Provision: GitLab Runner + MCR on Windows Server 2022
# Runs under SYSTEM via Vagrant WinRM provisioner
$ErrorActionPreference = "Stop"

Write-Host "[runner] Configuring dockerd for Linux containers..."
$daemonConfig = @{
    experimental = $true
    # Expose named pipe for docker CLI and volume mounts
    hosts        = @("npipe:////./pipe/docker_engine", "tcp://0.0.0.0:2376")
} | ConvertTo-Json

$daemonPath = "C:\ProgramData\docker\config\daemon.json"
New-Item -Path (Split-Path $daemonPath) -ItemType Directory -Force | Out-Null
Set-Content -Path $daemonPath -Value $daemonConfig -Encoding ASCII

Restart-Service docker -Force
Start-Sleep -Seconds 20

# Verify docker is up
$result = docker version 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "[runner] Docker daemon failed to start: $result"
}
Write-Host "[runner] Docker daemon running."

Write-Host "[runner] Installing docker compose plugin..."
$composeVersion = "v2.27.0"
$composeDest    = "C:\Program Files\Docker\cli-plugins"
New-Item -Path $composeDest -ItemType Directory -Force | Out-Null
Invoke-WebRequest -UseBasicParsing `
    "https://github.com/docker/compose/releases/download/$composeVersion/docker-compose-windows-x86_64.exe" `
    -OutFile "$composeDest\docker-compose.exe"
Write-Host "[runner] docker compose $composeVersion installed."

Write-Host "[runner] Installing gitlab-runner..."
$runnerDir = "C:\gitlab-runner"
New-Item -Path $runnerDir -ItemType Directory -Force | Out-Null

Invoke-WebRequest -UseBasicParsing `
    "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-windows-amd64.exe" `
    -OutFile "$runnerDir\gitlab-runner.exe"

# Install as Windows service
Set-Location $runnerDir
.\gitlab-runner.exe install
.\gitlab-runner.exe start
Write-Host "[runner] gitlab-runner service started."

$token = $env:REGISTRATION_TOKEN
if (-not $token) {
    Write-Warning "[runner] REGISTRATION_TOKEN not set - skipping registration."
} else {
    Write-Host "[runner] Registering gitlab-runner..."
    # Named pipe path for docker socket volume in CI jobs
    $socketVol = "\\.\pipe\docker_engine:\\.\pipe\docker_engine"

    & "$runnerDir\gitlab-runner.exe" register `
        --non-interactive `
        --url "https://gitlab.com/" `
        --token "$token" `
        --executor "docker" `
        --docker-image "docker:26.1.4" `
        --docker-volumes "$socketVol" `
        --docker-pull-policy "if-not-present" `
        --description "vagrant-windows-docker-builder"

    Write-Host "[runner] Runner registered."
}

# Fix cache volume path for Windows
$configPath = "C:\gitlab-runner\config.toml"
$config = Get-Content $configPath -Raw
$config = $config -replace 'volumes = \["/cache"\]', 'volumes = ["//./pipe/docker_engine://./pipe/docker_engine", "C:\\\\cache:C:\\\\cache"]'
Set-Content $configPath $config -Encoding UTF8
Restart-Service gitlab-runner
Write-Host "[runner] config.toml patched for Windows volumes."

Write-Host "[runner] Provisioning complete."
