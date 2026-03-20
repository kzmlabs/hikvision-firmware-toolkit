# How to Run Scripts

## Prerequisites

- Windows 10 or 11
- PowerShell 5.1+ (built into Windows)
- Administrator privileges (for network configuration)

## Running PowerShell Scripts

### Method 1: Right-click (Easiest)

1. Right-click the `.ps1` file
2. Select **"Run with PowerShell"**
3. If prompted about execution policy, type `Y` and press Enter

### Method 2: From PowerShell terminal

```powershell
# Open PowerShell as Administrator (right-click Start → Windows PowerShell (Admin))

# Navigate to the scripts folder
cd C:\Users\user\projects\hikvision\scripts

# Allow running scripts (one-time)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser

# Run a script
.\loopback_test.ps1
.\uart_raw_test.ps1
.\uart_tftp_flash.ps1
.\fix_ip.ps1
.\setup_firewall.ps1
```

### Method 3: Direct command

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\user\projects\hikvision\scripts\uart_tftp_flash.ps1"
```

## Script Execution Order

Run scripts in this order:

```
Step 1: .\setup_firewall.ps1     ← Run once, adds firewall rules
Step 2: .\fix_ip.ps1             ← Run before each TFTP attempt
Step 3: .\loopback_test.ps1      ← Verify adapter works (TX+RX touching)
Step 4: .\uart_raw_test.ps1      ← Verify NVR connection (wires on JP3)
Step 5: .\uart_tftp_flash.ps1    ← Main script: flash firmware
```

## Changing COM Port

All scripts default to **COM3**. If your adapter uses a different COM port:

1. Open Device Manager (`Win+R` → `devmgmt.msc`)
2. Expand **Ports (COM & LPT)**
3. Note your port number (e.g., COM5)
4. Edit the script, change `$comPort = 'COM3'` to `$comPort = 'COM5'`

## Troubleshooting Script Errors

### "Access to the port 'COM3' is denied"

Another process is using the COM port. Fix:

```powershell
# Close PuTTY if open
Stop-Process -Name putty -ErrorAction SilentlyContinue

# Kill other PowerShell scripts
Get-Process powershell | Where-Object { $_.Id -ne $PID } | Stop-Process -Force

# Wait 3 seconds, then try again
Start-Sleep 3
```

### "The port 'COM3' does not exist"

USB adapter is disconnected or driver not installed. Check:
- Is the adapter plugged into USB?
- Does Device Manager show it under Ports?
- Try a different USB port

### "Execution policy" error

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

### Script hangs / runs too long

Press **Ctrl+C** in the PowerShell window to stop the script. Then close and reopen PowerShell before running again (to release the COM port).
