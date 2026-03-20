# Tools Download Links

## Required Tools

### TFTP Server - tftpd64 (Portable)
- **Download:** https://github.com/PJO2/tftpd64/releases
- **Version:** v4.74 or later
- **File:** `tftpd64_portable_v4.74.zip` (portable, no install needed)

### Serial Terminal - PuTTY
- **Download:** https://the.earth.li/~sgtatham/putty/latest/w64/putty.exe
- **No installation needed** — single .exe file

### SADP Tool (Hikvision Device Discovery)
- **Download:** https://www.hikvision.com/en/support/tools/hitools/
- **Used for:** Finding NVR on network, checking serial number and Start Time

## USB-UART Adapters (Buy Links)

### Recommended: FT232RL USB-UART
- Has 3.3V/5V jumper (set to 3.3V for Hikvision NVRs)
- Drivers work on Windows 10/11 without hacks
- Search on AliExpress/Amazon/local electronics stores

### Budget: PL2303HX USB-TTL
- Cheapest option (~$2-3)
- **Requires driver workaround on Windows 10/11** (see README Section 3)
- Clone chips may be unreliable

### Alternative: CH340 USB-UART
- Good middle-ground option
- Drivers usually auto-install

## Firmware Sources

### Hikvision EU Portal
- **URL:** https://www.hikvisioneurope.com/eu/portal/
- **Path:** Technical Materials → 02 NVR → 00 Product Firmware → Q-series
- Contains firmware for most Hikvision NVR models and regional variants

### FIESA Mirror (Argentina Distributor)
- **URL:** https://descargas.fiesa.com.ar/descargas/Hikvision/Firmware/NVRS/
- Open directory with many NVR firmware versions
- Useful when official portal requires login

### Official Hikvision Firmware
- **URL:** https://www.hikvision.com/en/support/download/firmware/
- Requires Hikvision account login
- Most complete but restricted access
