# AI Agent Guide: Hikvision NVR Password Reset

## Purpose

This document is designed for AI coding assistants (Claude, GPT, Copilot, etc.) helping users reset a locked Hikvision NVR via UART serial console and TFTP firmware flash.

## Context for AI Agents

You are helping a user who has physical access to a Hikvision NVR/DVR and has lost the admin password. The device uses HiSilicon SoC with U-Boot bootloader. The SADP tool's "security code" reset method does NOT work on newer firmware versions (V3.4.99+).

## Decision Tree

```
User has locked Hikvision NVR
│
├── Try SADP password reset first
│   ├── "Security Code Mode" available? → Use old algorithm (serial + date)
│   └── "Export/Import device feature code Mode" only? → Algorithm won't work
│       │
│       ├── Contact Hikvision support → May take weeks/never respond
│       └── UART + TFTP method (this guide) ←── PROCEED HERE
│
├── Does user have USB-UART adapter?
│   ├── YES → Proceed with UART method
│   └── NO → User must purchase one (FT232RL recommended, ~$5)
│
├── UART connection established?
│   ├── Boot text visible → Good, proceed to TFTP
│   ├── All 0xFF → Console silent, need to power cycle during capture
│   ├── All 0x00 → TX/RX wires swapped, swap them
│   └── No data → Check wires, adapter, COM port
│
├── Enter U-Boot upgrade mode
│   ├── Send Ctrl+U (0x15) during "Hit ctrl+u to stop autoboot" message
│   ├── This enters upgrade menu, NOT a U-Boot shell
│   └── Send 'u' to start TFTP upgrade
│
├── TFTP firmware flash
│   ├── "cramfs.img checkSum ok" → Firmware matches! Wait for flash to complete!
│   ├── "upgrade packet mismatch" → WRONG firmware, need different version
│   └── "Retry count exceeded" → Network/firewall issue, check TFTP server
│
└── After successful flash → NVR reboots with factory defaults
```

## Critical Knowledge for AI Agents

### 1. Firmware Matching

The NVR rejects firmware that doesn't match its `device_class`. This is the HARDEST part.

```
Error: "upgrade packet mismatch, please select correct packet"
Shown: "device_class - 0xNNN oemCode - 0xN"
```

**The device_class varies by:**
- Model variant: `/8P` vs `/8P/M` → DIFFERENT firmware!
- Hardware revision: `(C)` vs `(D)` suffixes
- Regional variant: Serial number contains region codes (CCRR = CIS/Russia/Ukraine)
- Manufacturing date: Same model from different years may need different firmware

**How to find correct firmware:**
1. Check Hikvision EU Portal: `hikvisioneurope.com/eu/portal/` → Technical Materials → NVR → Product Firmware → Q-series
2. The firmware PACKAGE NAME matters (e.g., NVR_K53 vs NVR_K74 are DIFFERENT series)
3. If one firmware says "mismatch", try firmware from a DIFFERENT series folder
4. The firmware that was originally on the device is the safest bet

**For DS-7108NI-Q1/8P (device_class 0x5DE, CIS/CCRR variant):**
- **V4 UPGRADE: NVR_K75_BL_ML_A_NEU from `[7100NI-Q1]` folder — THIS WORKS!**
- **V3.4 RECOVERY: digicap.dav from `descargas.fiesa.com.ar/DS-7108NI-Q18P/` — THIS WORKS!**
- WRONG: NVR_K74 from `[76NI-Q1(Q2)]` folder — device_class mismatch
- WRONG: NVR_K9B2 from `[76NI-Q1(Q2)](C)` folder — device_class mismatch
- WRONG: NVR_K21B2 from `76NI-Q1(Q2)(D)` folder — device_class mismatch
- WRONG: Any firmware labeled for `/8P/M` variant

**Critical lesson:** The folder name does NOT always match the device. This NVR (7108NI-Q1/8P) uses firmware from the `[7100NI-Q1]` folder, specifically the K75 "NEU" (neutral) variant. Trial and error with device_class matching is sometimes the only way.

### 2. UART Communication

**Settings:** 115200 baud, 8N1, no flow control

**The NVR console is SILENT after Linux boots.** You can only see output during boot (first ~10 seconds). To interact with U-Boot, you must send Ctrl+U during boot.

**PL2303HX clone adapters on Windows 10/11:**
- Show as "USB-Serial Controller D" with ERROR status
- Fix: Device Manager → Update driver → Let me pick → Ports → Microsoft → USB Serial Device
- These adapters are unreliable and may disconnect randomly

### 3. Network Setup

**TFTP server IP must be `192.0.0.128`** (Hikvision standard).
**NVR will use IP `192.0.0.2`** when in manual upgrade mode.

**Common pitfall:** Windows auto-assigns link-local IPs (169.254.x.x) which causes the TFTP server (tftpd64) to switch its listening interface. Always remove extra IPs:

```powershell
# Remove all IPs except 192.0.0.128
Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 | ForEach-Object {
    if ($_.IPAddress -ne '192.0.0.128') {
        Remove-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress $_.IPAddress -Confirm:$false
    }
}
```

### 4. Flash Process Timing

After firmware downloads via TFTP:
1. Checksum verification: ~5 seconds
2. Kernel boot for flash: ~10 seconds
3. **Writing firmware: ~2-3 minutes** (progress bar 0% → 100%)
4. **Verifying firmware: ~1-2 minutes** (second progress bar 0% → 100%)
5. Reboot

**DO NOT interrupt during steps 3-4.** Interrupting = bricked NVR (recoverable via TFTP, but annoying).

### 5. PowerShell COM Port Issues

COM ports in PowerShell get locked if a script crashes without calling `$port.Close()`. Fix:

```powershell
# Kill all PowerShell processes holding the port
Get-Process powershell | Where-Object { $_.Id -ne $PID } | Stop-Process -Force
# Or use taskkill
taskkill /F /IM powershell.exe
```

Wait 3 seconds after killing before opening the port again.

## Step-by-Step Commands for AI Agents

### Check if USB-UART adapter is detected
```powershell
Get-WMIObject Win32_PnPEntity | Where-Object { $_.Name -match 'COM[0-9]' } | Select-Object Name, Status
```

### Read UART data
```powershell
$port = New-Object System.IO.Ports.SerialPort 'COM3', 115200, 'None', 8, 'One'
$port.Encoding = [System.Text.Encoding]::GetEncoding(28591)
$port.Open()
# ... read/write operations ...
$port.Close()
```

### Send Ctrl+U to bootloader
```powershell
$port.Write([byte[]](0x15), 0, 1)  # Ctrl+U = 0x15
```

### Send text command
```powershell
$port.WriteLine("192.0.0.2")  # Sends text + CR/LF
```

### Download firmware
```bash
curl -sk -L -o digicap.dav "https://www.hikvisioneurope.com/eu/portal/portal/Technical%20Materials/02%20%20NVR/00%20%20Product%20Firmware/06%20Q-series/%5B76NI-Q1%28Q2%29%5D/V3.4.99_build171121/NVR_K74_BL_ML_STD_V3.4.99_171121.zip"
# Extract digicap.dav from zip and place in TFTP directory
```

### Configure network
```powershell
New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress 192.0.0.128 -PrefixLength 24
```

## Common Mistakes to Avoid

1. **Don't match "CRAMFS load complete" as flash success** — this appears during download, NOT after flash. Wait for "Update successfully !"
2. **Don't send Ctrl+C during "press CTRL+C" messages** — this is the flash writing process, NOT a prompt to cancel
3. **Don't use firmware for /8P/M on a /8P device** — different device_class
4. **Don't forget to select 192.0.0.128 in tftpd64 dropdown** — it defaults to the first interface
5. **Don't run multiple scripts that open the same COM port** — the second one will fail with "Access denied"
