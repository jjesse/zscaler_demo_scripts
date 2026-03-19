# Zscaler Demo – Zero Trust Exchange Lab

A complete, hands-on demo kit for **Zscaler Internet Access (ZIA)** and
**Zscaler Private Access (ZPA)**, built around a typical Sales-Engineer home
lab: one **Windows 11 client**, one **Windows Server 2022**, and one **Ubuntu
22.04 Server**.

---

## What This Repo Provides

### ZPA – Zscaler Private Access

| Area | Files |
|------|-------|
| Lab architecture & setup | `docs/zpa/Lab_Setup.md` |
| End-to-end demo walkthrough | `docs/zpa/ZPA_Demo_Guide.md` |
| Ubuntu App Connector setup | `scripts/zpa/linux/setup_app_connector.sh` |
| Linux traffic generator | `scripts/zpa/linux/generate_zpa_traffic.sh` |
| App Discovery demo (Linux) | `scripts/zpa/linux/demo_discovered_apps.sh` |
| **Per-user access demo (Linux)** | **`scripts/zpa/linux/demo_user_access.sh`** |
| Windows client traffic generator | `scripts/zpa/windows/generate_zpa_traffic.ps1` |
| Windows policy-block demo | `scripts/zpa/windows/demo_policy_blocks.ps1` |
| **Per-user access demo (Windows)** | **`scripts/zpa/windows/demo_user_access.ps1`** |
| Windows Server internal-app setup | `scripts/zpa/windows/setup_internal_apps.ps1` |

### ZIA – Zscaler Internet Access

| Area | Files |
|------|-------|
| Lab architecture & setup | `docs/zia/Lab_Setup.md` |
| End-to-end demo walkthrough | `docs/zia/ZIA_Demo_Guide.md` |
| Ubuntu ZIA client setup | `scripts/zia/linux/setup_zia_client.sh` |
| Linux traffic generator | `scripts/zia/linux/generate_zia_traffic.sh` |
| URL filtering & threat demo (Linux) | `scripts/zia/linux/demo_url_filtering.sh` |
| Windows traffic generator | `scripts/zia/windows/generate_zia_traffic.ps1` |
| **Threat protection demo (Windows)** | **`scripts/zia/windows/demo_threat_protection.ps1`** |
| **Cloud App Control demo (Windows)** | **`scripts/zia/windows/demo_cloud_app_control.ps1`** |
| **Data Loss Prevention demo (Windows)** | **`scripts/zia/windows/demo_dlp.ps1`** |

---

## Quick Start

### ZPA Demo

1. Read **[ZPA Lab Setup](docs/zpa/Lab_Setup.md)** to understand the topology,
   prerequisites, and the four demo user personas (IT Admin, Engineer,
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

1. Read **[ZIA Lab Setup](docs/zia/Lab_Setup.md)** to understand how to
   configure your ZIA tenant, enable SSL inspection, and set up URL filtering,
   Cloud App Control, and DLP policies.
2. Follow **[ZIA Demo Guide](docs/zia/ZIA_Demo_Guide.md)** for the full
   step-by-step demo flow, including:
   - SSL inspection & full visibility
   - Advanced Threat Protection (EICAR, malware, phishing)
   - Cloud App Control (sanctioned vs. personal apps)
   - Data Loss Prevention (credit cards, SSNs, confidential docs)
   - Visibility & analytics
3. Run the relevant scripts on each machine to generate traffic and trigger
   the demo scenarios.

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

- **SSL Inspection** – every HTTPS session is decrypted, inspected, and
  re-encrypted; no blind spots for encrypted threats.
- **Advanced Threat Protection** – real-time feed blocks malware, phishing,
  and C2 callbacks before they reach the endpoint.
- **Cloud App Control** – distinguish between corporate and personal tenants
  of the same app; block personal Dropbox, allow corporate OneDrive.
- **Data Loss Prevention** – 100+ built-in DLP dictionaries detect credit
  cards, SSNs, health data, and custom IP patterns in any upload.
- **Bandwidth Control** – throttle video streaming and file-sharing without
  blocking productivity apps.
- **Full Identity-Aware Logs** – every internet access event is logged with
  the user's full identity for compliance and forensic analysis.

---

### ZPA Persona Access Matrix

| Resource | bob.jones (IT) | alice.smith (Eng) | carol.white (Contractor) | dave.hr (HR) |
|----------|:--------------:|:-----------------:|:------------------------:|:------------:|
| Web Portal (80/443/8080) | ✅ | ✅ | ✅ | ❌ |
| SSH (22) | ✅ | ✅ | ❌ | ❌ |
| RDP (3389) | ✅ | ❌ | ❌ | ❌ |
| File Share (445) | ✅ | ❌ | ❌ | ❌ |
| Shadow IT / DBs | ❌ | ❌ | ❌ | ❌ |

❌ = **silent timeout** — the app is invisible to the user, not a permission error.

### ZIA Policy Matrix

| Category | Policy | Example |
|----------|--------|---------|
| Business productivity | ✅ Allow | Microsoft 365, Google Workspace, GitHub |
| Social media (view) | ⚠️ Warn/Allow | Reddit, Twitter/X (read-only) |
| Social media (post) | ❌ Block | Twitter/X (POST blocked) |
| P2P / Torrents | ❌ Block | BitTorrent, ThePirateBay |
| Malware / Phishing | ❌ Block | EICAR, known threat feeds |
| Personal cloud storage | ❌ Block | Personal Dropbox, WeTransfer |
| DLP – Credit cards | ❌ Block | Luhn-valid card numbers in uploads |
| DLP – SSNs | ❌ Block | US Social Security Number patterns |

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
│   ├── zpa/
│   │   ├── Lab_Setup.md          # ZPA prerequisites, topology, tenant config
│   │   └── ZPA_Demo_Guide.md     # Narrated 5-act ZPA demo flow
│   └── zia/
│       ├── Lab_Setup.md          # ZIA prerequisites, policy config, DLP setup
│       └── ZIA_Demo_Guide.md     # Narrated 5-act ZIA demo flow
└── scripts/
    ├── zpa/
    │   ├── linux/
    │   │   ├── setup_app_connector.sh      # One-shot ZPA connector install
    │   │   ├── generate_zpa_traffic.sh     # Continuous ZPA traffic generator
    │   │   ├── demo_discovered_apps.sh     # App Discovery demo
    │   │   └── demo_user_access.sh         # Per-user access demo (Act 1.5)
    │   └── windows/
    │       ├── setup_internal_apps.ps1     # IIS + RDP + SMB on Windows Server
    │       ├── generate_zpa_traffic.ps1    # HTTP/RDP/SMB traffic generator
    │       ├── demo_policy_blocks.ps1      # Policy-block scenarios
    │       └── demo_user_access.ps1        # Per-user access demo (Act 1.5)
    └── zia/
        ├── linux/
        │   ├── setup_zia_client.sh         # ZIA Client Connector + proxy setup
        │   ├── generate_zia_traffic.sh     # Continuous ZIA traffic generator
        │   └── demo_url_filtering.sh       # URL filtering & threat demo
        └── windows/
            ├── generate_zia_traffic.ps1    # HTTP/HTTPS ZIA traffic generator
            ├── demo_threat_protection.ps1  # EICAR + malware + phishing demo
            ├── demo_cloud_app_control.ps1  # Sanctioned vs. personal app demo
            └── demo_dlp.ps1               # DLP: CC, SSN, confidential docs
```
