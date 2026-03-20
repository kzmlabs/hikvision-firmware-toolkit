# UART TFTP Flash Script - Main script for flashing firmware
#
# PREREQUISITES:
#   1. TFTP server (tftpd64) running on 192.0.0.128 with digicap.dav
#   2. Ethernet cable connected between PC and NVR uplink port
#   3. UART wires connected to JP3
#   4. NVR must be OFF before starting
#
# USAGE: Run this script, then power on the NVR
# CHANGE COM3 to your COM port number if different

$comPort = 'COM3'
$deviceIP = '192.0.0.2'
$serverIP = '192.0.0.128'

$port = New-Object System.IO.Ports.SerialPort $comPort, 115200, 'None', 8, 'One'
$port.Encoding = [System.Text.Encoding]::GetEncoding(28591)
$port.Open()
$port.DiscardInBuffer()

Write-Host "============================================"
Write-Host "  Hikvision NVR TFTP Firmware Flash Script"
Write-Host "============================================"
Write-Host ""
Write-Host "  POWER ON THE NVR NOW!"
Write-Host ""

$ctrlU = [byte[]](0x15)

# ===== Phase 1: Wait for U-Boot, send Ctrl+U to enter upgrade mode =====
$buf = ""
$timeout = (Get-Date).AddSeconds(60)
$gotUpgrade = $false

while ((Get-Date) -lt $timeout) {
    $data = $port.ReadExisting()
    if ($data.Length -gt 0) {
        $buf += $data
        if ($buf -match "autoboot") {
            $port.Write($ctrlU, 0, 1)
            Write-Host "[*] Sent Ctrl+U to stop autoboot"
        }
        if ($buf -match "press \[u/U\]") {
            Write-Host "[*] Upgrade menu reached. Sending 'u'..."
            Start-Sleep 1
            $port.WriteLine("u")
            $gotUpgrade = $true
            $buf = ""
            break
        }
    }
    Start-Sleep -Milliseconds 5
}

if (-not $gotUpgrade) {
    Write-Host "[ERROR] Could not reach upgrade mode. Check UART connection."
    Write-Host "        Make sure NVR was OFF before starting, then powered ON."
    $port.Close()
    exit 1
}

# ===== Phase 2: Answer "device IP" prompt =====
Write-Host "[*] Waiting for device IP prompt..."
$buf = ""
$timeout = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $timeout) {
    $data = $port.ReadExisting()
    if ($data.Length -gt 0) {
        $buf += $data
        $ascii = ($data -replace '[^\x20-\x7E\r\n]', '').Trim()
        if ($ascii.Length -gt 0) { Write-Host "    $ascii" }
    }
    if ($buf -match "address of device") {
        Start-Sleep -Milliseconds 300
        $port.WriteLine($deviceIP)
        Write-Host "[*] Device IP: $deviceIP"
        break
    }
    Start-Sleep -Milliseconds 20
}

# ===== Phase 3: Answer "server IP" prompt =====
Write-Host "[*] Waiting for server IP prompt..."
$buf = ""
$timeout = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $timeout) {
    $data = $port.ReadExisting()
    if ($data.Length -gt 0) {
        $buf += $data
        $ascii = ($data -replace '[^\x20-\x7E\r\n]', '').Trim()
        if ($ascii.Length -gt 0) { Write-Host "    $ascii" }
    }
    if ($buf -match "upgrade server") {
        Start-Sleep -Milliseconds 300
        $port.WriteLine($serverIP)
        Write-Host "[*] Server IP: $serverIP"
        break
    }
    Start-Sleep -Milliseconds 20
}

# ===== Phase 4: Answer confirmation =====
Write-Host "[*] Waiting for confirmation..."
$buf = ""
$timeout = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $timeout) {
    $buf += $port.ReadExisting()
    if ($buf -match "y/n") {
        Start-Sleep -Milliseconds 300
        $port.WriteLine("y")
        Write-Host "[*] Confirmed! TFTP transfer starting..."
        break
    }
    Start-Sleep -Milliseconds 20
}

# ===== Phase 5: Monitor flash progress (up to 10 minutes) =====
Write-Host ""
Write-Host "============================================"
Write-Host "  FIRMWARE FLASHING IN PROGRESS"
Write-Host "  DO NOT POWER OFF OR DISCONNECT!"
Write-Host "  This takes approximately 3-5 minutes."
Write-Host "============================================"
Write-Host ""

$timeout = (Get-Date).AddSeconds(600)
$lastMsg = ""
$flashStarted = $false

while ((Get-Date) -lt $timeout) {
    $data = $port.ReadExisting()
    if ($data.Length -gt 0) {
        $clean = ($data -replace '[^\x20-\x7E\r\n]', '').Trim()
        if ($clean.Length -gt 0 -and $clean -ne $lastMsg -and $clean -notmatch '^(et:|100Mbps|ress CTRL)') {
            Write-Host $clean
            $lastMsg = $clean
        }

        if ($clean -match "checkSum ok") {
            $flashStarted = $true
        }

        # Detect successful completion: NVR reboots after flash
        if ($flashStarted -and $clean -match "Update successfully") {
            Write-Host ""
            Write-Host "============================================"
            Write-Host "  FIRMWARE FLASH SUCCESSFUL!"
            Write-Host "  NVR will reboot now."
            Write-Host "  Connect HDMI to see setup wizard."
            Write-Host "============================================"
            break
        }

        # Detect firmware mismatch
        if ($clean -match "upgrade packet mismatch") {
            Write-Host ""
            Write-Host "[ERROR] FIRMWARE MISMATCH!"
            Write-Host "        The firmware file does not match your hardware."
            Write-Host "        You need a different firmware version."
            Write-Host "        Check device_class in the error output above."
            break
        }
    }
    Start-Sleep -Milliseconds 100
}

$port.Close()
Write-Host ""
Write-Host "Script finished."
