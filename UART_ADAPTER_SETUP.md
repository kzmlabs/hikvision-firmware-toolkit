# USB-UART Adapter Setup Guide

## Supported Adapters

| Adapter | Chip | Voltage | Windows Driver | Reliability | Price |
|---------|------|---------|---------------|-------------|-------|
| FT232RL | FTDI FT232RL | 3.3V/5V (jumper) | Auto-install | Excellent | $5-10 |
| CH340 | WCH CH340G | 3.3V/5V (varies) | Auto or manual | Good | $2-5 |
| PL2303HX | Prolific PL2303 | 5V (usually) | Needs hack | Poor (clones) | $1-3 |
| CP2102 | Silicon Labs | 3.3V | Auto-install | Excellent | $3-8 |

**Recommendation: FT232RL** — it has a voltage jumper (set to 3.3V), drivers work out of the box, and it's reliable.

---

## FT232RL Setup

### Hardware

```
┌─────────────────────────┐
│    FT232RL Adapter       │
│                          │
│  USB ◄── to PC           │
│                          │
│  ┌──────────────────┐   │
│  │ 3V3 ○    ○ 5V    │   │  ◄── Jumper: SET TO 3V3!
│  └──────────────────┘   │
│                          │
│  Pins:                   │
│  [GND] [CTS] [VCC]      │
│  [TXD] [RXD] [DTR]      │
│                          │
└─────────────────────────┘
```

### Driver Installation

1. Plug adapter into USB
2. Windows should auto-install the driver
3. Check Device Manager → Ports → "USB Serial Port (COM#)"
4. If not found, download from: https://ftdichip.com/drivers/

### Wiring to NVR

| Adapter Pin | Wire | NVR JP3 Pin |
|-------------|------|-------------|
| GND | Black | Pin 4 (GND) |
| TXD | Green | Pin 3 (NVR RX) |
| RXD | White | Pin 2 (NVR TX) |
| VCC | — | **DO NOT CONNECT** |

---

## PL2303HX Setup (Budget Clone)

### Hardware

```
┌──────────────────────────┐
│   PL2303HX Adapter        │
│                            │
│  USB ◄── to PC             │
│                            │
│  Wires:                    │
│  ══ Red ══   VCC (5V)      │  ◄── DO NOT CONNECT TO NVR!
│  ══ Black ══ GND           │
│  ══ White ══ RX (data in)  │
│  ══ Green ══ TX (data out) │
│                            │
│  No voltage selector!      │
│  Always outputs 5V TTL.    │
└──────────────────────────┘
```

### Driver Installation (Windows 10/11)

The PL2303HX clone is **blocked by Prolific** on Windows 10/11. It shows as "USB-Serial Controller D" with an error.

**Fix (step by step with screenshots description):**

1. **Plug in** the USB adapter
2. Open **Device Manager** (`Win+R` → type `devmgmt.msc` → Enter)
3. Find **"USB-Serial Controller D"** — it will have a yellow ⚠️ warning icon
   - Usually under "Other devices" or "Universal Serial Bus controllers"
4. **Right-click** on it → **"Update driver"**
5. Click **"Browse my computer for drivers"**
6. Click **"Let me pick from a list of available drivers on my computer"**
7. In the device type list, select **"Ports (COM & LPT)"** → click **Next**
8. Left column: select **"Microsoft"**
9. Right column: select **"USB Serial Device"**
10. Click **Next**
11. Warning dialog appears: "Installing this device driver is not recommended..." → click **Yes**
12. Success: "Windows has successfully updated your drivers"
13. The device now shows as **"USB Serial Device (COM#)"** — note the COM number!

```
Before fix:                          After fix:
┌──────────────────────┐            ┌──────────────────────┐
│ ⚠ USB-Serial         │            │ ✓ USB Serial Device  │
│   Controller D       │     →      │   (COM3)             │
│   Status: Error      │            │   Status: OK         │
└──────────────────────┘            └──────────────────────┘
```

### Wiring to NVR

| Wire Color | Function | NVR JP3 Pin |
|------------|----------|-------------|
| Red | VCC | **DO NOT CONNECT!** Tape it off. |
| Black | GND | Pin 4 (far from arrow) |
| White | RX (adapter receives) | Pin 2 (NVR TX sends) |
| Green | TX (adapter sends) | Pin 3 (NVR RX receives) |

### Known Issues with PL2303HX

- **Disconnects randomly** — the clone chip may reset under load
- **5V only** — some NVRs may not read 5V input reliably (3.3V preferred)
- **Driver keeps resetting** — after Windows Update, you may need to redo the driver fix
- **COM port changes** — unplugging/replugging may assign a different COM port number

---

## CH340 Setup

### Driver Installation

1. Plug adapter into USB
2. If auto-installed: Device Manager shows "USB-SERIAL CH340 (COM#)"
3. If not found, download driver from: http://www.wch-ic.com/downloads/CH341SER_EXE.html

### Wiring

Same as other adapters — check PCB labels for GND, TXD, RXD. Wire colors vary.

---

## CP2102 Setup

### Driver Installation

1. Usually auto-installs on Windows 10/11
2. If not, download from: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers

---

## Verifying Any Adapter

After driver installation:

### 1. Check Device Manager

```
Device Manager → Ports (COM & LPT)
  └── USB Serial Device (COM3)    ← Your adapter
      Status: "This device is working properly"
```

### 2. Run Loopback Test

```
1. Touch TX wire to RX wire (Green to White)
2. Open PowerShell
3. Run: powershell -ExecutionPolicy Bypass -File scripts\loopback_test.ps1
4. Expected output: "SUCCESS! TX is working. Got back: HELLO123"
```

### 3. Check Voltage (if you have a multimeter)

```
1. Plug adapter into USB
2. Set multimeter to DC Voltage
3. Measure between GND and TX pins
4. Should read:
   - ~3.3V if adapter is 3.3V mode
   - ~5.0V if adapter is 5V mode
5. For Hikvision NVRs, 3.3V is preferred
```

---

## Serial Communication Settings

All Hikvision NVR/DVR devices use:

| Parameter | Value |
|-----------|-------|
| Baud rate | **115200** |
| Data bits | **8** |
| Stop bits | **1** |
| Parity | **None** |
| Flow control | **None** |

These settings are used in all scripts and should be used in PuTTY if connecting manually.

### PuTTY Manual Connection

1. Open PuTTY
2. Connection type: **Serial**
3. Serial line: **COM3** (your COM port number)
4. Speed: **115200**
5. Click **Open**
6. Power on NVR — you should see boot text scrolling
