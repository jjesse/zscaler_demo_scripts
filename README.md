# ZPA & ZIA Demo – Zscaler Lab Kit

A complete, hands-on demo kit for **Zscaler Private Access (ZPA)** and
**Zscaler Internet Access (ZIA)** built around a typical Sales-Engineer home
lab: one **Windows 11 client**, one **Windows Server 2022**, and one
**Ubuntu 22.04 Server**.

---

## What This Repo Provides

### Zscaler Private Access (ZPA)

| Area | Files |
|------|-------|
| Lab architecture & setup | `docs/Lab_Setup.md` |
| End-to-end ZPA demo walkthrough | `docs/ZPA_Demo_Guide.md` |
| Ubuntu App Connector setup | `scripts/linux/setup_app_connector.sh` |
| Linux ZPA traffic generator | `scripts/linux/generate_zpa_traffic.sh` |
| App Discovery demo (Linux) | `scripts/linux/demo_discovered_apps.sh` |
| Per-user access demo (Linux) | `scripts/linux/demo_user_access.sh` |
| Windows ZPA traffic generator | `scripts/windows/generate_zpa_traffic.ps1` |
| Windows policy-block demo | `scripts/windows/demo_policy_blocks.ps1` |
| Per-user access demo (Windows) | `scripts/windows/demo_user_access.ps1` |
| Windows Server internal-app setup | `scripts/windows/setup_internal_apps.ps1` |

### Zscaler Internet Access (ZIA)

| Area | Files |
|------|-------|
| End-to-end ZIA demo walkthrough | `docs/ZIA_Demo_Guide.md` |
| Linux ZIA traffic generator | `scripts/linux/generate_zia_traffic.sh` |
| Linux ZIA block demo | `scripts/linux/demo_zia_blocks.sh` |
| Windows ZIA traffic generator | `scripts/windows/generate_zia_traffic.ps1` |
| Windows ZIA block demo | `scripts/windows/demo_zia_blocks.ps1` |

---

## Quick Start

### ZPA Demo

1. Read **[Lab Setup](docs/Lab_Setup.md)** to understand the topology,
   pre-requisites, and the four demo user personas (IT Admin, Engineer,
   Contractor, HR).
2. Follow **[ZPA Demo Guide](docs/zpa/ZPA_Demo_Guide.md)** for the full
   step-by-step demo flow, including:
   - Verified private-app access via ZPA
   - **Granular per-user access control** (Act 1.5 – the "wow" moment)
   - App Discovery (finding un-segmented apps)
   - Policy-block / access-denied scenarios
   - Full visibility and analytics
3. Run the relevant scripts on each machine to generate traffic and trigger
   the demo scenarios.

### ZIA Demo

1. Ensure Zscaler Client Connector is installed and connected on the Windows 11
   client and Ubuntu machine (or a ZIA PAC/proxy is configured).
2. Follow **[ZIA Demo Guide](docs/ZIA_Demo_Guide.md)** for the four-act demo:
   - SSL inspection and inline proxy visibility
   - URL filtering across News, Social, Sports, Streaming, and Business categories
   - Threat protection — malware, phishing, and C2 blocking
   - Analytics, shadow-IT discovery, and Cloud App Control
3. Run the traffic generator and block-demo scripts:
   ```powershell
   # Windows 11 – populate dashboards before the meeting
   .\scripts\windows\generate_zia_traffic.ps1

   # Windows 11 – demonstrate blocks live during the meeting
   .\scripts\windows\demo_zia_blocks.ps1
   ```
   ```bash
   # Ubuntu – same in bash
   bash scripts/linux/generate_zia_traffic.sh &
   bash scripts/linux/demo_zia_blocks.sh
   ```

---

## Demo Highlights

### ZPA Highlights

- **Zero-Trust Access** – users never connect directly to the network; every
  session is brokered through the ZPA cloud.
- **Granular Per-User Policy** – four personas (IT Admin, Engineer, Contractor,
  HR) each see a different set of applications based on their IdP group.
- **Access Denied Scenarios** – show contractors blocked from RDP and SSH,
  HR users blocked from everything, and the Shadow IT app blocked for all users.
- **App Discovery** – ZPA automatically discovers applications the connector
  can reach that aren't yet covered by a policy.
- **Real-Time Policy Push** – grant access and revoke it live; changes take
  effect in under 60 seconds with no firewall tickets.
- **Privileged Remote Access** – RDP and SSH in-browser via ZPA, with full
  session recording hooks.
- **Workload-to-Workload Segmentation** – server-to-server policies so lateral
  movement is impossible even inside the data-centre.

### ZIA Highlights

- **Inline SSL Inspection** – 100% of HTTPS traffic decrypted, inspected, and
  re-encrypted in the cloud with no device-side performance hit.
- **URL Filtering across 200+ Categories** – News, Social, Sports, Streaming,
  Gambling, Anonymizers, P2P, and more enforced in real time.
- **Traffic to Good Sites** – generates logged traffic across News, Social
  Media, Sports, Streaming, and Business categories.
- **Traffic to Bad Sites** – demonstrates ZIA blocking malware test URLs,
  phishing pages, gambling sites, anonymizers, and torrent sites.
- **Advanced Threat Protection** – EICAR malware test, phishing simulation,
  and cloud sandbox verdict shown live.
- **Shadow IT / Cloud App Control** – discover unsanctioned SaaS apps with
  risk scores; block or restrict in real time.
- **Full Analytics** – Web Insights dashboard shows every request with user
  identity, URL, category, action, and bytes.

### ZPA Persona Access Matrix

| Resource | bob.jones (IT) | alice.smith (Eng) | carol.white (Contractor) | dave.hr (HR) |
|----------|:--------------:|:-----------------:|:------------------------:|:------------:|
| Web Portal (80/443/8080) | ✅ | ✅ | ✅ | ❌ |
| SSH (22) | ✅ | ✅ | ❌ | ❌ |
| RDP (3389) | ✅ | ❌ | ❌ | ❌ |
| File Share (445) | ✅ | ❌ | ❌ | ❌ |
| Shadow IT / DBs | ❌ | ❌ | ❌ | ❌ |

❌ = **silent timeout** — the app is invisible to the user, not a permission error.

### ZIA URL Category Matrix

| Category | Example Sites | Demo Policy |
|----------|---------------|-------------|
| News | cnn.com, bbc.co.uk, reuters.com | ✅ Allow |
| Social Media | linkedin.com, twitter.com, reddit.com | ✅ Allow |
| Sports | espn.com, nfl.com, nba.com | ✅ Allow |
| Streaming | youtube.com, twitch.tv, spotify.com | ✅ Allow |
| Business | microsoft.com, salesforce.com, zoom.us | ✅ Allow |
| Gambling | bet365.com, draftkings.com | ❌ Block |
| Anonymizers | hidemyass.com, anonymouse.org | ❌ Block |
| P2P / Torrents | thepiratebay.org | ❌ Block |
| Malware (test) | eicar.org test URL | ❌ Block (Threat Protection) |
| Phishing (test) | testsafebrowsing.appspot.com | ❌ Block (Threat Protection) |

---

## Lab Topology

```
Internet / ZIA Cloud / ZPA Cloud
         │
    ┌────┴──────────────────────────────────────────────┐
    │          Zscaler Zero Trust Exchange (cloud)       │
    │  ┌──────────────┐   ┌─────────────────────────────┐│
    │  │  ZPA Broker  │   │  ZIA Gateway (SSL Inspect)  ││
    │  └──────┬───────┘   └─────────────────────────────┘│
    └─────────┼─────────────────────────────────────────┘
              │  mTLS (outbound-only from ZPA connector)
    ┌─────────┴───────────────────────────────────────────┐
    │               Lab Network (192.168.1.0/24)           │
    │                                                       │
    │  ┌──────────────────┐  ┌──────────────────────────┐  │
    │  │  Ubuntu 22.04    │  │  Windows Server 2022     │  │
    │  │  ZPA Connector   │  │  Internal Apps:          │  │
    │  │  ZIA Proxy/Client│  │  IIS (HTTP/HTTPS)        │  │
    │  │  192.168.1.10    │  │  RDP (3389)              │  │
    │  └──────────────────┘  │  SMB (445)               │  │
    │                         │  192.168.1.20            │  │
    │                         └──────────────────────────┘  │
    │                                                        │
    │  ┌──────────────────┐                                 │
    │  │  Windows 11      │  (ZPA + ZIA Client installed)   │
    │  │  192.168.1.30    │                                 │
    │  └──────────────────┘                                 │
    └────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
zscaler_demo/
├── README.md
├── docs/
│   ├── Lab_Setup.md          # Pre-requisites, topology, ZPA tenant config, user personas
│   ├── ZPA_Demo_Guide.md     # Narrated 5-act ZPA demo flow for a customer meeting
│   └── ZIA_Demo_Guide.md     # Narrated 4-act ZIA demo flow for a customer meeting
└── scripts/
    ├── linux/
    │   ├── setup_app_connector.sh      # One-shot ZPA connector install & enrol
    │   ├── generate_zpa_traffic.sh     # Continuous traffic against private apps (ZPA)
    │   ├── demo_discovered_apps.sh     # Start services that trigger ZPA App Discovery
    │   ├── demo_user_access.sh         # ZPA per-user access demo (Act 1.5)
    │   ├── generate_zia_traffic.sh     # Traffic to internet sites across URL categories (ZIA)
    │   └── demo_zia_blocks.sh          # Attempt blocked/malicious URLs — show ZIA blocks
    └── windows/
        ├── setup_internal_apps.ps1     # IIS + RDP + SMB on Windows Server
        ├── generate_zpa_traffic.ps1    # HTTP/RDP/SMB traffic from Windows client (ZPA)
        ├── demo_policy_blocks.ps1      # Attempt blocked ZPA destinations & log results
        ├── demo_user_access.ps1        # ZPA per-user access demo (Act 1.5)
        ├── generate_zia_traffic.ps1    # Traffic to internet sites across URL categories (ZIA)
        └── demo_zia_blocks.ps1         # Attempt blocked/malicious URLs — show ZIA blocks
```
