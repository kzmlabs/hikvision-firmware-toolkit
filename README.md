# Hikvision NVR/DVR Password Reset & Firmware Recovery Guide

> **Factory reset a locked Hikvision NVR when all standard methods fail — using UART serial console and TFTP firmware flash.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## The Problem

You have a Hikvision NVR/DVR and:
- Admin password is lost or forgotten
- SADP tool password reset shows "Export/Import device feature code Mode" (newer firmware — old algorithm doesn't work)
- Hikvision support is unresponsive or slow
- Security questions were never configured
- No physical reset button exists on the board
- Default passwords (admin/12345, admin/admin, etc.) don't work

**This guide will walk you through resetting the device using the UART serial debug console and flashing firmware via TFTP, which resets everything to factory defaults.**

## What We Achieved

| Task | Status |
|------|--------|
| UART serial console access | Done |
| Password reset via firmware flash | Done |
| Firmware upgrade V3.4.99 → V4.30.091 | Done |
| HDD format & overwrite configuration | Done |
| Hik-Connect cloud unbinding | Requires Hikvision support (server-side) |

**Tested on:** DS-7108NI-Q1/8P (Board: DS-8025 PcEV1.0, HiSilicon hi3536dv100)
**Applicable to:** Most Hikvision NVRs/DVRs with HiSilicon SoC and U-Boot bootloader

---

## Table of Contents

1. [Hardware Required](#1-hardware-required)
2. [Identify UART Pins](#2-identify-uart-pins)
3. [USB-UART Adapter Setup](#3-usb-uart-adapter-setup)
4. [Wire Connection](#4-wire-connection)
5. [Verify UART Communication](#5-verify-uart-communication)
6. [Find the Correct Firmware](#6-find-the-correct-firmware)
7. [Setup TFTP Server](#7-setup-tftp-server)
8. [Configure Network](#8-configure-network)
9. [Flash Firmware via PuTTY (Recommended)](#9-flash-firmware-via-putty-recommended)
10. [Flash Firmware via Script (Alternative)](#10-flash-firmware-via-script-alternative)
11. [After Successful Flash](#11-after-successful-flash)
12. [Firmware Upgrade to V4.x](#12-firmware-upgrade-to-v4x)
13. [Hik-Connect Cloud Unbinding](#13-hik-connect-cloud-unbinding)
14. [NVR Configuration via API](#14-nvr-configuration-via-api)
15. [Troubleshooting](#15-troubleshooting)

---

## 1. Hardware Required

| Item | Description | Cost |
|------|-------------|------|
| **USB-to-UART TTL adapter** | FT232RL recommended (3.3V/5V jumper). PL2303HX works but unreliable. CH340 also OK. | $3-10 |
| **Dupont wires** | Female-to-female, 20cm, at least 3 wires (GND, TX, RX) | $2-5 |
| **Ethernet cable** | Cat5e/Cat6, direct PC-to-NVR connection for TFTP | — |
| **PC with Windows** | For TFTP server, PuTTY terminal, and scripts | — |

### Adapter Comparison

| Adapter | Voltage | Windows Driver | Reliability | Recommended |
|---------|---------|---------------|-------------|-------------|
| **FT232RL** | 3.3V/5V jumper | Auto-install | Excellent | Yes |
| **CH340** | Varies | Auto or manual | Good | Yes |
| **CP2102** | 3.3V | Auto-install | Excellent | Yes |
| **PL2303HX** | 5V only | Needs driver hack | Poor (clones disconnect) | No |

> **Warning:** The NVR UART operates at 3.3V TTL. Set your adapter to 3.3V if possible. 5V adapters work for receiving data but some NVRs may not read 5V input reliably.

---

## 2. Identify UART Pins

### DS-7108NI-Q1/8P (Board: DS-8025 PcEV1.0)

The debug UART is on connector **JP3** — a 4-pin header near the top-left of the board.

```
JP3 Pin Layout (arrow/dot marks Pin 1):

  Arrow
   ▼
  ┌───┬───┬───┬───┐
  │ 1 │ 2 │ 3 │ 4 │
  │VCC│ TX│ RX│GND│
  └───┴───┴───┴───┘
   ▲              ▲
   DO NOT         Connect
   CONNECT!       here
```

| Pin | Function | Description |
|-----|----------|-------------|
| 1 (arrow) | VCC (3.3V) | **DO NOT CONNECT** — can damage adapter |
| 2 | TX (NVR transmits) | Connect to adapter's **RX** wire |
| 3 | RX (NVR receives) | Connect to adapter's **TX** wire |
| 4 | GND | Connect to adapter's **GND** wire |

### How to Verify GND (with multimeter)

1. Set multimeter to continuity/beep mode
2. Touch one probe to a known ground (metal shield of USB/HDMI port)
3. Touch other probe to each JP3 pin — the one that beeps = GND

### Without Multimeter

Look for the arrow/dot/square pad marking on the PCB — that's Pin 1. Count from there.

---

## 3. USB-UART Adapter Setup

### PL2303HX Driver Fix (Windows 10/11)

PL2303HX clones show as "USB-Serial Controller D" with an error. Fix:

1. Open **Device Manager** (`Win+R` → `devmgmt.msc`)
2. Find **USB-Serial Controller D** (yellow ⚠ warning)
3. Right-click → **Update driver**
4. **Browse my computer for drivers**
5. **Let me pick from a list of available drivers on my computer**
6. Select **Ports (COM & LPT)** → Next
7. Manufacturer: **Microsoft** → Model: **USB Serial Device** → Next
8. Click **Yes** on the compatibility warning
9. Note the **COM port number** (e.g., COM3)

```
Before:                              After:
┌──────────────────────┐            ┌──────────────────────┐
│ ⚠ USB-Serial         │     →     │ ✓ USB Serial Device  │
│   Controller D       │            │   (COM3)             │
│   Status: Error      │            │   Status: OK         │
└──────────────────────┘            └──────────────────────┘
```

> **Note:** This driver fix may need to be repeated after Windows updates or replugging the adapter.

### FT232RL / CH340 / CP2102

Usually auto-installs. Check Device Manager → Ports for the COM port number.

---

## 4. Wire Connection

### Wiring Diagram

```
USB-UART Adapter              JP3 on NVR Board
────────────────              ────────────────
GND (Black)    ─────────────► Pin 4 (GND)
TX  (Green)    ─────────────► Pin 3 (NVR RX)     ← ACTIVE: sends TO NVR
RX  (White)    ◄─────────────  Pin 2 (NVR TX)     ← ACTIVE: receives FROM NVR
VCC (Red)      ────── ✕ ────  Pin 1 (VCC)         ← DO NOT CONNECT!
```

### Critical Rules

1. **TX/RX are CROSSED**: Adapter TX → NVR RX, Adapter RX ← NVR TX
2. **NEVER connect VCC** — tape off the red wire
3. **Power the NVR from its own power supply**
4. Wire colors vary between adapters — always check PCB labels

### Common Wire Colors

| Wire | Function | Connects to |
|------|----------|-------------|
| Red | VCC | **DO NOT CONNECT** |
| Black | GND | JP3 Pin 4 |
| White | RX (adapter receives) | JP3 Pin 2 (NVR TX) |
| Green | TX (adapter sends) | JP3 Pin 3 (NVR RX) |

### Loopback Test (Verify Adapter Works)

Before connecting to the NVR:

1. Touch TX and RX wires together (green + white)
2. Run `scripts/loopback_test.ps1`
3. Expected: `"SUCCESS! TX is working. Got back: HELLO123"`

### Dealing with Loose Connections

Dupont connectors often don't grip header pins well. Tips:
- Squeeze the metal crimp slightly with pliers
- Hold wires in place with electrical tape
- Use male-to-female jumper wires

---

## 5. Verify UART Communication

### Serial Settings

| Parameter | Value |
|-----------|-------|
| Baud rate | **115200** |
| Data bits | **8** |
| Stop bits | **1** |
| Parity | **None** |
| Flow control | **None** |

### Quick Test

1. Connect wires to NVR JP3 (NVR should be OFF)
2. Open PuTTY → Serial → COM port → Speed 115200 → Open
3. Power ON the NVR
4. You should see U-Boot text scrolling

### Diagnostic Results

| What You See | Meaning | Action |
|-------------|---------|--------|
| U-Boot text, boot messages | **Working!** | Proceed to firmware flash |
| All `0xFF` bytes | UART idle, console silent | NVR already booted — power cycle to see boot messages |
| All `0x00` bytes | TX/RX wires are **swapped** | Swap white and green wires |
| Garbage/random characters | Wrong baud rate | Try 9600, 57600 |
| Nothing at all | No connection | Check wires, adapter, COM port |

---

## 6. Find the Correct Firmware

### CRITICAL: Firmware Must Match Your Hardware

Each Hikvision NVR has a `device_class` identifier. During TFTP flash, the NVR checks if the firmware contains a matching packet. If not:

```
The board info: language - 0x1 device_class - 0x5DE oemCode - 0x1
upgrade packet mismatch, please select correct packet
Can not find correct packet for upgrade, give up!!!
```

### Firmware for DS-7108NI-Q1/8P (device_class 0x5DE, CIS/CCRR variant)

After extensive testing, these are the results:

| Firmware Package | Source Folder | Version | Size | Result |
|-----------------|---------------|---------|------|--------|
| **digicap.dav** (base) | `fiesa.com.ar/DS-7108NI-Q18P/` | V3.4.x | 16MB | **WORKS** — password reset |
| **NVR_K75_BL_ML_A_NEU** | EU Portal `[7100NI-Q1]` | V4.30.080 | 16MB | **WORKS** — V4 upgrade |
| **Official from support** | Hikvision support link | V4.30.091 | 16MB | **WORKS** — best option |
| NVR_K74_BL_ML_STD | EU Portal `[76NI-Q1(Q2)]` | V4.30.085 | 32MB | REJECTED |
| NVR_K9B2_BL_ML_STD | EU Portal `[76NI-Q1(Q2)](C)` | V4.31.102 | 31MB | REJECTED |
| NVR_K21B2 | EU Portal `76NI-Q1(Q2)(D)` | V4.74.115 | — | REJECTED |

> **Key Insight:** The V4 upgrade firmware is in the `[7100NI-Q1]` folder (K75 "NEU" series), NOT the `[76NI-Q1(Q2)]` folder (K74 series). The folder name does NOT always match the device model!

### Where to Download

1. **V3.4.x (for password reset):**
   `https://descargas.fiesa.com.ar/descargas/Hikvision/Firmware/NVRS/DS-7108NI-Q18P/digicap.dav`

2. **V4.30 (for upgrade):**
   Hikvision EU Portal → Technical Materials → 02 NVR → 00 Product Firmware → 06 Q-series → [7100NI-Q1] → V4.30.080

3. **Official firmware:**
   Contact Hikvision support with your serial number — they provide the exact firmware for your hardware variant.

### For Other Models

If the firmware is rejected with "upgrade packet mismatch":
- Note the `device_class` value from the error
- Try firmware from **different folders** on the EU portal
- Try the "NEU" (neutral) variant if available
- Contact Hikvision support for region-specific firmware

---

## 7. Setup TFTP Server

### Download tftpd64

1. Download from: https://github.com/PJO2/tftpd64/releases (portable version)
2. Extract to a folder (e.g., `C:\tftpd64\`)
3. Place `digicap.dav` firmware file in the same folder

### Configure tftpd64

1. Run `tftpd64.exe`
2. **Current Directory:** folder containing `digicap.dav`
3. **Server interfaces:** select `192.0.0.128` from dropdown

> **Common Problem:** Windows auto-assigns extra IPs (169.254.x.x) which causes tftpd64 to switch interfaces. Fix: remove all extra IPs and keep only 192.0.0.128.

### Windows Firewall

Run as Administrator:
```powershell
New-NetFirewallRule -DisplayName 'TFTP In' -Direction Inbound -Protocol UDP -Action Allow
New-NetFirewallRule -DisplayName 'TFTP Out' -Direction Outbound -Protocol UDP -Action Allow
```

Or temporarily disable the firewall entirely:
```powershell
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
```

---

## 8. Configure Network

### Direct PC-to-NVR Connection

Connect Ethernet cable directly from PC to NVR's **uplink port** (NOT a PoE port!).

```
┌──────────┐    Ethernet Cable     ┌──────────────┐
│    PC    │◄─────────────────────►│  NVR Uplink  │
│192.0.0   │    (direct, no       │  Port        │
│  .128    │     router!)          │              │
└──────────┘                       └──────────────┘
```

### Set Static IP

```powershell
# Remove all existing IPs from Ethernet
Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 | ForEach-Object {
    Remove-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress $_.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
}
# Disable DHCP
Set-NetIPInterface -InterfaceAlias 'Ethernet' -Dhcp Disabled
# Set static IP
New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress 192.0.0.128 -PrefixLength 24
```

### Verify

```powershell
Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4
# Should show ONLY: 192.0.0.128
```

---

## 9. Flash Firmware via PuTTY (Recommended)

**This is the most reliable method.** You see everything in real-time and control the timing.

### Prerequisites
- UART wires connected to JP3
- TFTP server running on 192.0.0.128 with `digicap.dav`
- Ethernet cable direct PC ↔ NVR uplink port
- PuTTY open: Serial, your COM port, 115200 baud

### Step-by-Step

1. **NVR must be OFF**
2. Click inside PuTTY window
3. **Hold Ctrl+U** on keyboard (keep holding!)
4. **Power ON the NVR** with other hand (keep holding Ctrl+U)
5. Watch boot text scroll — keep holding Ctrl+U
6. Release when you see the upgrade menu

You should see:
```
U-Boot 2010.06-svn19235 (Jan 15 2018 - 20:50:54)
Hit ctrl+u to stop autoboot:  1  0

This program will upgrade software.
*******************************************************
*  ATTENTION!! PLEASE READ THIS NOTICE CAREFULLY!     *
...
Now press [u/U] key to upgrade software:
```

7. Type **u** + Enter

```
File system error, please upgrade by TFTP
Please input ip address of device:
```

8. Type **192.0.0.2** + Enter

```
Please input ip address of upgrade server:
```

9. Type **192.0.0.128** + Enter

```
Confirm?(y/n):
```

10. Type **y** + Enter

11. Watch the TFTP transfer:
```
TFTP from server 192.0.0.128; our IP address is 192.0.0.2
Download Filename 'digicap.dav'.
Downloading: *###########################
done
Bytes transferred = 16007532
```

12. Watch for the result:
```
cramfs.img checkSum ok !           ← FIRMWARE ACCEPTED!
```
or:
```
upgrade packet mismatch            ← WRONG FIRMWARE, try another
```

13. If accepted, **DO NOT TOUCH ANYTHING!** Wait for:
```
Writing ...
|##################################################| 100%
Done
Checking ...
|##################################################| 100%
Done
Update successfully !
Press ENTER key to reboot
```

### Trying Multiple Firmware Files

If the firmware is rejected ("upgrade packet mismatch"), the NVR returns to the IP prompt. You can:

1. **Replace `digicap.dav`** in the TFTP folder with a different firmware
2. Type the IPs again (**192.0.0.2**, **192.0.0.128**, **y**)
3. No need to power cycle — try multiple firmware files in one session!

---

## 10. Flash Firmware via Script (Alternative)

If you prefer automation, use `scripts/uart_tftp_flash.ps1`. See [HOW_TO_RUN.md](HOW_TO_RUN.md) for instructions.

> **Note:** The PuTTY method is more reliable because PL2303HX adapters tend to disconnect during automated sessions.

---

## 11. After Successful Flash

After "Update successfully!" the NVR reboots with factory defaults:

1. **Set new admin password** — via HDMI monitor setup wizard or SADP tool
2. **Set date/time** — the CMOS battery may be dead (shows 1970-01-01)
3. **Enable NTP** — Configuration → System → System Settings → Time Settings
4. **Configure network** — set static IP or enable DHCP
5. **Format HDD** — Configuration → Storage → Storage Management → Init
6. **Enable overwrite** — so recordings loop when HDD is full
7. **Re-add cameras** — Configuration → Camera Management

### Configure via API (Faster)

```bash
# Format HDD
curl --digest -u "admin:PASSWORD" "http://NVR_IP/ISAPI/ContentMgmt/Storage/hdd/1/format" -X PUT

# Enable overwrite/recycling
curl --digest -u "admin:PASSWORD" "http://NVR_IP/ISAPI/ContentMgmt/Storage/hdd/1" -X PUT \
  -H "Content-Type: application/xml" \
  -d '<hdd><id>1</id><property>RW</property><overWrite>true</overWrite></hdd>'

# Check HDD status
curl --digest -u "admin:PASSWORD" "http://NVR_IP/ISAPI/ContentMgmt/Storage/hdd"
```

---

## 12. Firmware Upgrade to V4.x

After the password reset with V3.4.x firmware, you can upgrade to V4.x for new features.

### Method 1: TFTP (same process as password reset)

1. Replace `digicap.dav` in TFTP folder with V4.x firmware
2. Enter upgrade mode via PuTTY (Ctrl+U during boot)
3. Flash as described in [Section 9](#9-flash-firmware-via-putty-recommended)

### Method 2: Web API Upload (V4.30+ only)

Once the NVR is running V4.30+, you can upload firmware via the web API:

```bash
curl --digest -u "admin:PASSWORD" "http://NVR_IP/ISAPI/System/updateFirmware" \
  -X PUT -T digicap.dav -H "Content-Type: application/octet-stream"
```

Then reboot:
```bash
curl --digest -u "admin:PASSWORD" "http://NVR_IP/ISAPI/System/reboot" -X PUT
```

> **Note:** The web API upload does NOT work on V3.4.x firmware — only TFTP.

### Method 3: USB Flash Drive

1. Copy `digicap.dav` to USB stick
2. Plug into NVR's USB port
3. HDMI menu → Maintenance → Upgrade → Local Upgrade

---

## 13. Hik-Connect Cloud Unbinding

### The Problem

If the NVR was previously bound to someone else's Hik-Connect account, you'll see:
- SADP Unbind: "Failed"
- Hik-Connect app: "unbinding current device not supported"
- Full factory reset does NOT clear the cloud binding

The binding is **server-side** on Hikvision's cloud servers — nothing you do on the device will remove it.

### What We Tried (All Failed)

| Method | Result |
|--------|--------|
| SADP Unbind button | "Failed" |
| Hik-Connect app unbind | "unbinding current device not supported" |
| GuardingVision app unbind | "device is offline" |
| Disable/re-enable EZVIZ via API | Binding persists |
| Full factory reset via API | Binding persists |
| Partial factory reset | Binding persists |
| Change Hik-Connect server region | Other regions show "Offline" |
| Firmware upgrade V3.4 → V4.30 | Binding still persists |

### The Only Solution

**Contact Hikvision support** and ask them to unbind the device server-side:

1. **Email:** techsupport.usa@mailservice.hikvision.com
2. **Ticket portal:** https://supportusa.hikvision.com
3. **Phone (Canada):** 1-855-655-9888

Provide:
- Device serial number
- MAC address
- Current firmware version
- Proof of physical access (photo of device)

### Alternative: Remote Access Without Hik-Connect

Set up **port forwarding** on your router:
- Forward port 8000 (SDK) and 80 (HTTP) to the NVR's IP
- Use **iVMS-4500** app to connect via your public IP/DDNS

---

## 14. NVR Configuration via API

### Useful ISAPI Commands

```bash
# Device info
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/deviceInfo"

# Check firmware version
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/deviceInfo" | grep firmwareVersion

# Format HDD
curl --digest -u "admin:PASS" "http://IP/ISAPI/ContentMgmt/Storage/hdd/1/format" -X PUT

# Enable HDD overwrite
curl --digest -u "admin:PASS" "http://IP/ISAPI/ContentMgmt/Storage/hdd/1" -X PUT \
  -H "Content-Type: application/xml" \
  -d '<hdd><id>1</id><property>RW</property><overWrite>true</overWrite></hdd>'

# Check Hik-Connect status
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/Network/EZVIZ"

# Reboot
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/reboot" -X PUT

# Factory reset (partial — keeps network)
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/factoryReset" -X PUT \
  -H "Content-Type: application/xml" -d '<factoryReset><mode>part</mode></factoryReset>'

# Factory reset (full)
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/factoryReset" -X PUT \
  -H "Content-Type: application/xml" -d '<factoryReset><mode>full</mode></factoryReset>'

# Upload firmware (V4.30+ only)
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/updateFirmware" \
  -X PUT -T digicap.dav -H "Content-Type: application/octet-stream"

# Check upgrade status
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/upgradeStatus"

# Network config
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/Network/interfaces/1"
```

---

## 15. Troubleshooting

### "upgrade packet mismatch"

Wrong firmware for your hardware. Note the `device_class` from the error and try firmware from different folders on the EU portal. See [Section 6](#6-find-the-correct-firmware).

### TFTP Transfer Timeout

```
Downloading: *
T
Retry count exceeded
```

- Check TFTP server shows **192.0.0.128** (not a different interface)
- Ethernet cable must be **direct PC-to-NVR** (not through router)
- Check Windows Firewall is disabled
- Remove extra IPs from Ethernet adapter

### "CRAMFS LOAD ERROR" After Flash

The firmware was written but is incompatible. The NVR enters **auto-recovery TFTP mode**. Flash the correct firmware using the same process — the NVR will keep retrying.

### USB-UART Adapter Disconnects During Boot

PL2303HX clones reset when the NVR power-cycles (current spike). Workarounds:
- Plug adapter into PC **after** NVR is powered on, then reboot NVR via web API
- Use a **FT232RL** adapter instead (more stable)
- Use the **PuTTY method** — it handles reconnections better than scripts

### SADP Tool Doesn't Find NVR

- Disable Windows Firewall
- PC and NVR must be on the same network
- Try closing and reopening SADP
- SADP uses broadcast — may not work over some network configurations

### Web UI "Browse" Button Doesn't Open File Dialog

The web UI requires an ActiveX plugin that only works in **Internet Explorer**. Alternatives:
- Upload firmware via API (V4.30+ only)
- Use TFTP method
- Use USB flash drive method

### PL2303HX Shows "Error" After Windows Update

Repeat the driver fix from [Section 3](#3-usb-uart-adapter-setup). Windows updates often revert the driver.

---

## Files in This Repository

```
hikvision-nvr-reset-guide/
├── README.md                      ← You are here
├── HOW_TO_RUN.md                  ← How to run PowerShell scripts
├── UART_ADAPTER_SETUP.md          ← Detailed USB-UART adapter guide
├── DIAGRAMS.md                    ← Visual wiring & flow diagrams
├── AGENT_GUIDE.md                 ← Guide for AI assistants
├── scripts/
│   ├── loopback_test.ps1          ← Test USB-UART adapter
│   ├── uart_raw_test.ps1          ← Verify UART connection
│   ├── uart_monitor.ps1           ← Find correct pins (beeps on data)
│   ├── uart_tftp_flash.ps1        ← Automated flash script
│   ├── fix_ip.ps1                 ← Lock Ethernet to 192.0.0.128
│   └── setup_firewall.ps1         ← Windows Firewall rules for TFTP
└── tools/
    └── download_tools.md          ← Download links for all tools
```

---

## Quick Reference Card

```
UART Settings:        115200 8N1 No flow control
NVR TFTP IP:          192.0.0.2
PC TFTP Server IP:    192.0.0.128
Firmware filename:    digicap.dav
Boot interrupt key:   Ctrl+U (hold before power-on)
Upgrade trigger:      u (at upgrade menu)
```

---

## Credits

This guide was created from a real-world password reset session on a Hikvision DS-7108NI-Q1/8P NVR in Kharkiv, Ukraine (March 2026). The process involved extensive trial-and-error to find the correct firmware variant, establish reliable UART communication with a budget PL2303HX adapter, and navigate Hikvision's firmware ecosystem.

## Contributing

Found a working firmware for a different device_class? Fixed the Hik-Connect unbinding? Please open a PR or issue!

## License

MIT License — use at your own risk. The authors are not responsible for any damage to your equipment.
