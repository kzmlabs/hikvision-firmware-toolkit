# Hikvision Camera Password Reset

## Method 1 — Change Password via API (password known)

If you know the current camera password, change it with a single command:

```bash
curl --digest -u "admin:OLD_PASSWORD" \
  "http://CAMERA_IP/ISAPI/Security/users/1" \
  -X PUT -H "Content-Type: application/xml" \
  -d '<User><id>1</id><userName>admin</userName><password>NEW_PASSWORD</password></User>'
```

Response `<statusString>OK</statusString>` means success.

### Verify

```bash
curl --digest -u "admin:NEW_PASSWORD" "http://CAMERA_IP/ISAPI/System/deviceInfo"
```

### Password Requirements

- Minimum 8 characters
- Must include at least 2 of: uppercase, lowercase, number, special character
- Cannot contain the username ("admin")

### Example: Change All Cameras on NVR PoE Network

```bash
# Connect PC to NVR PoE port, set IP:
netsh interface ip set address "Ethernet" static 192.168.254.100 255.255.255.0

# Change password on each camera:
for IP in 192.168.254.5 192.168.254.6 192.168.254.7; do
  echo "=== $IP ==="
  curl --digest -u "admin:OLD_PASS" "http://$IP/ISAPI/Security/users/1" \
    -X PUT -H "Content-Type: application/xml" \
    -d '<User><id>1</id><userName>admin</userName><password>NEW_PASS</password></User>'
  echo ""
done

# Then update NVR channel credentials (from LAN via Wi-Fi):
for CH in 1 2 3 4 5 6 7 8; do
  curl --digest -u "admin:NVR_PASS" "http://NVR_IP:PORT/ISAPI/ContentMgmt/InputProxy/channels/$CH" \
    -X PUT -H "Content-Type: application/xml" \
    -d "<InputProxyChannel version=\"1.0\" xmlns=\"http://www.hikvision.com/ver20/XMLSchema\">
      <id>$CH</id><sourceInputPortDescriptor>
      <proxyProtocol>HIKVISION</proxyProtocol>
      <addressingFormatType>ipaddress</addressingFormatType>
      <ipAddress>192.168.254.$((CH+4))</ipAddress>
      <managePortNo>8000</managePortNo><srcInputPort>1</srcInputPort>
      <userName>admin</userName><password>NEW_PASS</password>
      <connMode>plugplay</connMode><streamType>auto</streamType>
      </sourceInputPortDescriptor></InputProxyChannel>"
done
```

---

## Method 2 — SADP Reset (password unknown)

Use Hikvision's SADP tool to reset the password if you have access to the camera on the network.

### Requirements

- [SADP Tool](https://www.hikvision.com/en/support/tools/hitools/) installed
- Camera reachable on the network

### Steps

1. Open SADP → find the camera
2. Click **Forgot Password**
3. Choose reset mode:

| Mode | Works on | How |
|------|----------|-----|
| Security Question | All firmware | Answer questions set by previous owner |
| Export/Import XML | V5.3+ | Export feature code → send to Hikvision support → get reset file |

4. For XML mode:
   - Export the device feature code XML
   - Email it to Hikvision support with the camera serial number
   - They send back a reset file → import it in SADP

### Hikvision Support Contacts

| Region | Contact |
|--------|---------|
| Ukraine (VIATEC) | 0 800 21 73 17, support@viatec.ua |
| Ukraine (Hikvision) | 095-767-50-94, 068-523-47-20 |
| USA/Canada | techsupport.usa@mailservice.hikvision.com, 1-855-655-9888 |
| Global | supportusa.hikvision.com |

### What to Provide

- Camera model and serial number
- Start Time (shown in SADP)
- Exported XML feature code file

---

## Method 3 — Physical Reset Button (password unknown)

Most Hikvision dome cameras have a hardware reset button.

### Location

**DS-2CD1323G0-IU / DS-2CD1121-I:**
- Unscrew dome cover (Torx or twist-off)
- Reset button is near the microSD card slot

### Steps

1. Camera must be powered on
2. Press and hold the reset button for **10-15 seconds**
3. Camera reboots and becomes **Inactive**
4. Set new password via SADP or NVR

> If cameras are mounted high, use a PoE injector to bring the camera down to desk level for reset.

---

## Method 4 — TFTP Factory Reset (password unknown)

Flash firmware via TFTP to factory reset the camera. No UART needed — cameras have built-in TFTP recovery.

### Requirements

- Camera connected directly to PC via Ethernet
- 12V power adapter for the camera (or PoE injector)
- Correct firmware file (`digicap.dav`)
- TFTP server

### Camera Firmware

| Platform | Models | Firmware File |
|----------|--------|---------------|
| E3 | DS-2CD1323G0-IU | `IPC_E3_EN_STD_5.5.92_190227.zip` |
| E4 | DS-2CD1121-I | `IPC_E4_EN_STD_5.5.801_210701.zip` |

> Firmware must be **newer or equal** to current version. Older firmware is blocked by anti-rollback.

### Network Setup

Cameras use different TFTP IPs than NVRs:

| Address | Device | Purpose |
|---------|--------|---------|
| 192.168.1.128 | Your PC | TFTP server |
| 192.168.1.64 | Camera | During TFTP recovery |

```powershell
netsh interface ip set address "Ethernet" static 192.168.1.128 255.255.255.0
Set-NetFirewallProfile -All -Enabled False
```

### Steps

1. Extract `digicap.dav` from the firmware zip
2. Start TFTP server on 192.168.1.128:

**Option A — Hikvision Python TFTP:**
```bash
python scripts/hik_tftp.py 192.168.1.128
```

**Option B — tftpd64:**
- Place `digicap.dav` in tftpd64 folder
- Select 192.168.1.128 in Server interfaces dropdown

3. Connect camera Ethernet directly to PC
4. Power cycle the camera (unplug 12V, wait 5 sec, plug back in)
5. Camera requests firmware via TFTP automatically on boot
6. Wait 3-5 minutes — camera reboots as **Inactive**
7. Set new password via SADP

### Automated Script

```powershell
powershell -ExecutionPolicy Bypass -File scripts\camera_tftp_reset.ps1
```

### Known Issues

- **Wi-Fi conflict**: TFTP server may bind to Wi-Fi adapter instead of Ethernet. Disable Wi-Fi temporarily:
  ```powershell
  netsh interface set interface "Wi-Fi" disabled
  # ... do the TFTP reset ...
  netsh interface set interface "Wi-Fi" enabled
  ```
- **Anti-rollback**: Firmware older than what's on the camera will be rejected silently
- **Camera stays Active after TFTP**: Firmware may be wrong variant for the camera platform

---

## After Reset

1. Open SADP — camera should show as **Inactive**
2. Set new admin password
3. If camera is on NVR PoE, update the NVR channel password:
   ```bash
   curl --digest -u "admin:NVR_PASS" "http://NVR_IP:PORT/ISAPI/ContentMgmt/InputProxy/channels/1" \
     -X PUT -H "Content-Type: application/xml" \
     -d '<InputProxyChannel version="1.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
       <id>1</id><sourceInputPortDescriptor>
       <proxyProtocol>HIKVISION</proxyProtocol>
       <addressingFormatType>ipaddress</addressingFormatType>
       <ipAddress>CAMERA_IP</ipAddress><managePortNo>8000</managePortNo>
       <srcInputPort>1</srcInputPort><userName>admin</userName>
       <password>NEW_CAMERA_PASS</password>
       <connMode>plugplay</connMode><streamType>auto</streamType>
       </sourceInputPortDescriptor></InputProxyChannel>'
   ```
4. Restore PC network:
   ```powershell
   netsh interface ip set address "Ethernet" dhcp
   Set-NetFirewallProfile -All -Enabled True
   ```

---

## Accessing Cameras on NVR PoE Subnet

Cameras on the NVR's internal PoE ports are on an isolated subnet (192.168.254.x). To reach them from your PC:

1. Plug PC Ethernet into NVR PoE port 4-8
2. Set PC IP:
   ```
   netsh interface ip set address "Ethernet" static 192.168.254.100 255.255.255.0
   ```
3. Wi-Fi stays connected for internet
4. Cameras are at 192.168.254.5, .6, .7, etc.
5. To restore: `netsh interface ip set address "Ethernet" dhcp`

---

## Camera API Reference

```bash
# Device info
curl --digest -u "admin:PASS" "http://CAMERA_IP/ISAPI/System/deviceInfo"

# Change password
curl --digest -u "admin:PASS" "http://CAMERA_IP/ISAPI/Security/users/1" \
  -X PUT -H "Content-Type: application/xml" \
  -d '<User><id>1</id><userName>admin</userName><password>NEW_PASS</password></User>'

# Get network config
curl --digest -u "admin:PASS" "http://CAMERA_IP/ISAPI/System/Network/interfaces/1"

# Reboot
curl --digest -u "admin:PASS" "http://CAMERA_IP/ISAPI/System/reboot" -X PUT

# Factory reset
curl --digest -u "admin:PASS" "http://CAMERA_IP/ISAPI/System/factoryReset" -X PUT \
  -H "Content-Type: application/xml" -d '<factoryReset><mode>full</mode></factoryReset>'
```
