# ZPA Demo – Zscaler Private Access Lab

A complete, hands-on demo kit for Zscaler Private Access (ZPA) built around a
typical Sales-Engineer home lab: one **Windows 11 client**, one **Windows
Server 2022**, and one **Ubuntu 22.04 Server**.

---

## What This Repo Provides

| Area | Files |
|------|-------|
| Lab architecture & setup | `docs/Lab_Setup.md` |
| End-to-end demo walkthrough | `docs/ZPA_Demo_Guide.md` |
| Ubuntu App Connector setup | `scripts/linux/setup_app_connector.sh` |
| Linux traffic generator | `scripts/linux/generate_zpa_traffic.sh` |
| App Discovery demo (Linux) | `scripts/linux/demo_discovered_apps.sh` |
| **Per-user access demo (Linux)** | **`scripts/linux/demo_user_access.sh`** |
| Windows client traffic generator | `scripts/windows/generate_zpa_traffic.ps1` |
| Windows policy-block demo | `scripts/windows/demo_policy_blocks.ps1` |
| **Per-user access demo (Windows)** | **`scripts/windows/demo_user_access.ps1`** |
| Windows Server internal-app setup | `scripts/windows/setup_internal_apps.ps1` |

---

## Quick Start

1. Read **[Lab Setup](docs/Lab_Setup.md)** to understand the topology,
   pre-requisites, and the four demo user personas (IT Admin, Engineer,
   Contractor, HR).
2. Follow **[ZPA Demo Guide](docs/ZPA_Demo_Guide.md)** for the full
   step-by-step demo flow, including:
   - Verified private-app access via ZPA
   - **Granular per-user access control** (Act 1.5 – the "wow" moment)
   - App Discovery (finding un-segmented apps)
   - Policy-block / access-denied scenarios
   - Full visibility and analytics
3. Run the relevant scripts on each machine to generate traffic and trigger
   the demo scenarios.

---

## Demo Highlights

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

### Persona Access Matrix

| Resource | bob.jones (IT) | alice.smith (Eng) | carol.white (Contractor) | dave.hr (HR) |
|----------|:--------------:|:-----------------:|:------------------------:|:------------:|
| Web Portal (80/443/8080) | ✅ | ✅ | ✅ | ❌ |
| SSH (22) | ✅ | ✅ | ❌ | ❌ |
| RDP (3389) | ✅ | ❌ | ❌ | ❌ |
| File Share (445) | ✅ | ❌ | ❌ | ❌ |
| Shadow IT / DBs | ❌ | ❌ | ❌ | ❌ |

❌ = **silent timeout** — the app is invisible to the user, not a permission error.

---

## Lab Topology

```
Internet / ZPA Cloud
        │
    ┌───┴───────────────────────────────────────────┐
    │              ZPA Tenant (cloud)                │
    │  ┌──────────────┐   ┌────────────────────────┐│
    │  │  ZPA Broker  │   │  Admin Portal          ││
    │  └──────┬───────┘   └────────────────────────┘│
    └─────────┼──────────────────────────────────────┘
              │  mTLS  (outbound-only from connector)
    ┌─────────┴──────────────────────────────────────┐
    │               Lab Network (192.168.1.0/24)      │
    │                                                  │
    │  ┌──────────────────┐  ┌──────────────────────┐ │
    │  │  Ubuntu 22.04    │  │  Windows Server 2022 │ │
    │  │  App Connector   │  │  Internal Apps:      │ │
    │  │  192.168.1.10    │  │  IIS (HTTP/HTTPS)    │ │
    │  └──────────────────┘  │  RDP (3389)          │ │
    │                         │  SMB (445)           │ │
    │                         │  192.168.1.20        │ │
    │                         └──────────────────────┘ │
    │                                                   │
    │  ┌──────────────────┐                            │
    │  │  Windows 11      │  (ZPA Client installed)    │
    │  │  192.168.1.30    │                            │
    │  └──────────────────┘                            │
    └───────────────────────────────────────────────────┘
```

---

## Repository Structure

```
zpa_demo/
├── README.md
├── docs/
│   ├── Lab_Setup.md          # Pre-requisites, topology, ZPA tenant config, user personas
│   └── ZPA_Demo_Guide.md     # Narrated 5-act demo flow for a customer meeting
└── scripts/
    ├── linux/
    │   ├── setup_app_connector.sh      # One-shot connector install & enrol
    │   ├── generate_zpa_traffic.sh     # Continuous traffic against private apps
    │   ├── demo_discovered_apps.sh     # Start services that trigger App Discovery
    │   └── demo_user_access.sh         # Per-user access demo (Act 1.5)
    └── windows/
        ├── setup_internal_apps.ps1     # IIS + RDP + SMB on Windows Server
        ├── generate_zpa_traffic.ps1    # HTTP/RDP/SMB traffic from Windows client
        ├── demo_policy_blocks.ps1      # Attempt blocked destinations & log results
        └── demo_user_access.ps1        # Per-user access demo (Act 1.5)
```
