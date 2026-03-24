# Firmware Files

## NVR Firmware (DS-7108NI-Q1/8P, device_class 0x5DE)

| File | Version | Use For | Size |
|------|---------|---------|------|
| `digicap.dav` | V3.4.x | Password reset via TFTP | 22 MB |
| `v4.30.080_K75_NEU_digicap.dav` | V4.30.080 | Upgrade to V4 | 16 MB |
| `v4.30.091_official_digicap.dav` | V4.30.091 | Best option (from Hikvision support) | 16 MB |

> V4 firmware uses K75 "NEU" variant from `[7100NI-Q1]` folder. Firmware from `[76NI-Q1(Q2)]` will be rejected.

## Camera Firmware

| File | Platform | Models | Size |
|------|----------|--------|------|
| `IPC_E3_EN_STD_5.5.92_190227.zip` | E3 | DS-2CD1323G0-IU | 22 MB |
| `IPC_E4_EN_STD_5.5.801_210701.zip` | E4 | DS-2CD1121-I | 15 MB |
| `e4_new/digicap.dav` | E4 | Extracted, ready for TFTP | 15 MB |

> Camera firmware must be newer or equal to current version (anti-rollback protection).

## Download Sources

| Source | URL |
|--------|-----|
| Hikvision EU Portal | https://www.hikvisioneurope.com/eu/portal/ |
| FIESA Mirror | https://descargas.fiesa.com.ar/descargas/Hikvision/Firmware/ |
| Hikvision Global | https://www.hikvision.com/en/support/download/firmware/ |
