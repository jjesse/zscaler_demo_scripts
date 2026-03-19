# ZPA, ZIA & ZDX Demo – Zscaler Lab Kit

A complete, hands-on demo kit for **Zscaler Private Access (ZPA)**,
**Zscaler Internet Access (ZIA)**, and **Zscaler Digital Experience (ZDX)**
built around a typical Sales-Engineer home lab: one **Windows 11 client**, one
**Windows Server 2022**, and one **Ubuntu 22.04 Server**.

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

### Zscaler Digital Experience (ZDX)

| Area | Files |
|------|-------|
| End-to-end ZDX demo walkthrough | `docs/zdx/ZDX_Demo_Guide.md` |
| Windows ZDX good/poor score demo | `scripts/zdx/windows/demo_zdx_scores.ps1` |
| Linux ZDX good/poor score demo | `scripts/zdx/linux/demo_zdx_scores.sh` |

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

### ZDX Demo

1. Ensure Zscaler Client Connector (v3.7+) is installed and **Connected** on
   the Windows 11 client and Ubuntu machine — ZDX data collection is built into
   the Client Connector.
2. Follow **[ZDX Demo Guide](docs/zdx/ZDX_Demo_Guide.md)** for the four-act demo:
   - ZDX Score Dashboard — real-time view of every user's digital experience
   - Path Tracing & Root Cause — pinpoint exactly where experience is poor
   - **Good scores vs poor scores** — live contrast shown in the ZDX portal
   - Proactive Alerting & Remediation — fix problems before users call IT
3. Run the score simulation scripts:
   ```powershell
   # Windows 11 – baseline good score (run 10 min before the meeting)
   .\scripts\zdx\windows\demo_zdx_scores.ps1 -Scenario Good

   # Windows 11 – degrade experience live during the meeting
   .\scripts\zdx\windows\demo_zdx_scores.ps1 -Scenario Poor

   # Windows 11 – restore healthy state after the demo
   .\scripts\zdx\windows\demo_zdx_scores.ps1 -Scenario Restore
   ```
   ```bash
   # Ubuntu – same in bash
   bash scripts/zdx/linux/demo_zdx_scores.sh --scenario good &
   bash scripts/zdx/linux/demo_zdx_scores.sh --scenario poor
   bash scripts/zdx/linux/demo_zdx_scores.sh --scenario restore
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

### ZDX Highlights

- **Real-Time ZDX Score Dashboard** – every endpoint shown as a coloured dot
  (green / yellow / orange / red) so IT sees problems before users call.
- **Good Score vs Poor Score Demo** – run the simulation scripts live and watch
  the score drop from 80+ (green) to below 40 (red) in the portal.
- **End-to-End Path Tracing** – ZDX shows latency and packet loss at every hop
  from device → Wi-Fi → corporate network → Zscaler PoP → ISP → SaaS app.
- **Device Health Metrics** – CPU, RAM, battery, and Wi-Fi signal from the
  endpoint, so IT can distinguish network problems from device problems.
- **Per-Application Scoring** – independent scores for Microsoft 365, Zoom,
  Salesforce, Workday, and any custom SaaS application.
- **Proactive Alerting** – alerts fire on score thresholds before the help desk
  receives a single ticket.
- **No Additional Agent** – ZDX is built into Zscaler Client Connector; if ZPA
  or ZIA is deployed, ZDX can be enabled instantly.

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
│   ├── ZIA_Demo_Guide.md     # Legacy ZIA demo guide (see docs/zia/ for the full kit)
│   ├── zia/
│   │   ├── Lab_Setup.md          # ZIA pre-requisites and topology
│   │   └── ZIA_Demo_Guide.md     # Narrated 5-act ZIA demo flow for a customer meeting
│   ├── zpa/
│   │   ├── Lab_Setup.md          # ZPA pre-requisites, topology, user personas
│   │   └── ZPA_Demo_Guide.md     # Narrated 5-act ZPA demo flow for a customer meeting
│   └── zdx/
│       └── ZDX_Demo_Guide.md     # Narrated 4-act ZDX demo: good scores, poor scores, path tracing
└── scripts/
    ├── linux/                      # Legacy Linux scripts
    ├── windows/                    # Legacy Windows scripts
    ├── zia/
    │   ├── linux/
    │   │   ├── setup_zia_client.sh         # ZIA Client Connector install
    │   │   ├── generate_zia_traffic.sh     # Traffic across URL categories
    │   │   └── demo_url_filtering.sh       # Demonstrate URL filter blocks
    │   └── windows/
    │       ├── generate_zia_traffic.ps1    # Traffic across URL categories (Windows)
    │       ├── demo_threat_protection.ps1  # EICAR and phishing block demo
    │       ├── demo_cloud_app_control.ps1  # Sanctioned vs unsanctioned app demo
    │       └── demo_dlp.ps1                # DLP credit-card / SSN block demo
    ├── zpa/
    │   ├── linux/
    │   │   ├── setup_app_connector.sh      # One-shot ZPA connector install & enrol
    │   │   ├── generate_zpa_traffic.sh     # Continuous traffic against private apps
    │   │   ├── demo_discovered_apps.sh     # Start services that trigger App Discovery
    │   │   └── demo_user_access.sh         # ZPA per-user access demo (Act 1.5)
    │   └── windows/
    │       ├── setup_internal_apps.ps1     # IIS + RDP + SMB on Windows Server
    │       ├── generate_zpa_traffic.ps1    # HTTP/RDP/SMB traffic from Windows client
    │       ├── demo_policy_blocks.ps1      # Attempt blocked ZPA destinations & log results
    │       └── demo_user_access.ps1        # ZPA per-user access demo (Act 1.5)
    └── zdx/
        ├── linux/
        │   └── demo_zdx_scores.sh          # Simulate good/poor ZDX scores (Linux)
        └── windows/
            └── demo_zdx_scores.ps1         # Simulate good/poor ZDX scores (Windows)
```
