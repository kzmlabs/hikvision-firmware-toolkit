# Firmware Files

Firmware files are too large for GitHub. Download them from the sources below.

## Working Firmware for DS-7108NI-Q1/8P (device_class 0x5DE)

### V3.4.x — Password Reset (16MB)

**Use this for initial password reset via TFTP.**

- **Source:** FIESA Mirror (open directory)
- **URL:** https://descargas.fiesa.com.ar/descargas/Hikvision/Firmware/NVRS/DS-7108NI-Q18P/digicap.dav
- **Size:** 16,007,532 bytes
- **SHA256:** Verify after download

```bash
# Download:
curl -L -o digicap.dav "https://descargas.fiesa.com.ar/descargas/Hikvision/Firmware/NVRS/DS-7108NI-Q18P/digicap.dav"
```

### V4.30.080 — Upgrade to V4 (16MB)

**Use this to upgrade from V3.4.x to V4.30.**

- **Source:** Hikvision EU Portal
- **Path:** Technical Materials → 02 NVR → 00 Product Firmware → 06 Q-series → [7100NI-Q1] → V4.30.080 build210412
- **Package:** NVR_K75_BL_ML_A_NEU_V4.30.080_210412.zip
- **URL:** https://www.hikvisioneurope.com/eu/portal/ (navigate to path above)
- **Size:** digicap.dav = 16,073,068 bytes inside the zip

> **Important:** This is the K75 "NEU" (neutral) variant from the `[7100NI-Q1]` folder. Do NOT use firmware from `[76NI-Q1(Q2)]` — it will be rejected!

### V4.30.091 — Official from Hikvision Support (16MB)

**Best option — contact Hikvision support for your specific serial number.**

- **Source:** Hikvision Technical Support
- **How to get:** Email techsupport.usa@mailservice.hikvision.com with your serial number
- **Size:** 16,036,204 bytes

## Firmware That Does NOT Work (device_class 0x5DE)

These were tested and **rejected** with "upgrade packet mismatch":

| Package | Source | Size | Result |
|---------|--------|------|--------|
| NVR_K74_BL_ML_STD_V4.30.085 | [76NI-Q1(Q2)] | 32MB | REJECTED |
| NVR_K9B2_BL_ML_STD_V4.31.102 | [76NI-Q1(Q2)](C) | 31MB | REJECTED |
| DS-7108NI-Q1/8P_V4.31.115 | fiesa.com.ar | 16MB | REJECTED |
| DS-7108NI-Q18P_V4.76.107 | fiesa.com.ar | 16MB | REJECTED |

## For Other Models

If you have a different Hikvision NVR model:

1. Note your `device_class` from the TFTP error message
2. Try firmware from different folders on the EU portal
3. Look for "NEU" (neutral) variants
4. Contact Hikvision support with your serial number — they have region-specific firmware

## Firmware Sources

| Source | URL | Notes |
|--------|-----|-------|
| Hikvision EU Portal | https://www.hikvisioneurope.com/eu/portal/ | Best selection, organized by model |
| FIESA Mirror | https://descargas.fiesa.com.ar/descargas/Hikvision/Firmware/NVRS/ | Open directory, easy to browse |
| Hikvision Global | https://www.hikvision.com/en/support/download/firmware/ | Requires login |
| Hikvision Support | techsupport.usa@mailservice.hikvision.com | For region-specific firmware |
