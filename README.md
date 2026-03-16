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
| Windows client traffic generator | `scripts/windows/generate_zpa_traffic.ps1` |
| Windows policy-block demo | `scripts/windows/demo_policy_blocks.ps1` |
| Windows Server internal-app setup | `scripts/windows/setup_internal_apps.ps1` |

---

## Quick Start

1. Read **[Lab Setup](docs/Lab_Setup.md)** to understand the topology and
   pre-requisites.
2. Follow **[ZPA Demo Guide](docs/ZPA_Demo_Guide.md)** for the full
   step-by-step demo flow, including:
   - Verified private-app access via ZPA
   - App Discovery (finding un-segmented apps)
   - Policy-block scenarios
3. Run the relevant scripts on each machine to generate traffic and trigger
   the demo scenarios.

---

## Demo Highlights

- **Zero-Trust Access** – users never connect directly to the network; every
  session is brokered through the ZPA cloud.
- **App Discovery** – ZPA automatically discovers applications the connector
  can reach that aren't yet covered by a policy.
- **Granular Policy Blocks** – show in real time what happens when a user
  tries to reach an app they are not entitled to.
- **Privileged Remote Access** – RDP and SSH in-browser via ZPA, with full
  session recording hooks.
- **Workload-to-Workload Segmentation** – server-to-server policies so lateral
  movement is impossible even inside the data-centre.

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
│   ├── Lab_Setup.md          # Pre-requisites, topology, ZPA tenant config
│   └── ZPA_Demo_Guide.md     # Narrated demo flow for a customer meeting
└── scripts/
    ├── linux/
    │   ├── setup_app_connector.sh      # One-shot connector install & enrol
    │   ├── generate_zpa_traffic.sh     # Continuous traffic against private apps
    │   └── demo_discovered_apps.sh     # Start services that trigger App Discovery
    └── windows/
        ├── setup_internal_apps.ps1     # IIS + RDP + SMB on Windows Server
        ├── generate_zpa_traffic.ps1    # HTTP/RDP/SMB traffic from Windows client
        └── demo_policy_blocks.ps1      # Attempt blocked destinations & log results
```
