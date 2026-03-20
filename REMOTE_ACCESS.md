# Remote Access Without Hik-Connect

Access your Hikvision NVR from anywhere on the internet using free DDNS and port forwarding — no cloud dependency, no Hik-Connect required.

## When to Use This

- Hik-Connect bound to an old account you can't unbind
- You prefer direct access without cloud middleman
- Hikvision servers are down or unreachable
- You want full control over your remote access

---

## Architecture

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

## DDNS Update Flow

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

## Port Forwarding Detail

```
 INTERNET                    ROUTER                         NVR
 ─────────                   ──────                         ───

 :9080 (HTTP)  ──────►  NAT: 9080 → 192.168.X.X:9080  ──────►  Web UI
 :9000 (SDK)   ──────►  NAT: 9000 → 192.168.X.X:9000  ──────►  iVMS app
 :554  (RTSP)  ──────►  NAT: 554  → 192.168.X.X:554   ──────►  Live video

 All other ports: BLOCKED (router firewall)
```

## Hik-Connect vs DDNS + Port Forward

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

---

## Step-by-Step Setup

### Step 1: Register Free DDNS Hostname

1. Sign up at [noip.com](https://www.noip.com) (free, 3 hostnames)
2. Go to **DDNS & Remote Access → DNS Records**
3. Click **Create Hostname**
   - Host: pick a name (e.g. `mynvr`)
   - Domain: `ddns.net` (or any free option)
   - Check **"Enable Dynamic DNS"**
4. Select **"DDNS Compatible Device"** as updater platform
5. Click **Generate DDNS Key** — save the username and password (shown only once!)

### Step 2: Configure DDNS on NVR

NVR Web UI → **Configuration → Network → Basic Settings → DDNS**

| Field          | Value                         |
|----------------|-------------------------------|
| Enable DDNS    | checked                       |
| DDNS Type      | NO-IP                         |
| Server Address | `dynupdate.no-ip.com`         |
| Host Name      | `all.ddnskey.com`             |
| User Name      | your DDNS Key username        |
| Password       | your DDNS Key password        |

> **Important:** Use the DDNS Key credentials, NOT your No-IP account email/password. Account credentials return `badauth`.

Or via ISAPI:
```bash
curl --digest -u "admin:PASS" -X PUT "http://NVR_IP/ISAPI/System/Network/DDNS/1" \
  -H "Content-Type: application/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<DDNS version="1.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
  <id>1</id>
  <enabled>true</enabled>
  <provider>NoIpDns</provider>
  <serverAddress>
    <addressingFormatType>hostname</addressingFormatType>
    <hostName>dynupdate.no-ip.com</hostName>
  </serverAddress>
  <deviceDomainName>all.ddnskey.com</deviceDomainName>
  <userName>YOUR_DDNS_KEY_USER</userName>
</DDNS>'
```

> **Note:** Password cannot be set via ISAPI — enter it through the web UI.

**Status should show "DDNS Normal".** If it shows "connServerfail", see [Troubleshooting](#troubleshooting).

### Step 3: Change Default Ports

Avoid port conflicts with the router and reduce bot scanning exposure.

| Service     | Default | Recommended |
|-------------|---------|-------------|
| HTTP        | 80      | 9080        |
| Server/SDK  | 8000    | 9000        |
| RTSP        | 554     | 554 (keep)  |

Via NVR Web UI: **Configuration → Network → Basic Settings → Port**

Or via ISAPI:
```bash
# Change HTTP port 80 → 9080
curl --digest -u "admin:PASS" -X PUT "http://NVR_IP/ISAPI/Security/adminAccesses/1" \
  -H "Content-Type: application/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<AdminAccessProtocol version="1.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
  <id>1</id><enabled>true</enabled>
  <protocol>HTTP</protocol><portNo>9080</portNo>
</AdminAccessProtocol>'

# Change Server/SDK port 8000 → 9000 (use new HTTP port!)
curl --digest -u "admin:PASS" -X PUT "http://NVR_IP:9080/ISAPI/Security/adminAccesses/4" \
  -H "Content-Type: application/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<AdminAccessProtocol version="1.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
  <id>4</id><enabled>true</enabled>
  <protocol>DEV_MANAGE</protocol><portNo>9000</portNo>
</AdminAccessProtocol>'
```

After changing HTTP port, local access becomes: `http://NVR_IP:9080`

### Step 4: Port Forward on Router

Open your router admin panel and add Virtual Server / Port Forwarding rules:

| Service Port | Internal IP    | Internal Port | Protocol |
|-------------|----------------|---------------|----------|
| 9080        | 192.168.X.X    | 9080          | TCP      |
| 9000        | 192.168.X.X    | 9000          | TCP      |
| 554         | 192.168.X.X    | 554           | TCP/UDP  |

> **Port 80 conflict:** Many routers use port 80 for their own web management. If you get "port conflicting with remote web management", use non-standard ports (9080, 9000) as shown above.

Also **reserve the NVR's IP** in router DHCP settings (bind MAC address to a fixed IP) so port forwarding rules don't break.

### Step 5: Test Remote Access

**From your phone on mobile data** (WiFi OFF — NAT hairpin doesn't work on most consumer routers):

- **Browser**: `http://mynvr.ddns.net:9080`
- **iVMS-4500 app**: Add device → Manual → address `mynvr.ddns.net`, port `9000`
- **RTSP**: `rtsp://admin:PASS@mynvr.ddns.net:554/Streaming/Channels/101`

> **Do NOT test from your home WiFi!** Most consumer routers (TP-Link, Netgear, etc.) don't support NAT hairpin — you'll get errors even though everything is configured correctly.

### Step 6: DNS Fix (if needed)

If DDNS status shows "connServerfail", the NVR can't resolve `dynupdate.no-ip.com`. Fix by setting Google DNS:

NVR Web UI → **Configuration → Network → Basic Settings → TCP/IP** → uncheck "Auto DNS":
- Primary DNS: `8.8.8.8`
- Secondary DNS: `8.8.4.4`

Or via ISAPI:
```bash
curl --digest -u "admin:PASS" -X PUT "http://NVR_IP/ISAPI/System/Network/interfaces/1" \
  -H "Content-Type: application/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<NetworkInterface version="1.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
  <id>1</id>
  <IPAddress version="1.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
    <ipVersion>dual</ipVersion>
    <addressingType>dynamic</addressingType>
    <PrimaryDNS><ipAddress>8.8.8.8</ipAddress></PrimaryDNS>
    <SecondaryDNS><ipAddress>8.8.4.4</ipAddress></SecondaryDNS>
    <DNSEnable>true</DNSEnable>
  </IPAddress>
</NetworkInterface>'
```

Then disable and re-enable DDNS to force a fresh connection attempt.

---

## Security Recommendations

- [ ] Change default HTTP port (80 → 9080 or higher)
- [ ] Change default server port (8000 → 9000 or higher)
- [ ] Use a strong admin password (not default `admin`/`12345`)
- [ ] Enable HTTPS on the NVR if supported
- [ ] Disable UPnP on the NVR
- [ ] Only forward the ports you need
- [ ] Do NOT forward port 23 (Telnet) or 22 (SSH)

## Maintenance

- **No-IP free tier** requires monthly email confirmation (every 30 days) or hostname pauses
- If hostname expires, reactivate at noip.com — it's not deleted, just paused
- Check DDNS status on NVR periodically (should say "Normal" / "DDNS у нормі")
- Verify your DDNS hostname resolves correctly: `nslookup mynvr.ddns.net 8.8.8.8`

## Free DDNS Alternatives

| Provider | Monthly Confirm? | NVR Built-in? | Notes |
|----------|-----------------|---------------|-------|
| **No-IP** | Yes (30 days) | Yes (native) | Easiest for Hikvision |
| DuckDNS | No | No | Needs external updater script |
| Dynu | No | No | Free, reliable |
| FreeDNS (afraid.org) | No | No | Thousands of free subdomains |

No-IP is recommended because Hikvision NVRs have a built-in NO-IP client — zero extra software needed.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| DDNS status "connServerfail" | Set DNS to `8.8.8.8` / `8.8.4.4` on NVR (see [Step 6](#step-6-dns-fix-if-needed)) |
| DDNS status "connecting" forever | Disable DDNS, wait 60s, re-enable with fresh credentials |
| Can't access from internet | Verify port forwarding rules on router |
| Works on LAN but not remotely | ISP may block port — try different port numbers |
| Can't test DDNS from home WiFi | NAT hairpin not supported on most consumer routers — test from mobile data |
| Router rejects port 80 forward | Router remote management uses port 80 — use 9080+ for NVR |
| "badauth" in No-IP | Use DDNS Key credentials, not account email/password |
| Hostname expired on No-IP | Click confirmation link in email, hostname reactivates immediately |
| NVR web UI loads but JS errors | NAT hairpin issue — access from mobile data, not home WiFi |

## Tested On

| Component | Details |
|-----------|---------|
| NVR | DS-7108NI-Q1/8P (V4.30.091) |
| Router | TP-Link Archer C50 v4 |
| DDNS | No-IP (free tier, DDNS Key auth) |
| Ports | HTTP 9080, SDK 9000, RTSP 554 |
