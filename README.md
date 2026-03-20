# Hikvision NVR/DVR Password Reset & Firmware Recovery Toolkit

> **Factory reset a locked Hikvision NVR when all standard methods fail — using UART serial console and TFTP firmware flash.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%2F11-blue.svg)]()
[![Tested: DS-7108NI-Q1/8P](https://img.shields.io/badge/Tested-DS--7108NI--Q1%2F8P-green.svg)]()

---

## When to Use This Guide

- Admin password lost, SADP reset code doesn't work
- Hikvision support unresponsive
- No physical reset button on the board
- Default passwords don't work

**Tested on:** DS-7108NI-Q1/8P (HiSilicon hi3536dv100)
**Applicable to:** Most Hikvision NVRs/DVRs with HiSilicon SoC and U-Boot bootloader

---

## Quick Start

```
1. Connect USB-UART adapter to NVR's JP3 header
2. Setup TFTP server (192.0.0.128) with digicap.dav firmware
3. Connect Ethernet direct PC ↔ NVR uplink port
4. Open PuTTY (Serial, 115200 baud)
5. Hold Ctrl+U, power on NVR → enter upgrade mode
6. Type: u → 192.0.0.2 → 192.0.0.128 → y
7. Wait for "Update successfully!" → NVR reboots with factory defaults
```

---

## Table of Contents

1. [Hardware Required](#1-hardware-required)
2. [UART Wiring](#2-uart-wiring)
3. [USB-UART Driver Setup](#3-usb-uart-driver-setup)
4. [Firmware Selection](#4-firmware-selection)
5. [Network & TFTP Setup](#5-network--tftp-setup)
6. [Flash Firmware via PuTTY](#6-flash-firmware-via-putty)
7. [Flash Firmware via Script](#7-flash-firmware-via-script)
8. [After Reset](#8-after-reset)
9. [Firmware Upgrade to V4.x](#9-firmware-upgrade-to-v4x)
10. [Hik-Connect Cloud Unbinding](#10-hik-connect-cloud-unbinding)
    - [10.1 Remote Access Without Hik-Connect](#101-remote-access-without-hik-connect)
11. [API Reference](#11-api-reference)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Hardware Required

| Item | Recommended | Cost |
|------|------------|------|
| USB-UART adapter | **FT232RL** (3.3V/5V jumper) | $3-10 |
| Dupont wires | Female-to-female, 3 wires | $2-5 |
| Ethernet cable | Direct PC-to-NVR connection | — |

> PL2303HX works but is unreliable (disconnects during power cycles). CH340 and CP2102 also work.

---

## 2. UART Wiring

### JP3 Header on DS-7108NI-Q1/8P

```
Arrow
 ▼
┌───┬───┬───┬───┐
│ 1 │ 2 │ 3 │ 4 │  JP3
│VCC│ TX│ RX│GND│
└───┴───┴───┴───┘
 ✕   ↓   ↓   ↓
 NC  WH  GR  BK    (adapter wires)
```

| NVR Pin | Adapter Wire | Color | Note |
|---------|-------------|-------|------|
| Pin 1 (VCC) | **DO NOT CONNECT** | Red | Tape it off! |
| Pin 2 (TX) | RX (adapter receives) | White | NVR sends → adapter receives |
| Pin 3 (RX) | TX (adapter sends) | Green | Adapter sends → NVR receives |
| Pin 4 (GND) | GND | Black | Ground reference |

> **TX/RX are crossed!** Adapter TX → NVR RX, Adapter RX ← NVR TX.

### Verify Connection

| UART Output | Meaning | Fix |
|------------|---------|-----|
| Boot text visible | Working! | Proceed |
| All `0x00` | TX/RX swapped | Swap white & green |
| All `0xFF` | Console silent | Power cycle NVR |
| Nothing | No connection | Check wires, adapter, COM port |

### Loopback Test

Touch TX + RX wires together → run `scripts/loopback_test.ps1` → should print "SUCCESS"

---

## 3. USB-UART Driver Setup

### PL2303HX on Windows 10/11 (driver fix)

1. Device Manager → find "USB-Serial Controller D" (⚠ error)
2. Right-click → Update driver → Browse → Let me pick from list
3. Select: **Ports (COM & LPT)** → **Microsoft** → **USB Serial Device**
4. Click Yes on warning → Note COM port number

### FT232RL / CH340 / CP2102

Drivers auto-install. Check Device Manager → Ports for COM number.

---

## 4. Firmware Selection

### CRITICAL: Firmware Must Match Your device_class

The NVR rejects firmware with wrong `device_class`. You'll see:
```
upgrade packet mismatch, please select correct packet
```

### Working Firmware for DS-7108NI-Q1/8P (device_class 0x5DE)

| Firmware | Version | Use For | Download |
|----------|---------|---------|----------|
| **digicap.dav** | V3.4.x | Password reset | [firmware/v3.4.x_recovery_digicap.dav](firmware/) |
| **NVR_K75_NEU** | V4.30.080 | V4 upgrade | [firmware/v4.30.080_K75_NEU_digicap.dav](firmware/) |
| **Official** | V4.30.091 | Best option | [firmware/v4.30.091_official_digicap.dav](firmware/) |

> **Key insight:** V4 firmware is in `[7100NI-Q1]` folder (K75 series), NOT `[76NI-Q1(Q2)]` (K74). The folder name doesn't always match the model!

### Rejected Firmware (tested, doesn't work)

NVR_K74, NVR_K9B2, NVR_K21B2, DS-7108NI-Q18P_V4.76.107 — all "upgrade packet mismatch"

See [firmware/README.md](firmware/README.md) for full compatibility matrix and download links.

---

## 5. Network & TFTP Setup

### IP Addresses

| Address | Who | Purpose |
|---------|-----|---------|
| **192.0.0.128** | Your PC | TFTP server (Hikvision standard) |
| **192.0.0.2** | NVR | During manual upgrade mode |
| **192.168.1.64** | NVR | Factory default after reset |

### Setup Steps

1. **Connect** Ethernet cable direct from PC to NVR **uplink port** (not PoE!)

2. **Set PC IP:**
```powershell
# Run scripts/fix_ip.ps1 or:
Set-NetIPInterface -InterfaceAlias 'Ethernet' -Dhcp Disabled
New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress 192.0.0.128 -PrefixLength 24
```

3. **Start TFTP server:**
   - Download [tftpd64 portable](https://github.com/PJO2/tftpd64/releases)
   - Place `digicap.dav` in tftpd64 folder
   - Run tftpd64.exe → select **192.0.0.128** in Server interfaces dropdown

4. **Disable firewall:**
```powershell
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
```

> **Common problem:** Windows auto-assigns 169.254.x.x IPs which makes tftpd64 switch interfaces. Always run `scripts/fix_ip.ps1` first.

### Finding NVR IP After Boot

```bash
# By MAC address:
arp -a | grep "68-6d-bc"

# Or use SADP Tool for discovery
```

---

## 6. Flash Firmware via PuTTY

**Recommended method** — you see everything and control the timing.

### Setup

- PuTTY: Serial → your COM port → Speed 115200 → Open
- TFTP server running on 192.0.0.128
- Ethernet direct PC ↔ NVR

### Steps

1. **NVR must be OFF**
2. Click PuTTY window, **hold Ctrl+U**
3. **Power ON NVR** (keep holding Ctrl+U)
4. When you see upgrade menu, release Ctrl+U

5. **Type responses:**

```
Now press [u/U] key to upgrade software: u
Please input ip address of device: 192.0.0.2
Please input ip address of upgrade server: 192.0.0.128
Confirm?(y/n): y
```

6. **Watch for result:**
```
cramfs.img checkSum ok !        ← ACCEPTED! Don't touch!
```
or:
```
upgrade packet mismatch         ← Wrong firmware. Replace digicap.dav and retry
```

7. **If accepted, wait for flash to complete:**
```
Writing ...  |##################################################| 100%
Checking ... |##################################################| 100%
Update successfully !
```

> **Tip:** If firmware is rejected, the NVR returns to the IP prompt. Just replace `digicap.dav` in the TFTP folder and type the IPs again — no need to power cycle!

---

## 7. Flash Firmware via Script

Alternative to PuTTY — use `scripts/uart_tftp_flash.ps1`.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\uart_tftp_flash.ps1
```

See [HOW_TO_RUN.md](HOW_TO_RUN.md) for details. PuTTY method is more reliable.

---

## 8. After Reset

The NVR reboots with factory defaults:

1. **Set new admin password** (HDMI wizard or SADP)
2. **Set date/time** and enable NTP
3. **Format HDD** and enable overwrite (see API below)
4. **Configure network** (static IP or DHCP)
5. **Re-add cameras**

---

## 9. Firmware Upgrade to V4.x

After password reset with V3.4.x, upgrade to V4.x:

**Method 1: TFTP** — same process as password reset, use V4.x firmware file

**Method 2: Web API** (V4.30+ only):
```bash
curl --digest -u "admin:PASSWORD" "http://NVR_IP/ISAPI/System/updateFirmware" \
  -X PUT -T digicap.dav -H "Content-Type: application/octet-stream"
curl --digest -u "admin:PASSWORD" "http://NVR_IP/ISAPI/System/reboot" -X PUT
```

**Method 3: USB flash drive** — copy `digicap.dav` to USB, plug into NVR, upgrade from HDMI menu

---

## 10. Hik-Connect Cloud Unbinding

If the NVR was bound to someone else's Hik-Connect account:

| Method | Result |
|--------|--------|
| SADP Unbind | "Failed" |
| Hik-Connect app | "unbinding current device not supported" |
| Factory reset | Does NOT clear cloud binding |
| Firmware upgrade | Does NOT clear cloud binding |

**The binding is server-side.** Only Hikvision support can remove it:

- Email: **techsupport.usa@mailservice.hikvision.com**
- Portal: https://supportusa.hikvision.com
- Phone: 1-855-655-9888 (Canada)

**Alternative:** Use port forwarding + DDNS for remote access without Hik-Connect. See [Section 10.1](#101-remote-access-without-hik-connect).

### 10.1 Remote Access Without Hik-Connect

If Hik-Connect is unusable (bound to old account, or you prefer not to depend on cloud), you can access the NVR directly over the internet using free DDNS + port forwarding.

#### Architecture

```
                       REMOTE ACCESS — HOW IT WORKS
                       ════════════════════════════

 YOUR PHONE / LAPTOP                         THE INTERNET
 (anywhere in the world)
 ┌──────────────────┐                  ┌─────────────────────┐
 │                  │                  │                     │
 │  Browser:        │    ①            │   DDNS Provider     │
 │  mynvr.ddns.net  │───────────────► │   (e.g. No-IP)     │
 │  :9080           │  DNS lookup     │   ┌───────────────┐ │
 │                  │                 │   │ mynvr.ddns.net│ │
 │  iVMS-4500 app:  │  ◄─────────────│   │ = 1.2.3.4     │ │
 │  port 9000       │    ②           │   └───────────────┘ │
 │                  │  Answer: IP     └─────────────────────┘
 │  RTSP player:    │                          ▲
 │  port 554        │                          │
 └────────┬─────────┘                          │ ⑤ NVR updates IP
          │                                    │   periodically
          │ ③ Connect to                       │
          │   public IP:port                   │
          ▼                                    │
 ┌──────────────────────────────────────────────────────────────┐
 │                      HOME NETWORK                             │
 │                                                               │
 │   ┌──────────────┐    Port Forward     ┌──────────────────┐  │
 │   │              │    Rules:           │                  │  │
 │   │    Router     │                     │  Hikvision NVR   │  │
 │   │              │  :9080 ──────────►  │                  │  │
 │   │ Public IP:   │  :9000 ──────────►  │  LAN IP:         │  │
 │   │ 1.2.3.4     │  :554  ──────────►  │  192.168.X.X     │  │
 │   │              │         ④           │                  │  │
 │   └──────────────┘                     └──────────────────┘  │
 └──────────────────────────────────────────────────────────────┘

 FLOW:
 ① Phone asks DDNS: "what IP is mynvr.ddns.net?"
 ② DDNS answers with your home public IP
 ③ Phone connects to your public IP on the forwarded port
 ④ Router forwards traffic to NVR on the LAN
 ⑤ NVR's built-in DDNS client keeps the IP up to date
```

#### DDNS Update Flow

```
 ┌──────────────────┐          HTTPS           ┌──────────────────┐
 │  Hikvision NVR   │ ──────────────────────►  │  DDNS Server     │
 │                  │  "My IP is 1.2.3.4"      │  (dynupdate.     │
 │  Built-in DDNS   │                           │  no-ip.com)      │
 │  client runs     │  ◄──────────────────────  │                  │
 │  every ~5 min    │  "good" or "nochg"       │  Updates:        │
 │                  │                           │  mynvr.ddns.net  │
 └──────────────────┘                           │  → 1.2.3.4      │
                                                └──────────────────┘
```

#### Setup Steps

1. **Register free DDNS hostname** at [noip.com](https://www.noip.com) (3 free hostnames)
   - Create hostname → select "DDNS Compatible Device" → generate DDNS Key

2. **Configure DDNS on NVR** (Configuration → Network → DDNS):

   | Field          | Value                         |
   |----------------|-------------------------------|
   | Enable DDNS    | checked                       |
   | DDNS Type      | NO-IP                         |
   | Server Address | `dynupdate.no-ip.com`         |
   | Host Name      | `all.ddnskey.com`             |
   | User Name      | your DDNS Key username        |
   | Password       | your DDNS Key password        |

   Or via ISAPI:
   ```bash
   curl --digest -u "admin:PASS" -X PUT "http://NVR_IP/ISAPI/System/Network/DDNS/1" \
     -H "Content-Type: application/xml" \
     -d '<DDNS xmlns="http://www.hikvision.com/ver20/XMLSchema">
       <id>1</id><enabled>true</enabled><provider>NoIpDns</provider>
       <serverAddress><addressingFormatType>hostname</addressingFormatType>
         <hostName>dynupdate.no-ip.com</hostName></serverAddress>
       <deviceDomainName>all.ddnskey.com</deviceDomainName>
       <userName>YOUR_DDNS_KEY_USER</userName></DDNS>'
   ```

3. **Change default ports** (avoid conflicts and improve security):

   ```bash
   # HTTP 80 → 9080
   curl --digest -u "admin:PASS" -X PUT "http://NVR_IP/ISAPI/Security/adminAccesses/1" \
     -H "Content-Type: application/xml" \
     -d '<AdminAccessProtocol xmlns="http://www.hikvision.com/ver20/XMLSchema">
       <id>1</id><enabled>true</enabled><protocol>HTTP</protocol><portNo>9080</portNo>
       </AdminAccessProtocol>'

   # Server/SDK 8000 → 9000
   curl --digest -u "admin:PASS" -X PUT "http://NVR_IP:9080/ISAPI/Security/adminAccesses/4" \
     -H "Content-Type: application/xml" \
     -d '<AdminAccessProtocol xmlns="http://www.hikvision.com/ver20/XMLSchema">
       <id>4</id><enabled>true</enabled><protocol>DEV_MANAGE</protocol><portNo>9000</portNo>
       </AdminAccessProtocol>'
   ```

4. **Port forward on router** (Forwarding → Virtual Servers):

   | Service Port | Internal IP    | Internal Port | Protocol |
   |-------------|----------------|---------------|----------|
   | 9080        | 192.168.X.X    | 9080          | TCP      |
   | 9000        | 192.168.X.X    | 9000          | TCP      |
   | 554         | 192.168.X.X    | 554           | TCP/UDP  |

   > Port 80 may conflict with router's remote management — use non-standard ports.

5. **Reserve NVR IP** in router DHCP settings (bind MAC to fixed IP).

6. **Access from internet:**
   - Browser: `http://mynvr.ddns.net:9080`
   - iVMS-4500: add device manually, address `mynvr.ddns.net`, port `9000`
   - RTSP: `rtsp://admin:PASS@mynvr.ddns.net:554/Streaming/Channels/101`

#### Comparison: Hik-Connect vs DDNS + Port Forward

```
 Hik-Connect (P2P cloud):
   Phone ◄──► Hikvision Cloud ◄──► NVR
   ✓ Zero config, works behind any NAT
   ✗ Depends on Hikvision servers
   ✗ Device binding is permanent and server-side
   ✗ Cannot use if bound to another account

 DDNS + Port Forward (direct):
   Phone ──► Your Router ──► NVR
   ✓ No cloud dependency
   ✓ Works regardless of Hik-Connect binding
   ✓ Free (No-IP free tier)
   ✗ Requires router port forwarding
   ✗ Some ISPs block common ports
   ✗ No-IP free tier needs monthly email confirmation
```

#### Troubleshooting

| Problem | Fix |
|---------|-----|
| DDNS status "connServerfail" | Set DNS to `8.8.8.8` / `8.8.4.4` on NVR (TCP/IP → uncheck auto DNS) |
| DDNS status "connecting" forever | Disable DDNS, wait 60s, re-enable with fresh credentials |
| Can't access from internet | Verify port forwarding rules on router |
| Works on LAN but not remotely | ISP may block port — try different port numbers |
| Can't test DDNS from home WiFi | NAT hairpin not supported on most consumer routers — test from mobile data |
| Router port 80 conflict | Router remote management uses port 80 — use 9080+ for NVR |
| "badauth" in No-IP | Use DDNS Key credentials, not account email/password |

---

## 11. API Reference

```bash
# Device info
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/deviceInfo"

# Format HDD
curl --digest -u "admin:PASS" "http://IP/ISAPI/ContentMgmt/Storage/hdd/1/format" -X PUT

# Enable HDD overwrite
curl --digest -u "admin:PASS" "http://IP/ISAPI/ContentMgmt/Storage/hdd/1" -X PUT \
  -H "Content-Type: application/xml" \
  -d '<hdd><id>1</id><property>RW</property><overWrite>true</overWrite></hdd>'

# Hik-Connect status
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/Network/EZVIZ"

# Reboot
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/reboot" -X PUT

# Factory reset (partial)
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/factoryReset" -X PUT \
  -H "Content-Type: application/xml" -d '<factoryReset><mode>part</mode></factoryReset>'

# Upload firmware (V4.30+ only)
curl --digest -u "admin:PASS" "http://IP/ISAPI/System/updateFirmware" \
  -X PUT -T digicap.dav -H "Content-Type: application/octet-stream"
```

---

## 12. Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| "upgrade packet mismatch" | Wrong firmware | Try different firmware file (see [Section 4](#4-firmware-selection)) |
| TFTP timeout (`T` then retry) | Network issue | Check TFTP shows 192.0.0.128, cable is direct, firewall off |
| "CRAMFS LOAD ERROR" on boot | Bad firmware flashed | NVR enters auto-recovery — flash correct firmware via TFTP |
| Adapter disconnects during boot | PL2303HX power spike | Use FT232RL, or plug adapter after NVR is on then reboot via API |
| SADP doesn't find NVR | Network/firewall | Disable firewall, same network, try Refresh |
| Web UI Browse button broken | Needs ActiveX/IE plugin | Use API upload, TFTP, or USB stick instead |
| tftpd64 switches interface | Windows auto-assigns extra IPs | Run `scripts/fix_ip.ps1` to keep only 192.0.0.128 |

---

## Repository Structure

```
hikvision-firmware-toolkit/
├── README.md                 ← You are here
├── firmware/
│   ├── README.md             ← Firmware download links & compatibility
│   ├── v3.4.x_recovery_digicap.dav
│   ├── v4.30.080_K75_NEU_digicap.dav
│   └── v4.30.091_official_digicap.dav
├── scripts/
│   ├── loopback_test.ps1     ← Test USB-UART adapter
│   ├── uart_raw_test.ps1     ← Verify UART connection
│   ├── uart_monitor.ps1      ← Find correct pins
│   ├── uart_tftp_flash.ps1   ← Automated flash script
│   ├── fix_ip.ps1            ← Lock Ethernet to 192.0.0.128
│   └── setup_firewall.ps1    ← Windows Firewall rules
├── REMOTE_ACCESS.md          ← DDNS + port forwarding setup (private, not in repo)
├── AGENT_GUIDE.md            ← Guide for AI assistants
├── DIAGRAMS.md               ← Visual wiring & flow diagrams
├── HOW_TO_RUN.md             ← How to run scripts
├── UART_ADAPTER_SETUP.md     ← Adapter configuration details
├── LICENSE                   ← MIT
└── tools/
    └── download_tools.md     ← Download links for tftpd64, PuTTY, etc.
```

---

## Quick Reference

```
UART:     115200 8N1, no flow control
PC IP:    192.0.0.128
NVR IP:   192.0.0.2
Firmware: digicap.dav
Boot key: Ctrl+U (hold before power-on)
Upgrade:  u → 192.0.0.2 → 192.0.0.128 → y
```

---

## Tested Hardware

| Component | Details |
|-----------|---------|
| NVR | DS-7108NI-Q1/8P (DS-8025 PcEV1.0) |
| SoC | HiSilicon hi3536dv100 |
| Original FW | V3.4.99 build 180706 |
| Upgraded FW | V4.30.091 build 220919 |
| device_class | 0x5DE (1502) |

## Contributing

Found working firmware for a different `device_class`? Tested on another model? **Open a PR or issue!**

## Disclaimer

For **legitimate device owners** who lost access to their own equipment. Do not use on devices you do not own.

## License

[MIT](LICENSE)
