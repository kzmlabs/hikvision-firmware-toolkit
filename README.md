# Hikvision NVR & Camera Password Reset Toolkit

Factory reset a locked Hikvision NVR or IP camera when standard methods fail.

## Tested Hardware

| Device | Model | Firmware | Method |
|--------|-------|----------|--------|
| NVR | DS-7108NI-Q1/8P | V3.4.99 → V4.30.091 | UART + TFTP |
| Camera | DS-2CD1323G0-IU | V5.5.84 | API password change |
| Camera | DS-2CD1121-I | V5.5.84 | API password change |

---

## Guides

| Guide | When to Use |
|-------|-------------|
| [NVR Reset (UART + TFTP)](#nvr-password-reset) | Admin password lost, SADP reset doesn't work |
| [Camera Password Reset](CAMERA_PASSWORD_RESET.md) | Camera password known — change via API |
| [Camera TFTP Recovery](CAMERA_PASSWORD_RESET.md#tftp-factory-reset) | Camera password unknown — flash firmware |

---

## NVR Password Reset

### When to Use

- Admin password lost, SADP reset code doesn't work
- Hikvision support unresponsive
- Default passwords don't work

### Requirements

| Item | Recommended | Cost |
|------|------------|------|
| USB-UART adapter | FT232RL (3.3V) | $3-10 |
| Dupont wires | Female-to-female, 3 wires | $2-5 |
| Ethernet cable | Direct PC-to-NVR | — |
| TFTP server | [tftpd64](https://github.com/PJO2/tftpd64/releases) | Free |
| Serial terminal | [PuTTY](https://the.earth.li/~sgtatham/putty/latest/w64/putty.exe) | Free |

### Quick Start

```
1. Connect USB-UART adapter to NVR's JP3 header
2. Setup TFTP server (192.0.0.128) with digicap.dav firmware
3. Connect Ethernet direct PC ↔ NVR uplink port
4. Open PuTTY (Serial, 115200 baud)
5. Hold Ctrl+U, power on NVR → enter upgrade mode
6. Type: u → 192.0.0.2 → 192.0.0.128 → y
7. Wait for "Update successfully!" → NVR reboots with factory defaults
```

### UART Wiring (JP3 Header)

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

| NVR Pin | Adapter Wire | Note |
|---------|-------------|------|
| Pin 1 (VCC) | DO NOT CONNECT | Tape it off |
| Pin 2 (TX) | RX on adapter | NVR sends → adapter receives |
| Pin 3 (RX) | TX on adapter | Adapter sends → NVR receives |
| Pin 4 (GND) | GND | Ground reference |

> TX/RX are crossed: Adapter TX → NVR RX, Adapter RX ← NVR TX.

### Network Setup

| Address | Device | Purpose |
|---------|--------|---------|
| 192.0.0.128 | Your PC | TFTP server |
| 192.0.0.2 | NVR | During upgrade mode |
| 192.168.1.64 | NVR | Factory default after reset |

```powershell
# Set PC IP
netsh interface ip set address "Ethernet" static 192.0.0.128 255.255.255.0

# Disable firewall
Set-NetFirewallProfile -All -Enabled False
```

Start tftpd64 → select 192.0.0.128 → place `digicap.dav` in its folder.

### Flash Firmware

1. NVR must be OFF
2. Open PuTTY (Serial, COM port, 115200 baud)
3. Hold **Ctrl+U**, power ON NVR
4. When upgrade menu appears, release Ctrl+U
5. Type responses:

```
Now press [u/U] key to upgrade software: u
Please input ip address of device: 192.0.0.2
Please input ip address of upgrade server: 192.0.0.128
Confirm?(y/n): y
```

6. Wait for result:
   - `cramfs.img checkSum ok` → firmware accepted, wait for flash
   - `upgrade packet mismatch` → wrong firmware, replace and retry

7. After `Update successfully!` → NVR reboots with factory defaults

### After NVR Reset

1. Set new admin password (HDMI wizard or SADP)
2. Set date/time, enable NTP
3. Format HDD and enable overwrite
4. Configure network (static IP or DHCP)
5. Re-add cameras

### Firmware Compatibility (DS-7108NI-Q1/8P, device_class 0x5DE)

| Firmware | Version | Use For |
|----------|---------|---------|
| digicap.dav (V3.4.x) | V3.4.x | Password reset |
| NVR_K75_NEU | V4.30.080 | Upgrade to V4 |
| Official | V4.30.091 | Best option |

> V4 firmware is in `[7100NI-Q1]` folder (K75 series), NOT `[76NI-Q1(Q2)]` (K74).

Firmware sources:
- [Hikvision EU Portal](https://www.hikvisioneurope.com/eu/portal/) → Technical Materials → NVR → Product Firmware
- [FIESA Mirror](https://descargas.fiesa.com.ar/descargas/Hikvision/Firmware/NVRS/)

---

## NVR API Reference

```bash
# Device info
curl --digest -u "admin:PASS" "http://IP:PORT/ISAPI/System/deviceInfo"

# Camera channel status
curl --digest -u "admin:PASS" "http://IP:PORT/ISAPI/ContentMgmt/InputProxy/channels/status"

# Update camera password on NVR channel
curl --digest -u "admin:PASS" "http://IP:PORT/ISAPI/ContentMgmt/InputProxy/channels/1" \
  -X PUT -H "Content-Type: application/xml" \
  -d '<InputProxyChannel version="1.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
    <id>1</id><name>Camera1</name>
    <sourceInputPortDescriptor>
      <proxyProtocol>HIKVISION</proxyProtocol>
      <addressingFormatType>ipaddress</addressingFormatType>
      <ipAddress>192.168.254.5</ipAddress>
      <managePortNo>8000</managePortNo>
      <srcInputPort>1</srcInputPort>
      <userName>admin</userName>
      <password>NEW_PASSWORD</password>
      <connMode>plugplay</connMode>
      <streamType>auto</streamType>
    </sourceInputPortDescriptor></InputProxyChannel>'

# Format HDD
curl --digest -u "admin:PASS" "http://IP:PORT/ISAPI/ContentMgmt/Storage/hdd/1/format" -X PUT

# Enable HDD overwrite
curl --digest -u "admin:PASS" "http://IP:PORT/ISAPI/ContentMgmt/Storage/hdd/1" -X PUT \
  -H "Content-Type: application/xml" \
  -d '<hdd><id>1</id><property>RW</property><overWrite>true</overWrite></hdd>'

# Reboot
curl --digest -u "admin:PASS" "http://IP:PORT/ISAPI/System/reboot" -X PUT

# Upload firmware (V4.30+)
curl --digest -u "admin:PASS" "http://IP:PORT/ISAPI/System/updateFirmware" \
  -X PUT -T digicap.dav -H "Content-Type: application/octet-stream"
```

---

## Hik-Connect Cloud Unbinding

Factory reset does NOT clear Hik-Connect binding — it's server-side. Only Hikvision support can remove it.

**Alternative:** Use DDNS + port forwarding for remote access without Hik-Connect.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `upgrade packet mismatch` | Wrong firmware — try different file |
| TFTP timeout | Check TFTP shows 192.0.0.128, cable is direct, firewall off |
| SADP doesn't find NVR | Disable firewall, same network |
| PL2303HX disconnects | Use FT232RL adapter instead |
| tftpd64 switches interface | Run `scripts/fix_ip.ps1` to lock IP |

---

## Repository Structure

```
hikvision/
├── README.md                      ← NVR reset guide
├── CAMERA_PASSWORD_RESET.md       ← Camera password reset guide
├── firmware/
│   ├── README.md                  ← Firmware sources & compatibility
│   ├── digicap.dav                ← NVR V3.4.x recovery
│   ├── v4.30.080_K75_NEU_digicap.dav
│   ├── v4.30.091_official_digicap.dav
│   ├── IPC_E3_EN_STD_5.5.92_190227.zip  ← Camera firmware (E3 platform)
│   ├── IPC_E4_EN_STD_5.5.801_210701.zip ← Camera firmware (E4 platform)
│   └── e4_new/digicap.dav        ← Extracted E4 firmware
├── scripts/
│   ├── camera_tftp_reset.ps1      ← Camera TFTP factory reset
│   ├── hik_tftp.py                ← Python TFTP server for cameras
│   ├── fix_ip.ps1                 ← Lock Ethernet to TFTP IP
│   ├── setup_firewall.ps1         ← Windows Firewall rules
│   ├── loopback_test.ps1          ← Test USB-UART adapter
│   ├── uart_raw_test.ps1          ← Verify UART connection
│   └── uart_tftp_flash.ps1        ← NVR automated flash script
└── LICENSE
```

## Disclaimer

For legitimate device owners who lost access to their own equipment. Do not use on devices you do not own.

## License

[MIT](LICENSE)
