# Camera TFTP Factory Reset Script
# Resets Hikvision camera password by flashing firmware via TFTP
#
# Prerequisites:
#   1. Camera connected via ethernet directly to PC
#   2. Camera powered by 12V adapter (separate from ethernet)
#   3. tftpd64 installed (portable OK)
#   4. Firmware file (digicap.dav) in tftpd64 folder
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\camera_tftp_reset.ps1

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Hikvision Camera TFTP Factory Reset" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Set IP
Write-Host "[1/5] Setting PC IP to 192.0.0.128..." -ForegroundColor Yellow

# Disable DHCP
Set-NetIPInterface -InterfaceAlias 'Ethernet' -Dhcp Disabled -ErrorAction SilentlyContinue

# Remove other IPs
Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.IPAddress -ne '192.0.0.128') {
        Remove-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress $_.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
    }
}

# Add 192.0.0.128
$existing = Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -ErrorAction SilentlyContinue
if (-not ($existing | Where-Object { $_.IPAddress -eq '192.0.0.128' })) {
    New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress 192.0.0.128 -PrefixLength 24 | Out-Null
}
Write-Host "  IP set to 192.0.0.128" -ForegroundColor Green

# Step 2: Check firmware file
Write-Host ""
Write-Host "[2/5] Checking for digicap.dav..." -ForegroundColor Yellow

$tftpPaths = @(
    "$PSScriptRoot\..\firmware",
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Downloads",
    "C:\tftpd64",
    "C:\tftp"
)

$davFile = $null
foreach ($path in $tftpPaths) {
    $candidate = Join-Path $path "digicap.dav"
    if (Test-Path $candidate) {
        $davFile = $candidate
        break
    }
}

if ($davFile) {
    $size = (Get-Item $davFile).Length / 1MB
    Write-Host "  Found: $davFile ($([math]::Round($size, 1)) MB)" -ForegroundColor Green
} else {
    Write-Host "  ERROR: digicap.dav not found!" -ForegroundColor Red
    Write-Host "  Place the firmware file (renamed to digicap.dav) in one of:" -ForegroundColor Red
    foreach ($p in $tftpPaths) { Write-Host "    - $p" -ForegroundColor Gray }
    exit 1
}

# Step 3: Check tftpd64
Write-Host ""
Write-Host "[3/5] Checking tftpd64..." -ForegroundColor Yellow

$tftpProcess = Get-Process -Name "tftpd64" -ErrorAction SilentlyContinue
if ($tftpProcess) {
    Write-Host "  tftpd64 is running (PID: $($tftpProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "  WARNING: tftpd64 is NOT running!" -ForegroundColor Red
    Write-Host "  Start tftpd64, set server interface to 192.0.0.128," -ForegroundColor Red
    Write-Host "  and set the base directory to: $(Split-Path $davFile)" -ForegroundColor Red
    Write-Host ""
    $start = Read-Host "  Press Enter after starting tftpd64 (or 'q' to quit)"
    if ($start -eq 'q') { exit 0 }
}

# Step 4: Disable firewall
Write-Host ""
Write-Host "[4/5] Disabling Windows Firewall..." -ForegroundColor Yellow
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False -ErrorAction SilentlyContinue
Write-Host "  Firewall disabled" -ForegroundColor Green

# Step 5: Power cycle instructions
Write-Host ""
Write-Host "[5/5] Ready to flash!" -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " NOW DO THIS:" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Make sure camera ethernet goes to PC (not router)" -ForegroundColor White
Write-Host "  2. UNPLUG the 12V power from the camera" -ForegroundColor White
Write-Host "  3. Wait 5 seconds" -ForegroundColor White
Write-Host "  4. PLUG the 12V power back in" -ForegroundColor White
Write-Host "  5. Watch tftpd64 - you should see a transfer start" -ForegroundColor White
Write-Host "  6. Wait 3-5 minutes for flash to complete" -ForegroundColor White
Write-Host "  7. Camera reboots as INACTIVE in SADP" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

# Monitor for camera
Write-Host ""
Write-Host "Monitoring network for camera..." -ForegroundColor Yellow
Write-Host "(Camera will appear at 192.0.0.64 during recovery)" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Gray
Write-Host ""

$found = $false
$startTime = Get-Date
while (-not $found) {
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)

    # Ping camera recovery IP
    $ping = Test-Connection -ComputerName 192.0.0.64 -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($ping) {
        Write-Host "  [$elapsed`s] Camera detected at 192.0.0.64! TFTP transfer should start..." -ForegroundColor Green
        $found = $true
    } else {
        Write-Host "  [$elapsed`s] Waiting for camera at 192.0.0.64..." -ForegroundColor Gray
    }

    Start-Sleep -Seconds 3

    if ($elapsed -gt 300) {
        Write-Host ""
        Write-Host "  Timeout after 5 minutes. Camera may not support TFTP recovery." -ForegroundColor Red
        Write-Host "  Check tftpd64 window for any transfer activity." -ForegroundColor Red
        break
    }
}

if ($found) {
    Write-Host ""
    Write-Host "Camera is flashing firmware. DO NOT unplug power!" -ForegroundColor Red
    Write-Host "Wait 3-5 minutes for the process to complete." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "After reboot:" -ForegroundColor Cyan
    Write-Host "  1. Open SADP - camera should show as 'Inactive'" -ForegroundColor White
    Write-Host "  2. Set a new admin password" -ForegroundColor White
    Write-Host "  3. Re-enable firewall: Set-NetFirewallProfile -All -Enabled True" -ForegroundColor White
    Write-Host "  4. Restore IP: netsh interface ip set address 'Ethernet' dhcp" -ForegroundColor White
}
